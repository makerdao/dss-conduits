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

    // TODO: Investigate persisting in storage
    function _getActiveFundRequestIds()
        internal view returns (
            uint256 activeFundRequestsCount,
            uint256[] memory activeFundRequestIds
        )
    {
        uint256 fundRequestsLength = arrangerConduit.getFundRequestsLength();

        activeFundRequestIds = new uint256[](fundRequestsLength);

        for (uint256 i = 0; i < fundRequestsLength; i++) {
            ArrangerConduit.FundRequest memory fundRequest = arrangerConduit.getFundRequest(i);

            // If status == PENDING
            if (uint256(fundRequest.status) == uint256(1)) {
                activeFundRequestIds[activeFundRequestsCount] = i;
                activeFundRequestsCount++;
            }
        }

        // Adjust the activeFundRequestIds array to the correct size
        assembly {
            mstore(activeFundRequestIds, activeFundRequestsCount)
        }
    }

    function _getAsset(uint256 indexSeed) internal view returns (address asset) {
        uint256 seed = _hash(indexSeed, "asset");
        asset = testContract.assets(seed % testContract.getAssetsLength());
    }

    function _getBroker(uint256 indexSeed) internal view returns (address broker) {
        uint256 seed = _hash(indexSeed, "broker");
        broker = testContract.brokers(seed % testContract.getBrokersLength());
    }

    function _getActiveFundRequestId(uint256 indexSeed)
        internal view returns (bool active, uint256 fundRequestId)
    {
        ( uint256 activeFundRequestsCount, uint256[] memory activeFundRequests )
            = _getActiveFundRequestIds();

        uint256 seed = _hash(indexSeed, "activeFundRequest");
        fundRequestId = seed % activeFundRequestsCount;

        // Added since array will return a index value of zero with no active fund requests
        active = activeFundRequestsCount > 0;
    }

    function _getIlk(uint256 indexSeed) internal view returns (bytes32 ilk) {
        uint256 seed = _hash(indexSeed, "ilk");
        ilk = testContract.ilks(seed % testContract.getIlksLength());
    }

    function _hash(uint256 number_, string memory salt) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_, salt)));
    }

}
