// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal mock LayerZero V2 endpoint for local Hardhat deployment.
///        Allows GoldPressedLatinum (OFT) to deploy without a real endpoint.
contract MockLZEndpoint {
    function setDelegate(address, address) external {}
    function setConfig(address, address, uint16, bytes calldata) external {}
    function getConfig(address, address, uint16) external pure returns (bytes memory) { return ""; }
    function setSendVersion(uint32) external {}
    function setReceiveVersion(uint32) external {}
    function send(MessagingParams calldata, bytes calldata) external payable returns (bytes32) {
        return bytes32(0);
    }
    function quote(MessagingParams calldata, bytes calldata) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    struct MessagingParams {
        uint32 dstEid;
        bytes32 receiver;
        bytes message;
        bytes options;
        bool payInLzToken;
    }

    fallback() external payable {}
    receive() external payable {}
}
