// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { stdError } from "../lib/forge-std/src/StdError.sol";

import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

import { IArrangerConduit } from "../src/interfaces/IArrangerConduit.sol";

import { ConduitAssetTestBase } from "./ConduitTestBase.sol";

contract Conduit_RequestFundsTest is ConduitAssetTestBase {

    function test_requestFunds_singleIlk_singleRequest() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        assertEq(conduit.requestedFunds(ilk, address(asset)), 0);

        conduit.requestFunds(ilk, address(asset), 100, "info");

        (
            IArrangerConduit.StatusEnum status,
            address actualAsset,
            bytes32 actualIlk,
            uint256 amountRequested,
            uint256 amountFilled,
            string memory info
        ) = conduit.fundRequests(0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualAsset,     address(asset));
        assertEq(actualIlk,       ilk);
        assertEq(amountRequested, 100);
        assertEq(amountFilled,    0);
        assertEq(info,            "info");

        assertEq(conduit.requestedFunds(ilk, address(asset)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset)), 100);

        _assertInvariants(ilk, address(asset));
    }

    function test_requestFunds_multiIlk_singleRequest_singleAsset() public {
        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        _setupRoles(ilk1, arranger, address(this));
        _setupRoles(ilk2, arranger, address(this));

        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk1, address(asset), 40);
        conduit.deposit(ilk2, address(asset), 60);

        assertEq(conduit.requestedFunds(ilk1, address(asset)), 0);
        assertEq(conduit.requestedFunds(ilk2, address(asset)), 0);

        uint256 returnFundRequestId = conduit.requestFunds(ilk1, address(asset), 40, "info1");

        assertEq(returnFundRequestId, 0);

        (
            IArrangerConduit.StatusEnum status,
            address actualAsset,
            bytes32 actualIlk,
            uint256 amountRequested,
            uint256 amountFilled,
            string memory info
        ) = conduit.fundRequests(0);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualAsset,     address(asset));
        assertEq(actualIlk,       ilk1);
        assertEq(amountRequested, 40);
        assertEq(amountFilled,    0);
        assertEq(info,            "info1");

        assertEq(conduit.requestedFunds(ilk1, address(asset)), 40);
        assertEq(conduit.totalRequestedFunds(address(asset)),  40);

        returnFundRequestId = conduit.requestFunds(ilk2, address(asset), 60, "info2");

        assertEq(returnFundRequestId, 1);

        (
            status,
            actualAsset,
            actualIlk,
            amountRequested,
            amountFilled,
            info
        ) = conduit.fundRequests(1);

        assertTrue(status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(actualAsset,     address(asset));
        assertEq(actualIlk,       ilk2);
        assertEq(amountRequested, 60);
        assertEq(amountFilled,    0);
        assertEq(info,            "info2");

        assertEq(conduit.requestedFunds(ilk2, address(asset)), 60);
        assertEq(conduit.totalRequestedFunds(address(asset)),  100);

        _assertInvariants(ilk1, ilk2, address(asset));
    }

    // NOTE: Removing all struct-level assertions for below tests since they have been adequately
    //       asserted in above tests and FundRequest structs are mutually exclusive to each other
    //       as proven in the above test. Below tests are only testing the mapping-level handling of
    //       multi-ilk multi-asset scenarios.

    function test_requestFunds_singleIlk_multiRequest_singleAsset() public {
        asset.mint(address(this), 100);
        asset.approve(address(conduit), 100);

        conduit.deposit(ilk, address(asset), 100);

        assertEq(conduit.requestedFunds(ilk, address(asset)), 0);

        uint256 returnFundRequestId = conduit.requestFunds(ilk, address(asset), 40, "info");

        assertEq(returnFundRequestId, 0);

        assertEq(conduit.requestedFunds(ilk, address(asset)), 40);
        assertEq(conduit.totalRequestedFunds(address(asset)), 40);

        returnFundRequestId = conduit.requestFunds(ilk, address(asset), 60, "info");

        assertEq(conduit.requestedFunds(ilk, address(asset)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset)), 100);

        _assertInvariants(ilk, address(asset));
    }

    function test_requestFunds_singleIlk_singleRequest_multiAsset() public {
        MockERC20 asset1 = new MockERC20("asset1", "asset1", 18);
        MockERC20 asset2 = new MockERC20("asset2", "asset2", 18);

        asset1.mint(address(this), 100);
        asset2.mint(address(this), 300);
        asset1.approve(address(conduit), 100);
        asset2.approve(address(conduit), 300);

        conduit.deposit(ilk, address(asset1), 100);
        conduit.deposit(ilk, address(asset2), 300);

        assertEq(conduit.requestedFunds(ilk, address(asset1)), 0);
        assertEq(conduit.requestedFunds(ilk, address(asset2)), 0);

        uint256 returnFundRequestId = conduit.requestFunds(ilk, address(asset1), 100, "info1");

        assertEq(returnFundRequestId, 0);

        assertEq(conduit.requestedFunds(ilk, address(asset1)), 100);
        assertEq(conduit.requestedFunds(ilk, address(asset2)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 0);

        returnFundRequestId = conduit.requestFunds(ilk, address(asset2), 300, "info2");

        assertEq(returnFundRequestId, 1);

        assertEq(conduit.requestedFunds(ilk, address(asset1)), 100);
        assertEq(conduit.requestedFunds(ilk, address(asset2)), 300);
        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 300);

        _assertInvariants(ilk, address(asset1));
        _assertInvariants(ilk, address(asset2));
    }

    function test_requestFunds_multiIlk_multiRequest_multiAsset() public {
        MockERC20 asset1 = new MockERC20("asset1", "asset1", 18);
        MockERC20 asset2 = new MockERC20("asset2", "asset2", 18);

        bytes32 ilk1 = "ilk1";
        bytes32 ilk2 = "ilk2";

        _setupRoles(ilk1, arranger, address(this));
        _setupRoles(ilk2, arranger, address(this));

        /********************************************/
        /*** First round of deposits and requests ***/
        /********************************************/

        asset1.mint(address(this), 100);
        asset2.mint(address(this), 400);

        asset1.approve(address(conduit), 100);
        asset2.approve(address(conduit), 400);

        conduit.deposit(ilk1, address(asset1), 40);
        conduit.deposit(ilk2, address(asset1), 60);
        conduit.deposit(ilk1, address(asset2), 100);
        conduit.deposit(ilk2, address(asset2), 300);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 0);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 0);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 0);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 0);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 0);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        // Request Funds for asset1 ilk1

        uint256 returnFundRequestId = conduit.requestFunds(ilk1, address(asset1), 40, "info");

        assertEq(returnFundRequestId, 0);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 40);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 0);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 0);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 40);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 0);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        // Request Funds for asset1 ilk2

        returnFundRequestId = conduit.requestFunds(ilk2, address(asset1), 60, "info");

        assertEq(returnFundRequestId, 1);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 40);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 60);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 0);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 0);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        // Request Funds for asset2 ilk1

        returnFundRequestId = conduit.requestFunds(ilk1, address(asset2), 100, "info");

        assertEq(returnFundRequestId, 2);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 40);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 60);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 100);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 0);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 100);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        // Request Funds for asset2 ilk2

        returnFundRequestId = conduit.requestFunds(ilk2, address(asset2), 300, "info");

        assertEq(returnFundRequestId, 3);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 40);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 60);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 100);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 100);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 400);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        asset1.mint(address(this), 100);
        asset2.mint(address(this), 400);

        asset1.approve(address(conduit), 100);
        asset2.approve(address(conduit), 400);

        conduit.deposit(ilk1, address(asset1), 40);
        conduit.deposit(ilk2, address(asset1), 60);
        conduit.deposit(ilk1, address(asset2), 100);
        conduit.deposit(ilk2, address(asset2), 300);

        /*********************************************/
        /*** Second round of deposits and requests ***/
        /*********************************************/

        // Request Funds for asset1 ilk1

        returnFundRequestId = conduit.requestFunds(ilk1, address(asset1), 40, "info");

        assertEq(returnFundRequestId, 4);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 80);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 60);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 100);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 140);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 400);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        // Request Funds for asset1 ilk2

        returnFundRequestId = conduit.requestFunds(ilk2, address(asset1), 60, "info");

        assertEq(returnFundRequestId, 5);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 80);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 120);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 100);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 200);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 400);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        // Request Funds for asset2 ilk1

        returnFundRequestId = conduit.requestFunds(ilk1, address(asset2), 100, "info");

        assertEq(returnFundRequestId, 6);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 80);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 120);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 200);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 300);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 200);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 500);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));

        // Request Funds for asset2 ilk2

        returnFundRequestId = conduit.requestFunds(ilk2, address(asset2), 300, "info");

        assertEq(returnFundRequestId, 7);

        assertEq(conduit.requestedFunds(ilk1, address(asset1)), 80);
        assertEq(conduit.requestedFunds(ilk2, address(asset1)), 120);
        assertEq(conduit.requestedFunds(ilk1, address(asset2)), 200);
        assertEq(conduit.requestedFunds(ilk2, address(asset2)), 600);

        assertEq(conduit.totalRequestedFunds(address(asset1)), 200);
        assertEq(conduit.totalRequestedFunds(address(asset2)), 800);

        _assertInvariants(ilk1, ilk2, address(asset1));
        _assertInvariants(ilk1, ilk2, address(asset2));
    }

}
