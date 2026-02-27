// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IGPL {
    function mint(address to, uint256 amount) external;
}

contract LatinumPress is Ownable {
    // Constants from Whitepaper v1.1
    uint256 public constant MINT_RATE = 500_000; // 1 USDC : 500k GPL
    uint256 public constant NAGUS_FEE_BPS = 25;  // 0.25%
    uint256 public constant HARD_CAP_USDC = 1_000_000 * 10**6;
    
    IERC20 public immutable usdc;
    IGPL public immutable gpl;
    
    uint256 public totalUsdcCollected;
    address public nagusReserve;
    bool public isGlobalThresholdMet = false;

    mapping(address => uint256) public lockedBalances;

    event Minted(address indexed user, uint256 usdcIn, uint256 gplOut);
    event ThresholdReached();

    constructor(address _usdc, address _gpl, address _nagus) Ownable(msg.sender) {
        usdc = IERC20(_usdc);
        gpl = IGPL(_gpl);
        nagusReserve = _nagus;
    }

    /**
     * @dev Primary Minting Function
     * @param _usdcAmount Amount of USDC to spend (6 decimals)
     */
    function mintGPL(uint256 _usdcAmount) external {
        require(!isGlobalThresholdMet, "Latinum: Hard Cap reached");
        require(totalUsdcCollected + _usdcAmount <= HARD_CAP_USDC, "Latinum: Exceeds Hard Cap");

        // 1. Transfer USDC from user
        usdc.transferFrom(msg.sender, address(this), _usdcAmount);

        // 2. Calculate Nagus Fee (0.25%)
        uint256 fee = (_usdcAmount * NAGUS_FEE_BPS) / 10000;
        uint256 netUsdc = _usdcAmount - fee;
        usdc.transfer(nagusReserve, fee);

        // 3. Calculate GPL Output (Math: USDC_Amount * 10^12 * 500,000)
        // Adjusting 6 decimals to 18 decimals: 10^12
        uint256 gplAmount = netUsdc * 10**12 * MINT_RATE;

        // 4. Update state and Mint to this contract (GestationVault logic)
        totalUsdcCollected += _usdcAmount;
        lockedBalances[msg.sender] += gplAmount;
        
        gpl.mint(address(this), gplAmount);

        if (totalUsdcCollected >= HARD_CAP_USDC) {
            isGlobalThresholdMet = true;
            emit ThresholdReached();
        }

        emit Minted(msg.sender, _usdcAmount, gplAmount);
    }

    function setNagusReserve(address _newNagus) external onlyOwner {
        nagusReserve = _newNagus;
    }
}
