// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IGPL {
    function mint(address to, uint256 amount) external;
}

contract LatinumPress is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    IGPL public immutable gpl;
    address public workingWallet;

    uint256 public constant MIRROR_BPS = 500; // 5% Mirror Mint
    uint256 public constant BPS_DENOMINATOR = 10000;

    constructor(address _usdc, address _gpl, address _workingWallet) Ownable(msg.sender) {
        usdc = IERC20(_usdc);
        gpl = IGPL(_gpl);
        workingWallet = _workingWallet;
    }

    /// @notice Deposit USDC to mint GPL 1:1.
    /// @dev Handles 6-decimal USDC to 18-decimal GPL conversion.
    function deposit(uint256 _usdcAmount) external {
        require(_usdcAmount > 0, "Amount must be > 0");

        // 1. Pull USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), _usdcAmount);

        // 2. Convert to 18 decimals (1 USDC = 10^6 units, 1 GPL = 10^18 units)
        uint256 gplToUser = _usdcAmount * 10**12; 
        uint256 gplMirror = (gplToUser * MIRROR_BPS) / BPS_DENOMINATOR;

        // 3. Command the Token contract to Mint
        gpl.mint(msg.sender, gplToUser);
        gpl.mint(workingWallet, gplMirror);
    }

    function setWorkingWallet(address _newWallet) external onlyOwner {
        workingWallet = _newWallet;
    }
}
