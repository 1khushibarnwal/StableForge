// Commented out for now until revert on fail == false per function customization is implemented

// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

//import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Test, console} from "forge-std/Test.sol";
// import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; Updated mock location
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
import {SFCEngine} from "../../../src/SFCEngine.sol";
import {StableForgeCoin} from "../../../src/StableForgeCoin.sol";
// import {Randomish, EnumerableSet} from "../Randomish.sol"; // Randomish is not found in the codebase, EnumerableSet
// is imported from openzeppelin

contract ContinueOnRevertHandler is Test {
    // using EnumerableSet for EnumerableSet.AddressSet;
    // using Randomish for EnumerableSet.AddressSet;

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

        ethUsdPriceFeed = MockV3Aggregator(
            sfcEngine.getCollateralTokenPriceFeed(address(weth))
        );
        btcUsdPriceFeed = MockV3Aggregator(
            sfcEngine.getCollateralTokenPriceFeed(address(wbtc))
        );
    }

    // FUNCTIONS TO INTERACT WITH

    ///////////////
    // SFCEngine //
    ///////////////
    function mintAndDepositCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        collateral.mint(msg.sender, amountCollateral);
        sfcEngine.depositCollateral(address(collateral), amountCollateral);
    }

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        sfcEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    function burnSfc(uint256 amountSfc) public {
        amountSfc = bound(amountSfc, 0, sfc.balanceOf(msg.sender));
        sfc.burn(amountSfc);
    }

    function mintSfc(uint256 amountSfc) public {
        amountSfc = bound(amountSfc, 0, MAX_DEPOSIT_SIZE);
        sfc.mint(msg.sender, amountSfc);
    }

    function liquidate(
        uint256 collateralSeed,
        address userToBeLiquidated,
        uint256 debtToCover
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        sfcEngine.liquidate(
            address(collateral),
            userToBeLiquidated,
            debtToCover
        );
    }

    /////////////////////////////
    // DecentralizedStableCoin //
    /////////////////////////////
    function transferSfc(uint256 amountSfc, address to) public {
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
    function updateCollateralPrice(
        uint128,
        /* newPrice */
        uint256 collateralSeed
    ) public {
        // int256 intNewPrice = int256(uint256(newPrice));
        int256 intNewPrice = 0;
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(
            sfcEngine.getCollateralTokenPriceFeed(address(collateral))
        );

        priceFeed.updateAnswer(intNewPrice);
    }

    /// Helper Functions
    function _getCollateralFromSeed(
        uint256 collateralSeed
    ) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }

    function callSummary() external view {
        console.log("Weth total deposited", weth.balanceOf(address(sfcEngine)));
        console.log("Wbtc total deposited", wbtc.balanceOf(address(sfcEngine)));
        console.log("Total supply of SFC", sfc.totalSupply());
    }
}
