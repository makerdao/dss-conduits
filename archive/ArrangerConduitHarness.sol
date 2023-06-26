// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;


import { ArrangerConduit } from "../src/ArrangerConduit.sol";

contract ArrangerConduitHarness is ArrangerConduit {

    constructor(address admin_, address fundManager_) ArrangerConduit(admin_, fundManager_) {}

    function __setFundRequestStatus(
        address asset,
        uint256 fundRequestId,
        ArrangerConduit.StatusEnum status
    )
        external
    {
        fundRequests[asset][fundRequestId].status = status;
    }

}
