// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {StableForgeCoin} from "./StableForgeCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

/**
 * @title SFCEngine
 * @author Khushi Barnwal
 * @notice This contrat is the core of the Decentralized Stable Coin system.
 * It handles all the logic for minting and redeeming SFC, as well as depositing and withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI Stablecoin System) system.
 *
 * This system is designed to be as minimal as possible, and have the tokens maintain a (1 token == $1) peg.
 *
 * Collateral: Exogenous (ETH & BTC)
 * Dollar Pegged
 * Algorithmically Stable
 *
 * Our SFC system should always be OVERCOLLATERALIZED to ensure the peg. At no point should the value of all collateral <= the $ backed value of all SFC.
 *
 * It is similar to DAI if it had no governance, no fees, and was only backed by wETH & wBTC.
 */
contract SFCEngine is ReentrancyGuard {
    /*////////////////////////////////////////////////
                        ERRORS
    ////////////////////////////////////////////////*/
    error SFCEngine__NeedsMoreThanZero();
    error SFCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error SFCEngine__NotAllowedToken();
    error SFCEngine__TransferFailedInDepositCollateral();
    error SFCEngine__BreaksHealthFactor();
    error SFCEngine__MintFailed();
    error SFCEngine__TransferFailedInRedeemCollateral();
    error SFCEngine__TransferFailedInBurnSfc();
    error SFCEngine__HealthFactorOk();
    error SFCEngine__HealthFactorNotImproved();
    error SFCEngine__BurnFailedBecauseMintedLesserThanAttemptedToBurn();
    error SFCEngine__OraclePriceStale();
    error SFCEngine__OracleRoundIncomplete();
    error SFCEngine__OraclePriceInvalid();

    /*////////////////////////////////////////////////
                            TYPES
    ////////////////////////////////////////////////*/
    using OracleLib for AggregatorV3Interface;

    /*////////////////////////////////////////////////
                    STATE VARIABLES
    ////////////////////////////////////////////////*/
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10; // to bring 8 decimal places to 18
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50; // ??  // 200% overcollateralized
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_BONUS = 10; // 10%

    uint256 public constant MAX_PRICE_AGE = 3 hours;

    mapping(address token => address priceFeed) private sPriceFeeds; // types of collateral tokens accepted
    mapping(address user => mapping(address token => uint256 amount)) private sCollateralDeposited; // Says, “User X deposited Y amount of Token Z”
    mapping(address user => uint256 amountSfcMinted) private sSfcMinted; // user mapped to amount of SFC they have minted

    address[] private sCollateralTokens;

    StableForgeCoin private immutable I_SFC;

    /*////////////////////////////////////////////////
                        EVENTS
    ////////////////////////////////////////////////*/
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    /*////////////////////////////////////////////////
                        MODIFIERS
    ////////////////////////////////////////////////*/
    modifier moreThanZero(uint256 amount) {
        _moreThanZero(amount);
        _;
    }

    function _moreThanZero(uint256 amount) internal pure {
        if (amount == 0) {
            revert SFCEngine__NeedsMoreThanZero();
        }
    }

    modifier isAllowedToken(address token) {
        _isAllowedToken(token);
        _;
    }

    function _isAllowedToken(address token) internal view {
        if (sPriceFeeds[token] == address(0)) {
            revert SFCEngine__NotAllowedToken();
        }
    }

    /*////////////////////////////////////////////////
                        FUNCTIONS
    ////////////////////////////////////////////////*/
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address sfcAddress) {
        // USD Price Feeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert SFCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // For example: ETH/USD, BTC/USD, MKR/USD, etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            sPriceFeeds[tokenAddresses[i]] = priceFeedAddresses[i]; // if the tokens have a price feed they are allowed, else are not!
            sCollateralTokens.push(tokenAddresses[i]);
        }

        I_SFC = StableForgeCoin(sfcAddress);
    }

    /*////////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////*/

    /**
     * @notice Deposit collateral and mint SFC, an external state-modifying contract function.
     * @notice Both will be done in a single transaction.
     * @param tokenCollateralAddress The address of the token to deposit collateral.
     * @param amountCollateral The amount collateral to deposit.
     * @param amountSfcToMint The amount SFC to mint.
     * @custom:signature depositCollateralAndMintSfc(address,uint256,uint256)
     * @custom:selector 0xe90db8a3
     */
    function depositCollateralAndMintSfc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountSfcToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintSfc(amountSfcToMint);
    }

    /**
     * @notice Follows CEI.
     * @param tokenCollateralAddress The address of the token to deposit as collateral.
     * @param amountCollateral The amount collateral to deposit.
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        sCollateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;

        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral); // why IERC20? because we are interacting with an already deployed ERC20 token
        // why IERC20 and not ERC20? because we don't need the full implementation, just the interface to interact with it.

        if (!success) {
            revert SFCEngine__TransferFailedInDepositCollateral();
        }
    }

    /**
     * @notice Redeem collateral for sfc, an external state-modifying contract function.
     * @param tokenCollateralAddress The token collateral address to redeem.
     * @param amountCollateral The amount collateral to redeem.
     * @param amountSfcToBurn The amount sfc to burn.
     * This function burns SFC and redeems collateral in a single transaction.
     */
    function redeemCollateralForSfc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountSfcToBurn)
        external
    {
        burnSfc(amountSfcToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeemCollateral already checks for health factor
    }

    // In order to redeem collateral, you have to burn SFC.
    // 1. Health factor must be >1 AFTER collateral pulled.
    // DRY: Don't Repeat Yourself
    // CEI: Check, Effects, Interactions
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);

        _revertIfHealthFactorIsBroken(msg.sender);

        // $100 ETH = $20 SFC
        // $100 (breaks health factor)
        // 1. burn SFC
        // 2. pull collateral / redeem ETH
    }

    // Do we need to check health factor here? No, because they are reducing their debt.
    function burnSfc(uint256 amount) public moreThanZero(amount) {
        _burnSfc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // if they burned too much SFC, their health factor could go below minimum
        // i don't think this would ever hit...
    }

    // Check if the collateral value > SFC amount minted =>> Price Feeds, get USD value of collateral etc.
    /**
     * @notice Follows CEI.
     * @param amountSfcToMint -> The amount of stablecoins to mint.
     * @notice they must have more collateral value than the minimum threshold.
     */
    function mintSfc(uint256 amountSfcToMint) public moreThanZero(amountSfcToMint) nonReentrant {
        sSfcMinted[msg.sender] += amountSfcToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = I_SFC.mint(msg.sender, amountSfcToMint);
        if (!minted) {
            revert SFCEngine__MintFailed();
        }
    }

    // If we do start nearing undercollateralization, we need someone to liquidate positions.
    // ------------------------------------------------
    // $100 ETH backing $50 SFC
    // $20 ETH back $50 SFC (undercollateralized) => SFC isn't worth $1!!!
    // $75 ETH backing $50 SFC => This is done to lure liquidators(since they get a discount)
    // Liquidator take $75 backing and burns off $50 SFC
    // ------------------------------------------------
    // If someone is almost undercollateralized, we will pay you to liquidate them!

    /**
     * @notice Liquidate, an external state-modifying contract function.
     * @param collateral The collateral address to liquidate from the user.
     * @param user The user address who has broken health factor. Their _healthFactor < MIN_HEALTH_FACTOR.
     * @param debtToCover The amount of SFC you want to burn to improve the user's health factor.
     * @notice You can partially liquidate a user.
     * @notice This function will transfer the collateral to the liquidator at a discount.
     * @notice The working of this function assumes the protocol will be roughly 200% overcollateralized at all times, so there should always be enough collateral to cover the SFC.
     * @notice A known bug would be if the protocol were 100% or less collateralized, then we wouldn't be able to incentivize liquidators properly.
     * For ex, if the price of the collateral plummeted before anyone colud be liquidated.
     */
    /**
     * Follow CEI.
     * 1. Check that the user is indeed below the minimum health factor.
     * 2. Burn the SFC from the liquidator.
     * 3. Calculate the amount of collateral to give to the liquidator.
     * 4. Transfer the collateral to the liquidator.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // 1.
        // Check health factor of user(must be below minimum)
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert SFCEngine__HealthFactorOk();
        }

        // 2.
        // We want to burn their SFC "debt"
        // and take their collateral
        // Bad user ex: $140 ETH, $100 SFC
        // debtToCover = $100
        // $100 of SFC == ??? ETH?
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // 3.
        // Give liquidator 10% bonus
        // So we are giving the liquidator $110 worth of ETH for $100 SFC
        // We should implement a feature to liquidate in the event the protocol is insolvent.
        // And sweep extra amounts into a treasury.

        // ex: 0.05 * 10 / 100 = 0.005 ETH bonus
        // total amount given to liquidator = 0.055 ETH
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);

        // 4.
        // Burn SFC from liquidator
        _burnSfc(debtToCover, user, msg.sender);

        // Check health factor improved
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert SFCEngine__HealthFactorNotImproved();
        }

        // if this process ruined the liquidaror's health factor, we should not let them do so.
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*////////////////////////////////////////////////
            PRIVATE & INTERNAL VIEW FUNCTIONS
    ////////////////////////////////////////////////*/

    /**
     * @dev Low-level internal function to burn SFC.
     * Do not call unless the function calling it is checking for health factor being broken.
     */
    function _burnSfc(uint256 amountSfcToBurn, address onBehalfOf, address sfcFrom) internal {
        if (sSfcMinted[onBehalfOf] < amountSfcToBurn) {
            revert SFCEngine__BurnFailedBecauseMintedLesserThanAttemptedToBurn();
        } // added this check to prevent underflow

        sSfcMinted[onBehalfOf] -= amountSfcToBurn;
        bool success = I_SFC.transferFrom(sfcFrom, address(this), amountSfcToBurn);
        // This conditional is hypothetically unreachable.
        if (!success) {
            revert SFCEngine__TransferFailedInBurnSfc();
        }
        I_SFC.burn(amountSfcToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        sCollateralDeposited[from][tokenCollateralAddress] -= amountCollateral; // we are assuming the compiler will check for underflow
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert SFCEngine__TransferFailedInRedeemCollateral();
        }
    }

    /**
     * @notice Tells us how close to liquidation a user is.
     * @notice If a user goes below 1, they can be liquidated.
     * @param user The user address.
     */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalSfcMinted, uint256 collateralValueInUsd)
    {
        totalSfcMinted = sSfcMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * Returns how to close to liquidation a user is.
     * If a user goes below 1, they can be liquidated.
     * @param user The user address.
     */
    function _healthFactor(address user) private view returns (uint256) {
        // 1. Get the USD value of all collateral.
        // 2. Get the USD value of all SFC minted.
        (uint256 totalSfcMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        if (totalSfcMinted == 0) {
            /* FOUND IT */
            return type(uint256).max;
        }

        // 3. Calculate health factor.
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalSfcMinted;
    }

    // 1. Check health factor (do they have enough collateral?)
    // 2. Revert if they don't
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SFCEngine__BreaksHealthFactor();
        }
    }

    /*////////////////////////////////////////////////
            PUBLIC & EXTERNAL VIEW FUNCTIONS
    ////////////////////////////////////////////////*/
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount they have deposited,
        // and map it to price feed to get USD value of each collateral token.
        for (uint256 i = 0; i < sCollateralTokens.length; i++) {
            address token = sCollateralTokens[i];
            uint256 amount = sCollateralDeposited[user][token];
            totalCollateralValueInUsd += (getUsdValue(token, amount));
        }

        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(sPriceFeeds[token]);

        uint256 price = _getValidatedPrice(priceFeed);
        // 1 ETH = $1,000
        // The returned value from CL will be 1000_00000000 (8 decimal places)
        // We want to convert the price to have 18 decimal places to be consistent with ERC20 tokens
        return ((price * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        // price of ETH(token)
        AggregatorV3Interface priceFeed = AggregatorV3Interface(sPriceFeeds[token]);
        uint256 price = _getValidatedPrice(priceFeed);
        return (usdAmountInWei * PRECISION) / ((price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalSfcMinted, uint256 collateralValueInUsd)
    {
        (totalSfcMinted, collateralValueInUsd) = _getAccountInformation(user);
        return (totalSfcMinted, collateralValueInUsd);
    }

    /*////////////////////////////////////////////////
                    ORACLE PRICE SECURITY
    ////////////////////////////////////////////////*/
    function _getValidatedPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

        if (price <= 0) revert SFCEngine__OraclePriceInvalid();
        if (answeredInRound < roundId) {
            revert SFCEngine__OracleRoundIncomplete();
        }
        if (block.timestamp - updatedAt > MAX_PRICE_AGE) {
            revert SFCEngine__OraclePriceStale();
        }

        return uint256(price);
    }

    /*////////////////////////////////////////////////
                        GETTERS
    ////////////////////////////////////////////////*/
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return sPriceFeeds[token];
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return sCollateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return sCollateralDeposited[user][token];
    }

    function getSPriceFeed(address token) external view returns (address) {
        return sPriceFeeds[token];
    }

    function getSfc() external view returns (address) {
        return address(I_SFC);
    }
}
