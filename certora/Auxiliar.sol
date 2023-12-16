// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract Auxiliar {
    function hashString(string memory data) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(data));
    }
}

