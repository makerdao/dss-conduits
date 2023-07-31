// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ArrangerConduit } from "../../../../src/ArrangerConduit.sol";

import { InvariantTestBase } from "../InvariantTestBase.t.sol";

contract HandlerBase {

    ArrangerConduit   public arrangerConduit;
    InvariantTestBase public testContract;

    constructor(address arrangerConduit_, address testContract_) {
        arrangerConduit = ArrangerConduit(arrangerConduit_);
        testContract    = InvariantTestBase(testContract_);
    }

    function _getIlk(uint256 indexSeed) internal view returns (bytes32 ilk) {
        uint256 seed = _hash(indexSeed, "ilk");
        ilk = testContract.ilks(seed % testContract.getIlksLength());
    }

    function _getAsset(uint256 indexSeed) internal view returns (address asset) {
        uint256 seed = _hash(indexSeed, "asset");
        asset = testContract.assets(seed % testContract.getAssetsLength());
    }

    function _hash(uint256 number_, string memory salt) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_, salt)));
    }

}
