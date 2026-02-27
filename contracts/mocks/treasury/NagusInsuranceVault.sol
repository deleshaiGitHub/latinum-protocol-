// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NagusInsuranceVault
 * @dev Protocol-owned safety buffer for de-peg protection and IL mitigation.
 */
contract NagusInsuranceVault is Ownable {
    IERC20 public immutable usdc;

    event FundsWithdrawn(address indexed to, uint256 amount);

    constructor(address _usdc, address _delegate) Ownable(_delegate) {
        usdc = IERC20(_usdc);
    }

    /**
     * @dev Rule #1: Only the Nagus (Owner) can withdraw for protocol stability.
     */
    function emergencyWithdraw(address _to, uint256 _amount) external onlyOwner {
        require(usdc.balanceOf(address(this)) >= _amount, "Vault: Insufficient balance");
        usdc.transfer(_to, _amount);
        emit FundsWithdrawn(_to, _amount);
    }

    /**
     * @dev Returns total USDC reserve held in the vault.
     */
    function getReserveBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
}
