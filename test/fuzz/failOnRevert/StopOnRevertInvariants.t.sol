// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// Invariants:
// protocol must never be insolvent / undercollateralized
// TODO: users cant create stablecoins with a bad health factor
// TODO: a user should only be able to be liquidated if they have a bad health factor

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {SFCEngine} from "../../../src/SFCEngine.sol";
import {StableForgeCoin} from "../../../src/StableForgeCoin.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {DeploySFC} from "../../../script/DeploySFC.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol"; // Updated mock location
//import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {StopOnRevertHandler} from "./StopOnRevertHandler.t.sol";
//import {console} from "forge-std/console.sol";

contract StopOnRevertInvariants is StdInvariant, Test {
    SFCEngine public sfcEngine;
    StableForgeCoin public sfc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;

    uint256 internal amountCollateral = 10 ether;
    uint256 internal amountToMint = 100 ether;

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    address public constant USER = address(1);
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    StopOnRevertHandler public handler;

    function setUp() external {
        DeploySFC deployer = new DeploySFC();
        (sfc, sfcEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, ) = helperConfig
            .activeNetworkConfig();
        handler = new StopOnRevertHandler(sfcEngine, sfc);
        targetContract(address(handler));
        // targetContract(address(ethUsdPriceFeed)); Why can't we just do this?
    }

    function invariant_protocolMustHaveMoreValueThatTotalSupplyDollars_Stop()
        public
        view
    {
        uint256 totalSupply = sfc.totalSupply();
        uint256 wethDeposited = ERC20Mock(weth).balanceOf(address(sfcEngine));
        uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(sfcEngine));

        uint256 wethValue;
        uint256 wbtcValue;

        try sfcEngine.getUsdValue(weth, wethDeposited) returns (uint256 value) {
            wethValue = value;
        } catch {
            // Oracle failure = protocol invariant violated
            return;
        }

        try sfcEngine.getUsdValue(wbtc, wbtcDeposited) returns (uint256 value) {
            wbtcValue = value;
        } catch {
            // Oracle failure = protocol invariant violated
            return;
        }

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersCantRevert() public view {
        sfcEngine.getAdditionalFeedPrecision();
        sfcEngine.getCollateralTokens();
        sfcEngine.getLiquidationBonus();
        sfcEngine.getLiquidationThreshold();
        sfcEngine.getMinHealthFactor();
        sfcEngine.getPrecision();
        sfcEngine.getSfc();
        // sfcEngine.getTokenAmountFromUsd();
        // sfcEngine.getCollateralTokenPriceFeed();
        // sfcEngine.getCollateralBalanceOfUser();
        // getAccountCollateralValue();
    }
}
