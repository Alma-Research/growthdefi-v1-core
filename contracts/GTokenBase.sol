// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { Addresses } from "./Addresses.sol";
import { Transfers } from "./Transfers.sol";
import { GToken } from "./GToken.sol";
import { BFactory, BPool } from "./interop/Balancer.sol";

contract GFormulae
{
	using SafeMath for uint256;

	function _calcDepositSharesFromCost(uint256 _cost, uint256 _totalReserve, uint256 _totalSupply, uint256 _depositFee) internal pure returns (uint256 _netShares, uint256 _feeShares)
	{
		uint256 _grossShares = _totalReserve == _totalSupply ? _cost : _cost.mul(_totalSupply).div(_totalReserve);
		_netShares = _grossShares.mul(1e18).div(uint256(1e18).add(_depositFee));
		_feeShares = _grossShares.sub(_netShares);
		return (_netShares, _feeShares);
	}

	function _calcDepositCostFromShares(uint256 _netShares, uint256 _totalReserve, uint256 _totalSupply, uint256 _depositFee) internal pure returns (uint256 _cost, uint256 _feeShares)
	{
		uint256 _grossShares = _netShares.mul(uint256(1e18).add(_depositFee)).div(1e18);
		_cost = _totalReserve == _totalSupply ? _grossShares : _grossShares.mul(_totalReserve).div(_totalSupply);
		_feeShares = _grossShares.sub(_netShares);
		return (_cost, _feeShares);
	}

	function _calcWithdrawalSharesFromCost(uint256 _cost, uint256 _totalReserve, uint256 _totalSupply, uint256 _withdrawalFee) internal pure returns (uint256 _grossShares, uint256 _feeShares)
	{
		uint256 _netShares = _totalReserve == _totalSupply ? _cost : _cost.mul(_totalSupply).div(_totalReserve);
		_grossShares = _netShares.mul(1e18).div(uint256(1e18).sub(_withdrawalFee));
		_feeShares = _grossShares.sub(_netShares);
		return (_grossShares, _feeShares);
	}

	function _calcWithdrawalCostFromShares(uint256 _grossShares, uint256 _totalReserve, uint256 _totalSupply, uint256 _withdrawalFee) internal pure returns (uint256 _cost, uint256 _feeShares)
	{
		uint256 _netShares = _grossShares.mul(uint256(1e18).sub(_withdrawalFee)).div(1e18);
		_cost = _totalReserve == _totalSupply ? _netShares : _netShares.mul(_totalReserve).div(_totalSupply);
		_feeShares = _grossShares.sub(_netShares);
		return (_cost, _feeShares);
	}
}

contract BalancerLiquidityPoolAbstraction is Transfers
{
	using SafeMath for uint256;

	uint256 constant MIN_AMOUNT = 1e6;
	uint256 constant TOKEN0_WEIGHT = 25e18; // 25/50 = 50%
	uint256 constant TOKEN1_WEIGHT = 25e18; // 25/50 = 50%
	uint256 constant SWAP_FEE = 10e16; // 10%

	function _createPool(address _token0, uint256 _amount0, address _token1, uint256 _amount1) internal returns (address _pool)
	{
		require(_amount0 >= MIN_AMOUNT && _amount1 >= MIN_AMOUNT, "amount below the minimum");
		_pool = BFactory(Addresses.Balancer_FACTORY).newBPool();
		_approveFunds(_token0, _pool, _amount0);
		_approveFunds(_token1, _pool, _amount1);
		BPool(_pool).bind(_token0, _amount0, TOKEN0_WEIGHT);
		BPool(_pool).bind(_token1, _amount1, TOKEN1_WEIGHT);
		BPool(_pool).setSwapFee(SWAP_FEE);
		BPool(_pool).finalize();
		return _pool;
	}

	function _joinPool(address _pool, uint256 _maxAmount1) internal returns (uint256 _amount1)
	{
		address[] memory _tokens = BPool(_pool).getFinalTokens();
		address _token1 = _tokens[1];
		uint256 _balanceAmount1 = BPool(_pool).getBalance(_token1);
		if (_balanceAmount1 == 0) return 0;
		uint256 _limitAmount1 = _balanceAmount1.div(2);
		_amount1 = _maxAmount1 < _limitAmount1 ? _maxAmount1 : _limitAmount1;
		_approveFunds(_token1, _pool, _amount1);
		BPool(_pool).joinswapExternAmountIn(_token1, _amount1, 0);
		return _amount1;
	}

	function _exitPool(address _pool, uint256 _percent) internal returns (uint256 _amount0, uint256 _amount1)
	{
		if (_percent == 0) return (0, 0);
		address[] memory _tokens = BPool(_pool).getFinalTokens();
		_amount0 = _getBalance(_tokens[0]);
		_amount1 = _getBalance(_tokens[1]);
		uint256 _poolAmount = _getBalance(_pool);
		uint256 _poolExitAmount = _poolAmount.mul(_percent).div(1e18);
		uint256[] memory _minAmountsOut = new uint256[](2);
		_minAmountsOut[0] = 0;
		_minAmountsOut[1] = 0;
		BPool(_pool).exitPool(_poolExitAmount, _minAmountsOut);
		_amount0 = _getBalance(_tokens[0]).sub(_amount0);
		_amount1 = _getBalance(_tokens[1]).sub(_amount1);
		return (_amount0, _amount1);
	}
}

