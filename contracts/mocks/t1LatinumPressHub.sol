
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IGPLToken {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title LatinumPressHub (TEST MODE - NO LOCK)
 * @dev MODIFIED FOR TEST: Direct mint to users, no gestation lock, no refund logic
 * Central hub for Latinum Protocol on Base Sepolia
 */
contract LatinumPressHub is OApp, ReentrancyGuard {
    using Address for address payable;

    // -------------------- CONSTANTS --------------------
    uint256 public constant GLOBAL_HARD_CAP = 1_000_000 * 10**6; // $1M USDC (6 decimals)
    uint256 public constant MINT_RATE = 500_000; // 1 USDC = 500k GPL
    uint256 public constant NAGUS_FEE_BPS = 25; // 0.25%
    
    // -------------------- STATE VARIABLES --------------------
    // Core
    uint256 public totalGlobalInflow;
    IGPLToken public gplToken;
    IERC20 public usdc;
    
    // Security
    mapping(bytes32 => bool) public processedMessages;
    mapping(uint32 => bool) public trustedSourceChains;
    bool public emergencyShutdown;
    
    // MODIFIED FOR TEST: Only keep what's needed for basic stats
    mapping(address => uint256) public totalMinted; // Track per-user minted amount for UI

    // -------------------- EVENTS --------------------
    event RemoteMintSynced(uint32 srcEid, address indexed user, uint256 amountUSDC, uint256 gplMinted);
    event LocalMint(address indexed user, uint256 amountUSDC, uint256 gplMinted);
    event HardCapReached(uint256 totalInflow);
    event EmergencyShutdownTriggered(uint256 timestamp);
    event TrustedSourceAdded(uint32 srcEid);
    event TrustedSourceRemoved(uint32 srcEid);
    event NagusFeeCollected(uint256 amount);

    // -------------------- ERRORS --------------------
    error HardCapExceeded();
    error InvalidAmount();
    error UnauthorizedSource();
    error AlreadyProcessed();
    error EmergencyActive();
    error TokenNotSet();

    // -------------------- CONSTRUCTOR --------------------
    constructor(
        address _lzEndpoint,
        address _delegate,
        address _usdc,
        address _gplToken
    ) 
        OApp(_lzEndpoint, _delegate) 
        Ownable(_delegate)
        ReentrancyGuard() 
    {
        usdc = IERC20(_usdc);
        gplToken = IGPLToken(_gplToken);
    }

    // -------------------- ADMIN FUNCTIONS --------------------
    function setGPLToken(address _gplToken) external onlyOwner {
        require(_gplToken != address(0), "Invalid address");
        gplToken = IGPLToken(_gplToken);
    }

    function setUSDC(address _usdc) external onlyOwner {
        require(_usdc != address(0), "Invalid address");
        usdc = IERC20(_usdc);
    }

    function addTrustedSource(uint32 _srcEid) external onlyOwner {
        trustedSourceChains[_srcEid] = true;
        emit TrustedSourceAdded(_srcEid);
    }

    function removeTrustedSource(uint32 _srcEid) external onlyOwner {
        trustedSourceChains[_srcEid] = false;
        emit TrustedSourceRemoved(_srcEid);
    }

    function triggerEmergencyShutdown() external onlyOwner {
        if (emergencyShutdown) revert EmergencyActive();
        if (totalGlobalInflow >= GLOBAL_HARD_CAP) revert HardCapExceeded();
        
        emergencyShutdown = true;
        emit EmergencyShutdownTriggered(block.timestamp);
    }

    // -------------------- CORE MINTING LOGIC --------------------
    /**
     * @dev MODIFIED FOR TEST: Mints GPL directly to user, no locking
     */
    function localMint(uint256 _amountUSDC) external nonReentrant {
        if (_amountUSDC == 0) revert InvalidAmount();
        if (emergencyShutdown) revert EmergencyActive();
        if (address(gplToken) == address(0)) revert TokenNotSet();
        if (address(usdc) == address(0)) revert TokenNotSet();
        
        uint256 newTotal = totalGlobalInflow + _amountUSDC;
        if (newTotal > GLOBAL_HARD_CAP) revert HardCapExceeded();
        
        // Transfer USDC from user to contract
        require(
            usdc.transferFrom(msg.sender, address(this), _amountUSDC),
            "USDC transfer failed"
        );
        
        // Calculate GPL amounts
        (uint256 gplToUser, uint256 nagusFee) = _calculateGPLWithFee(_amountUSDC);
        
        // Update state
        totalGlobalInflow = newTotal;
        totalMinted[msg.sender] += gplToUser;
        
        // MODIFIED FOR TEST: Mint GPL directly to user
        gplToken.mint(msg.sender, gplToUser);
        
        // KEPT: Fee minting to owner (can be redirected to vault later)
        if (nagusFee > 0) {
            gplToken.mint(owner(), nagusFee);
            emit NagusFeeCollected(nagusFee);
        }
        
        emit LocalMint(msg.sender, _amountUSDC, gplToUser);
        
        if (totalGlobalInflow >= GLOBAL_HARD_CAP) {
            emit HardCapReached(totalGlobalInflow);
        }
    }

    // -------------------- LAYERZERO RECEIVE --------------------
    /**
     * @dev MODIFIED FOR TEST: Remote mint sends GPL directly to user
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        if (!trustedSourceChains[_origin.srcEid]) revert UnauthorizedSource();
        if (processedMessages[_guid]) revert AlreadyProcessed();
        if (emergencyShutdown) revert EmergencyActive();
        if (address(gplToken) == address(0)) revert TokenNotSet();
        
        (bytes32 remoteMinter, uint64 amountUSDC) = abi.decode(_message, (bytes32, uint64));
        address userAddress = address(uint160(uint256(remoteMinter)));
        
        uint256 newTotal = totalGlobalInflow + amountUSDC;
        if (newTotal > GLOBAL_HARD_CAP) revert HardCapExceeded();
        
        // Calculate GPL amounts
        (uint256 gplToUser, uint256 nagusFee) = _calculateGPLWithFee(amountUSDC);
        
        // Update state
        processedMessages[_guid] = true;
        totalGlobalInflow = newTotal;
        totalMinted[userAddress] += gplToUser;
        
        // MODIFIED FOR TEST: Mint GPL directly to user
        gplToken.mint(userAddress, gplToUser);
        
        // KEPT: Fee minting to owner
        if (nagusFee > 0) {
            gplToken.mint(owner(), nagusFee);
            emit NagusFeeCollected(nagusFee);
        }
        
        emit RemoteMintSynced(_origin.srcEid, userAddress, amountUSDC, gplToUser);
        
        if (totalGlobalInflow >= GLOBAL_HARD_CAP) {
            emit HardCapReached(totalGlobalInflow);
        }
    }

    // -------------------- VIEW FUNCTIONS --------------------
    function getRemainingCap() external view returns (uint256) {
        return GLOBAL_HARD_CAP - totalGlobalInflow;
    }

    function isHardCapReached() external view returns (bool) {
        return totalGlobalInflow >= GLOBAL_HARD_CAP;
    }

    function isEmergencyActive() external view returns (bool) {
        return emergencyShutdown;
    }

    // -------------------- INTERNAL FUNCTIONS --------------------
    function _calculateGPLWithFee(uint256 amountUSDC) internal pure returns (uint256 userAmount, uint256 nagusFee) {
        uint256 scaledUSDC = amountUSDC * 10**12;
        uint256 grossGPL = scaledUSDC * MINT_RATE;
        nagusFee = (grossGPL * NAGUS_FEE_BPS) / 10000;
        userAmount = grossGPL - nagusFee;
    }

    // -------------------- FALLBACK --------------------
    receive() external payable {}
}
