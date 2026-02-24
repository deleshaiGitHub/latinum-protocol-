// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GoldPressedLatinum is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 500_000_000_000 * 10**18;
    address public latinumPress;

    constructor() ERC20("Gold Pressed Latinum", "GPL") Ownable(msg.sender) {}

    modifier onlyPress() {
        require(msg.sender == latinumPress || msg.sender == owner(), "GPL: Unauthorized");
        _;
    }

    function setPress(address _press) external onlyOwner { 
        latinumPress = _press; 
    }

    function mint(address to, uint256 amount) external onlyPress {
        require(totalSupply() + amount <= MAX_SUPPLY, "GPL: Cap Exceeded");
        _mint(to, amount);
    }
}