contract GLiquidityPoolManager is BalancerLiquidityPoolAbstraction
{
	enum State { Created, Allocated, Migrating, Migrated }

	uint256 constant BURNING_RATE = 5e15; // 0.5%
	uint256 constant BURNING_INTERVAL = 7 days;
	uint256 constant MIGRATION_INTERVAL = 7 days;

	address public immutable stakeToken;
	address public immutable sharesToken;

	State public state = State.Created;
	address public liquidityPool = address(0);

	uint256 public burningRate = BURNING_RATE;
	uint256 public lastBurningTime = 0;

	address public migrationRecipient = address(0);
	uint256 public migrationUnlockTime = uint256(-1);

	constructor (address _stakeToken, address _sharesToken) internal
	{
		stakeToken = _stakeToken;
		sharesToken = _sharesToken;
	}

	function _hasPool() internal view returns (bool _hasMigrated)
	{
		return state == State.Allocated || state == State.Migrating;
	}

	function _gulpPoolAssets() internal
	{
		if (_hasPool()) {
			_joinPool(liquidityPool, _getBalance(sharesToken));
		}
	}

	function _setBurningRate(uint256 _burningRate) internal
	{
		require(_burningRate <= 1e18, "invalid rate");
		burningRate = _burningRate;
	}

	function _burnPoolPortion() internal returns (uint256 _stakeAmount, uint256 _sharesAmount)
	{
		require(_hasPool(), "pool not available");
		require(now > lastBurningTime + BURNING_INTERVAL, "must wait lock interval");
		lastBurningTime = now;
		return _exitPool(liquidityPool, burningRate);
	}

	function _allocatePool(uint256 _stakeAmount, uint256 _sharesAmount) internal
	{
		require(state == State.Created, "pool cannot be allocated");
		state = State.Allocated;
		liquidityPool = _createPool(stakeToken, _stakeAmount, sharesToken, _sharesAmount);
	}

	function _initiatePoolMigration(address _migrationRecipient) internal
	{
		require(state == State.Allocated, "pool not allocated");
		state = State.Migrating;
		migrationRecipient = _migrationRecipient;
		migrationUnlockTime = now + MIGRATION_INTERVAL;
	}

	function _cancelPoolMigration() internal returns (address _migrationRecipient)
	{
		require(state == State.Migrating, "migration not initiated");
		_migrationRecipient = migrationRecipient;
		state = State.Allocated;
		migrationRecipient = address(0);
		migrationUnlockTime = uint256(-1);
		return _migrationRecipient;
	}

	function _completePoolMigration() internal returns (address _migrationRecipient, uint256 _stakeAmount, uint256 _sharesAmount)
	{
		require(state == State.Migrating, "migration not initiated");
		require(now >= migrationUnlockTime, "must wait lock interval");
		state = State.Migrated;
		(_stakeAmount, _sharesAmount) = _exitPool(liquidityPool, 1e18);
		return (migrationRecipient, _stakeAmount, _sharesAmount);
	}
}

