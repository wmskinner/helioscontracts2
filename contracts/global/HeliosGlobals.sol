// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISubFactory} from "../interfaces/ISubFactory.sol";
import {IHeliosGlobals} from "../interfaces/IHeliosGlobals.sol";

// HeliosGlobals maintains a central source of parameters and allowLists for the Helios protocol.
contract HeliosGlobals is AccessControl, IHeliosGlobals {
    bytes32 public constant USER_ROLE = keccak256("USER");

    bool public override protocolPaused; // Switch to pause the functionality of the entire protocol.
    mapping(address => bool) public override isValidPoolFactory; // Mapping of valid Pool Factories
    mapping(address => bool) public override isValidLiquidityAsset; // Mapping of valid Liquidity Assets
    mapping(address => bool) public override isValidLiquidityLockerFactory;

    event ProtocolPaused(bool pause);
    event Initialized();
    event LiquidityAssetSet(address asset, uint256 decimals, string symbol, bool valid);
    event ValidPoolFactorySet(address indexed poolFactory, bool valid);
    event ValidLiquidityLockerFactorySet(address indexed liquidityLockerFactory, bool valid);

    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setRoleAdmin(USER_ROLE, DEFAULT_ADMIN_ROLE);
        emit Initialized();
    }

    function isAdmin(address account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    // Sets the paused/unpaused state of the protocol. Only the Admin can call this function
    function setProtocolPause(bool pause) external onlyAdmin {
        protocolPaused = pause;
        emit ProtocolPaused(pause);
    }

    // Sets the validity of a PoolFactory. Only the Admin can call this function
    function setValidPoolFactory(address poolFactory, bool valid) external onlyAdmin {
        isValidPoolFactory[poolFactory] = valid;
        emit ValidPoolFactorySet(poolFactory, valid);
    }

    // Sets the validity of a sub factory as it relates to a super factory. Only the Admin can call this function
    function setValidLiquidityLockerFactory(address liquidityLockerFactory, bool valid) external onlyAdmin {
        isValidLiquidityLockerFactory[liquidityLockerFactory] = valid;
        emit ValidLiquidityLockerFactorySet(liquidityLockerFactory, valid);
    }

    // Sets the validity of an asset for liquidity in Pools. Only the Admin can call this function
    function setLiquidityAsset(address asset, bool valid) external onlyAdmin {
        isValidLiquidityAsset[asset] = valid;
        emit LiquidityAssetSet(asset, IERC20Metadata(asset).decimals(), IERC20Metadata(asset).symbol(), valid);
    }

    /// @dev Restricted to members of the admin role.
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "HG:NOT_ADMIN");
        _;
    }
}
