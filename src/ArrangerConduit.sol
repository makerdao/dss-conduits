// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { UpgradeableProxied } from "../lib/upgradeable-proxy/src/UpgradeableProxied.sol";

import { IArrangerConduit } from "./interfaces/IArrangerConduit.sol";

interface ERC20Like {
    function balanceOf(address src) external view returns (uint256 wad);
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

interface RolesLike {
    function canCall(bytes32, address, address, bytes4) external view returns (bool);
}

interface RegistryLike {
    function buffers(bytes32 ilk) external view returns (address buffer);
}

// TODO: Use ERC20Helper
// TODO: Figure out optimal way to structure natspec

contract ArrangerConduit is UpgradeableProxied, IArrangerConduit {

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    FundRequest[] internal fundRequests;

    address public override arranger;
    address public override registry;
    address public override roles;

    mapping(address => uint256) public override totalDeposits;
    mapping(address => uint256) public override totalRequestedFunds;
    mapping(address => uint256) public override totalWithdrawableFunds;
    mapping(address => uint256) public override totalWithdrawals;

    mapping(bytes32 => mapping(address => uint256)) public override deposits;
    mapping(bytes32 => mapping(address => uint256)) public override requestedFunds;
    mapping(bytes32 => mapping(address => uint256)) public override withdrawableFunds;
    mapping(bytes32 => mapping(address => uint256)) public override withdrawals;

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier auth {
        require(wards[msg.sender] == 1, "ArrangerConduit/not-authorized");
        _;
    }

    modifier ilkAuth(bytes32 ilk) {
        _checkAuth(ilk);
        _;
    }

    modifier isArranger {
        require(msg.sender == arranger, "ArrangerConduit/not-arranger");
        _;
    }
    /**********************************************************************************************/
    /*** Administrative Functions                                                               ***/
    /**********************************************************************************************/

    function file(bytes32 what, address data) external auth {
        if      (what == "arranger") arranger = data;
        else if (what == "registry") registry = data;
        else if (what == "roles")    roles    = data;
        else revert("ArrangerConduit/file-unrecognized-param");
        emit File(what, data);
    }

    /**********************************************************************************************/
    /*** Router Functions                                                                       ***/
    /**********************************************************************************************/

    function deposit(bytes32 ilk, address asset, uint256 amount) external override ilkAuth(ilk) {
        deposits[ilk][asset] += amount;
        totalDeposits[asset] += amount;

        address source = RegistryLike(registry).buffers(ilk);

        require(
            ERC20Like(asset).transferFrom(source, address(this), amount),
            "ArrangerConduit/deposit-transfer-failed"
        );

        emit Deposit(ilk, asset, source, amount);
    }

    function withdraw(bytes32 ilk, address asset, uint256 maxAmount)
        external override ilkAuth(ilk) returns (uint256 amount)
    {
        uint256 withdrawableFunds_ = withdrawableFunds[ilk][asset];

        amount = maxAmount > withdrawableFunds_ ? withdrawableFunds_ : maxAmount;

        withdrawableFunds[ilk][asset] -= amount;
        totalWithdrawableFunds[asset] -= amount;

        withdrawals[ilk][asset] += amount;
        totalWithdrawals[asset] += amount;

        address destination = RegistryLike(registry).buffers(ilk);

        require(
            ERC20Like(asset).transfer(destination, amount),
            "ArrangerConduit/withdraw-transfer-failed"
        );

        emit Withdraw(ilk, asset, destination, amount);
    }

    function requestFunds(bytes32 ilk, address asset, uint256 amount, string memory info)
        external override ilkAuth(ilk) returns (uint256 fundRequestId)
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

        emit RequestFunds(ilk, asset, fundRequestId, amount, info);
    }

    function cancelFundRequest(uint256 fundRequestId) external override {
        FundRequest memory fundRequest = fundRequests[fundRequestId];

        require(fundRequest.status == StatusEnum.PENDING, "ArrangerConduit/invalid-status");

        address asset = fundRequest.asset;
        bytes32 ilk   = fundRequest.ilk;

        _checkAuth(ilk);

        uint256 amountRequested = fundRequest.amountRequested;

        fundRequests[fundRequestId].status = StatusEnum.CANCELLED;

        requestedFunds[ilk][asset] -= amountRequested;
        totalRequestedFunds[asset] -= amountRequested;

        emit CancelFundRequest(fundRequestId);
    }

    /**********************************************************************************************/
    /*** Fund Manager Functions                                                                 ***/
    /**********************************************************************************************/

    function drawFunds(address asset, uint256 amount) external override isArranger {
        require(amount <= drawableFunds(asset), "ArrangerConduit/insufficient-funds");

        require(ERC20Like(asset).transfer(msg.sender, amount), "ArrangerConduit/transfer-failed");

        emit DrawFunds(asset, amount);
    }

    function returnFunds(uint256 fundRequestId, uint256 returnAmount)
        external override isArranger
    {
        FundRequest storage fundRequest = fundRequests[fundRequestId];

        require(fundRequest.status == StatusEnum.PENDING, "ArrangerConduit/invalid-status");

        address asset = fundRequest.asset;
        bytes32 ilk   = fundRequest.ilk;

        uint256 amountRequested = fundRequest.amountRequested;

        withdrawableFunds[ilk][asset] += returnAmount;
        totalWithdrawableFunds[asset] += returnAmount;

        requestedFunds[ilk][asset] -= amountRequested;
        totalRequestedFunds[asset] -= amountRequested;

        fundRequest.amountFilled = returnAmount;

        fundRequest.status = StatusEnum.COMPLETED;

        require(
            ERC20Like(fundRequest.asset).transferFrom(msg.sender, address(this), returnAmount),
            "ArrangerConduit/transfer-failed"
        );

        emit ReturnFunds(ilk, asset, fundRequestId, amountRequested, returnAmount);
    }

    /**********************************************************************************************/
    /*** View Functions                                                                         ***/
    /**********************************************************************************************/

    function drawableFunds(address asset) public view override returns (uint256 drawableFunds_) {
        drawableFunds_ = ERC20Like(asset).balanceOf(address(this)) - totalWithdrawableFunds[asset];
    }

    function getFundRequest(uint256 fundRequestId)
        external override view returns (FundRequest memory fundRequest)
    {
        fundRequest = fundRequests[fundRequestId];
    }

    function getFundRequestsLength() external override view returns (uint256 fundRequestsLength) {
        fundRequestsLength = fundRequests.length;
    }

    function isCancelable(uint256 fundRequestId)
        external override view returns (bool isCancelable_)
    {
        isCancelable_ = fundRequests[fundRequestId].status == StatusEnum.PENDING;
    }

    function maxDeposit(bytes32, address)
        external override pure returns (uint256 maxDeposit_)
    {
        maxDeposit_ = type(uint256).max;
    }

    function maxWithdraw(bytes32 ilk, address asset)
        external override view returns (uint256 maxWithdraw_)
    {
        maxWithdraw_ = withdrawableFunds[ilk][asset];
    }

    /**********************************************************************************************/
    /*** Internal Functions                                                                     ***/
    /**********************************************************************************************/

    function _checkAuth(bytes32 ilk) internal view {
        require(
            RolesLike(roles).canCall(ilk, msg.sender, address(this), msg.sig),
            "ArrangerConduit/not-authorized"
        );
    }

}
