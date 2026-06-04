// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeploySFC} from "../../script/DeploySFC.s.sol";
import {SFCEngine} from "../../src/SFCEngine.sol";
import {StableForgeCoin} from "../../src/StableForgeCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

/*//////////////////////////////////////////////////////////////
                    MALICIOUS MOCK
//////////////////////////////////////////////////////////////*/
contract ERC20FailTransfer is ERC20Mock {
    constructor() ERC20Mock("FAIL", "FAIL", msg.sender, 0) {}

    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }
}

contract ERC20FailTransferFrom is ERC20Mock {
    constructor() ERC20Mock("FAIL", "FAIL", msg.sender, 0) {}

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }
}

contract SFCEngineTest is Test {
    DeploySFC internal deployer;
    StableForgeCoin internal sfc;
    SFCEngine internal sfcEngine;
    HelperConfig internal config;
    address internal weth;
    address internal ethUsdPriceFeed;
    address internal wbtc;
    address internal btcUsdPriceFeed;

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    event CollateralRedeemed(address indexed from, address indexed to, address indexed token, uint256 amount);

    address public user = makeAddr("user");
    address internal liquidator = makeAddr("liquidator");

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant MINT_VALUE = 8 ether;
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 3000e8;
    uint256 public constant MINT_VALUE_TO_TEST_LIQUIDATION_WORKS = 100 ether;
    uint256 public constant DEBT_TO_COVER = 50 ether;
    uint256 public constant DEBT_TO_COVER_TO_CHECK_IF_LIQUIDATOR_RECEIVES_BONUS = 3000 ether;

    function setUp() public {
        deployer = new DeploySFC();
        (sfc, sfcEngine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_ERC20_BALANCE);
    }

    /*////////////////////////////////////////////////
                    CONSTRUCTOR TESTS
    ////////////////////////////////////////////////*/
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesNotMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(SFCEngine.SFCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new SFCEngine(tokenAddresses, priceFeedAddresses, address(sfc));
    }

    function testConstructorSetsPriceFeedsCorrectly() public {
        ERC20Mock wethForCheckingPrice = new ERC20Mock("Wrapped ETH", "WETH", address(this), 0);
        MockV3Aggregator ethUsdFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        address[] memory tokens = new address[](1);
        address[] memory priceFeeds = new address[](1);

        tokens[0] = address(wethForCheckingPrice);
        priceFeeds[0] = address(ethUsdFeed);

        sfc = new StableForgeCoin();

        SFCEngine engine = new SFCEngine(tokens, priceFeeds, address(sfc));

        address storedFeed = engine.getSPriceFeed(address(wethForCheckingPrice));
        assertEq(storedFeed, address(ethUsdFeed));
    }

    function testConstructorRegistersCollateralTokens() public {
        ERC20Mock wethForCheckingRegistration = new ERC20Mock("Wrapped ETH", "WETH", address(this), 0);
        ERC20Mock wbtcForCheckingRegistration = new ERC20Mock("Wrapped BTC", "WBTC", address(this), 0);

        MockV3Aggregator ethFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        MockV3Aggregator btcFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);

        address[] memory tokens = new address[](2);
        address[] memory feeds = new address[](2);

        tokens[0] = address(wethForCheckingRegistration);
        tokens[1] = address(wbtcForCheckingRegistration);
        feeds[0] = address(ethFeed);
        feeds[1] = address(btcFeed);

        sfc = new StableForgeCoin();
        SFCEngine engine = new SFCEngine(tokens, feeds, address(sfc));

        address[] memory collateralTokens = engine.getCollateralTokens();

        assertEq(collateralTokens.length, 2);
        assertEq(collateralTokens[0], address(wethForCheckingRegistration));
        assertEq(collateralTokens[1], address(wbtcForCheckingRegistration));
    }

    function testConstructorSetsSfcAddress() public {
        address[] memory tokens = new address[](0);
        address[] memory feeds = new address[](0);

        sfc = new StableForgeCoin();
        SFCEngine engine = new SFCEngine(tokens, feeds, address(sfc));

        address storedSfc = engine.getSfc();
        assertEq(storedSfc, address(sfc));
    }

    function testIfSPriceFeedsDontCorrectlyMatch() public {
        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);

        tokens[0] = address(0);
        feeds[0] = address(0);

        sfc = new StableForgeCoin();

        SFCEngine engine = new SFCEngine(tokens, feeds, address(sfc));

        address storedFeed = engine.getSPriceFeed(address(0));
        assertEq(storedFeed, address(0));
    }

    /*////////////////////////////////////////////////
                        PRICE TESTS
    ////////////////////////////////////////////////*/
    function testGetUsdValue() public view {
        // 15e18 * 2,000/ETH = 30,000e18
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = sfcEngine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        // $2000 per ETH -> 100/2000 = 0.05 ETH
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = sfcEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /*////////////////////////////////////////////////
                depositCollateral TESTS
    ////////////////////////////////////////////////*/
    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier approved() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        _;
        vm.stopPrank();
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(SFCEngine.SFCEngine__NeedsMoreThanZero.selector);
        sfcEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", address(this), AMOUNT_COLLATERAL);
        vm.startPrank(user);
        vm.expectRevert(SFCEngine.SFCEngine__NotAllowedToken.selector);
        sfcEngine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testDepositCollateralUpdatesCollateralBalance() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
    }

    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalSfcMinted, uint256 collateralValueInUsd) = sfcEngine.getAccountInformation(user);
        uint256 expectedDepositedAmount = sfcEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalSfcMinted, 0);
        assertEq(expectedDepositedAmount, AMOUNT_COLLATERAL);
    }

    function testDepositCollateralUpdatesStateAndTransfersTokens() public approved {
        vm.startPrank(user);
        sfcEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // State updated
        uint256 deposited = sfcEngine.getCollateralBalanceOfUser(user, weth);
        assertEq(deposited, AMOUNT_COLLATERAL);

        // Tokens transferred to engine
        uint256 engineBalance = ERC20Mock(weth).balanceOf(address(sfcEngine));
        assertEq(engineBalance, AMOUNT_COLLATERAL);
    }

    function testDepositCollateralEmitsEvent() public approved {
        vm.startPrank(user);

        vm.expectEmit(true, true, true, true);
        emit CollateralDeposited(user, weth, AMOUNT_COLLATERAL);

        sfcEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testMultipleDepositsAccumulateCorrectly() public approved {
        vm.startPrank(user);

        sfcEngine.depositCollateral(weth, 5 ether);
        sfcEngine.depositCollateral(weth, 5 ether);

        vm.stopPrank();

        uint256 deposited = sfcEngine.getCollateralBalanceOfUser(user, weth);
        assertEq(deposited, AMOUNT_COLLATERAL);
    }

    function testRevertsIfTransferFromFails() public {
        ERC20FailTransferFrom badToken = new ERC20FailTransferFrom();
        MockV3Aggregator badFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);

        tokens[0] = address(badToken);
        feeds[0] = address(badFeed);

        SFCEngine engine = new SFCEngine(tokens, feeds, address(sfc));

        vm.startPrank(user);
        badToken.mint(user, AMOUNT_COLLATERAL);
        badToken.approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(SFCEngine.SFCEngine__TransferFailedInDepositCollateral.selector);
        engine.depositCollateral(address(badToken), AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    /*////////////////////////////////////////////////
            depositCollateralAndMintSfc TESTS
    ////////////////////////////////////////////////*/
    modifier depositedAndApproved() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        _;
        vm.stopPrank();
    }

    function testDepositCollateralAndMintSfc() public depositedAndApproved {
        uint256 sfcToMint = 5000e18; // safe amount

        vm.startPrank(user);
        sfcEngine.depositCollateralAndMintSfc(weth, AMOUNT_COLLATERAL, sfcToMint);
        vm.stopPrank();

        // Assert collateral was deposited
        uint256 collateralBalance = sfcEngine.getCollateralBalanceOfUser(user, weth);
        assertEq(collateralBalance, AMOUNT_COLLATERAL);

        // Assert SFC was minted
        uint256 sfcBalance = sfc.balanceOf(user);
        assertEq(sfcBalance, sfcToMint);
    }

    function testDepositAndMintMatchesSeparateCalls() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);

        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        sfcEngine.mintSfc(MINT_VALUE);

        vm.stopPrank();

        uint256 collateral = sfcEngine.getCollateralBalanceOfUser(user, address(weth));
        uint256 sfcBalance = sfc.balanceOf(user);

        assertEq(collateral, AMOUNT_COLLATERAL);
        assertEq(sfcBalance, MINT_VALUE);
    }

    function testDepositAndMintIsEquivalentToSeparateCalls() public depositedAndApproved {
        uint256 sfcToMint = 5000e18;

        vm.startPrank(user);

        sfcEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        sfcEngine.mintSfc(sfcToMint);

        vm.stopPrank();

        assertEq(sfcEngine.getCollateralBalanceOfUser(user, weth), AMOUNT_COLLATERAL);
        assertEq(sfc.balanceOf(user), sfcToMint);
    }

    function testRevertsIfZeroCollateral() public {
        vm.startPrank(user);
        vm.expectRevert();
        sfcEngine.depositCollateralAndMintSfc(address(weth), 0, 100e18);
        vm.stopPrank();
    }

    function testRevertsIfTokenNotAllowed() public {
        ERC20Mock fakeToken = new ERC20Mock("Fake", "FAKE", user, 100 ether);

        vm.startPrank(user);
        fakeToken.approve(address(sfcEngine), type(uint256).max);

        vm.expectRevert();
        sfcEngine.depositCollateralAndMintSfc(address(fakeToken), 10 ether, 100e18);
        vm.stopPrank();
    }

    /*////////////////////////////////////////////////
        PUBLIC & EXTERNAL VIEW FUNCTIONS TESTS
    ////////////////////////////////////////////////*/
    modifier depositedWeth() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 20_000e18;
        uint256 expectedEthAmount = 10 ether;

        uint256 actualEthAmount = sfcEngine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(actualEthAmount, expectedEthAmount);
    }

    function testUsdToTokenToUsdRoundTrip() public view {
        uint256 usdAmount = 15_000e18;

        uint256 tokenAmount = sfcEngine.getTokenAmountFromUsd(weth, usdAmount);

        uint256 usdValueBack = sfcEngine.getUsdValue(weth, tokenAmount);

        assertApproxEqAbs(usdValueBack, usdAmount, 1);
    }

    function testGetAccountCollateralValueSingleToken() public depositedWeth {
        uint256 expectedUsdValue = 20_000e18;

        uint256 actualUsdValue = sfcEngine.getAccountCollateralValue(user);

        assertEq(actualUsdValue, expectedUsdValue);
    }

    function testGetAccountCollateralValueMultipleTokens() public {
        // -------- WETH --------
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // -------- WBTC --------
        uint256 wbtcAmount = 10 ether;
        vm.startPrank(user);
        ERC20Mock(wbtc).approve(address(sfcEngine), wbtcAmount);
        sfcEngine.depositCollateral(wbtc, wbtcAmount);
        vm.stopPrank();

        // 10 ETH * $2000 = $20,000
        // 10 BTC * $1000 = $10,000
        uint256 expectedTotalUsdValue = 30_000e18;

        uint256 actualUsdValue = sfcEngine.getAccountCollateralValue(user);

        assertEq(actualUsdValue, expectedTotalUsdValue);
    }

    function testGetAccountInformationReturnsCorrectValues() public depositedWeth {
        (uint256 totalSfcMinted, uint256 collateralUsdValue) = sfcEngine.getAccountInformation(user);

        assertEq(totalSfcMinted, 0);
        assertEq(collateralUsdValue, 20_000e18);
    }

    function testGetAccountCollateralValueReturnsZeroForEmptyUser() public view {
        uint256 value = sfcEngine.getAccountCollateralValue(user);

        assertEq(value, 0);
    }

    /*////////////////////////////////////////////////
                redeemCollateral TESTS
    ////////////////////////////////////////////////*/
    modifier depositedAndMinted() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        sfcEngine.mintSfc(5_000e18); // safe mint
        vm.stopPrank();
        _;
    }

    function testRedeemCollateralReducesBalanceAndTransfersTokens() public depositedCollateral {
        //ERC20Mock(weth).mint(user, MINT_VALUE); -> Not needed here, coz redeeming SFC doesn't require user to have SFC tokens.
        uint256 redeemAmount = 5 ether;

        uint256 userBalanceBefore = ERC20Mock(weth).balanceOf(user);

        vm.startPrank(user);
        sfcEngine.redeemCollateral(weth, redeemAmount);
        vm.stopPrank();

        // Storage updated
        uint256 remainingCollateral = sfcEngine.getCollateralBalanceOfUser(user, weth);
        assertEq(remainingCollateral, AMOUNT_COLLATERAL - redeemAmount);

        // Tokens transferred back
        uint256 userBalanceAfter = ERC20Mock(weth).balanceOf(user);
        assertEq(userBalanceAfter, userBalanceBefore + redeemAmount);
    }

    function testRedeemCollateralEmitsEvent() public depositedCollateral {
        uint256 redeemAmount = 3 ether;

        vm.startPrank(user);

        vm.expectEmit(true, true, true, true);
        emit CollateralRedeemed(user, user, weth, redeemAmount);

        sfcEngine.redeemCollateral(weth, redeemAmount);
        vm.stopPrank();
    }

    function testRedeemCollateralRevertsIfTransferFails() public {
        // Arrange
        ERC20FailTransfer badToken = new ERC20FailTransfer();
        MockV3Aggregator badFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);

        tokens[0] = address(badToken);
        feeds[0] = address(badFeed);

        SFCEngine engine = new SFCEngine(tokens, feeds, address(sfc));

        badToken.mint(user, AMOUNT_COLLATERAL);

        vm.startPrank(user);
        badToken.approve(address(engine), AMOUNT_COLLATERAL);

        engine.depositCollateral(address(badToken), AMOUNT_COLLATERAL);

        // Act + Assert
        vm.expectRevert(SFCEngine.SFCEngine__TransferFailedInRedeemCollateral.selector);
        engine.redeemCollateral(address(badToken), 1 ether);
        vm.stopPrank();
    }

    function testDepositCollateralRevertsIfTransferFromFails() public {
        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);
        // Arrange
        ERC20FailTransferFrom badToken = new ERC20FailTransferFrom();
        MockV3Aggregator feed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        tokens[0] = address(badToken);
        feeds[0] = address(feed);

        SFCEngine engine = new SFCEngine(tokens, feeds, address(sfc));

        badToken.mint(user, STARTING_ERC20_BALANCE);

        vm.startPrank(user);
        badToken.approve(address(engine), AMOUNT_COLLATERAL);

        // Act + Assert
        vm.expectRevert(SFCEngine.SFCEngine__TransferFailedInDepositCollateral.selector);
        engine.depositCollateral(address(badToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /*////////////////////////////////////////////////
                    burnSfc TESTS
    ////////////////////////////////////////////////*/
    function testBurnSfcRevertsIfZero() public {
        vm.startPrank(user);

        vm.expectRevert(SFCEngine.SFCEngine__NeedsMoreThanZero.selector);
        sfcEngine.burnSfc(0);

        vm.stopPrank();
    }

    function testBurnSfcReducesUserBalance() public {
        // Arrange
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        sfcEngine.mintSfc(MINT_VALUE);

        uint256 startingBalance = sfc.balanceOf(user);

        // Act
        vm.startPrank(user);
        sfc.approve(address(sfcEngine), MINT_VALUE);
        sfcEngine.burnSfc(MINT_VALUE);
        vm.stopPrank();

        // Assert
        uint256 endingBalance = sfc.balanceOf(user);
        assertEq(endingBalance, startingBalance - MINT_VALUE);
        vm.stopPrank();
    }

    function testBurnSfcUpdatesMintedAmount() public {
        // Arrange
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        sfcEngine.mintSfc(MINT_VALUE);

        // Act
        vm.startPrank(user);
        sfc.approve(address(sfcEngine), MINT_VALUE);
        sfcEngine.burnSfc(MINT_VALUE);
        vm.stopPrank();

        // Assert
        (uint256 totalMinted,) = sfcEngine.getAccountInformation(user);
        assertEq(totalMinted, 0);

        vm.stopPrank();
    }

    function testBurnSfcRevertsIfBurningMoreThanMinted() public {
        // Arrange
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        sfcEngine.mintSfc(MINT_VALUE);

        // Act + Assert
        vm.expectRevert(SFCEngine.SFCEngine__BurnFailedBecauseMintedLesserThanAttemptedToBurn.selector);
        sfcEngine.burnSfc(MINT_VALUE + 1);
        vm.stopPrank();
    }

    function testBurnSfcDoesNotBreakHealthFactor() public {
        // Arrange
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        sfcEngine.mintSfc(MINT_VALUE);

        // Act
        sfc.approve(address(sfcEngine), MINT_VALUE);
        sfcEngine.burnSfc(MINT_VALUE / 2);

        // Assert
        uint256 healthFactor = sfcEngine.getHealthFactor(user);
        assert(healthFactor >= sfcEngine.getMinHealthFactor());

        vm.stopPrank();
    }

    /*////////////////////////////////////////////////
                    mintSfc TESTS
    ////////////////////////////////////////////////*/
    function testMintSfcRevertsIfZero() public {
        vm.startPrank(user);

        vm.expectRevert(SFCEngine.SFCEngine__NeedsMoreThanZero.selector);
        sfcEngine.mintSfc(0);

        vm.stopPrank();
    }

    function testMintSfcRevertsIfHealthFactorIsBroken() public {
        vm.startPrank(user);

        // Deposit collateral
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        // Try to mint too much SFC
        uint256 excessiveMintAmount = 100_000 ether;

        vm.expectRevert(SFCEngine.SFCEngine__BreaksHealthFactor.selector);
        sfcEngine.mintSfc(excessiveMintAmount);

        vm.stopPrank();
    }

    function testMintSfcMintsSfcSuccessfully() public {
        vm.startPrank(user);

        // Deposit collateral
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        uint256 mintAmount = 5 ether;

        sfcEngine.mintSfc(mintAmount);

        uint256 userSfcBalance = sfc.balanceOf(user);
        assertEq(userSfcBalance, mintAmount);

        vm.stopPrank();
    }

    function testMintSfcUpdatesMintedMapping() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        uint256 mintAmount = 5 ether;
        sfcEngine.mintSfc(mintAmount);

        (uint256 totalSfcMinted,) = sfcEngine.getAccountInformation(user);
        assertEq(totalSfcMinted, mintAmount);

        vm.stopPrank();
    }

    function testMintSfcRevertsIfMintFails() public {
        uint256 collateralAmount = 10 ether;
        uint256 mintAmount = 100 ether;

        // Arrange: give user collateral
        ERC20Mock(weth).mint(user, collateralAmount);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), collateralAmount);
        sfcEngine.depositCollateral(weth, collateralAmount);
        vm.stopPrank();

        // Mock SFC mint to return false
        vm.mockCall(address(sfc), abi.encodeWithSelector(sfc.mint.selector), abi.encode(false));

        // Act + Assert
        vm.startPrank(user);
        vm.expectRevert(SFCEngine.SFCEngine__MintFailed.selector);
        sfcEngine.mintSfc(mintAmount);
        vm.stopPrank();
    }

    /*////////////////////////////////////////////////
                    liquidate TESTS
    ////////////////////////////////////////////////*/
    function testLiquidateRevertsIfDebtToCoverIsZero() public {
        vm.startPrank(user);

        vm.expectRevert(SFCEngine.SFCEngine__NeedsMoreThanZero.selector);
        sfcEngine.liquidate(address(weth), user, 0);

        vm.stopPrank();
    }

    function testLiquidateRevertsIfHealthFactorIsOk() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        sfcEngine.mintSfc(10 ether); // Safe mint

        vm.expectRevert(SFCEngine.SFCEngine__HealthFactorOk.selector);
        sfcEngine.liquidate(address(weth), user, 1 ether);

        vm.stopPrank();
    }

    function testLiquidateWorks() public {
        // USER: deposit + over-mint to break HF
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        sfcEngine.mintSfc(MINT_VALUE_TO_TEST_LIQUIDATION_WORKS); // Over mint to break HF
        vm.stopPrank();

        // PRICE CRASH 🔥
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(18e8);

        // LIQUIDATOR setup
        vm.startPrank(liquidator);
        ERC20Mock(weth).mint(liquidator, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
        sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        sfcEngine.mintSfc(DEBT_TO_COVER);
        sfc.approve(address(sfcEngine), DEBT_TO_COVER);

        // Act
        sfcEngine.liquidate(address(weth), user, DEBT_TO_COVER);
        vm.stopPrank();
    }

    function testLiquidateRevertsIfHealthFactorNotImproved() public {
        uint256 collateralAmount = 10 ether;
        uint256 mintAmount = 5000 ether;
        uint256 debtToCover = 50 ether;

        // ---------- Arrange ----------
        // User deposits collateral & mints SFC
        ERC20Mock(weth).mint(user, collateralAmount);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), collateralAmount);
        sfcEngine.depositCollateral(weth, collateralAmount);
        sfcEngine.mintSfc(mintAmount);
        vm.stopPrank();

        // Crash ETH price -> user becomes unhealthy
        MockV3Aggregator ethUsdFeed = MockV3Aggregator(sfcEngine.getCollateralTokenPriceFeed(weth));

        ethUsdFeed.updateAnswer(500e8);

        uint256 startingHealthFactor = sfcEngine.getHealthFactor(user);
        assertLt(startingHealthFactor, sfcEngine.getMinHealthFactor());

        // ---------- Liquidator setup ----------
        ERC20Mock(weth).mint(liquidator, collateralAmount);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(sfcEngine), collateralAmount);
        sfcEngine.depositCollateral(weth, collateralAmount);
        sfcEngine.mintSfc(debtToCover);
        ERC20Mock(address(sfc)).approve(address(sfcEngine), debtToCover);
        vm.stopPrank();

        // ---------- Act + Assert ----------
        vm.startPrank(liquidator);
        vm.expectRevert(SFCEngine.SFCEngine__HealthFactorNotImproved.selector);
        sfcEngine.liquidate(weth, user, debtToCover);
        vm.stopPrank();
    }

    // function testLiquidatorReceivesBonusCollateral() public {
    //     // ---------- Arrange ----------
    //     // User becomes undercollateralized
    //     vm.startPrank(user);
    //     ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
    //     sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
    //     sfcEngine.mintSfc(500 ether);
    //     vm.stopPrank();

    //     // Price crash
    //     MockV3Aggregator(ethUsdPriceFeed).updateAnswer(100e8);

    //     // Liquidator setup
    //     vm.startPrank(liquidator);
    //     ERC20Mock(weth).mint(liquidator, AMOUNT_COLLATERAL);
    //     ERC20Mock(weth).approve(address(sfcEngine), AMOUNT_COLLATERAL);
    //     sfcEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
    //     sfcEngine.mintSfc(50 ether);

    //     sfc.approve(address(sfcEngine), 50 ether);

    //     uint256 balanceBefore = ERC20Mock(weth).balanceOf(liquidator);

    //     // ---------- Act ----------
    //     sfcEngine.liquidate(address(weth), user, 3000 ether);

    //     uint256 balanceAfter = ERC20Mock(weth).balanceOf(liquidator);

    //     vm.stopPrank();

    //     // ---------- Assert ----------
    //     assertGt(balanceAfter, balanceBefore);
    // }

    // function testLiquidationReducesUserDebt() public {
    //     (uint256 mintedBefore, ) = sfcEngine.getAccountInformation(user);

    //     // liquidate...

    //     (uint256 mintedAfter, ) = sfcEngine.getAccountInformation(user);
    //     assertLt(mintedAfter, mintedBefore);
    // }

    // function testLiquidateRevertsIfHealthFactorNotImproved() public {
    //     vm.startPrank(user);
    //     ERC20Mock(weth).approve(address(sfcEngine), 1 ether);
    //     sfcEngine.depositCollateral(address(weth), 1 ether);
    //     sfcEngine.mintSfc(100 ether);
    //     vm.stopPrank();

    //     vm.startPrank(liquidator);
    //     sfc.approve(address(sfcEngine), 1 ether);

    //     vm.expectRevert(SFCEngine.SFCEngine__HealthFactorNotImproved.selector);
    //     sfcEngine.liquidate(address(weth), user, 1 ether);
    //     vm.stopPrank();
    // }

    /*////////////////////////////////////////////////
                    MODIFIERS TESTS
    ////////////////////////////////////////////////*/
    function testMoreThanZeroModifierRevertsForZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(SFCEngine.SFCEngine__NeedsMoreThanZero.selector);
        sfcEngine.depositCollateral(address(weth), 0);
        vm.stopPrank();
    }

    function testIsAllowedModifierRevertsForUnapprovedToken() public {
        ERC20Mock fakeToken = new ERC20Mock("Fake", "FAKE", user, 100 ether);
        vm.startPrank(user);
        vm.expectRevert(SFCEngine.SFCEngine__NotAllowedToken.selector);
        sfcEngine.depositCollateral(address(fakeToken), 10 ether);
        vm.stopPrank();
    }

    function testDepositCollateralSucceedsIfAmountMoreThanZero() public {
        uint256 amount = 1 ether;

        ERC20Mock(weth).mint(user, amount);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), amount);
        sfcEngine.depositCollateral(weth, amount);
        vm.stopPrank();

        uint256 deposited = sfcEngine.getCollateralBalanceOfUser(user, weth);

        assertEq(deposited, amount); // 1 ether + previous deposits
    }

    /*////////////////////////////////////////////////
        getUsdValue & getTokenAmountFromUsd TESTS
    ////////////////////////////////////////////////*/
    function testGetUsdValueForOneEth() public view {
        uint256 ethAmount = 1 ether;

        uint256 usdValue = sfcEngine.getUsdValue(weth, ethAmount);

        assertEq(usdValue, 2000 ether);
    }

    function testGetUsdValueZeroAmount() public view {
        uint256 usdValue = sfcEngine.getUsdValue(weth, 0);

        assertEq(usdValue, 0);
    }

    function testGetUsdValueAfterPriceChange() public {
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(3000e8);

        uint256 usdValue = sfcEngine.getUsdValue(weth, 1 ether);

        assertEq(usdValue, 3000 ether);
    }

    function testGetTokenAmountFromUsdAfterPriceChange() public {
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(3000e8);

        uint256 usdAmount = 3000 ether;
        uint256 ethAmount = sfcEngine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(ethAmount, 1 ether);
    }

    function testUsdToTokenAndBackIsConsistent() public view {
        uint256 ethAmount = 2 ether;

        uint256 usdValue = sfcEngine.getUsdValue(weth, ethAmount);

        uint256 tokenAmount = sfcEngine.getTokenAmountFromUsd(weth, usdValue);

        assertEq(tokenAmount, ethAmount);
    }

    /*////////////////////////////////////////////////
                    TEST GETTERS
    ////////////////////////////////////////////////*/
    function testGetAdditionalFeedPrecision() public view {
        assertEq(sfcEngine.getAdditionalFeedPrecision(), sfcEngine.ADDITIONAL_FEED_PRECISION());
    }

    function testGetPrecision() public view {
        assertEq(sfcEngine.getPrecision(), sfcEngine.PRECISION());
    }

    function testGetLiquidationThreshold() public view {
        assertEq(sfcEngine.getLiquidationThreshold(), sfcEngine.LIQUIDATION_THRESHOLD());
    }

    function testGetLiquidationPrecision() public view {
        assertEq(sfcEngine.getLiquidationPrecision(), sfcEngine.LIQUIDATION_PRECISION());
    }

    function testGetMinHealthFactor() public view {
        assertEq(sfcEngine.getMinHealthFactor(), sfcEngine.MIN_HEALTH_FACTOR());
    }

    function testGetLiquidationBonus() public view {
        assertEq(sfcEngine.getLiquidationBonus(), sfcEngine.LIQUIDATION_BONUS());
    }

    function testGetSfcReturnsCorrectAddress() public view {
        assertEq(sfcEngine.getSfc(), address(sfc));
    }

    function testGetCollateralTokenPriceFeed() public view {
        address priceFeed = sfcEngine.getCollateralTokenPriceFeed(weth);
        assertTrue(priceFeed != address(0));
    }

    function testGetSPriceFeedReturnsSameValue() public view {
        assertEq(sfcEngine.getSPriceFeed(weth), sfcEngine.getCollateralTokenPriceFeed(weth));
    }

    function testGetCollateralTokens() public view {
        address[] memory tokens = sfcEngine.getCollateralTokens();

        assertEq(tokens.length, 2);
        assertEq(tokens[0], weth);
        assertEq(tokens[1], wbtc);
    }

    function testGetCollateralBalanceOfUserIsZeroInitially() public view {
        uint256 balance = sfcEngine.getCollateralBalanceOfUser(user, weth);

        assertEq(balance, 0);
    }

    function testGetCollateralBalanceOfUserAfterDeposit() public {
        uint256 depositAmount = 10 ether;

        ERC20Mock(weth).mint(user, depositAmount);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), depositAmount);
        sfcEngine.depositCollateral(weth, depositAmount);
        vm.stopPrank();

        uint256 balance = sfcEngine.getCollateralBalanceOfUser(user, weth);

        assertEq(balance, depositAmount);
    }

    function testGetHealthFactorWithNoDebt() public view {
        uint256 healthFactor = sfcEngine.getHealthFactor(user);

        assertEq(healthFactor, type(uint256).max);
    }

    function testGetHealthFactorAfterMinting() public {
        uint256 depositAmount = 10 ether;
        uint256 mintAmount = 1000 ether;

        ERC20Mock(weth).mint(user, depositAmount);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(sfcEngine), depositAmount);
        sfcEngine.depositCollateral(weth, depositAmount);
        sfcEngine.mintSfc(mintAmount);
        vm.stopPrank();

        uint256 healthFactor = sfcEngine.getHealthFactor(user);

        assertGt(healthFactor, sfcEngine.getMinHealthFactor());
    }
}