contract GTokenBase is ERC20, Ownable, ReentrancyGuard, GToken, GFormulae, GLiquidityPoolManager
{
	uint256 constant DEPOSIT_FEE = 1e16; // 1%
	uint256 constant WITHDRAWAL_FEE = 1e16; // 1%

	address public immutable reserveToken;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _stakeToken, address _reserveToken)
		ERC20(_name, _symbol) GLiquidityPoolManager(_stakeToken, address(this)) public
	{
		_setupDecimals(_decimals);
		reserveToken = _reserveToken;
	}

	function calcDepositSharesFromCost(uint256 _cost, uint256 _totalReserve, uint256 _totalSupply, uint256 _depositFee) public pure override returns (uint256 _netShares, uint256 _feeShares)
	{
		return _calcDepositSharesFromCost(_cost, _totalReserve, _totalSupply, _depositFee);
	}

	function calcDepositCostFromShares(uint256 _netShares, uint256 _totalReserve, uint256 _totalSupply, uint256 _depositFee) public pure override returns (uint256 _cost, uint256 _feeShares)
	{
		return _calcDepositCostFromShares(_netShares, _totalReserve, _totalSupply, _depositFee);
	}

	function calcWithdrawalSharesFromCost(uint256 _cost, uint256 _totalReserve, uint256 _totalSupply, uint256 _withdrawalFee) public pure override returns (uint256 _grossShares, uint256 _feeShares)
	{
		return _calcWithdrawalSharesFromCost(_cost, _totalReserve, _totalSupply, _withdrawalFee);
	}

	function calcWithdrawalCostFromShares(uint256 _grossShares, uint256 _totalReserve, uint256 _totalSupply, uint256 _withdrawalFee) public pure override returns (uint256 _cost, uint256 _feeShares)
	{
		return _calcWithdrawalCostFromShares(_grossShares, _totalReserve, _totalSupply, _withdrawalFee);
	}

	function depositFee() public view returns (uint256 _depositFee) {
		return _hasPool() ? DEPOSIT_FEE : 0;
	}

	function withdrawalFee() public view returns (uint256 _withdrawalFee) {
		return _hasPool() ? WITHDRAWAL_FEE : 0;
	}

	function totalReserve() public virtual override returns (uint256 _totalReserve)
	{
		return _getBalance(reserveToken);
	}

	function deposit(uint256 _cost) external override nonReentrant
	{
		address _from = msg.sender;
		require(_cost > 0, "deposit cost must be greater than 0");
		(uint256 _netShares, uint256 _feeShares) = calcDepositSharesFromCost(_cost, totalReserve(), totalSupply(), depositFee());
		require(_netShares > 0, "deposit shares must be greater than 0");
		_pullFunds(reserveToken, _from, _cost);
		_mint(_from, _netShares);
		_mint(sharesToken, _feeShares.div(2));
		_gulpPoolAssets();
	}

	function withdraw(uint256 _grossShares) external override nonReentrant
	{
		address _from = msg.sender;
		require(_grossShares > 0, "withdrawal shares must be greater than 0");
		(uint256 _cost, uint256 _feeShares) = calcWithdrawalCostFromShares(_grossShares, totalReserve(), totalSupply(), withdrawalFee());
		require(_cost > 0, "withdrawal cost must be greater than 0");
		_pushFunds(reserveToken, _from, _cost);
		_burn(_from, _grossShares);
		_mint(sharesToken, _feeShares.div(2));
		_gulpPoolAssets();
	}

	function allocateLiquidityPool(uint256 _stakeAmount, uint256 _sharesAmount) public override onlyOwner nonReentrant
	{
		address _from = msg.sender;
		_pullFunds(stakeToken, _from, _stakeAmount);
		_transfer(_from, sharesToken, _sharesAmount);
		_allocatePool(_stakeAmount, _sharesAmount);
	}

	function setLiquidityPoolBurningRate(uint256 _burningRate) public override onlyOwner nonReentrant
	{
		_setBurningRate(_burningRate);
	}

	function burnLiquidityPoolPortion() public override onlyOwner nonReentrant
	{
		(uint256 _stakeAmount, uint256 _sharesAmount) = _burnPoolPortion();
		_pushFunds(stakeToken, address(0), _stakeAmount);
		_burn(sharesToken, _sharesAmount);
		emit BurnLiquidityPoolPortion(_stakeAmount, _sharesAmount);
	}

	function initiateLiquidityPoolMigration(address _migrationRecipient) public override onlyOwner nonReentrant
	{
		_initiatePoolMigration(_migrationRecipient);
		emit InitiateLiquidityPoolMigration(_migrationRecipient);
	}

	function cancelLiquidityPoolMigration() public override onlyOwner nonReentrant
	{
		address _migrationRecipient = _cancelPoolMigration();
		emit CancelLiquidityPoolMigration(_migrationRecipient);
	}

	function completeLiquidityPoolMigration() public override onlyOwner nonReentrant
	{
		(address _migrationRecipient, uint256 _stakeAmount, uint256 _sharesAmount) = _completePoolMigration();
		_pushFunds(stakeToken, _migrationRecipient, _stakeAmount);
		_transfer(sharesToken, _migrationRecipient, _sharesAmount);
		emit CompleteLiquidityPoolMigration(_migrationRecipient, _stakeAmount, _sharesAmount);
	}

	event BurnLiquidityPoolPortion(uint256 _stakeAmount, uint256 _sharesAmount);
	event InitiateLiquidityPoolMigration(address indexed _migrationRecipient);
	event CancelLiquidityPoolMigration(address indexed _migrationRecipient);
	event CompleteLiquidityPoolMigration(address indexed _migrationRecipient, uint256 _stakeAmount, uint256 _sharesAmount);
}