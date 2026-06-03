// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {StableForgeCoin} from "../../src/StableForgeCoin.sol";

contract StableForgeCoinTest is Test {
    StableForgeCoin internal sfc;

    address internal owner = address(this); // test contract deploys it
    address internal user = makeAddr("user");

    uint256 internal constant AMOUNT = 100 ether;

    function setUp() external {
        sfc = new StableForgeCoin();
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testConstructorSetsNameAndSymbol() public view {
        assertEq(sfc.name(), "StableForgeCoin");
        assertEq(sfc.symbol(), "SFC");
    }

    function testConstructorSetsOwnerCorrectly() public view {
        assertEq(sfc.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanMint() public {
        bool success = sfc.mint(user, AMOUNT);

        assertTrue(success);
        assertEq(sfc.balanceOf(user), AMOUNT);
    }

    function testMintRevertsIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert(); // Ownable revert
        sfc.mint(user, AMOUNT);
    }

    function testMintRevertsIfAmountIsZero() public {
        vm.expectRevert(StableForgeCoin.StableForgeCoin__MustBeMoreThanZero.selector);
        sfc.mint(user, 0);
    }

    function testMintRevertsIfToIsZeroAddress() public {
        vm.expectRevert(StableForgeCoin.StableForgeCoin__NotZeroAddress.selector);
        sfc.mint(address(0), AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                BURN
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanBurn() public {
        sfc.mint(owner, AMOUNT);

        sfc.burn(AMOUNT);

        assertEq(sfc.balanceOf(owner), 0);
    }

    function testBurnRevertsIfNotOwner() public {
        sfc.mint(owner, AMOUNT);

        vm.prank(user);
        vm.expectRevert(); // Ownable revert
        sfc.burn(AMOUNT);
    }

    function testBurnRevertsIfAmountIsZero() public {
        sfc.mint(owner, AMOUNT);

        vm.expectRevert(StableForgeCoin.StableForgeCoin__MustBeMoreThanZero.selector);
        sfc.burn(0);
    }

    function testBurnRevertsIfAmountExceedsBalance() public {
        vm.expectRevert(StableForgeCoin.StableForgeCoin__AmountExceedsBalance.selector);
        sfc.burn(1 ether);
    }

    function testBurnReducesBalanceCorrectly() public {
        sfc.mint(owner, AMOUNT);

        sfc.burn(40 ether);

        assertEq(sfc.balanceOf(owner), 60 ether);
    }
}
