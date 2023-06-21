// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console2 as console } from "../lib/forge-std/src/console2.sol";

import { IArrangerConduit } from "./interfaces/IArrangerConduit.sol";

interface ERC20Like {
    function balanceOf(address src) external view returns (uint256 wad);
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

    mapping(address => uint256) public outstandingPrincipal;
    mapping(address => uint256) public startingFundRequestId;
    mapping(address => uint256) public totalInterestEarned;
    mapping(address => uint256) public totalPositions;
    mapping(address => uint256) public totalWithdrawable;

    mapping(address => FundRequest[]) public fundRequests;

    mapping(bytes32 => mapping(address => uint256)) public availableWithdrawals;
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
        // availableWithdrawals < pendingWithdrawals < positions
        // positions < totalWithdrawable < totalPositions
        require(
            withdrawAmount <= availableWithdrawals[ilk][asset],
            "Conduit/insufficient-withdrawal"
        );

        availableWithdrawals[ilk][asset] -= withdrawAmount;
        pendingWithdrawals[ilk][asset]   -= withdrawAmount;
        positions[ilk][asset]            -= withdrawAmount;

        totalPositions[asset]    -= withdrawAmount;
        totalWithdrawable[asset] -= withdrawAmount;

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
            fundRequestId:   fundRequestId  // TODO: Necessary?
        }));

        pendingWithdrawals[ilk][asset] += amount;

        require(
            pendingWithdrawals[ilk][asset] <= positions[ilk][asset],
            "Conduit/insufficient-position"
        );
    }

    function cancelFundRequest(address asset, uint256 fundRequestId) external override {
        // TODO: What is permissioning for this?
        // If they send the funds back, and the request is cancelled, they can be treated as deposits.
    }

    /**********************************************************************************************/
    /*** Fund Manager Functions                                                                 ***/
    /**********************************************************************************************/

    function drawFunds(address asset, uint256 amount) external override isFundManager {
        outstandingPrincipal[asset] += amount;

        require(
            amount <= ERC20Like(asset).balanceOf(address(this)) - totalWithdrawable[asset],
            "Conduit/insufficient-available-cash"
        );

        require(ERC20Like(asset).transfer(fundManager, amount), "Conduit/transfer-failed");
    }

    function returnFunds(address asset, uint256 returnAmount) external override isFundManager {
        outstandingPrincipal[asset] -= returnAmount;

        uint256 fundsRemaining = returnAmount;

        uint256 newStartingFundRequestId = startingFundRequestId[asset];

        // For all of the assets fund requests, fill as much as possible
        // Maintain the order of the fund requests array and update after all fills are complete.
        for (uint256 i = newStartingFundRequestId; i < fundRequests[asset].length; i++) {
            FundRequest storage fundRequest = fundRequests[asset][i];

            if (
                fundRequest.status == StatusEnum.CANCELLED ||
                fundRequest.status == StatusEnum.COMPLETED
            ) {
                newStartingFundRequestId++;
                continue;
            }

            uint256 fillAmount = fundRequest.amountRequested - fundRequest.amountAvailable;

            if (fillAmount > fundsRemaining) {
                fillAmount = fundsRemaining;
                fundRequest.status = StatusEnum.PARTIAL;
            } else {
                fundRequest.status = StatusEnum.COMPLETED;
                newStartingFundRequestId++;
            }

            fundsRemaining              -= fillAmount;
            fundRequest.amountAvailable += fillAmount;
            totalWithdrawable[asset]    += fillAmount;

            availableWithdrawals[fundRequest.ilk][asset] += fillAmount;

            if (fundsRemaining == 0) break;
        }

        startingFundRequestId[asset] = newStartingFundRequestId;

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
        external override pure returns (uint256 maxDeposit_)
    {
        ilk; asset;  // Silence warnings
        maxDeposit_ = type(uint256).max;
    }

    function maxWithdraw(bytes32 ilk, address asset)
        external override view returns (uint256 maxWithdraw_)
    {
        // TODO: Check if maxWithdraw should turn into a mapping
        maxWithdraw_ = availableWithdrawals[ilk][asset];
    }

    function isCancelable(address asset, uint256 fundRequestId)
        external override view returns (bool isCancelable_)
    {
        isCancelable_ = fundRequests[asset][fundRequestId].status == StatusEnum.PENDING;
    }

    function fundRequestStatus(address asset, uint256 fundRequestId)
        external override view returns (bytes32 ilk, FundRequest memory fundRequest)
    {
        // TODO: Change the interface to just return the struct?
        ilk         = fundRequests[asset][fundRequestId].ilk;
        fundRequest = fundRequests[asset][fundRequestId];
    }

    function activeFundRequests(address asset, bytes32 ilk)
        external override view returns (
            uint256[] memory fundRequestIds,
            uint256 totalRequested,
            uint256 totalAvailable
        )
    {
        uint256 i;

        for (uint256 j = startingFundRequestId[asset]; j < fundRequests[asset].length; j++) {
            FundRequest memory fundRequest = fundRequests[asset][j];

            if (
                fundRequest.status == StatusEnum.PENDING ||
                fundRequest.status == StatusEnum.PARTIAL
            ) {
                fundRequestIds[i++] = j;

                totalRequested += fundRequest.amountRequested;
                totalAvailable += fundRequest.amountAvailable;
            }
        }
    }

    function totalActiveFundRequests(address asset)
        external override view returns (uint256 totalAmount) {}

}
