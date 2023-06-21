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

    address public override admin;
    address public override fundManager;

    mapping(address => uint256) public override outstandingPrincipal;
    mapping(address => uint256) public override startingFundRequestId;
    mapping(address => uint256) public override totalInterestEarned;
    mapping(address => uint256) public override totalPositions;
    mapping(address => uint256) public override totalWithdrawable;

    mapping(address => FundRequest[]) public fundRequests;

    mapping(bytes32 => mapping(address => uint256)) public override maxWithdraw;
    mapping(bytes32 => mapping(address => uint256)) public override pendingWithdrawals;
    mapping(bytes32 => mapping(address => uint256)) public override positions;

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
        // maxWithdraw < pendingWithdrawals < positions < totalWithdrawable < totalPositions
        require(
            withdrawAmount <= maxWithdraw[ilk][asset],
            "Conduit/insufficient-withdrawal"
        );

        maxWithdraw[ilk][asset]        -= withdrawAmount;
        pendingWithdrawals[ilk][asset] -= withdrawAmount;
        positions[ilk][asset]          -= withdrawAmount;

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
            amountRequested: amount,
            amountFilled:    0
        }));

        pendingWithdrawals[ilk][asset] += amount;

        require(
            pendingWithdrawals[ilk][asset] <= positions[ilk][asset],
            "Conduit/insufficient-position"
        );
    }

    function cancelFundRequest(address asset, uint256 fundRequestId) external override {
        delete fundRequests[asset][fundRequestId];
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

            uint256 fillAmount = fundRequest.amountRequested - fundRequest.amountFilled;

            if (fillAmount > fundsRemaining) {
                fillAmount = fundsRemaining;
                fundRequest.status = StatusEnum.PARTIAL;
            } else {
                fundRequest.status = StatusEnum.COMPLETED;
                newStartingFundRequestId++;
            }

            fundsRemaining           -= fillAmount;
            fundRequest.amountFilled += fillAmount;
            totalWithdrawable[asset] += fillAmount;

            maxWithdraw[fundRequest.ilk][asset] += fillAmount;

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

    function isCancelable(address asset, uint256 fundRequestId)
        external override view returns (bool isCancelable_)
    {
        isCancelable_ = fundRequests[asset][fundRequestId].status == StatusEnum.PENDING;
    }

    function activeFundRequests(address asset, bytes32 ilk)
        external override view returns (
            uint256[] memory fundRequestIds,
            uint256 totalRequested,
            uint256 totalFilled
        )
    {
        uint256 i;

        for (uint256 j = startingFundRequestId[asset]; j < fundRequests[asset].length; j++) {
            FundRequest memory fundRequest = fundRequests[asset][j];

            if (
                (
                    fundRequest.status == StatusEnum.PENDING ||
                    fundRequest.status == StatusEnum.PARTIAL
                ) &&
                fundRequest.ilk == ilk
            ) {
                fundRequestIds[i++] = j;

                totalRequested += fundRequest.amountRequested;
                totalFilled    += fundRequest.amountFilled;
            }
        }
    }

    function totalActiveFundRequests(address asset)
        external override view returns (uint256 totalRequested, uint256 totalFilled)
    {
        for (uint256 i = startingFundRequestId[asset]; i < fundRequests[asset].length; i++) {
            FundRequest memory fundRequest = fundRequests[asset][i];

            if (
                fundRequest.status == StatusEnum.PENDING ||
                fundRequest.status == StatusEnum.PARTIAL
            ) {

                totalRequested += fundRequest.amountRequested;
                totalFilled    += fundRequest.amountFilled;
            }
        }
    }

}
