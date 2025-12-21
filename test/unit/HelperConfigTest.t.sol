// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract HelperConfigTest is Test {
    HelperConfig internal helperConfig;
    address internal weth;
    address internal wethUsdPriceFeed;
    address internal wbtc;
    address internal wbtcUsdPriceFeed;
    uint256 internal deployerKey;

    function setUp() public {
        // Anvil chainid != 11155111
        helperConfig = new HelperConfig();
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testConstructorSetsActiveNetworkConfigOnAnvil() public {
        (
            wethUsdPriceFeed,
            wbtcUsdPriceFeed,
            weth,
            wbtc,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        assertTrue(wethUsdPriceFeed != address(0));
        assertTrue(wbtcUsdPriceFeed != address(0));
        assertTrue(weth != address(0));
        assertTrue(wbtc != address(0));
        assertEq(deployerKey, helperConfig.DEFAULT_ANVIL_KEY());
    }

    /*//////////////////////////////////////////////////////////////
                    getOrCreateAnvilEthConfig
    //////////////////////////////////////////////////////////////*/

    function testGetOrCreateAnvilEthConfigDeploysMocks() public {
        HelperConfig.NetworkConfig memory config = helperConfig
            .getOrCreateAnvilEthConfig();

        // ETH/USD price feed
        MockV3Aggregator ethFeed = MockV3Aggregator(config.wethUsdPriceFeed);

        assertEq(ethFeed.decimals(), helperConfig.DECIMALS());

        (, int256 ethPrice, , , ) = ethFeed.latestRoundData();
        assertEq(ethPrice, helperConfig.ETH_USD_PRICE());

        // BTC/USD price feed
        MockV3Aggregator btcFeed = MockV3Aggregator(config.wbtcUsdPriceFeed);

        (, int256 btcPrice, , , ) = btcFeed.latestRoundData();
        assertEq(btcPrice, helperConfig.BTC_USD_PRICE());
    }

    function testGetOrCreateAnvilEthConfigDeploysERC20Mocks() public {
        HelperConfig.NetworkConfig memory config = helperConfig
            .getOrCreateAnvilEthConfig();

        ERC20Mock wethMock = ERC20Mock(config.weth);
        ERC20Mock wbtcMock = ERC20Mock(config.wbtc);

        assertEq(wethMock.name(), "WETH");
        assertEq(wethMock.symbol(), "WETH");

        assertEq(wbtcMock.name(), "WBTC");
        assertEq(wbtcMock.symbol(), "WBTC");

        // Tokens minted to msg.sender during deployment
        assertGt(wethMock.balanceOf(address(this)), 0);
        assertGt(wbtcMock.balanceOf(address(this)), 0);
    }

    function testGetOrCreateAnvilEthConfigIsIdempotent() public {
        HelperConfig.NetworkConfig memory first = helperConfig
            .getOrCreateAnvilEthConfig();

        HelperConfig.NetworkConfig memory second = helperConfig
            .getOrCreateAnvilEthConfig();

        assertEq(first.wethUsdPriceFeed, second.wethUsdPriceFeed);
        assertEq(first.wbtcUsdPriceFeed, second.wbtcUsdPriceFeed);
        assertEq(first.weth, second.weth);
        assertEq(first.wbtc, second.wbtc);
    }

    /*//////////////////////////////////////////////////////////////
                    getSepoliaEthConfig
    //////////////////////////////////////////////////////////////*/

    function testGetSepoliaEthConfigReturnsCorrectValues() public {
        // Arrange
        uint256 fakePrivateKey = 123;
        vm.setEnv("PRIVATE_KEY", vm.toString(fakePrivateKey));

        // Act
        HelperConfig.NetworkConfig memory config = helperConfig
            .getSepoliaEthConfig();

        // Assert — price feeds
        assertEq(
            config.wethUsdPriceFeed,
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        assertEq(
            config.wbtcUsdPriceFeed,
            0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
        );

        // Assert — tokens
        assertEq(config.weth, 0xdd13E55209Fd76AfE204dBda4007C227904f0a81);
        assertEq(config.wbtc, 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);

        // Assert — deployer key
        assertEq(config.deployerKey, fakePrivateKey);
    }

    function testConstructorUsesSepoliaConfigOnSepoliaChain() public {
        vm.chainId(11155111);
        vm.setEnv("PRIVATE_KEY", "123");

        HelperConfig config = new HelperConfig();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, ) = config
            .activeNetworkConfig();

        assertEq(wethUsdPriceFeed, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }
}
