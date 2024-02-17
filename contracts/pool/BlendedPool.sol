// SPDX-License-Identifier: MIT
// @author Tigran Arakelyan
pragma solidity 0.8.20;

import {AbstractPool} from "./AbstractPool.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";
import {Pool} from "./Pool.sol";

/// @title Blended Pool
contract BlendedPool is AbstractPool {
    event RegPoolDeposit(address indexed regPool, uint256 amount);

    constructor(
        address _asset,
        uint256 _lockupPeriod,
        uint256 _duration,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_asset, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        poolInfo = PoolLibrary.PoolInfo(
            _lockupPeriod,
            _duration,
            type(uint256).max,
            _minInvestmentAmount,
            _withdrawThreshold);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external override whenProtocolNotPaused nonReentrant {
        _depositLogic(_amount);
    }

    /// @notice Only called by a RegPool when it doesn't have enough Assets
    function requestAssets(uint256 _amountMissing) external onlyPool {
        require(_amountMissing > 0, "BP:INVALID_INPUT");
        require(totalBalance() >= _amountMissing, "BP:NOT_ENOUGH_LA_BP");

        _transferFunds(msg.sender, _amountMissing);

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
