// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin internal dsc;

    address internal owner = address(this); // test contract deploys it
    address internal user = makeAddr("user");

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
        assertEq(dsc.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanMint() public {
        bool success = dsc.mint(user, AMOUNT);

        assertTrue(success);
        assertEq(dsc.balanceOf(user), AMOUNT);
    }

    function testMintRevertsIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert(); // Ownable revert
        dsc.mint(user, AMOUNT);
    }

    function testMintRevertsIfAmountIsZero() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.mint(user, 0);
    }

    function testMintRevertsIfToIsZeroAddress() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__NotZeroAddress.selector);
        dsc.mint(address(0), AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                BURN
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanBurn() public {
        dsc.mint(owner, AMOUNT);

        dsc.burn(AMOUNT);

        assertEq(dsc.balanceOf(owner), 0);
    }

    function testBurnRevertsIfNotOwner() public {
        dsc.mint(owner, AMOUNT);

        vm.prank(user);
        vm.expectRevert(); // Ownable revert
        dsc.burn(AMOUNT);
    }

    function testBurnRevertsIfAmountIsZero() public {
        dsc.mint(owner, AMOUNT);

        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.burn(0);
    }

    function testBurnRevertsIfAmountExceedsBalance() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountExceedsBalance.selector);
        dsc.burn(1 ether);
    }

    function testBurnReducesBalanceCorrectly() public {
        dsc.mint(owner, AMOUNT);

        dsc.burn(40 ether);

        assertEq(dsc.balanceOf(owner), 60 ether);
    }
}
