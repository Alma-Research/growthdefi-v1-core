// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import { GTokenType0 } from "./GTokenType0.sol";
import { GCTokenType1 } from "./GCTokenType1.sol";
import { GCTokenType2 } from "./GCTokenType2.sol";

import { $ } from "./network/$.sol";

/**
 * @notice Definition of gDAI. As a gToken Type 0, it uses DAI as reserve and
 * distributes to other gToken types.
 */
contract gDAI is GTokenType0
{
	constructor ()
		GTokenType0("growth DAI", "gDAI", 18, $.GRO, $.DAI) public
	{
	}
}

/**
 * @notice Definition of gUSDC. As a gToken Type 0, it uses USDC as reserve and
 * distributes to other gToken types.
 */
contract gUSDC is GTokenType0
{
	constructor ()
		GTokenType0("growth USDC", "gUSDC", 6, $.GRO, $.USDC) public
	{
	}
}

/**
 * @notice Definition of gUSDT. As a gToken Type 0, it uses USDT as reserve and
 * distributes to other gToken types.
 */
contract gUSDT is GTokenType0
{
	constructor ()
		GTokenType0("growth USDT", "gUSDT", 6, $.GRO, $.USDT) public
	{
	}
}

/**
 * @notice Definition of gETH. As a gToken Type 0, it uses WETH as reserve and
 * distributes to other gToken types.
 */
contract gETH is GTokenType0
{
	constructor ()
		GTokenType0("growth ETH", "gETH", 18, $.GRO, $.WETH) public
	{
	}
}

/**
 * @notice Definition of gWBTC. As a gToken Type 0, it uses WBTC as reserve and
 * distributes to other gToken types.
 */
contract gWBTC is GTokenType0
{
	constructor ()
		GTokenType0("growth WBTC", "gWBTC", 8, $.GRO, $.WBTC) public
	{
	}
}

/**
 * @notice Definition of gBAT. As a gToken Type 0, it uses BAT as reserve and
 * distributes to other gToken types.
 */
contract gBAT is GTokenType0
{
	constructor ()
		GTokenType0("growth BAT", "gBAT", 18, $.GRO, $.BAT) public
	{
	}
}

/**
 * @notice Definition of gZRX. As a gToken Type 0, it uses ZRX as reserve and
 * distributes to other gToken types.
 */
contract gZRX is GTokenType0
{
	constructor ()
		GTokenType0("growth ZRX", "gZRX", 18, $.GRO, $.ZRX) public
	{
	}
}

/**
 * @notice Definition of gUNI. As a gToken Type 0, it uses UNI as reserve and
 * distributes to other gToken types.
 */
contract gUNI is GTokenType0
{
	constructor ()
		GTokenType0("growth UNI", "gUNI", 18, $.GRO, $.UNI) public
	{
	}
}

/**
 * @notice Definition of gCOMP. As a gToken Type 0, it uses COMP as reserve and
 * distributes to other gToken types.
 */
contract gCOMP is GTokenType0
{
	constructor ()
		GTokenType0("growth COMP", "gCOMP", 18, $.GRO, $.COMP) public
	{
	}
}

/**
 * @notice Definition of gcDAI. As a gcToken Type 1, it uses cDAI as reserve
 * and employs leverage to maximize returns.
 */
contract gcDAI is GCTokenType1
{
	constructor ()
		GCTokenType1("growth cDAI", "gcDAI", 8, $.GRO, $.cDAI, $.COMP) public
	{
	}
}

/**
 * @notice Definition of gcUSDC. As a gcToken Type 1, it uses cUSDC as reserve
 * and employs leverage to maximize returns.
 */
contract gcUSDC is GCTokenType1
{
	constructor ()
		GCTokenType1("growth cUSDC", "gcUSDC", 8, $.GRO, $.cUSDC, $.COMP) public
	{
	}
}

/**
 * @notice Definition of gcUSDT. As a gcToken Type 1, it uses cUSDT as reserve
 * and employs leverage to maximize returns.
 */
contract gcUSDT is GCTokenType1
{
	constructor ()
		GCTokenType1("growth cUSDT", "gcUSDT", 8, $.GRO, $.cUSDT, $.COMP) public
	{
	}
}

/**
 * @notice Definition of gcETH. As a gcToken Type 2, it uses cETH as reserve
 * which serves as collateral for minting gcUSDC.
 */
contract gcETH is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cETH", "gcETH", 8, $.GRO, $.cETH, $.COMP, _growthToken) public
	{
	}

	receive() external payable {} // not to be used directly
}

/**
 * @notice Definition of gcWBTC. As a gcToken Type 2, it uses cWBTC as reserve
 * which serves as collateral for minting gcUSDC.
 */
contract gcWBTC is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cWBTC", "gcWBTC", 8, $.GRO, $.cWBTC, $.COMP, _growthToken) public
	{
	}
}

/**
 * @notice Definition of gcBAT. As a gcToken Type 2, it uses cBAT as reserve
 * which serves as collateral for minting gcUSDC.
 */
contract gcBAT is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cBAT", "gcBAT", 8, $.GRO, $.cBAT, $.COMP, _growthToken) public
	{
	}
}

/**
 * @notice Definition of gcZRX. As a gcToken Type 2, it uses cZRX as reserve
 * which serves as collateral for minting gcUSDC.
 */
contract gcZRX is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cZRX", "gcZRX", 8, $.GRO, $.cZRX, $.COMP, _growthToken) public
	{
	}
}

/**
 * @notice Definition of gcUNI. As a gcToken Type 2, it uses cUNI as reserve
 * which serves as collateral for minting gcUSDC.
 */
contract gcUNI is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cUNI", "gcUNI", 8, $.GRO, $.cUNI, $.COMP, _growthToken) public
	{
	}
}

/**
 * @notice Definition of gcCOMP. As a gcToken Type 2, it uses cCOMP as reserve
 * which serves as collateral for minting gcUSDC.
 */
contract gcCOMP is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cCOMP", "gcCOMP", 8, $.GRO, $.cCOMP, $.COMP, _growthToken) public
	{
	}
}
