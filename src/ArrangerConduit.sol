// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IArrangerConduit } from "./interfaces/IArrangerConduit.sol";

// TODO: Add and test Router ACL
// TODO: Add events

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
    address public override fundManager;

    mapping(address => uint256) public override totalDeposits;
    mapping(address => uint256) public override totalRequestedFunds;
    mapping(address => uint256) public override totalWithdrawableFunds;

    mapping(bytes32 => mapping(address => uint256)) public override deposits;
    mapping(bytes32 => mapping(address => uint256)) public override requestedFunds;
    mapping(bytes32 => mapping(address => uint256)) public override withdrawableFunds;

    mapping(bytes32 => mapping(address => FundRequest[])) public fundRequests;

    constructor(address admin_, address fundManager_) {
        admin       = admin_;
        fundManager = fundManager_;
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier isAdmin {
        // require(msg.sender == admin, "Conduit/not-admin");
        _;
    }

    modifier isFundManager {
        // require(msg.sender == fundManager, "Conduit/not-fund-manager");
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
        external override
    {
        // TODO: Ensure withdrawers cant withdraw from deposits
        withdrawableFunds[ilk][asset] -= withdrawAmount;
        totalWithdrawableFunds[asset] -= withdrawAmount;

        // TODO: Do lookup from ilk => buffer
        require(
            ERC20Like(asset).transfer(destination, withdrawAmount),
            "Conduit/withdraw-transfer-failed"
        );
    }

    function requestFunds(bytes32 ilk, address asset, uint256 amount, string memory info)
        external override returns (uint256 fundRequestId)
    {
        fundRequestId = fundRequests[ilk][asset].length;  // Current length will be the next index

        fundRequests[ilk][asset].push(FundRequest({
            status:          StatusEnum.PENDING,
            ilk:             ilk,
            amountRequested: amount,
            amountFilled:    0,
            info:            info
        }));

        requestedFunds[ilk][asset] += amount;
        totalRequestedFunds[asset] += amount;
    }

    function cancelFundRequest(bytes32 ilk, address asset, uint256 fundRequestId)
        external override
    {
        // TODO: Should we allow the arranger to cancel?
        delete fundRequests[ilk][asset][fundRequestId];
    }

    /**********************************************************************************************/
    /*** Fund Manager Functions                                                                 ***/
    /**********************************************************************************************/

    function drawFunds(bytes32 ilk, address asset, uint256 amount) external override isFundManager {
        deposits[ilk][asset] -= amount;
        totalDeposits[asset] -= amount;

        require(ERC20Like(asset).transfer(fundManager, amount), "Conduit/transfer-failed");
    }

    // TODO: Should we add (principal, interest, losses) and just emit as an event?
    function returnFunds(bytes32 ilk, address asset, uint256 fundRequestId, uint256 returnAmount)
        external override isFundManager
    {
        withdrawableFunds[ilk][asset] += returnAmount;
        totalWithdrawableFunds[asset] += returnAmount;

        FundRequest storage fundRequest = fundRequests[ilk][asset][fundRequestId];

        // TODO: Should we add info to the fund request itself?
        fundRequest.amountFilled += returnAmount;

        fundRequest.status = fundRequest.amountFilled == fundRequest.amountRequested
            ? StatusEnum.COMPLETED
            : StatusEnum.PARTIAL;

        require(
            ERC20Like(asset).transferFrom(fundManager, address(this), returnAmount),
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

    function isCancelable(bytes32 ilk, address asset, uint256 fundRequestId)
        external override view returns (bool isCancelable_)
    {
        isCancelable_ = _isActiveRequest(fundRequests[ilk][asset][fundRequestId].status);
    }

    /**********************************************************************************************/
    /*** Internal Functions                                                                     ***/
    /**********************************************************************************************/

    function _isActiveRequest(StatusEnum status) internal pure returns (bool) {
        return status == StatusEnum.PENDING || status == StatusEnum.PARTIAL;
    }

}
