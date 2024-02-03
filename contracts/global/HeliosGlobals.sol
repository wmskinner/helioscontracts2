// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
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

    constructor(address _admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _setRoleAdmin(USER_ROLE, DEFAULT_ADMIN_ROLE);
        emit Initialized();
    }

    function isAdmin(address _account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _account);
    }

    // Sets the paused/unpaused state of the protocol. Only the Admin can call this function
    function setProtocolPause(bool _pause) external onlyAdmin {
        protocolPaused = _pause;
        emit ProtocolPaused(_pause);
    }

    // Sets the validity of a PoolFactory. Only the Admin can call this function
    function setValidPoolFactory(address _poolFactory, bool _valid) external onlyAdmin {
        isValidPoolFactory[_poolFactory] = _valid;
        emit ValidPoolFactorySet(_poolFactory, _valid);
    }

    // Sets the validity of a sub factory as it relates to a super factory. Only the Admin can call this function
    function setValidLiquidityLockerFactory(address _liquidityLockerFactory, bool _valid) external onlyAdmin {
        isValidLiquidityLockerFactory[_liquidityLockerFactory] = _valid;
        emit ValidLiquidityLockerFactorySet(_liquidityLockerFactory, _valid);
    }

    // Sets the validity of an asset for liquidity in Pools. Only the Admin can call this function
    function setLiquidityAsset(address _asset, bool _valid) external onlyAdmin {
        isValidLiquidityAsset[_asset] = _valid;
        emit LiquidityAssetSet(_asset, IERC20Metadata(_asset).decimals(), IERC20Metadata(_asset).symbol(), _valid);
    }

    /*
    Modifiers
    */
    /// @dev Restricted to members of the admin role.
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "HG:NOT_ADMIN");
        _;
    }
}
