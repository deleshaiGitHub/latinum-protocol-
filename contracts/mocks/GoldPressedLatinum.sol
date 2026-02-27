// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title GoldPressedLatinum
 * @dev GPL Token - OFTv2 for Omnichain Empire
 * Total Hard Cap: 500,000,000,000 (500B) - Enforced across all chains
 * Only the LatinumPressHub can mint during gestation phase
 */
contract GoldPressedLatinum is OFT {
    // -------------------- CONSTANTS --------------------
    uint256 public constant MAX_SUPPLY = 500_000_000_000 * 10**18; // 500B with 18 decimals
    
    // -------------------- STATE VARIABLES --------------------
    address public latinumPressHub; // Only this address can mint
    bool public hubSet; // Prevents hub from being changed after set

    // -------------------- EVENTS --------------------
    event HubSet(address indexed hub);
    event TokensBurned(address indexed user, uint256 amount);

    // -------------------- ERRORS --------------------
    error ExceedsMaxSupply();
    error OnlyHub();
    error HubAlreadySet();
    error InvalidAddress();

    // -------------------- CONSTRUCTOR --------------------
    constructor(
        address _lzEndpoint,
        address _delegate
    ) OFT("Gold-Pressed Latinum", "GPL", _lzEndpoint, _delegate) Ownable(_delegate) {
        // No initial mint - all supply comes through Hub
    }

    // -------------------- MODIFIERS --------------------
    modifier onlyHub() {
        if (msg.sender != latinumPressHub) revert OnlyHub();
        _;
    }

    // -------------------- ADMIN FUNCTIONS --------------------
    /**
     * @dev Set the LatinumPressHub address (can only be called once)
     * @param _hub Address of the deployed LatinumPressHub
     */
    function setHub(address _hub) external onlyOwner {
        if (_hub == address(0)) revert InvalidAddress();
        if (hubSet) revert HubAlreadySet();
        
        latinumPressHub = _hub;
        hubSet = true;
        
        emit HubSet(_hub);
    }

    // -------------------- MINT FUNCTIONS --------------------
    /**
     * @dev Mint new GPL tokens - ONLY callable by LatinumPressHub
     * @param _to Recipient address
     * @param _amount Amount to mint (with 18 decimals)
     */
    function mint(address _to, uint256 _amount) external onlyHub {
        uint256 newSupply = totalSupply() + _amount;
        if (newSupply > MAX_SUPPLY) revert ExceedsMaxSupply();
        
        _mint(_to, _amount);
    }

    /**
     * @dev Batch mint for efficiency - ONLY callable by LatinumPressHub
     * @param _to Array of recipient addresses
     * @param _amounts Array of amounts to mint
     */
    function batchMint(address[] calldata _to, uint256[] calldata _amounts) external onlyHub {
        if (_to.length != _amounts.length) revert InvalidAddress();
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }
        
        uint256 newSupply = totalSupply() + totalAmount;
        if (newSupply > MAX_SUPPLY) revert ExceedsMaxSupply();
        
        for (uint256 i = 0; i < _to.length; i++) {
            _mint(_to[i], _amounts[i]);
        }
    }

    // -------------------- BURN FUNCTIONS --------------------
    /**
     * @dev Burn tokens - anyone can burn their own
     * @param _amount Amount to burn
     */
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
        emit TokensBurned(msg.sender, _amount);
    }

    /**
     * @dev Burn tokens from a specific address (with approval)
     * @param _from Address to burn from
     * @param _amount Amount to burn
     */
    function burnFrom(address _from, uint256 _amount) external {
        _spendAllowance(_from, msg.sender, _amount);
        _burn(_from, _amount);
        emit TokensBurned(_from, _amount);
    }

    // -------------------- VIEW FUNCTIONS --------------------
    /**
     * @dev Check remaining supply until hard cap
     */
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    /**
     * @dev Check if max supply is reached
     */
    function isMaxSupplyReached() external view returns (bool) {
        return totalSupply() >= MAX_SUPPLY;
    }

    // -------------------- OVERRIDES --------------------
    /**
     * @dev Override to prevent transfers before hub is set (optional safety)
     * Remove if you want transfers allowed immediately
     */
    function _update(address from, address to, uint256 value) internal override {
        // If hub is not set yet, only allow minting (from = address(0))
        if (!hubSet && from != address(0)) {
            revert("Transfers locked until hub is set");
        }
        super._update(from, to, value);
    }
}
