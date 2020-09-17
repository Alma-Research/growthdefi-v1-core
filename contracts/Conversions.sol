// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Addresses } from "./Addresses.sol";
import { Transfers } from "./Transfers.sol";
import { Swap } from "./interop/Curve.sol";
import { Router02 } from "./interop/UniswapV2.sol";

contract Conversions is Addresses, Transfers
{
	function _calcConversionDAIToUSDCGivenDAI(uint256 _inputAmount) internal view returns (uint256 _outputAmount)
	{
		address _swap = Curve_COMPOUND;
		return Swap(_swap).get_dy_underlying(0, 1, _inputAmount);
	}

	function _calcConversionDAIToUSDCGivenUSDC(uint256 _outputAmount) internal view returns (uint256 _inputAmount)
	{
		address _swap = Curve_COMPOUND;
		return Swap(_swap).get_dx_underlying(0, 1, _outputAmount);
	}

	function _calcConversionUSDCToDAIGivenUSDC(uint256 _inputAmount) internal view returns (uint256 _outputAmount)
	{
		address _swap = Curve_COMPOUND;
		return Swap(_swap).get_dy_underlying(1, 0, _inputAmount);
	}

	function _calcConversionUSDCToDAIGivenDAI(uint256 _outputAmount) internal view returns (uint256 _inputAmount)
	{
		address _swap = Curve_COMPOUND;
		return Swap(_swap).get_dx_underlying(1, 0, _outputAmount);
	}

	function _convertFundsUSDCToDAI(uint256 _amount) internal
	{
		address _swap = Curve_COMPOUND;
		address _token = Swap(_swap).underlying_coins(1);
		_approveFunds(_token, _swap, _amount);
		Swap(_swap).exchange_underlying(1, 0, _amount, 0);
	}

	function _convertFundsDAIToUSDC(uint256 _amount) internal
	{
		address _swap = Curve_COMPOUND;
		address _token = Swap(_swap).underlying_coins(0);
		_approveFunds(_token, _swap, _amount);
		Swap(_swap).exchange_underlying(0, 1, _amount, 0);
	}

	function _convertFundsCOMPToDAI(uint256 _amount) internal
	{
		if (_amount == 0) return;
		address _router = UniswapV2_ROUTER02;
		address _token = COMP;
		address[] memory _path = new address[](3);
		_path[0] = _token;
		_path[1] = Router02(_router).WETH();
		_path[2] = DAI;
		_approveFunds(_token, _router, _amount);
		Router02(_router).swapExactTokensForTokens(_amount, 0, _path, address(this), block.timestamp);
	}
}