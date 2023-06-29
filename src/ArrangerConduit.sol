// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IArrangerConduit } from "./interfaces/IArrangerConduit.sol";

// TODO: Add and test Router ACL
// TODO: Add events
// TODO: Add cumulative withdrawals

interface ERC20Like {
    function balanceOf(address src) external view returns (uint256 wad);
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

contract ArrangerConduit is IArrangerConduit {

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    address public override admin;
    address public override arranger;
    address public override roles;

    mapping(address => uint256) public override totalDeposits;
    mapping(address => uint256) public override totalRequestedFunds;
    mapping(address => uint256) public override totalWithdrawableFunds;
    mapping(address => uint256) public override totalWithdrawals;

    mapping(bytes32 => mapping(address => uint256)) public override deposits;
    mapping(bytes32 => mapping(address => uint256)) public override requestedFunds;
    mapping(bytes32 => mapping(address => uint256)) public override withdrawableFunds;
    mapping(bytes32 => mapping(address => uint256)) public override withdrawals;

    FundRequest[] public fundRequests;  // TODO: Refactor functions to use this

    constructor(address admin_, address arranger_, address roles_) {
        admin    = admin_;
        arranger = arranger_;
        roles    = roles_;
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier isAdmin {
        // require(msg.sender == admin, "Conduit/not-admin");
        _;
    }

    modifier isArranger {
        // require(msg.sender == arranger, "Conduit/not-fund-manager");
        _;
    }

    /**********************************************************************************************/
    /*** Router Functions                                                                       ***/
    /**********************************************************************************************/

    function deposit(bytes32 ilk, address asset, uint256 amount) external override {
        deposits[ilk][asset] += amount;
        totalDeposits[asset] += amount;

        // TODO: Use ERC20Helper
        require(
            ERC20Like(asset).transferFrom(msg.sender, address(this), amount),
            "Conduit/deposit-transfer-failed"
        );
    }

    function withdraw(bytes32 ilk, address asset, address destination, uint256 withdrawAmount)
        external override returns (uint256 actualWithdrawAmount)
    {
        require(
            withdrawAmount <= withdrawableFunds[ilk][asset],
            "Conduit/insufficient-withdrawable"
        );

        withdrawableFunds[ilk][asset] -= withdrawAmount;
        totalWithdrawableFunds[asset] -= withdrawAmount;

        withdrawals[ilk][asset] += withdrawAmount;
        totalWithdrawals[asset] += withdrawAmount;

        actualWithdrawAmount = withdrawAmount;

        // TODO: Do lookup from ilk => buffer
        require(
            ERC20Like(asset).transfer(destination, withdrawAmount),
            "Conduit/withdraw-transfer-failed"
        );
    }

    function requestFunds(bytes32 ilk, address asset, uint256 amount, string memory info)
        external override returns (uint256 fundRequestId)
    {
        fundRequestId = fundRequests.length;  // Current length will be the next index

        fundRequests.push(FundRequest({
            status:          StatusEnum.PENDING,
            asset:           asset,
            ilk:             ilk,
            amountRequested: amount,
            amountFilled:    0,
            info:            info
        }));

        requestedFunds[ilk][asset] += amount;
        totalRequestedFunds[asset] += amount;
    }

    function cancelFundRequest(uint256 fundRequestId) external override {
        // TODO: Should we allow the arranger to cancel?
        delete fundRequests[fundRequestId];
    }

    /**********************************************************************************************/
    /*** Fund Manager Functions                                                                 ***/
    /**********************************************************************************************/

    function drawFunds(address asset, uint256 amount) external override isArranger {
        require(
            ERC20Like(asset).balanceOf(address(this)) >= (amount - totalWithdrawableFunds[asset]),
            "Conduit/insufficient-funds"
        );

        require(ERC20Like(asset).transfer(arranger, amount), "Conduit/transfer-failed");
    }

    // TODO: Add ilk and asset input and add require check to prevent human error?
    // TODO: Add require to check that request is pending
    function returnFunds(uint256 fundRequestId, uint256 returnAmount)
        external override isArranger
    {
        FundRequest storage fundRequest = fundRequests[fundRequestId];

        address asset = fundRequest.asset;
        bytes32 ilk   = fundRequest.ilk;

        uint256 amountRequested = fundRequest.amountRequested;

        withdrawableFunds[ilk][asset] += returnAmount;
        totalWithdrawableFunds[asset] += returnAmount;

        requestedFunds[ilk][asset] -= amountRequested;
        totalRequestedFunds[asset] -= amountRequested;

        fundRequest.amountFilled += returnAmount;

        fundRequest.status = StatusEnum.COMPLETED;

        require(
            ERC20Like(fundRequest.asset).transferFrom(arranger, address(this), returnAmount),
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
        maxWithdraw_ = withdrawableFunds[ilk][asset];
    }

    function isCancelable(uint256 fundRequestId)
        external override view returns (bool isCancelable_)
    {
        isCancelable_ = fundRequests[fundRequestId].status == StatusEnum.PENDING;
    }

}
