pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {MockTokenERC20} from "./mocks/MockTokenERC20.sol";
import {HeliosGlobals} from "../contracts/global/HeliosGlobals.sol";
import {AbstractPool} from "../contracts/pool/AbstractPool.sol";
import {Pool} from "../contracts/pool/Pool.sol";
import {BlendedPool} from "../contracts/pool/BlendedPool.sol";

import {FixtureContract} from "./fixtures/FixtureContract.t.sol";

contract BlendedPoolTest is Test, FixtureContract {
    event PendingYield(address indexed recipient, uint256 indexed amount);
    event WithdrawalOverThreshold(address indexed caller, uint256 indexed amount);

    function setUp() public {
        fixture();
        vm.prank(OWNER_ADDRESS);
        liquidityAsset.approve(address(blendedPool), 1000);
        vm.stopPrank();
        vm.prank(USER_ADDRESS);
        liquidityAsset.approve(address(blendedPool), 1000);
        vm.stopPrank();
    }

    /// @notice Test attempt to deposit; checking if variables are updated correctly
    function test_depositSuccess(address user1, address user2) external {
        createInvestorAndMintLiquidityAsset(user1, 1000);
        createInvestorAndMintLiquidityAsset(user2, 1000);
        vm.assume(user1 != user2);

        vm.startPrank(user1);

        //testing initial condition i.e. zeroes
        assertEq(blendedPool.balanceOf(user1), 0);
        assertEq(blendedPool.liquidityLockerTotalBalance(), 0);
        assertEq(blendedPool.totalDeposited(), 0);

        uint256 user1Deposit = 100;
        liquidityAsset.approve(address(blendedPool), user1Deposit);
        blendedPool.deposit(user1Deposit);

        //user's LP balance should be 100 now
        assertEq(blendedPool.balanceOf(user1), user1Deposit, "wrong LP balance for user1");

        //pool's total LA balance should be user1Deposit now
        assertEq(blendedPool.liquidityLockerTotalBalance(), user1Deposit, "wrong LA balance after user1 deposit");

        //pool's total minted should also be user1Deposit
        assertEq(blendedPool.totalDeposited(), user1Deposit, "wrong totalDeposit after user1 deposit");
        vm.stopPrank();

        //now let's test for user2
        vm.startPrank(user2);
        assertEq(blendedPool.balanceOf(user2), 0, "user2 shouldn't have >0 atm");
        uint256 user2Deposit = 101;

        liquidityAsset.approve(address(blendedPool), user2Deposit);
        blendedPool.deposit(user2Deposit);

        assertEq(blendedPool.balanceOf(user2), user2Deposit, "wrong user2 LP balance");

        //pool's total LA balance should be user1Deposit now
        assertEq(blendedPool.liquidityLockerTotalBalance(), user1Deposit + user2Deposit, "wrong totalLA after user2");

        //pool's total minted should also be user1Deposit
        assertEq(blendedPool.totalDeposited(), user1Deposit + user2Deposit, "wrong totalDeposited after user2");
        vm.stopPrank();
    }

    /// @notice Test attempt to deposit below minimum
    function test_depositFailure(address user) external {
        vm.startPrank(user);
        uint256 depositAmountBelowMin = 1;
        vm.expectRevert("P:DEP_AMT_BELOW_MIN");
        blendedPool.deposit(depositAmountBelowMin);
    }

    /// @notice Test attempt to withdraw; both happy and unhappy paths
    function test_withdraw(address user) external {
        createInvestorAndMintLiquidityAsset(user, 1000);

        vm.startPrank(user);
        uint256 depositAmount = 150;
        uint256 currentTime = block.timestamp;

        liquidityAsset.approve(address(blendedPool), depositAmount);
        //the user can withdraw the sum he has deposited earlier
        blendedPool.deposit(depositAmount);

        //attempt to withdraw too early fails
        vm.expectRevert("P:TOKENS_LOCKED");
        uint16[] memory indices = new uint16[](1);
        indices[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = depositAmount;
        blendedPool.withdraw(amounts, indices);

        vm.warp(currentTime + 1000);
        blendedPool.withdraw(amounts, indices);

        // but he cannot withdraw more
        // vm.expectRevert("P:INSUFFICIENT_BALANCE");
        // blendedPool.withdraw(1, indices);

        vm.stopPrank();
    }

    /// @notice Test complete scenario of depositing, distribution of yield and withdraw
    function test_distributeYieldsAndWithdraw(address user1, address user2) external {
        createInvestorAndMintLiquidityAsset(user1, 1000);
        createInvestorAndMintLiquidityAsset(user2, 1000);
        vm.assume(user1 != user2);

        //firstly the users need to deposit before withdrawing
        uint256 user1Deposit = 100;
        vm.startPrank(user1);
        liquidityAsset.approve(address(blendedPool), user1Deposit);
        blendedPool.deposit(user1Deposit);
        vm.stopPrank();

        uint256 user2Deposit = 1000;
        vm.startPrank(user2);
        liquidityAsset.approve(address(blendedPool), user2Deposit);
        blendedPool.deposit(user2Deposit);
        vm.stopPrank();

        //a non-pool-admin address shouldn't be able to call distributeYields()
        vm.prank(user1);
        vm.expectRevert("PF:NOT_ADMIN");
        blendedPool.distributeYields(1000);

        //only the pool admin can call distributeYields()
        vm.prank(OWNER_ADDRESS);
        blendedPool.distributeYields(1000);

        //now we need to test if the users got assigned the correct yields
        uint256 user1Yields = blendedPool.yields(user1);
        uint256 user2Yields = blendedPool.yields(user2);
        assertEq(user1Yields, 90, "wrong yield user1");
        assertEq(user2Yields, 909, "wrong yield user2"); //NOTE: 1 is lost as a dust value :(

        uint256 user1BalanceBefore = liquidityAsset.balanceOf(user1);
        vm.prank(user1);
        blendedPool.withdrawYield();
        assertEq(
            liquidityAsset.balanceOf(user1) - user1BalanceBefore,
            90,
            "user1 balance not upd after withdrawYield()"
        );

        uint256 user2BalanceBefore = liquidityAsset.balanceOf(user2);
        vm.prank(user2);
        blendedPool.withdrawYield();
        assertEq(
            liquidityAsset.balanceOf(user2) - user2BalanceBefore,
            909,
            "user2 balance not upd after withdrawYield()"
        );
    }

    /// @notice Test complete scenario of depositing, distribution of yields and withdraw
    function test_distributeYieldsAndWithdrawRegPool(address user1, address user2) external {
        createInvestorAndMintLiquidityAsset(user1, 1000);
        createInvestorAndMintLiquidityAsset(user2, 1000);
        vm.assume(user1 != user2);

        vm.startPrank(OWNER_ADDRESS);
        //firstly the users need to deposit before withdrawing
        address poolAddress = poolFactory.createPool(
            "1",
            address(liquidityAsset),
            address(liquidityLockerFactory),
            2000,
            10,
            1000,
            100000,
            100,
            500,
            1000
        );

        vm.stopPrank();

        Pool pool = Pool(poolAddress);
        uint256 user1Deposit = 100;
        vm.startPrank(user1);
        liquidityAsset.approve(poolAddress, 10000);
        pool.deposit(user1Deposit);
        vm.stopPrank();

        uint256 user2Deposit = 1000;
        vm.startPrank(user2);
        liquidityAsset.approve(poolAddress, 10000);
        pool.deposit(user2Deposit);
        vm.stopPrank();

        //a non-pool-admin address shouldn't be able to call distributeYields()
        vm.prank(user1);
        vm.expectRevert("PF:NOT_ADMIN");
        pool.distributeYields(1000);

        //only the pool admin can call distributeYields()
        vm.prank(OWNER_ADDRESS);
        pool.distributeYields(1000);

        //now we need to test if the users got assigned the correct yields
        uint256 user1Yields = pool.yields(user1);
        uint256 user2Yields = pool.yields(user2);
        assertEq(user1Yields, 1, "wrong yield user1");
        assertEq(user2Yields, 10, "wrong yield user2"); //NOTE: 1 is lost as a dust value :(

        uint256 user1BalanceBefore = liquidityAsset.balanceOf(user1);
        vm.prank(user1);
        pool.withdrawYield();
        assertEq(
            liquidityAsset.balanceOf(user1) - user1BalanceBefore, 1, "user1 balance not upd after withdrawYield()"
        );

        uint256 user2BalanceBefore = liquidityAsset.balanceOf(user2);
        vm.prank(user2);
        pool.withdrawYield();
        assertEq(
            liquidityAsset.balanceOf(user2) - user2BalanceBefore,
            10,
            "user2 balance not upd after withdrawYield()"
        );
    }

    /// @notice Test scenario when there are not enough funds on the pool
    function test_insufficientFundsWithdrawYield(address user) external {
        createInvestorAndMintLiquidityAsset(user, 1000);

        //firstly the users need to deposit before withdrawing
        uint256 user1Deposit = 100;
        vm.startPrank(user);
        liquidityAsset.approve(address(blendedPool), 10000);
        blendedPool.deposit(user1Deposit);
        vm.stopPrank();

        //only the pool admin can call distributeYields()
        vm.prank(OWNER_ADDRESS);
        blendedPool.distributeYields(1000);

        vm.prank(OWNER_ADDRESS);
        vm.expectRevert("P:INVALID_VALUE");
        blendedPool.distributeYields(0);

        assertEq(blendedPool.yields(user), 1000, "yields should be 1000 atm");

        // now let's deplete the pool's balance
        vm.startPrank(OWNER_ADDRESS);
        uint256 borrowAmount = blendedPool.totalSupply() - blendedPool.principalOut();
        blendedPool.borrow(OWNER_ADDRESS, borrowAmount);
        vm.stopPrank();

        //..and withdraw yields as user1
        vm.startPrank(user);
        vm.expectEmit(false, false, false, false);
        // The expected event signature
        emit PendingYield(user, 1000);
        assertFalse(blendedPool.withdrawYield(), "should return false if not enough LA");

        vm.stopPrank();

        assertEq(blendedPool.yields(user), 0, "yields should be 0 after withdraw attempt");

        assertEq(blendedPool.pendingYields(user), 1000, "pending yields should be 1000 after withdraw attempt");

        uint256 user1BalanceBefore = liquidityAsset.balanceOf(user);

        mintLiquidityAsset(OWNER_ADDRESS, 1000);
        vm.startPrank(OWNER_ADDRESS);
        liquidityAsset.approve(address(blendedPool), 1000);
        blendedPool.repay(1000);
        blendedPool.concludePendingYield(user);

        uint256 user1BalanceAfter = liquidityAsset.balanceOf(user);

        //checking if the user got his money now
        assertEq(user1BalanceAfter, user1BalanceBefore + 1000, "invalid user1 LA balance after concluding");
    }

    function test_subsidingRegPoolWithBlendedPool(address user) external {
        createInvestorAndMintLiquidityAsset(user, 1000);

        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);
        address poolAddress = poolFactory.createPool(
            "1", address(liquidityAsset), address(liquidityLockerFactory), 2000, 10, 1000, 1000, 100, 500, 1000
        );

        Pool pool = Pool(poolAddress);

        vm.stopPrank();

        //a user deposits some LA to the RegPool
        vm.startPrank(user);
        liquidityAsset.approve(poolAddress, 1000);
        pool.deposit(500);
        vm.stopPrank();

        //the admin distributes yields and takes all the LA, emptying the pool
        vm.startPrank(OWNER_ADDRESS);

        pool.distributeYields(100);
        pool.borrow(OWNER_ADDRESS, 100);
        vm.stopPrank();

        //now let's repay LA to the blended pool
        vm.startPrank(OWNER_ADDRESS);
        mintLiquidityAsset(OWNER_ADDRESS, 100);
        liquidityAsset.approve(address(blendedPool), 100);
        blendedPool.repay(100);
        vm.stopPrank();

        //now let's withdraw yield. The blended pool will help
        vm.startPrank(user);
        liquidityAsset.approve(poolAddress, 10000);
        pool.withdrawYield();
    }

    function test_maxPoolSize(address user, uint256 _maxPoolSize) external {
        createInvestorAndMintLiquidityAsset(user, 1000);

        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);

        _maxPoolSize = bound(_maxPoolSize, 1, 1e36);
        address poolAddress = poolFactory.createPool(
            "1",
            address(liquidityAsset),
            address(liquidityLockerFactory),
            2000,
            10,
            1000,
            _maxPoolSize,
            0,
            500,
            1000
        );
        vm.stopPrank();

        Pool pool = Pool(poolAddress);

        vm.startPrank(user);
        liquidityAsset.approve(poolAddress, 1000);
        vm.expectRevert("P:MAX_POOL_SIZE_REACHED");
        pool.deposit(_maxPoolSize + 1);
        vm.stopPrank();
    }

    function test_reinvestYield(address user) external {
        createInvestorAndMintLiquidityAsset(user, 1000);

        //firstly the user needs to deposit
        uint256 user1Deposit = 100;
        vm.startPrank(user);
        liquidityAsset.approve(address(blendedPool), 10000);
        blendedPool.deposit(user1Deposit);
        vm.stopPrank();

        //only the pool admin can call distributeYields()
        vm.prank(OWNER_ADDRESS);
        blendedPool.distributeYields(1000);

        mintLiquidityAsset(blendedPool.getLiquidityLocker(), 1003);

        //now the user wishes to reinvest
        uint256 userYields = blendedPool.yields(user);
        vm.startPrank(user);
        blendedPool.reinvestYield(1000);
        uint256 userBalanceNow = blendedPool.balanceOf(user);
        uint256 expected = user1Deposit + userYields;
        assertEq(userBalanceNow, expected);
    }
}
