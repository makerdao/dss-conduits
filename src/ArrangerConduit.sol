// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

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

contract ArrangerConduit is IArrangerConduit {

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    address public override arranger;
    address public override registry;
    address public override roles;

    mapping(address => uint256) public wards;

    mapping(address => uint256) public override totalDeposits;
    mapping(address => uint256) public override totalRequestedFunds;
    mapping(address => uint256) public override totalWithdrawableFunds;
    mapping(address => uint256) public override totalWithdrawals;

    mapping(bytes32 => mapping(address => uint256)) public override deposits;
    mapping(bytes32 => mapping(address => uint256)) public override requestedFunds;
    mapping(bytes32 => mapping(address => uint256)) public override withdrawableFunds;
    mapping(bytes32 => mapping(address => uint256)) public override withdrawals;

    FundRequest[] public fundRequests;

    constructor(address arranger_, address registry_, address roles_) {
        arranger = arranger_;
        registry = registry_;
        roles    = roles_;

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

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

    function rely(address usr) external override auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external override auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function file(bytes32 what, address data) external auth {
        if (what == "arranger") {
            arranger = data;
        } else revert("ArrangerConduit/file-unrecognized-param");
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
        require(
            maxAmount <= withdrawableFunds[ilk][asset],
            "ArrangerConduit/insufficient-withdrawable"
        );

        withdrawableFunds[ilk][asset] -= maxAmount;
        totalWithdrawableFunds[asset] -= maxAmount;

        withdrawals[ilk][asset] += maxAmount;
        totalWithdrawals[asset] += maxAmount;

        amount = maxAmount;

        address destination = RegistryLike(registry).buffers(ilk);

        require(
            ERC20Like(asset).transfer(destination, maxAmount),
            "ArrangerConduit/withdraw-transfer-failed"
        );

        emit Withdraw(ilk, asset, destination, maxAmount);
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

        address asset = fundRequest.asset;
        bytes32 ilk   = fundRequest.ilk;

        _checkAuth(ilk);

        uint256 amountRequested = fundRequest.amountRequested;

        delete fundRequests[fundRequestId];

        requestedFunds[ilk][asset] -= amountRequested;
        totalRequestedFunds[asset] -= amountRequested;

        emit CancelFundRequest(fundRequestId);
    }

    /**********************************************************************************************/
    /*** Fund Manager Functions                                                                 ***/
    /**********************************************************************************************/

    function drawFunds(address asset, uint256 amount) external override isArranger {
        require(amount <= drawableFunds(asset), "ArrangerConduit/insufficient-funds");

        require(ERC20Like(asset).transfer(arranger, amount), "ArrangerConduit/transfer-failed");

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

        fundRequest.amountFilled += returnAmount;

        fundRequest.status = StatusEnum.COMPLETED;

        require(
            ERC20Like(fundRequest.asset).transferFrom(arranger, address(this), returnAmount),
            "ArrangerConduit/transfer-failed"
        );

        emit ReturnFunds(ilk, asset, fundRequestId, amountRequested, returnAmount);
    }

    /**********************************************************************************************/
    /*** View Functions                                                                         ***/
    /**********************************************************************************************/

    function drawableFunds(address asset) public view returns (uint256 drawableFunds_) {
        drawableFunds_ = ERC20Like(asset).balanceOf(address(this)) - totalWithdrawableFunds[asset];
    }

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
