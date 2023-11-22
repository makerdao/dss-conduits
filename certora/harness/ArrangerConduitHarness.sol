// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import {ArrangerConduit} from "src/ArrangerConduit.sol";

contract ArrangerConduitHarness is ArrangerConduit {
 
  function fundRequestStatus(uint256 index) external view returns (uint256) {
    return uint256(fundRequests[index].status);
  }

  function fundRequestAsset(uint256 index) external view returns (address) {
    return fundRequests[index].asset;
  }

  function fundRequestIlk(uint256 index) external view returns (bytes32) {
    return fundRequests[index].ilk;
  }

  function fundRequestAmountRequested(uint256 index) external view returns (uint256) {
    return fundRequests[index].amountRequested;
  }

  function fundRequestAmountFilled(uint256 index) external view returns (uint256) {
    return fundRequests[index].amountFilled;
  }

  function fundRequestInfoHash(uint256 index) external view returns (bytes32) {
      return keccak256(abi.encodePacked(fundRequests[index].info));
  }

  function hash(string memory data) external view returns (bytes32) {
      return keccak256(abi.encodePacked(data));
  }
}

