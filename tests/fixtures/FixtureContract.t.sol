pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockTokenERC20} from "../mocks/MockTokenERC20.sol";
import {HeliosGlobals} from "../../contracts/global/HeliosGlobals.sol";
import {PoolFactory} from "../../contracts/pool/PoolFactory.sol";
import {BlendedPool} from "../../contracts/pool/BlendedPool.sol";
import {Pool} from "../../contracts/pool/Pool.sol";

abstract contract FixtureContract is Test {
    address public constant OWNER_ADDRESS = 0x8A867fcC5a4d1FBbf7c1A9D6e5306b78511fDDDe;
    address public constant USER_ADDRESS = 0x4F8fF72C3A17B571D4a1671d5ddFbcf48187FBCa;

    address internal constant INVESTOR_1 = address(uint160(uint256(keccak256("investor1"))));
    address internal constant INVESTOR_2 = address(uint160(uint256(keccak256("investor2"))));

    HeliosGlobals public heliosGlobals;
    ERC20 public asset;
    MockTokenERC20 private assetElevated;
    PoolFactory public poolFactory;
    BlendedPool public blendedPool;
    Pool public regPool1;

    function fixture() public {
        vm.startPrank(OWNER_ADDRESS, OWNER_ADDRESS);

        heliosGlobals = new HeliosGlobals(OWNER_ADDRESS);
        assetElevated = new MockTokenERC20("USDT", "USDT");
        asset = ERC20(assetElevated);

        assetElevated.mint(OWNER_ADDRESS, 1000000);
        assetElevated.mint(USER_ADDRESS, 1000);

        heliosGlobals.setAsset(address(asset), true);

        poolFactory = new PoolFactory(address(heliosGlobals));
        heliosGlobals.setPoolFactory(address(poolFactory));

        address poolAddress = poolFactory.createPool(
            "reg pool",
            address(asset),
            1000,
            100,
            100000
        );

        regPool1 = Pool(poolAddress);

        assertEq(regPool1.decimals(), asset.decimals());

        address blendedPoolAddress = poolFactory.createBlendedPool(
            address(asset),
            300,
            100
        );

        blendedPool = BlendedPool(blendedPoolAddress);
        assertEq(blendedPool.decimals(), asset.decimals());
        assertEq(poolFactory.getBlendedPool(), address(blendedPool));

        vm.stopPrank();
    }

    /// @notice Mint and some checks
    function createInvestorAndMintAsset(address investor, uint256 amount) public returns (address) {
        vm.assume(investor != address(0));
        vm.assume(investor != OWNER_ADDRESS);
        vm.assume(investor != address(regPool1));
        vm.assume(investor != address(blendedPool));
        vm.assume(investor != address(asset));
        vm.assume(amount < assetElevated.totalSupply());

        assetElevated.mint(investor, amount);
        return investor;
    }

    /// @notice Mint and some checks
    function createInvestor(address investor) public view returns (address) {
        vm.assume(investor != address(0));
        vm.assume(investor != OWNER_ADDRESS);
        vm.assume(investor != address(regPool1));
        vm.assume(investor != address(blendedPool));
        vm.assume(investor != address(asset));
        return investor;
    }

    /// @notice Mint assets
    function mintAsset(address user, uint256 amount) public {
        assetElevated.mint(user, amount);
    }

    /// @notice Burn assets
    function burnAsset(address user, uint256 amount) public {
        assetElevated.burn(user, amount);
    }

    /// @notice Burn all assets
    function burnAllAssets(address user) public {
        assetElevated.burn(user, asset.balanceOf(user));
    }
}
