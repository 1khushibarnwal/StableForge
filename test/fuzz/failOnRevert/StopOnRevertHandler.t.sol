// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Test} from "forge-std/Test.sol";
// import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; Updated mock location
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
import {SFCEngine} from "../../../src/SFCEngine.sol";
import {StableForgeCoin} from "../../../src/StableForgeCoin.sol";

contract StopOnRevertHandler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Deployed contracts to interact with
    SFCEngine public sfcEngine;
    StableForgeCoin public sfc;
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    // Ghost Variables
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(SFCEngine _sfcEngine, StableForgeCoin _sfc) {
        sfcEngine = _sfcEngine;
        sfc = _sfc;

        address[] memory collateralTokens = sfcEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(sfcEngine.getCollateralTokenPriceFeed(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(sfcEngine.getCollateralTokenPriceFeed(address(wbtc)));
    }

    // FUNCTOINS TO INTERACT WITH

    ///////////////
    // SFCEngine //
    ///////////////
    function mintAndDepositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        // must be more than 0
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(sfcEngine), amountCollateral);
        sfcEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateral = sfcEngine.getCollateralBalanceOfUser(msg.sender, address(collateral));

        amountCollateral = bound(amountCollateral, 0, maxCollateral);
        //vm.prank(msg.sender);
        if (amountCollateral == 0) {
            return;
        }
        vm.prank(msg.sender);
        sfcEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    function burnSfc(uint256 amountSfc) public {
        // Must burn more than 0
        amountSfc = bound(amountSfc, 0, sfc.balanceOf(msg.sender));
        if (amountSfc == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        sfc.approve(address(sfcEngine), amountSfc);
        sfcEngine.burnSfc(amountSfc);
        vm.stopPrank();
    }

    // Only the SFCEngine can mint SFC!
    // function mintSfc(uint256 amountSfc) public {
    //     amountSfc = bound(amountSfc, 0, MAX_DEPOSIT_SIZE);
    //     vm.prank(sfc.owner());
    //     sfc.mint(msg.sender, amountSfc);
    // }

    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
        uint256 minHealthFactor = sfcEngine.getMinHealthFactor();
        uint256 userHealthFactor = sfcEngine.getHealthFactor(userToBeLiquidated);
        if (userHealthFactor >= minHealthFactor) {
            return;
        }
        debtToCover = bound(debtToCover, 1, uint256(type(uint96).max));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        sfcEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
    }

    /////////////////////////////
    // StableForgeCoin //
    /////////////////////////////
    function transferSfc(uint256 amountSfc, address to) public {
        if (to == address(0)) {
            to = address(1);
        }
        amountSfc = bound(amountSfc, 0, sfc.balanceOf(msg.sender));
        vm.prank(msg.sender);
        bool success = sfc.transfer(to, amountSfc);
        if (!success) {
            return;
        }
    }

    /////////////////////////////
    // Aggregator //
    /////////////////////////////
    function updateCollateralPrice(uint96 newPrice, uint256 collateralSeed) public {
        int256 intNewPrice = int256(uint256(newPrice));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(sfcEngine.getCollateralTokenPriceFeed(address(collateral)));

        priceFeed.updateAnswer(intNewPrice);
    }

    /// Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
