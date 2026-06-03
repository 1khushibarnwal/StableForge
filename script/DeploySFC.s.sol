// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {StableForgeCoin} from "../src/StableForgeCoin.sol";
import {SFCEngine} from "../src/SFCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySFC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (StableForgeCoin, SFCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        tokenAddresses = [weth, wbtc]; // addresses of the allowed tokens, i.e., WETH and WBTC
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed]; // corresponding price feed addresses

        vm.startBroadcast(deployerKey);
        StableForgeCoin sfc = new StableForgeCoin();
        SFCEngine sfcEngine = new SFCEngine(tokenAddresses, priceFeedAddresses, address(sfc));

        sfc.transferOwnership(address(sfcEngine));
        vm.stopBroadcast();

        return (sfc, sfcEngine, helperConfig);
    }
}
