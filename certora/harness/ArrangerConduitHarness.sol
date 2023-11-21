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


  // WorkAround:
  // Without it the issue is that before writing the new string info into the storage, Solidity requires
  // the value originally stored in there also encodes a valid string (valid according to the ABI).
  // In general, pure Solidity code (without assembly) shouldn't cause any such problem.
  // However, the Prover does not assume this, and allows for a case where the storage is in a "dirty" state,
  // i.e. holds an invalid encoding of a string. This "dirty" state is what causes a revert.
  // The solution found so far is "cleaning" the storage before calling requestFunds.
  // We do this by pushing and then popping an empty struct into fundRequests
  
  function clearStorage() external {
    FundRequest memory emptyRequest;
    fundRequests.push(emptyRequest);
    fundRequests.pop();
  }  
}
