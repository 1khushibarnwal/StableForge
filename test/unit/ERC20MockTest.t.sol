// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract ERC20MockTest is Test {
    ERC20Mock internal token;

    address internal user = makeAddr("user");
    address internal user2 = makeAddr("user2");

    uint256 internal constant INITIAL_BALANCE = 1_000 ether;
    uint256 internal constant MINT_AMOUNT = 500 ether;

    function setUp() external {
        token = new ERC20Mock("Mock Token", "MOCK", user, INITIAL_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testConstructorSetsNameAndSymbol() public view {
        assertEq(token.name(), "Mock Token");
        assertEq(token.symbol(), "MOCK");
    }

    function testConstructorMintsInitialBalance() public view {
        assertEq(token.balanceOf(user), INITIAL_BALANCE);
        assertEq(token.totalSupply(), INITIAL_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/

    function testMintIncreasesBalanceAndSupply() public {
        token.mint(user, MINT_AMOUNT);

        assertEq(token.balanceOf(user), INITIAL_BALANCE + MINT_AMOUNT);
        assertEq(token.totalSupply(), INITIAL_BALANCE + MINT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                BURN
    //////////////////////////////////////////////////////////////*/

    function testBurnDecreasesBalanceAndSupply() public {
        token.burn(user, 200 ether);

        assertEq(token.balanceOf(user), INITIAL_BALANCE - 200 ether);
        assertEq(token.totalSupply(), INITIAL_BALANCE - 200 ether);
    }

    function testBurnRevertsIfAmountExceedsBalance() public {
        vm.expectRevert(); // ERC20: burn amount exceeds balance
        token.burn(user, INITIAL_BALANCE + 1);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER INTERNAL
    //////////////////////////////////////////////////////////////*/

    function testTransferInternalMovesTokens() public {
        token.transferInternal(user, user2, 100 ether);

        assertEq(token.balanceOf(user), INITIAL_BALANCE - 100 ether);
        assertEq(token.balanceOf(user2), 100 ether);
    }

    function testTransferInternalRevertsIfInsufficientBalance() public {
        vm.expectRevert(); // ERC20: transfer amount exceeds balance
        token.transferInternal(user2, user, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            APPROVE INTERNAL
    //////////////////////////////////////////////////////////////*/

    function testApproveInternalSetsAllowance() public {
        token.approveInternal(user, user2, 250 ether);

        assertEq(token.allowance(user, user2), 250 ether);
    }
}
