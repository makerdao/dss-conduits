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

        // Iterate through all fundRequests and make a new array of activeFundRequestIds
        for (uint256 i = 0; i < fundRequestsLength; i++) {
            ArrangerConduit.FundRequest memory fundRequest = arrangerConduit.getFundRequest(i);

            // If status == PENDING
            if (uint256(fundRequest.status) == uint256(1)) {
                activeFundRequestIds[activeFundRequestsCount] = i;
                activeFundRequestsCount++;
            }
        }

        // Adjust the activeFundRequestIds array to the correct size, removing empty elements
        assembly {
            mstore(activeFundRequestIds, activeFundRequestsCount)
        }
    }

    function _getAsset(uint256 indexSeed) internal view returns (address asset) {
        // Get a random asset from the actively used assets using a unique seed
        asset = testContract.assets(_hash(indexSeed, "asset") % testContract.getAssetsLength());
    }

    function _getBroker(uint256 indexSeed) internal view returns (address broker) {
        // Get a random broker from the actively used brokers using a unique seed
        broker = testContract.brokers(_hash(indexSeed, "broker") % testContract.getBrokersLength());
    }

    function _getIlk(uint256 indexSeed) internal view returns (bytes32 ilk) {
        // Get a random ilk from the actively used ilks using a unique seed
        ilk = testContract.ilks(_hash(indexSeed, "ilk") % testContract.getIlksLength());
    }

    function _getActiveFundRequestId(uint256 indexSeed)
        internal view returns (bool active, uint256 fundRequestId)
    {
        ( uint256 activeFundRequestsCount, uint256[] memory activeFundRequests )
            = _getActiveFundRequestIds();

        if (activeFundRequestsCount == 0) return (active, 0);  // Return false

        active = true;

        // Pick a random fund request from list of active fundRequests
        uint256 seed = _hash(indexSeed, "activeFundRequest");
        fundRequestId = activeFundRequests[seed % activeFundRequestsCount];
    }

    function _hash(uint256 number_, string memory salt) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_, salt)));
    }

}
