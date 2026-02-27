// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDC
 * @dev Simple ERC20 for testing the Latinum Protocol on Base Sepolia.
 * Matches USDC's 6 decimal places.
 */
contract MockUSDC is ERC20, Ownable {
    uint8 private constant _decimals = 6;

    constructor() ERC20("Mock USDC", "mUSDC") Ownable(msg.sender) {}

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Allows users to mint tokens to themselves for testing.
     * @param amount The amount of mUSDC to mint (remember 6 decimals).
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
