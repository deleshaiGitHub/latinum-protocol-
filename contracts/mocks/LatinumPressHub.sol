// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IGPLToken {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title LatinumPressHub
 * @dev Central hub for Latinum Protocol on Base Sepolia
 * v1.6 Ironclad
 */
contract LatinumPressHub is OApp, ReentrancyGuard {
    using Address for address payable;

    // -------------------- CONSTANTS --------------------
    uint256 public constant GLOBAL_HARD_CAP = 1_000_000 * 10**6; // $1M USDC (6 decimals)
    uint256 public constant MINT_RATE = 500_000; // 1 USDC = 500k GPL
    uint256 public constant NAGUS_FEE_BPS = 25; // 0.25%
    uint256 public constant REFUND_WINDOW = 30 days;
    uint256 public constant EXIT_TAX_BPS = 500; // 5% (for future use)
    
    // -------------------- STATE VARIABLES --------------------
    // Core
    uint256 public totalGlobalInflow;
    IGPLToken public gplToken;
    IERC20 public usdc;
    
    // Security
    mapping(bytes32 => bool) public processedMessages;
    mapping(uint32 => bool) public trustedSourceChains;
    bool public emergencyShutdown;
    uint256 public shutdownTimestamp;
    
    // User balances
    mapping(address => uint256) public globalGestationBalances;
    mapping(address => uint256) public originalDeposits;
    mapping(address => bool) public hasRefunded;
    
    // Cross-chain tracking
    mapping(address => bool) public mintedFromSolana;
    mapping(address => uint256) public solanaRefundAmount;
    mapping(address => bool) public solanaRefundEligible;

    // -------------------- EVENTS --------------------
    event RemoteMintSynced(uint32 srcEid, address indexed user, uint256 amountUSDC, uint256 gplMinted);
    event LocalMint(address indexed user, uint256 amountUSDC, uint256 gplMinted);
    event HardCapReached(uint256 totalInflow);
    event EmergencyShutdownTriggered(uint256 timestamp);
    event RefundProcessed(address indexed user, uint256 gplBurned, uint256 usdcRefunded);
    event SolanaRefundMarked(address indexed user, uint256 gplAmount);
    event TrustedSourceAdded(uint32 srcEid);
    event TrustedSourceRemoved(uint32 srcEid);
    event NagusFeeCollected(uint256 amount);

    // -------------------- ERRORS --------------------
    error HardCapExceeded();
    error InvalidAmount();
    error UnauthorizedSource();
    error AlreadyProcessed();
    error EmergencyActive();
    error NotEmergency();
    error RefundWindowClosed();
    error AlreadyRefunded();
    error NoBalance();
    error TokenNotSet();

    // -------------------- CONSTRUCTOR --------------------
    constructor(
        address _lzEndpoint,
        address _delegate,
        address _usdc,
        address _gplToken
    ) 
        OApp(_lzEndpoint, _delegate) 
        ReentrancyGuard() 
    {
        usdc = IERC20(_usdc);
        gplToken = IGPLToken(_gplToken);
        
        // Explicitly transfer ownership to _delegate (though OApp should handle this)
        _transferOwnership(_delegate);
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

    // -------------------- CORE MINTING LOGIC --------------------
    function localMint(uint256 _amountUSDC) external nonReentrant {
        if (_amountUSDC == 0) revert InvalidAmount();
        if (emergencyShutdown) revert EmergencyActive();
        if (address(gplToken) == address(0)) revert TokenNotSet();
        if (address(usdc) == address(0)) revert TokenNotSet();
        
        uint256 newTotal = totalGlobalInflow + _amountUSDC;
        if (newTotal > GLOBAL_HARD_CAP) revert HardCapExceeded();
        
        require(
            usdc.transferFrom(msg.sender, address(this), _amountUSDC),
            "USDC transfer failed"
        );
        
        (uint256 gplToUser, uint256 nagusFee) = _calculateGPLWithFee(_amountUSDC);
        
        totalGlobalInflow = newTotal;
        originalDeposits[msg.sender] += _amountUSDC;
        
        gplToken.mint(address(this), gplToUser);
        globalGestationBalances[msg.sender] += gplToUser;
        
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
        
        (uint256 gplToUser, uint256 nagusFee) = _calculateGPLWithFee(amountUSDC);
        
        processedMessages[_guid] = true;
        totalGlobalInflow = newTotal;
        originalDeposits[userAddress] += amountUSDC;
        mintedFromSolana[userAddress] = true;
        
        gplToken.mint(address(this), gplToUser);
        globalGestationBalances[userAddress] += gplToUser;
        
        if (nagusFee > 0) {
            gplToken.mint(owner(), nagusFee);
            emit NagusFeeCollected(nagusFee);
        }
        
        emit RemoteMintSynced(_origin.srcEid, userAddress, amountUSDC, gplToUser);
        
        if (totalGlobalInflow >= GLOBAL_HARD_CAP) {
            emit HardCapReached(totalGlobalInflow);
        }
    }

    // -------------------- EMERGENCY ABORT --------------------
    function triggerEmergencyShutdown() external onlyOwner {
        if (emergencyShutdown) revert EmergencyActive();
        if (totalGlobalInflow >= GLOBAL_HARD_CAP) revert HardCapExceeded();
        
        emergencyShutdown = true;
        shutdownTimestamp = block.timestamp;
        
        emit EmergencyShutdownTriggered(block.timestamp);
    }

    function claimRefund() external nonReentrant {
        if (!emergencyShutdown) revert NotEmergency();
        if (block.timestamp > shutdownTimestamp + REFUND_WINDOW) revert RefundWindowClosed();
        if (hasRefunded[msg.sender]) revert AlreadyRefunded();
        
        uint256 lockedGPL = globalGestationBalances[msg.sender];
        if (lockedGPL == 0) revert NoBalance();
        
        if (mintedFromSolana[msg.sender]) {
            solanaRefundEligible[msg.sender] = true;
            solanaRefundAmount[msg.sender] = lockedGPL;
            
            gplToken.burn(lockedGPL);
            globalGestationBalances[msg.sender] = 0;
            hasRefunded[msg.sender] = true;
            
            emit SolanaRefundMarked(msg.sender, lockedGPL);
        } else {
            uint256 usdcRefund = _calculateRefund(lockedGPL, originalDeposits[msg.sender]);
            
            gplToken.burn(lockedGPL);
            globalGestationBalances[msg.sender] = 0;
            hasRefunded[msg.sender] = true;
            
            require(usdc.transfer(msg.sender, usdcRefund), "USDC transfer failed");
            
            emit RefundProcessed(msg.sender, lockedGPL, usdcRefund);
        }
    }

    function markSolanaRefundComplete(address _user) external onlyOwner {
        if (!solanaRefundEligible[_user]) revert NoBalance();
        solanaRefundEligible[_user] = false;
        solanaRefundAmount[_user] = 0;
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

    function getRefundStatus(address _user) external view returns (bool eligible, uint256 amount, bool isSolana) {
        if (hasRefunded[_user]) {
            return (false, 0, false);
        }
        uint256 locked = globalGestationBalances[_user];
        if (locked == 0) {
            return (false, 0, false);
        }
        return (true, locked, mintedFromSolana[_user]);
    }

    function getRefundWindowEnd() external view returns (uint256) {
        if (!emergencyShutdown) return 0;
        return shutdownTimestamp + REFUND_WINDOW;
    }

    // -------------------- INTERNAL FUNCTIONS --------------------
    function _calculateGPLWithFee(uint256 amountUSDC) internal pure returns (uint256 userAmount, uint256 nagusFee) {
        uint256 scaledUSDC = amountUSDC * 10**12;
        uint256 grossGPL = scaledUSDC * MINT_RATE;
        nagusFee = (grossGPL * NAGUS_FEE_BPS) / 10000;
        userAmount = grossGPL - nagusFee;
    }

    function _calculateRefund(uint256 lockedGPL, uint256 originalDeposit) internal pure returns (uint256) {
        return (originalDeposit * 9975) / 10000; // 99.75%
    }

    // -------------------- FALLBACK --------------------
    receive() external payable {}
}
