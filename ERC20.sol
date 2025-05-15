// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SupplyChainToken is ERC20, ERC20Burnable, Ownable {
    constructor(uint256 initialSupply) ERC20("SupplyChainToken", "SCT") {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}


/* ERC20 tokens require functions like transfer, balanceOf, allowance, approve, and transferFrom.

1. It works like regular money: you can send it to others, approve payments, etc.
2. The owner (like the system admin) can "print" new tokens (called minting) when needed.
3. Anyone can "destroy" their own tokens (called burning), which might help keep the supply balanced.

How It Fits into the Supply Chain:
    * This token is used to automatically pay fees or rewards during steps like shipping or delivery.
    * For example, when a product moves from "Ready to Ship" to "Shipped," the smart contract might use these tokens to pay the distributor.

 */