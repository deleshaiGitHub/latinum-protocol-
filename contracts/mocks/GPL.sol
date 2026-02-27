// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GoldPressedLatinum ($GPL)
 * @dev Omnichain Fungible Token (OFT) V2 for the Latinum Protocol.
 * Base Sepolia Endpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f
 */
contract GoldPressedLatinum is OFT {
    // 500 Billion Max Supply (18 decimals)
    uint256 public constant MAX_SUPPLY = 500_000_000_000 * 10**18;

    constructor(
        address _lzEndpoint,
        address _delegate
    ) 
        OFT("Gold-Pressed Latinum", "GPL", _lzEndpoint, _delegate) 
        Ownable(_delegate) 
    {}

    /**
     * @dev Enforces the 500B Hard Cap from the Whitepaper.
     * Only the LatinumPress (once deployed and set as owner) will call this.
     */
    function mint(address _to, uint256 _amount) external onlyOwner {
        require(totalSupply() + _amount <= MAX_SUPPLY, "Latinum: Hard Cap Exceeded");
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}
