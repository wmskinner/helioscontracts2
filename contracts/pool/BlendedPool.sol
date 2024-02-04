// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AbstractPool} from "./AbstractPool.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";
import {Pool} from "./Pool.sol";

/// @title Blended Pool
contract BlendedPool is AbstractPool {
    event RegPoolDeposit(address indexed regPool, uint256 amount);

    constructor(
        address _liquidityAsset,
        address _liquidityLockerFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_liquidityAsset, _liquidityLockerFactory, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        poolInfo = PoolLibrary.PoolInfo(_lockupPeriod, _apy, _duration, type(uint256).max, _minInvestmentAmount, _withdrawThreshold);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external override whenProtocolNotPaused nonReentrant {
        _depositLogic(_amount, liquidityLocker.liquidityAsset());
    }

    /// @notice Used to distribute yields among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    function distributeYields(uint256 _amount) external override onlyAdmin nonReentrant {
        require(_amount > 0, "BP:INVALID_VALUE");

        for (uint256 i = 0; i < depositsHolder.getHoldersCount(); i++) {
            address holder = depositsHolder.getHolderByIndex(i);
            uint256 holderBalance = balanceOf(holder);
            uint256 holderShare = (_amount * holderBalance) / totalSupply();
            yields[holder] += holderShare;
        }
    }

    /// @notice Only called by a RegPool when it doesn't have enough Liquidity Assets
    function requestLiquidityAssets(uint256 _amountMissing) external onlyPool {
        require(_amountMissing > 0, "BP:INVALID_INPUT");
        require(liquidityLockerTotalBalance() >= _amountMissing, "BP:NOT_ENOUGH_LA_BP");
        address poolLiquidityLocker = AbstractPool(msg.sender).getLiquidityLocker();
        require(_transferLiquidityLockerFunds(poolLiquidityLocker, _amountMissing), "BP:REQUEST_FROM_BP_FAIL");

        emit RegPoolDeposit(msg.sender, _amountMissing);
    }

    /*
    Modifiers
    */

    modifier onlyPool() {
        require(poolFactory.isValidPool(msg.sender), "P:NOT_POOL");
        _;
    }
}
