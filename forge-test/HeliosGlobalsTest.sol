pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {FixtureContract} from "./FixtureContract.sol";

contract HeliosGlobalsTest is Test, FixtureContract {

    event ProtocolPaused(bool pause);
    event GlobalAdminSet(address indexed newGlobalAdmin);
    event PoolDelegateSet(address indexed delegate, bool valid);
    event LiquidityAssetSet(address asset, uint256 decimals, string symbol, bool valid);
    event ValidPoolFactorySet(address indexed poolFactory, bool valid);
    event ValidSubFactorySet(address indexed superFactory, address indexed subFactory, bool valid);

    function setUp() public {
        fixture();
    }

    function test_adminSetPaused() public {
        vm.startPrank(ADMIN_ADDRESS);

        //Asserts if initial state of contract is paused
        assertEq(heliosGlobals.protocolPaused(), false);

        vm.expectEmit();
        emit ProtocolPaused(true);
        //Sets contract paused
        heliosGlobals.setProtocolPause(true);

        //Asserts if after pausing contract paused
        assertEq(heliosGlobals.protocolPaused(), true);

        vm.expectEmit();
        emit ProtocolPaused(false);
        heliosGlobals.setProtocolPause(false);

        assertEq(heliosGlobals.protocolPaused(), false);

        vm.stopPrank();
    }

    function test_when_not_owner_setPaused(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        //Asserts if initial state of contract is paused
        assertEq(heliosGlobals.protocolPaused(), false);

        //Sets contract paused
        vm.expectRevert(bytes("HG:NOT_ADM"));
        heliosGlobals.setProtocolPause(true);

        //Asserts if after pausing contract it is not paused
        assertEq(heliosGlobals.protocolPaused(), false);

        vm.stopPrank();
    }

    function test_when_owner_setValidPoolFactory() public {
        vm.startPrank(OWNER_ADDRESS);

        address poolFactoryAddress = address(poolFactory);

        vm.expectEmit();
        emit ValidPoolFactorySet(poolFactoryAddress, true);

        heliosGlobals.setValidPoolFactory(poolFactoryAddress, true);
        assertEq(heliosGlobals.isValidPoolFactory(poolFactoryAddress), true);

        vm.stopPrank();
    }

    function test_when_not_owner_setValidPoolFactory(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        address poolFactoryAddress = address(poolFactory);
        vm.expectRevert(bytes("MG:NOT_GOV"));
        heliosGlobals.setValidPoolFactory(poolFactoryAddress, true);
        assertEq(heliosGlobals.isValidPoolFactory(poolFactoryAddress), false);

        vm.stopPrank();
    }

    function test_when_owner_setPoolDelegateAllowList(address poolDelegate) public {
        vm.startPrank(OWNER_ADDRESS);

        assertEq(heliosGlobals.isValidPoolDelegate(poolDelegate), false);

        vm.expectEmit();
        emit PoolDelegateSet(poolDelegate, true);

        heliosGlobals.setPoolDelegateAllowList(poolDelegate, true);
        assertEq(heliosGlobals.isValidPoolDelegate(poolDelegate), true);

        vm.stopPrank();
    }

    function test_when_not_owner_setPoolDelegateAllowList(address user, address poolDelegate) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        vm.expectRevert(bytes("MG:NOT_GOV"));
        heliosGlobals.setPoolDelegateAllowList(poolDelegate, true);
        assertEq(heliosGlobals.isValidPoolDelegate(poolDelegate), false);

        vm.stopPrank();
    }

    function test_when_owner_setGlobalAdmin(address newAdmin) public {
        vm.assume(newAdmin != address(0) && newAdmin != heliosGlobals.globalAdmin());
        assertNotEq(heliosGlobals.globalAdmin(), newAdmin);

        vm.startPrank(OWNER_ADDRESS);

        vm.expectEmit();
        emit GlobalAdminSet(newAdmin);

        heliosGlobals.setGlobalAdmin(newAdmin);
        vm.stopPrank();
        assertEq(heliosGlobals.globalAdmin(), newAdmin);
    }

    function test_when_owner_set_zero_setGlobalAdmin() public {
        address newAdmin = address(0);

        vm.startPrank(OWNER_ADDRESS);
        vm.expectRevert("HG:NOT_GOV_OR_ADM");
        heliosGlobals.setGlobalAdmin(newAdmin);

        assertNotEq(heliosGlobals.globalAdmin(), newAdmin);
        vm.stopPrank();
    }

    function test_when_paused_setGlobalAdmin(address newAdmin) public {
        vm.assume(newAdmin != address(0) && newAdmin != heliosGlobals.globalAdmin());

        vm.startPrank(ADMIN_ADDRESS);
        heliosGlobals.setProtocolPause(true);
        vm.stopPrank();

        vm.startPrank(OWNER_ADDRESS);
        vm.expectRevert(bytes("HG:PROTO_PAUSED"));
        heliosGlobals.setGlobalAdmin(newAdmin);
        vm.stopPrank();

        vm.startPrank(ADMIN_ADDRESS);
        heliosGlobals.setProtocolPause(false);
        vm.stopPrank();
    }

    function test_when_not_owner_setGlobalAdmin(address user, address globalAdmin) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.assume(user != ADMIN_ADDRESS);

        assertNotEq(heliosGlobals.globalAdmin(), globalAdmin);

        vm.startPrank(user);
        vm.expectRevert(bytes("HG:NOT_GOV_OR_ADM"));
        heliosGlobals.setGlobalAdmin(globalAdmin);
        vm.stopPrank();

        assertNotEq(heliosGlobals.globalAdmin(), globalAdmin);
    }

    function test_when_owner_setLiquidityAsset() public {
        vm.startPrank(OWNER_ADDRESS);

        address liquidityAssetAddress = address(liquidityAsset);

        vm.expectEmit();
        emit LiquidityAssetSet(liquidityAssetAddress, liquidityAsset.decimals(), liquidityAsset.symbol(), true);

        heliosGlobals.setLiquidityAsset(liquidityAssetAddress, true);
        assertEq(heliosGlobals.isValidLiquidityAsset(liquidityAssetAddress), true);

        vm.stopPrank();
    }

    function test_when_not_owner_setLiquidityAsset(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(user);

        address liquidityAssetAddress = address(liquidityAsset);
        vm.expectRevert(bytes("MG:NOT_GOV"));
        heliosGlobals.setLiquidityAsset(liquidityAssetAddress, true);
        assertEq(heliosGlobals.isValidLiquidityAsset(liquidityAssetAddress), false);

        vm.stopPrank();
    }

    function test_when_owner_setValidSubFactory() public {
        vm.startPrank(OWNER_ADDRESS);

        address poolFactoryAddress = address(poolFactory);
        address liquidityLockerFactoryAddress = address(liquidityLockerFactory);

        heliosGlobals.setValidPoolFactory(poolFactoryAddress, true);

        vm.expectEmit();
        emit ValidSubFactorySet(poolFactoryAddress, liquidityLockerFactoryAddress, true);

        heliosGlobals.setValidSubFactory(poolFactoryAddress, liquidityLockerFactoryAddress, true);
        assertEq(heliosGlobals.isValidSubFactory(poolFactoryAddress, liquidityLockerFactoryAddress, 1), true);
        assertEq(heliosGlobals.isValidSubFactory(poolFactoryAddress, liquidityLockerFactoryAddress, 2), false);

        vm.stopPrank();
    }

    function test_when_not_owner_setValidSubFactory(address user) public {
        vm.assume(user != OWNER_ADDRESS);
        vm.startPrank(OWNER_ADDRESS);

        address poolFactoryAddress = address(poolFactory);
        address liquidityLockerFactoryAddress = address(liquidityLockerFactory);

        heliosGlobals.setValidPoolFactory(poolFactoryAddress, true);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(bytes("MG:NOT_GOV"));
        heliosGlobals.setValidSubFactory(poolFactoryAddress, liquidityLockerFactoryAddress, true);
        vm.stopPrank();
    }
}