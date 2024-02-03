// SPDX-License-Identifier: MIT
// @author Tigran Arakelyan
pragma solidity 0.8.20;

import {LiquidityLocker} from "./LiquidityLocker.sol";
import {ISubFactory} from "../interfaces/ISubFactory.sol";
import {ILiquidityLockerFactory} from "../interfaces/ILiquidityLockerFactory.sol";

// LiquidityLockerFactory instantiates LiquidityLockers
contract LiquidityLockerFactory is ILiquidityLockerFactory {
    uint8 constant LIQ_LOCKER_FACTORY = 1;

    mapping(address => address) public owner; // Mapping of LiquidityLocker addresses to their owner (i.e owner[locker] = Owner of the LiquidityLocker).
    mapping(address => bool) public isLocker; // True only if a LiquidityLocker was created by this factory.

    function factoryType() external pure override returns (uint8) {
        return LIQ_LOCKER_FACTORY;
    }

    event LiquidityLockerCreated(address indexed owner, address liquidityLocker, address liquidityAsset);

    // Instantiates a LiquidityLocker contract
    function CreateLiquidityLocker(address _liquidityAsset) external override returns (address liquidityLocker) {
        liquidityLocker = address(new LiquidityLocker(_liquidityAsset, msg.sender));
        owner[liquidityLocker] = msg.sender;
        isLocker[liquidityLocker] = true;

        emit LiquidityLockerCreated(msg.sender, liquidityLocker, _liquidityAsset);
    }
}
