// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IGPL {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}

contract LatinumPress is Ownable {
    uint256 public constant MINT_RATE = 500_000; 
    uint256 public constant HARD_CAP_USDC = 1_000_000 * 10**6;
    uint256 public constant PLAN_B_DURATION = 180 days;
    uint256 public constant NAGUS_FEE_BPS = 25; // 0.25%

    IERC20 public immutable usdc;
    IGPL public immutable gpl;
    
    uint256 public deploymentTimestamp;
    uint256 public totalUsdcCollected;
    bool public isAborted = false;
    bool public isGlobalThresholdMet = false;

    mapping(address => uint256) public lockedBalances;
    mapping(address => uint256) public netUsdcDeposited; // Track net amount for refund

    event Minted(address indexed user, uint256 usdcIn, uint256 gplOut);
    event Aborted(address indexed byOwner);
    event RefundClaimed(address indexed user, uint256 amount);

    constructor(address _usdc, address _gpl) Ownable(msg.sender) {
        usdc = IERC20(_usdc);
        gpl = IGPL(_gpl);
        deploymentTimestamp = block.timestamp;
    }

    function mintGPL(uint256 _usdcAmount) external {
        require(!isAborted, "Latinum: Protocol Aborted");
        require(!isGlobalThresholdMet, "Latinum: Hard Cap Reached");
        require(block.timestamp < deploymentTimestamp + PLAN_B_DURATION, "Latinum: Period Expired");

        usdc.transferFrom(msg.sender, address(this), _usdcAmount);
        
        uint256 fee = (_usdcAmount * NAGUS_FEE_BPS) / 10000;
        uint256 netUsdc = _usdcAmount - fee;
        
        // Fee stays in the Nagus Vault; only Net stays here for backing/refund
        // Note: In production, transfer the fee to the Nagus Vault address here.

        uint256 gplAmount = netUsdc * 10**12 * MINT_RATE;
        lockedBalances[msg.sender] += gplAmount;
        netUsdcDeposited[msg.sender] += netUsdc;
        totalUsdcCollected += _usdcAmount;

        gpl.mint(address(this), gplAmount);
        emit Minted(msg.sender, _usdcAmount, gplAmount);
    }

    // --- EMERGENCY LOGIC ---

    /**
     * @dev Manual Kill Switch. Use if momentum stalls.
     */
    function emergencyAbort() external onlyOwner {
        isAborted = true;
        emit Aborted(msg.sender);
    }

    /**
     * @dev User pulls their net USDC back. They pay the gas.
     */
    function claimRefund() external {
        require(isAborted, "Latinum: Not in Abort state");
        uint256 amountToRefund = netUsdcDeposited[msg.sender];
        require(amountToRefund > 0, "Latinum: Nothing to refund");

        netUsdcDeposited[msg.sender] = 0;
        lockedBalances[msg.sender] = 0; // Wipe their "locked" credit
        
        usdc.transfer(msg.sender, amountToRefund);
        emit RefundClaimed(msg.sender, amountToRefund);
    }

    // Logic for Plan B timer check would go here for automatic abort
}
