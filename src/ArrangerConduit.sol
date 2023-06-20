// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console2 as console } from "../lib/forge-std/src/console2.sol";

import { IArrangerConduit } from "./interfaces/IArrangerConduit.sol";

interface ERC20Like {
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

contract ArrangerConduit is IArrangerConduit {

    // TODO: Add and test Router ACL

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    address public admin;
    address public fundManager;

    // TODO: Remove unnecessary mappings
    mapping(address => uint256) public startingFundRequestId;
    mapping(address => uint256) public lastFundRequestId;
    mapping(address => uint256) public latestFundRequestId;

    mapping(address => uint256) public outstandingPrincipal;
    mapping(address => uint256) public totalInterestEarned;
    mapping(address => uint256) public totalPositions;
    mapping(address => uint256) public totalWithdrawable;

    mapping(address => FundRequest[]) public fundRequests;

    mapping(bytes32 => mapping(address => uint256)) public pendingWithdrawals;
    mapping(bytes32 => mapping(address => uint256)) public positions;

    constructor(address admin_, address fundManager_) {
        admin       = admin_;
        fundManager = fundManager_;
    }

    /***********************************************************************************************/
    /*** Modifiers                                                                               ***/
    /***********************************************************************************************/

    modifier isAdmin {
        require(msg.sender == admin, "Conduit/not-admin");
        _;
    }

    modifier isFundManager {
        require(msg.sender == fundManager, "Conduit/not-fund-manager");
        _;
    }

    /**********************************************************************************************/
    /*** Router Functions                                                                       ***/
    /**********************************************************************************************/

    function deposit(bytes32 ilk, address asset, uint256 amount) external override {
        // TODO: Use ERC20Helper
        require(
            ERC20Like(asset).transferFrom(msg.sender, address(this), amount),
            "Conduit/deposit-transfer-failed"
        );

        positions[ilk][asset] += amount;
        totalPositions[asset] += amount;
    }

    function withdraw(bytes32 ilk, address asset, address destination, uint256 withdrawAmount)
        external override
    {
        positions[ilk][asset] -= withdrawAmount;
        totalPositions[asset] -= withdrawAmount;

        uint256 fundsRemaining = withdrawAmount;

        // For all of an ilk's fund requests, fill as much as possible
        // Maintain the order of the fund requests array and update after all fills are complete.
        for (uint256 i = startingFundRequestId[asset]; i < fundRequests[asset].length; i++) {
            FundRequest storage fundRequest = fundRequests[asset][i];

            if (fundRequest.ilk != ilk) continue;

            if (
                fundRequest.status == StatusEnum.CANCELLED ||
                fundRequest.status == StatusEnum.COMPLETED
            ) continue;

            uint256 fillAmount = fundRequest.amountAvailable - fundRequest.amountFilled;

            if (fillAmount > fundsRemaining) {
                fillAmount = fundsRemaining;
            }

            fundsRemaining           -= fillAmount;
            fundRequest.amountFilled += fillAmount;

            if (fundsRemaining == 0) break;
        }

        require(
            ERC20Like(asset).transfer(destination, withdrawAmount),
            "Conduit/withdraw-transfer-failed"
        );
    }

    function requestFunds(bytes32 ilk, address asset, uint256 amount, bytes memory data)
        external override returns (uint256 fundRequestId)
    {
        fundRequestId = fundRequests[asset].length;  // Current length will be the next index

        fundRequests[asset].push(FundRequest({
            status:          StatusEnum.PENDING,
            ilk:             ilk,
            amountAvailable: 0,
            amountRequested: amount,
            amountFilled:    0,
            fundRequestId:   fundRequestId
        }));

        pendingWithdrawals[ilk][asset] += amount;

        require(
            pendingWithdrawals[ilk][asset] <= positions[ilk][asset],
            "Conduit/insufficient-position"
        );


    }

    function cancelFundRequest(address asset, uint256 fundRequestId) external override {
        // TODO: What is permissioning for this?
    }

    /**********************************************************************************************/
    /*** Fund Manager Functions                                                                 ***/
    /**********************************************************************************************/

    function drawFunds(address asset, uint256 amount) external override isFundManager {
        outstandingPrincipal[asset] += amount;

        // TODO: Introduce reservedCash mapping? Use totalPositions - outstandingPrincipal?

        require(ERC20Like(asset).transfer(fundManager, amount), "Conduit/transfer-failed");
    }

    function returnFunds(address asset, uint256 returnAmount) external override isFundManager {
        outstandingPrincipal[asset] -= returnAmount;
        totalWithdrawable[asset]    += returnAmount;

        uint256 fundsRemaining = returnAmount;

        // For all of the assets fund requests, fill as much as possible
        // Maintain the order of the fund requests array and update after all fills are complete.
        for (uint256 i = startingFundRequestId[asset]; i < fundRequests[asset].length; i++) {
            FundRequest storage fundRequest = fundRequests[asset][i];

            if (
                fundRequest.status == StatusEnum.CANCELLED ||
                fundRequest.status == StatusEnum.COMPLETED
            ) continue;

            uint256 fillAmount = fundRequest.amountRequested - fundRequest.amountAvailable;

            if (fillAmount > fundsRemaining) {
                fillAmount = fundsRemaining;
            }

            fundsRemaining              -= fillAmount;
            fundRequest.amountAvailable += fillAmount;

            if (fundsRemaining == 0) break;
        }

        require(
            ERC20Like(asset).transferFrom(fundManager, address(this), returnAmount),
            "Conduit/transfer-failed"
        );
    }

    function payInterest(address asset, uint256 amount) external override isFundManager {
        totalInterestEarned[asset] += amount;

        require(
            ERC20Like(asset).transferFrom(fundManager, admin, amount),
            "Conduit/transfer-failed"
        );
    }

    /**********************************************************************************************/
    /*** View Functions                                                                         ***/
    /**********************************************************************************************/

    function maxDeposit(bytes32 ilk, address asset)
        external override view returns (uint256 maxDeposit_) {}

    function maxWithdraw(bytes32 ilk, address asset)
        external override view returns (uint256 maxWithdraw_) {}

    function isCancelable(address asset, uint256 fundRequestId)
        external override view returns (bool isCancelable_) {}

    function fundRequestStatus(address asset, uint256 fundRequestId)
        external override view returns (bytes32 ilk, FundRequest memory fundRequest) {}

    function activeFundRequests(address asset, bytes32 ilk)
        external override view returns (uint256[] memory fundRequestIds, uint256 totalAmount) {}

    function totalActiveFundRequests(address asset)
        external override view returns (uint256 totalAmount) {}

}
