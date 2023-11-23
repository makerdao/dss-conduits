// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import {ArrangerConduit} from "src/ArrangerConduit.sol";

contract ArrangerConduitHarness is ArrangerConduit {

  function hash(string memory data) external view returns (bytes32) {
      return keccak256(abi.encodePacked(data));

  }
}

