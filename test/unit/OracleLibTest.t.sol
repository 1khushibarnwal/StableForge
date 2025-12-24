// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {OracleLib} from "../../src/libraries/OracleLib.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract OracleLibTest is Test {
    MockV3Aggregator internal priceFeed;

    uint8 internal constant DECIMALS = 8;
    int256 internal constant INITIAL_PRICE = 2000e8;

    function setUp() external {
        priceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
    }

    /*//////////////////////////////////////////////////////////////
                            SUCCESS CASES
    //////////////////////////////////////////////////////////////*/

    function test_staleCheckLatestRoundData_passesWhenFresh() public {
        // Arrange
        vm.warp(block.timestamp + 1 hours);

        // Act
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            OracleLib.staleCheckLatestRoundData(priceFeed);

        // Assert
        assertEq(answer, INITIAL_PRICE);
        assertEq(answeredInRound, roundId);
        assertGt(updatedAt, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            REVERT CASES
    //////////////////////////////////////////////////////////////*/

    function test_revertsIfUpdatedAtIsZero() public {
        // Arrange
        vm.mockCall(
            address(priceFeed),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(
                uint80(1), // roundId
                int256(2000e8), // answer
                uint256(0), // startedAt
                uint256(0), // updatedAt  ← this is what we want
                uint80(1) // answeredInRound
            )
        );

        // Act / Assert
        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        OracleLib.staleCheckLatestRoundData(priceFeed);
    }

    function test_revertsIfAnsweredInRoundLessThanRoundId() public {
        // Arrange
        priceFeed.updateAnswer(INITIAL_PRICE);
        vm.warp(block.timestamp + 1);

        // Manually mock invalid data
        vm.mockCall(
            address(priceFeed),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(
                uint80(2), // roundId
                INITIAL_PRICE,
                block.timestamp,
                block.timestamp,
                uint80(1) // answeredInRound < roundId
            )
        );

        // Act / Assert
        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        OracleLib.staleCheckLatestRoundData(priceFeed);
    }

    function test_revertsIfPriceIsStale() public {
        // Arrange
        uint256 timeout = OracleLib.getTimeout(priceFeed);
        vm.warp(block.timestamp + timeout + 1);

        // Act / Assert
        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        OracleLib.staleCheckLatestRoundData(priceFeed);
    }

    /*//////////////////////////////////////////////////////////////
                            TIMEOUT
    //////////////////////////////////////////////////////////////*/

    function test_getTimeoutReturnsThreeHours() public view {
        uint256 timeout = OracleLib.getTimeout(priceFeed);
        assertEq(timeout, 3 hours);
    }
}
