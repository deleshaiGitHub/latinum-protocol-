// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

contract GoldPressedLatinum is OFT {
    uint256 public constant GLOBAL_HARD_CAP = 100_000_000_000 * 1e18;

    constructor(address _lzEndpoint, address _owner)
        OFT("Gold Pressed Latinum", "GPL", _lzEndpoint, _owner)
        Ownable(_owner)
    {}

    /// @notice Mints new GPL tokens with cap enforcement.
    function mint(address _to, uint256 _amount) external onlyOwner {
        // We check the cap here before calling the internal mint
        require(totalSupply() + _amount <= GLOBAL_HARD_CAP, "GPL: Cap Exceeded");
        _mint(_to, _amount);
    }
}
