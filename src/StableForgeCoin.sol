// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StableForgeCoin
 * @author Khushi Barnwal
 * @notice This is the contract for a decentralized stable coin system.
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract meant to be governed by SFCEngine. This contract is just the ERC20 implementation of the stable coin.
 */
contract StableForgeCoin is ERC20Burnable, Ownable {
    /* ERRORS */
    error StableForgeCoin__MustBeMoreThanZero();
    error StableForgeCoin__AmountExceedsBalance();
    error StableForgeCoin__NotZeroAddress();

    constructor() ERC20("StableForgeCoin", "SFC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert StableForgeCoin__MustBeMoreThanZero();
        }

        if (balance < _amount) {
            revert StableForgeCoin__AmountExceedsBalance();
        }

        super.burn(_amount); // calls the burn function from ERC20Burnable
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert StableForgeCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert StableForgeCoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
