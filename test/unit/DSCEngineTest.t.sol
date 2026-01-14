// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
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

contract DSCEngineTest is Test {
    DeployDSC internal deployer;
    DecentralizedStableCoin internal dsc;
    DSCEngine internal dscEngine;
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
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
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

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function testConstructorSetsPriceFeedsCorrectly() public {
        ERC20Mock wethForCheckingPrice = new ERC20Mock("Wrapped ETH", "WETH", address(this), 0);
        MockV3Aggregator ethUsdFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        address[] memory tokens = new address[](1);
        address[] memory priceFeeds = new address[](1);

        tokens[0] = address(wethForCheckingPrice);
        priceFeeds[0] = address(ethUsdFeed);

        dsc = new DecentralizedStableCoin();

        DSCEngine engine = new DSCEngine(tokens, priceFeeds, address(dsc));

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

        dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokens, feeds, address(dsc));

        address[] memory collateralTokens = engine.getCollateralTokens();

        assertEq(collateralTokens.length, 2);
        assertEq(collateralTokens[0], address(wethForCheckingRegistration));
        assertEq(collateralTokens[1], address(wbtcForCheckingRegistration));
    }

    function testConstructorSetsDscAddress() public {
        address[] memory tokens = new address[](0);
        address[] memory feeds = new address[](0);

        dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokens, feeds, address(dsc));

        address storedDsc = engine.getDsc();
        assertEq(storedDsc, address(dsc));
    }

    function testIfSPriceFeedsDontCorrectlyMatch() public {
        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);

        tokens[0] = address(0);
        feeds[0] = address(0);

        dsc = new DecentralizedStableCoin();

        DSCEngine engine = new DSCEngine(tokens, feeds, address(dsc));

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
        uint256 actualUsd = dscEngine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        // $2000 per ETH -> 100/2000 = 0.05 ETH
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dscEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /*////////////////////////////////////////////////
                depositCollateral TESTS
    ////////////////////////////////////////////////*/
    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier approved() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        _;
        vm.stopPrank();
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", address(this), AMOUNT_COLLATERAL);
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testDepositCollateralUpdatesCollateralBalance() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
    }

    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(user);
        uint256 expectedDepositedAmount = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(expectedDepositedAmount, AMOUNT_COLLATERAL);
    }

    function testDepositCollateralUpdatesStateAndTransfersTokens() public approved {
        vm.startPrank(user);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // State updated
        uint256 deposited = dscEngine.getCollateralBalanceOfUser(user, weth);
        assertEq(deposited, AMOUNT_COLLATERAL);

        // Tokens transferred to engine
        uint256 engineBalance = ERC20Mock(weth).balanceOf(address(dscEngine));
        assertEq(engineBalance, AMOUNT_COLLATERAL);
    }

    function testDepositCollateralEmitsEvent() public approved {
        vm.startPrank(user);

        vm.expectEmit(true, true, true, true);
        emit CollateralDeposited(user, weth, AMOUNT_COLLATERAL);

        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testMultipleDepositsAccumulateCorrectly() public approved {
        vm.startPrank(user);

        dscEngine.depositCollateral(weth, 5 ether);
        dscEngine.depositCollateral(weth, 5 ether);

        vm.stopPrank();

        uint256 deposited = dscEngine.getCollateralBalanceOfUser(user, weth);
        assertEq(deposited, AMOUNT_COLLATERAL);
    }

    function testRevertsIfTransferFromFails() public {
        ERC20FailTransferFrom badToken = new ERC20FailTransferFrom();
        MockV3Aggregator badFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);

        tokens[0] = address(badToken);
        feeds[0] = address(badFeed);

        DSCEngine engine = new DSCEngine(tokens, feeds, address(dsc));

        vm.startPrank(user);
        badToken.mint(user, AMOUNT_COLLATERAL);
        badToken.approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__TransferFailedInDepositCollateral.selector);
        engine.depositCollateral(address(badToken), AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    /*////////////////////////////////////////////////
            depositCollateralAndMintDsc TESTS
    ////////////////////////////////////////////////*/
    modifier depositedAndApproved() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        _;
        vm.stopPrank();
    }

    function testDepositCollateralAndMintDsc() public depositedAndApproved {
        uint256 dscToMint = 5000e18; // safe amount

        vm.startPrank(user);
        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, dscToMint);
        vm.stopPrank();

        // Assert collateral was deposited
        uint256 collateralBalance = dscEngine.getCollateralBalanceOfUser(user, weth);
        assertEq(collateralBalance, AMOUNT_COLLATERAL);

        // Assert DSC was minted
        uint256 dscBalance = dsc.balanceOf(user);
        assertEq(dscBalance, dscToMint);
    }

    function testDepositAndMintMatchesSeparateCalls() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dscEngine.mintDsc(MINT_VALUE);

        vm.stopPrank();

        uint256 collateral = dscEngine.getCollateralBalanceOfUser(user, address(weth));
        uint256 dscBalance = dsc.balanceOf(user);

        assertEq(collateral, AMOUNT_COLLATERAL);
        assertEq(dscBalance, MINT_VALUE);
    }

    function testDepositAndMintIsEquivalentToSeparateCalls() public depositedAndApproved {
        uint256 dscToMint = 5000e18;

        vm.startPrank(user);

        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        dscEngine.mintDsc(dscToMint);

        vm.stopPrank();

        assertEq(dscEngine.getCollateralBalanceOfUser(user, weth), AMOUNT_COLLATERAL);
        assertEq(dsc.balanceOf(user), dscToMint);
    }

    function testRevertsIfZeroCollateral() public {
        vm.startPrank(user);
        vm.expectRevert();
        dscEngine.depositCollateralAndMintDsc(address(weth), 0, 100e18);
        vm.stopPrank();
    }

    function testRevertsIfTokenNotAllowed() public {
        ERC20Mock fakeToken = new ERC20Mock("Fake", "FAKE", user, 100 ether);

        vm.startPrank(user);
        fakeToken.approve(address(dscEngine), type(uint256).max);

        vm.expectRevert();
        dscEngine.depositCollateralAndMintDsc(address(fakeToken), 10 ether, 100e18);
        vm.stopPrank();
    }

    /*////////////////////////////////////////////////
        PUBLIC & EXTERNAL VIEW FUNCTIONS TESTS
    ////////////////////////////////////////////////*/
    modifier depositedWeth() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 20_000e18;
        uint256 expectedEthAmount = 10 ether;

        uint256 actualEthAmount = dscEngine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(actualEthAmount, expectedEthAmount);
    }

    function testUsdToTokenToUsdRoundTrip() public view {
        uint256 usdAmount = 15_000e18;

        uint256 tokenAmount = dscEngine.getTokenAmountFromUsd(weth, usdAmount);

        uint256 usdValueBack = dscEngine.getUsdValue(weth, tokenAmount);

        assertApproxEqAbs(usdValueBack, usdAmount, 1);
    }

    function testGetAccountCollateralValueSingleToken() public depositedWeth {
        uint256 expectedUsdValue = 20_000e18;

        uint256 actualUsdValue = dscEngine.getAccountCollateralValue(user);

        assertEq(actualUsdValue, expectedUsdValue);
    }

    function testGetAccountCollateralValueMultipleTokens() public {
        // -------- WETH --------
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // -------- WBTC --------
        uint256 wbtcAmount = 10 ether;
        vm.startPrank(user);
        ERC20Mock(wbtc).approve(address(dscEngine), wbtcAmount);
        dscEngine.depositCollateral(wbtc, wbtcAmount);
        vm.stopPrank();

        // 10 ETH * $2000 = $20,000
        // 10 BTC * $1000 = $10,000
        uint256 expectedTotalUsdValue = 30_000e18;

        uint256 actualUsdValue = dscEngine.getAccountCollateralValue(user);

        assertEq(actualUsdValue, expectedTotalUsdValue);
    }

    function testGetAccountInformationReturnsCorrectValues() public depositedWeth {
        (uint256 totalDscMinted, uint256 collateralUsdValue) = dscEngine.getAccountInformation(user);

        assertEq(totalDscMinted, 0);
        assertEq(collateralUsdValue, 20_000e18);
    }

    function testGetAccountCollateralValueReturnsZeroForEmptyUser() public view {
        uint256 value = dscEngine.getAccountCollateralValue(user);

        assertEq(value, 0);
    }

    /*////////////////////////////////////////////////
                redeemCollateral TESTS
    ////////////////////////////////////////////////*/
    modifier depositedAndMinted() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        dscEngine.mintDsc(5_000e18); // safe mint
        vm.stopPrank();
        _;
    }

    function testRedeemCollateralReducesBalanceAndTransfersTokens() public depositedCollateral {
        //ERC20Mock(weth).mint(user, MINT_VALUE); -> Not needed here, coz redeeming DSC doesn't require user to have DSC tokens.
        uint256 redeemAmount = 5 ether;

        uint256 userBalanceBefore = ERC20Mock(weth).balanceOf(user);

        vm.startPrank(user);
        dscEngine.redeemCollateral(weth, redeemAmount);
        vm.stopPrank();

        // Storage updated
        uint256 remainingCollateral = dscEngine.getCollateralBalanceOfUser(user, weth);
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

        dscEngine.redeemCollateral(weth, redeemAmount);
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

        DSCEngine engine = new DSCEngine(tokens, feeds, address(dsc));

        badToken.mint(user, AMOUNT_COLLATERAL);

        vm.startPrank(user);
        badToken.approve(address(engine), AMOUNT_COLLATERAL);

        engine.depositCollateral(address(badToken), AMOUNT_COLLATERAL);

        // Act + Assert
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailedInRedeemCollateral.selector);
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

        DSCEngine engine = new DSCEngine(tokens, feeds, address(dsc));

        badToken.mint(user, STARTING_ERC20_BALANCE);

        vm.startPrank(user);
        badToken.approve(address(engine), AMOUNT_COLLATERAL);

        // Act + Assert
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailedInDepositCollateral.selector);
        engine.depositCollateral(address(badToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /*////////////////////////////////////////////////
                    burnDsc TESTS
    ////////////////////////////////////////////////*/
    function testBurnDscRevertsIfZero() public {
        vm.startPrank(user);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.burnDsc(0);

        vm.stopPrank();
    }

    function testBurnDscReducesUserBalance() public {
        // Arrange
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dscEngine.mintDsc(MINT_VALUE);

        uint256 startingBalance = dsc.balanceOf(user);

        // Act
        vm.startPrank(user);
        dsc.approve(address(dscEngine), MINT_VALUE);
        dscEngine.burnDsc(MINT_VALUE);
        vm.stopPrank();

        // Assert
        uint256 endingBalance = dsc.balanceOf(user);
        assertEq(endingBalance, startingBalance - MINT_VALUE);
        vm.stopPrank();
    }

    function testBurnDscUpdatesMintedAmount() public {
        // Arrange
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dscEngine.mintDsc(MINT_VALUE);

        // Act
        vm.startPrank(user);
        dsc.approve(address(dscEngine), MINT_VALUE);
        dscEngine.burnDsc(MINT_VALUE);
        vm.stopPrank();

        // Assert
        (uint256 totalMinted,) = dscEngine.getAccountInformation(user);
        assertEq(totalMinted, 0);

        vm.stopPrank();
    }

    function testBurnDscRevertsIfBurningMoreThanMinted() public {
        // Arrange
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dscEngine.mintDsc(MINT_VALUE);

        // Act + Assert
        vm.expectRevert(DSCEngine.DSCEngine__BurnFailedBecauseMintedLesserThanAttemptedToBurn.selector);
        dscEngine.burnDsc(MINT_VALUE + 1);
        vm.stopPrank();
    }

    function testBurnDscDoesNotBreakHealthFactor() public {
        // Arrange
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dscEngine.mintDsc(MINT_VALUE);

        // Act
        dsc.approve(address(dscEngine), MINT_VALUE);
        dscEngine.burnDsc(MINT_VALUE / 2);

        // Assert
        uint256 healthFactor = dscEngine.getHealthFactor(user);
        assert(healthFactor >= dscEngine.getMinHealthFactor());

        vm.stopPrank();
    }

    /*////////////////////////////////////////////////
                    mintDsc TESTS
    ////////////////////////////////////////////////*/
    function testMintDscRevertsIfZero() public {
        vm.startPrank(user);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.mintDsc(0);

        vm.stopPrank();
    }

    function testMintDscRevertsIfHealthFactorIsBroken() public {
        vm.startPrank(user);

        // Deposit collateral
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        // Try to mint too much DSC
        uint256 excessiveMintAmount = 100_000 ether;

        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        dscEngine.mintDsc(excessiveMintAmount);

        vm.stopPrank();
    }

    function testMintDscMintsDscSuccessfully() public {
        vm.startPrank(user);

        // Deposit collateral
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        uint256 mintAmount = 5 ether;

        dscEngine.mintDsc(mintAmount);

        uint256 userDscBalance = dsc.balanceOf(user);
        assertEq(userDscBalance, mintAmount);

        vm.stopPrank();
    }

    function testMintDscUpdatesMintedMapping() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        uint256 mintAmount = 5 ether;
        dscEngine.mintDsc(mintAmount);

        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(user);
        assertEq(totalDscMinted, mintAmount);

        vm.stopPrank();
    }

    function testMintDscRevertsIfMintFails() public {
        uint256 collateralAmount = 10 ether;
        uint256 mintAmount = 100 ether;

        // Arrange: give user collateral
        ERC20Mock(weth).mint(user, collateralAmount);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), collateralAmount);
        dscEngine.depositCollateral(weth, collateralAmount);
        vm.stopPrank();

        // Mock DSC mint to return false
        vm.mockCall(address(dsc), abi.encodeWithSelector(DecentralizedStableCoin.mint.selector), abi.encode(false));

        // Act + Assert
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        dscEngine.mintDsc(mintAmount);
        vm.stopPrank();
    }

    /*////////////////////////////////////////////////
                    liquidate TESTS
    ////////////////////////////////////////////////*/
    function testLiquidateRevertsIfDebtToCoverIsZero() public {
        vm.startPrank(user);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.liquidate(address(weth), user, 0);

        vm.stopPrank();
    }

    function testLiquidateRevertsIfHealthFactorIsOk() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dscEngine.mintDsc(10 ether); // Safe mint

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dscEngine.liquidate(address(weth), user, 1 ether);

        vm.stopPrank();
    }

    function testLiquidateWorks() public {
        // USER: deposit + over-mint to break HF
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dscEngine.mintDsc(MINT_VALUE_TO_TEST_LIQUIDATION_WORKS); // Over mint to break HF
        vm.stopPrank();

        // PRICE CRASH 🔥
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(18e8);

        // LIQUIDATOR setup
        vm.startPrank(liquidator);
        ERC20Mock(weth).mint(liquidator, AMOUNT_COLLATERAL);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);

        dscEngine.mintDsc(DEBT_TO_COVER);
        dsc.approve(address(dscEngine), DEBT_TO_COVER);

        // Act
        dscEngine.liquidate(address(weth), user, DEBT_TO_COVER);
        vm.stopPrank();
    }

    function testLiquidateRevertsIfHealthFactorNotImproved() public {
        uint256 collateralAmount = 10 ether;
        uint256 mintAmount = 5000 ether;
        uint256 debtToCover = 50 ether;

        // ---------- Arrange ----------
        // User deposits collateral & mints DSC
        ERC20Mock(weth).mint(user, collateralAmount);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), collateralAmount);
        dscEngine.depositCollateral(weth, collateralAmount);
        dscEngine.mintDsc(mintAmount);
        vm.stopPrank();

        // Crash ETH price -> user becomes unhealthy
        MockV3Aggregator ethUsdFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(weth));

        ethUsdFeed.updateAnswer(500e8);

        uint256 startingHealthFactor = dscEngine.getHealthFactor(user);
        assertLt(startingHealthFactor, dscEngine.getMinHealthFactor());

        // ---------- Liquidator setup ----------
        ERC20Mock(weth).mint(liquidator, collateralAmount);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dscEngine), collateralAmount);
        dscEngine.depositCollateral(weth, collateralAmount);
        dscEngine.mintDsc(debtToCover);
        ERC20Mock(address(dsc)).approve(address(dscEngine), debtToCover);
        vm.stopPrank();

        // ---------- Act + Assert ----------
        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        dscEngine.liquidate(weth, user, debtToCover);
        vm.stopPrank();
    }

    // function testLiquidatorReceivesBonusCollateral() public {
    //     // ---------- Arrange ----------
    //     // User becomes undercollateralized
    //     vm.startPrank(user);
    //     ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
    //     dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
    //     dscEngine.mintDsc(500 ether);
    //     vm.stopPrank();

    //     // Price crash
    //     MockV3Aggregator(ethUsdPriceFeed).updateAnswer(100e8);

    //     // Liquidator setup
    //     vm.startPrank(liquidator);
    //     ERC20Mock(weth).mint(liquidator, AMOUNT_COLLATERAL);
    //     ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
    //     dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
    //     dscEngine.mintDsc(50 ether);

    //     dsc.approve(address(dscEngine), 50 ether);

    //     uint256 balanceBefore = ERC20Mock(weth).balanceOf(liquidator);

    //     // ---------- Act ----------
    //     dscEngine.liquidate(address(weth), user, 3000 ether);

    //     uint256 balanceAfter = ERC20Mock(weth).balanceOf(liquidator);

    //     vm.stopPrank();

    //     // ---------- Assert ----------
    //     assertGt(balanceAfter, balanceBefore);
    // }

    // function testLiquidationReducesUserDebt() public {
    //     (uint256 mintedBefore, ) = dscEngine.getAccountInformation(user);

    //     // liquidate...

    //     (uint256 mintedAfter, ) = dscEngine.getAccountInformation(user);
    //     assertLt(mintedAfter, mintedBefore);
    // }

    // function testLiquidateRevertsIfHealthFactorNotImproved() public {
    //     vm.startPrank(user);
    //     ERC20Mock(weth).approve(address(dscEngine), 1 ether);
    //     dscEngine.depositCollateral(address(weth), 1 ether);
    //     dscEngine.mintDsc(100 ether);
    //     vm.stopPrank();

    //     vm.startPrank(liquidator);
    //     dsc.approve(address(dscEngine), 1 ether);

    //     vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
    //     dscEngine.liquidate(address(weth), user, 1 ether);
    //     vm.stopPrank();
    // }

    /*////////////////////////////////////////////////
                    MODIFIERS TESTS
    ////////////////////////////////////////////////*/
    function testMoreThanZeroModifierRevertsForZeroAmount() public {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(address(weth), 0);
        vm.stopPrank();
    }

    function testIsAllowedModifierRevertsForUnapprovedToken() public {
        ERC20Mock fakeToken = new ERC20Mock("Fake", "FAKE", user, 100 ether);
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(fakeToken), 10 ether);
        vm.stopPrank();
    }

    function testDepositCollateralSucceedsIfAmountMoreThanZero() public {
        uint256 amount = 1 ether;

        ERC20Mock(weth).mint(user, amount);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), amount);
        dscEngine.depositCollateral(weth, amount);
        vm.stopPrank();

        uint256 deposited = dscEngine.getCollateralBalanceOfUser(user, weth);

        assertEq(deposited, amount); // 1 ether + previous deposits
    }

    /*////////////////////////////////////////////////
        getUsdValue & getTokenAmountFromUsd TESTS
    ////////////////////////////////////////////////*/
    function testGetUsdValueForOneEth() public view {
        uint256 ethAmount = 1 ether;

        uint256 usdValue = dscEngine.getUsdValue(weth, ethAmount);

        assertEq(usdValue, 2000 ether);
    }

    function testGetUsdValueZeroAmount() public view {
        uint256 usdValue = dscEngine.getUsdValue(weth, 0);

        assertEq(usdValue, 0);
    }

    function testGetUsdValueAfterPriceChange() public {
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(3000e8);

        uint256 usdValue = dscEngine.getUsdValue(weth, 1 ether);

        assertEq(usdValue, 3000 ether);
    }

    function testGetTokenAmountFromUsdAfterPriceChange() public {
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(3000e8);

        uint256 usdAmount = 3000 ether;
        uint256 ethAmount = dscEngine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(ethAmount, 1 ether);
    }

    function testUsdToTokenAndBackIsConsistent() public view {
        uint256 ethAmount = 2 ether;

        uint256 usdValue = dscEngine.getUsdValue(weth, ethAmount);

        uint256 tokenAmount = dscEngine.getTokenAmountFromUsd(weth, usdValue);

        assertEq(tokenAmount, ethAmount);
    }

    /*////////////////////////////////////////////////
                    TEST GETTERS
    ////////////////////////////////////////////////*/
    function testGetAdditionalFeedPrecision() public view {
        assertEq(dscEngine.getAdditionalFeedPrecision(), dscEngine.ADDITIONAL_FEED_PRECISION());
    }

    function testGetPrecision() public view {
        assertEq(dscEngine.getPrecision(), dscEngine.PRECISION());
    }

    function testGetLiquidationThreshold() public view {
        assertEq(dscEngine.getLiquidationThreshold(), dscEngine.LIQUIDATION_THRESHOLD());
    }

    function testGetLiquidationPrecision() public view {
        assertEq(dscEngine.getLiquidationPrecision(), dscEngine.LIQUIDATION_PRECISION());
    }

    function testGetMinHealthFactor() public view {
        assertEq(dscEngine.getMinHealthFactor(), dscEngine.MIN_HEALTH_FACTOR());
    }

    function testGetLiquidationBonus() public view {
        assertEq(dscEngine.getLiquidationBonus(), dscEngine.LIQUIDATION_BONUS());
    }

    function testGetDscReturnsCorrectAddress() public view {
        assertEq(dscEngine.getDsc(), address(dsc));
    }

    function testGetCollateralTokenPriceFeed() public view {
        address priceFeed = dscEngine.getCollateralTokenPriceFeed(weth);
        assertTrue(priceFeed != address(0));
    }

    function testGetSPriceFeedReturnsSameValue() public view {
        assertEq(dscEngine.getSPriceFeed(weth), dscEngine.getCollateralTokenPriceFeed(weth));
    }

    function testGetCollateralTokens() public view {
        address[] memory tokens = dscEngine.getCollateralTokens();

        assertEq(tokens.length, 2);
        assertEq(tokens[0], weth);
        assertEq(tokens[1], wbtc);
    }

    function testGetCollateralBalanceOfUserIsZeroInitially() public view {
        uint256 balance = dscEngine.getCollateralBalanceOfUser(user, weth);

        assertEq(balance, 0);
    }

    function testGetCollateralBalanceOfUserAfterDeposit() public {
        uint256 depositAmount = 10 ether;

        ERC20Mock(weth).mint(user, depositAmount);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), depositAmount);
        dscEngine.depositCollateral(weth, depositAmount);
        vm.stopPrank();

        uint256 balance = dscEngine.getCollateralBalanceOfUser(user, weth);

        assertEq(balance, depositAmount);
    }

    function testGetHealthFactorWithNoDebt() public view {
        uint256 healthFactor = dscEngine.getHealthFactor(user);

        assertEq(healthFactor, type(uint256).max);
    }

    function testGetHealthFactorAfterMinting() public {
        uint256 depositAmount = 10 ether;
        uint256 mintAmount = 1000 ether;

        ERC20Mock(weth).mint(user, depositAmount);

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), depositAmount);
        dscEngine.depositCollateral(weth, depositAmount);
        dscEngine.mintDsc(mintAmount);
        vm.stopPrank();

        uint256 healthFactor = dscEngine.getHealthFactor(user);

        assertGt(healthFactor, dscEngine.getMinHealthFactor());
    }
}
