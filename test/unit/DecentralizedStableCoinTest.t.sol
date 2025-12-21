// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin internal dsc;

    address internal OWNER = address(this); // test contract deploys it
    address internal USER = makeAddr("user");

    uint256 internal constant AMOUNT = 100 ether;

    function setUp() external {
        dsc = new DecentralizedStableCoin();
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testConstructorSetsNameAndSymbol() public view {
        assertEq(dsc.name(), "DecentralizedStableCoin");
        assertEq(dsc.symbol(), "DSC");
    }

    function testConstructorSetsOwnerCorrectly() public view {
        assertEq(dsc.owner(), OWNER);
    }

    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanMint() public {
        bool success = dsc.mint(USER, AMOUNT);

        assertTrue(success);
        assertEq(dsc.balanceOf(USER), AMOUNT);
    }

    function testMintRevertsIfNotOwner() public {
        vm.prank(USER);
        vm.expectRevert(); // Ownable revert
        dsc.mint(USER, AMOUNT);
    }

    function testMintRevertsIfAmountIsZero() public {
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__MustBeMoreThanZero
                .selector
        );
        dsc.mint(USER, 0);
    }

    function testMintRevertsIfToIsZeroAddress() public {
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__NotZeroAddress
                .selector
        );
        dsc.mint(address(0), AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                BURN
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanBurn() public {
        dsc.mint(OWNER, AMOUNT);

        dsc.burn(AMOUNT);

        assertEq(dsc.balanceOf(OWNER), 0);
    }

    function testBurnRevertsIfNotOwner() public {
        dsc.mint(OWNER, AMOUNT);

        vm.prank(USER);
        vm.expectRevert(); // Ownable revert
        dsc.burn(AMOUNT);
    }

    function testBurnRevertsIfAmountIsZero() public {
        dsc.mint(OWNER, AMOUNT);

        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__MustBeMoreThanZero
                .selector
        );
        dsc.burn(0);
    }

    function testBurnRevertsIfAmountExceedsBalance() public {
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__AmountExceedsBalance
                .selector
        );
        dsc.burn(1 ether);
    }

    function testBurnReducesBalanceCorrectly() public {
        dsc.mint(OWNER, AMOUNT);

        dsc.burn(40 ether);

        assertEq(dsc.balanceOf(OWNER), 60 ether);
    }
}
