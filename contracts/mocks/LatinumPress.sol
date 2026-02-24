// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IGPL {
    function mint(address to, uint256 amount) external;
}

contract LatinumPress is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MINT_RATE = 500_000;           
    uint256 public constant PLAN_B_TIMER = 180 days;       
    uint256 public constant HARD_CAP = 1_000_000 * 10**6;  
    uint256 public constant NAGUS_FEE_BPS = 25;            
    uint256 public constant BPS_DENOMINATOR = 10000;

    IERC20 public immutable usdc;
    IGPL public immutable gpl;
    address public nagusVault;

    uint256 public totalRaised;
    uint256 public deploymentTime;
    bool public pressClosed;

    constructor(address _usdc, address _gpl, address _nagusVault) Ownable(msg.sender) {
        usdc = IERC20(_usdc);
        gpl = IGPL(_gpl);
        nagusVault = _nagusVault;
        deploymentTime = block.timestamp;
    }

    function pressLatinum(uint256 _amountUSDC) external {
        require(!pressClosed, "Press Closed");
        require(block.timestamp <= deploymentTime + PLAN_B_TIMER, "Plan B Active");
        require(totalRaised + _amountUSDC <= HARD_CAP, "Hard Cap Reached");

        uint256 nagusAmount = (_amountUSDC * NAGUS_FEE_BPS) / BPS_DENOMINATOR;
        uint256 treasuryAmount = _amountUSDC - nagusAmount;

        usdc.safeTransferFrom(msg.sender, nagusVault, nagusAmount);
        usdc.safeTransferFrom(msg.sender, address(this), treasuryAmount);

        uint256 gplToMint = (_amountUSDC * 10**12) * MINT_RATE;
        totalRaised += _amountUSDC;

        gpl.mint(msg.sender, gplToMint);
    }

    function triggerPlanB() external {
        require(block.timestamp > deploymentTime + PLAN_B_TIMER, "Too early");
        pressClosed = true;
    }
}
