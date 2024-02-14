// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AbstractPool} from "./AbstractPool.sol";
import {BlendedPool} from "./BlendedPool.sol";
import {PoolLibrary} from "../library/PoolLibrary.sol";

// Pool maintains all accounting and functionality related to Pools
contract Pool is AbstractPool {
    constructor(
        address _asset,
        uint256 _lockupPeriod,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount,
        uint256 _withdrawThreshold,
        uint256 _withdrawPeriod
    ) AbstractPool(_asset, NAME, SYMBOL, _withdrawThreshold, _withdrawPeriod) {
        poolInfo = PoolLibrary.PoolInfo(_lockupPeriod, _duration, _investmentPoolSize, _minInvestmentAmount, _withdrawThreshold);
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external override whenProtocolNotPaused nonReentrant {
        require(totalSupply() + _amount <= poolInfo.investmentPoolSize, "P:MAX_POOL_SIZE_REACHED");

        _depositLogic(_amount);
    }

    function _calculateYield(address _holder, uint256 _amount) internal view override returns (uint256) {
        uint256 holderBalance = balanceOf(_holder);
        uint256 holderShare = (holderBalance * 1e18) / poolInfo.investmentPoolSize;
        return holderShare * _amount / 1e18;
    }

    /// TODO: Tigran. I guess we don't need request funds compensation from Blended Pool here. Should be revisited!
    /// @notice Used to transfer the investor's yield to him
//    function withdrawYield() external override whenProtocolNotPaused returns (bool) {
//        uint256 callerYields = yields[msg.sender];
//        require(callerYields >= 0, "P:NOT_HOLDER");
//        uint256 totalBalance = totalBalance();
//
//        BlendedPool blendedPool = getBlendedPool();
//
//        yields[msg.sender] = 0;
//
//        if (totalBalance < callerYields) {
//            uint256 amountMissing = callerYields - totalBalance;
//
//            if (blendedPool.totalBalance() < amountMissing) {
//                pendingYields[msg.sender] += callerYields;
//                emit PendingYield(msg.sender, callerYields);
//                return false;
//            }
//
//            blendedPool.requestAssets(amountMissing);
//            _mintAndUpdateTotalDeposited(address(blendedPool), amountMissing);
//
//            require(_transferFunds(msg.sender, callerYields), "P:ERROR_TRANSFERRING_YIELD");
//
//            emit YieldWithdrawn(msg.sender, callerYields);
//            return true;
//        }
//
//        require(_transferFunds(msg.sender, callerYields), "P:ERROR_TRANSFERRING_YIELD");
//
//        emit YieldWithdrawn(msg.sender, callerYields);
//        return true;
//    }
}
