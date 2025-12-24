// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract MockV3AggregatorTest is Test {
    MockV3Aggregator internal mock;

    uint8 internal constant DECIMALS = 8;
    int256 internal constant INITIAL_ANSWER = 2_000e8;

    function setUp() external {
        mock = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testConstructorSetsDecimals() public view {
        assertEq(mock.decimals(), DECIMALS);
    }

    function testConstructorInitializesRoundAndAnswer() public view {
        assertEq(mock.latestRound(), 1);
        assertEq(mock.latestAnswer(), INITIAL_ANSWER);
        assertGt(mock.latestTimestamp(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            UPDATE ANSWER
    //////////////////////////////////////////////////////////////*/

    function testUpdateAnswerIncrementsRound() public {
        uint256 startingRound = mock.latestRound();

        mock.updateAnswer(3_000e8);

        assertEq(mock.latestRound(), startingRound + 1);
    }

    function testUpdateAnswerUpdatesAnswerAndTimestamp() public {
        vm.warp(12345);
        mock.updateAnswer(3_000e8);

        assertEq(mock.latestAnswer(), 3_000e8);
        assertEq(mock.latestTimestamp(), 12345);
    }

    function testUpdateAnswerStoresHistoricalData() public {
        mock.updateAnswer(3_000e8);
        uint256 round = mock.latestRound();

        assertEq(mock.getAnswer(round), 3_000e8);
        assertGt(mock.getTimestamp(round), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        UPDATE ROUND DATA
    //////////////////////////////////////////////////////////////*/

    function testUpdateRoundDataSetsExplicitValues() public {
        mock.updateRoundData(10, 1_500e8, 9999, 8888);

        assertEq(mock.latestRound(), 10);
        assertEq(mock.latestAnswer(), 1_500e8);
        assertEq(mock.latestTimestamp(), 9999);
        assertEq(mock.getAnswer(10), 1_500e8);
        assertEq(mock.getTimestamp(10), 9999);
    }

    /*//////////////////////////////////////////////////////////////
                        LATEST ROUND DATA
    //////////////////////////////////////////////////////////////*/

    function testLatestRoundDataReturnsCorrectValues() public view {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            mock.latestRoundData();

        assertEq(roundId, 1);
        assertEq(answer, INITIAL_ANSWER);
        assertEq(updatedAt, mock.latestTimestamp());
        assertEq(answeredInRound, roundId);
        assertEq(startedAt, updatedAt);
    }

    /*//////////////////////////////////////////////////////////////
                        GET ROUND DATA
    //////////////////////////////////////////////////////////////*/

    function testGetRoundDataReturnsHistoricalData() public {
        mock.updateAnswer(2_500e8);
        uint256 round = mock.latestRound();

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            mock.getRoundData(uint80(round));

        assertEq(roundId, round);
        assertEq(answer, 2_500e8);
        assertEq(startedAt, updatedAt);
        assertEq(answeredInRound, round);
    }

    /*//////////////////////////////////////////////////////////////
                            METADATA
    //////////////////////////////////////////////////////////////*/

    function testVersionIsZero() public view {
        assertEq(mock.VERSION(), 0);
    }

    function testDescription() public view {
        assertEq(mock.description(), "v0.6/tests/MockV3Aggregator.sol");
    }
}
