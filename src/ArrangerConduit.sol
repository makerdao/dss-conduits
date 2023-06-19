// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IAllocatorConduit } from "../lib/dss-allocator/src/interfaces/IAllocatorConduit.sol";

interface ERC20Like {
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

contract ArrangerConduit is IAllocatorConduit {

    /**
     *  @dev   Struct representing a fund request.
     *  @param status          The current status of the fund request.
     *  @param ilk             The unique identifier of the ilk.
     *  @param amountAvailable The amount of asset available for withdrawal.
     *  @param amountRequested The amount of asset requested in the fund request.
     *  @param amountFilled    The amount of asset filled in the fund request.
     *  @param fundRequestId   The ID of the fund request.
     */
    struct FundRequest {
        StatusEnum status;
        bytes32    ilk;
        uint256    amountAvailable;
        uint256    amountRequested;
        uint256    amountFilled;
        uint256    fundRequestId;  // NOTE: Investigate usage
    }

    /**
     *  @dev Enum representing the status of a fund request.
     *
     *  @notice PENDING   - The fund request has been made, but not yet processed.
     *  @notice PARTIAL   - The fund request has been partially filled, but not yet completed.
     *  @notice CANCELLED - The fund request has been cancelled by the ilk..
     *  @notice COMPLETED - The fund request has been fully processed and completed.
     */
    enum StatusEnum {
        PENDING,
        PARTIAL,
        CANCELLED,
        COMPLETED
    }

    /**********************************************************************************************/
    /***TODO:  Move Above to interface                                                          ***/
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

    mapping(address => FundRequest[]) fundRequests;

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

    function deposit(bytes32 ilk, address asset, uint256 amount) external {
        // TODO: Use ERC20Helper
        require(
            ERC20Like(asset).transferFrom(msg.sender, address(this), amount),
            "Conduit/deposit-transfer-failed"
        );

        positions[ilk][asset] += amount;
        totalPositions[asset] += amount;
    }

    function withdraw(bytes32 ilk, address asset, address destination, uint256 amount) external {
        require(
            ERC20Like(asset).transfer(destination, amount),
            "Conduit/withdraw-transfer-failed"
        );

        positions[ilk][asset] -= amount;
        totalPositions[asset] -= amount;
    }

    function requestFunds(bytes32 ilk, address asset, uint256 amount, bytes memory data)
        external returns (uint256 fundRequestId)
    {
        lastFundRequestId[asset] = fundRequestId = latestFundRequestId[asset]++;

        fundRequests[asset].push(FundRequest({
            status:          StatusEnum.PENDING,
            ilk:             ilk,
            amountAvailable: 0,
            amountRequested: amount,
            amountFilled:    0,
            fundRequestId:   fundRequestId
        }));
    }

    function cancelFundRequest(uint256 fundRequestId) external {}

    /***********************************************************************************************/
    /*** Fund Manager Functions                                                                  ***/
    /***********************************************************************************************/

    function drawFunds(address asset, uint256 amount) external isFundManager {
        outstandingPrincipal[asset] += amount;

        require(ERC20Like(asset).transfer(fundManager, amount), "Conduit/transfer-failed");
    }

    function returnFunds(address asset, uint256 amount) external isFundManager {
        outstandingPrincipal[asset] -= amount;

        require(
            ERC20Like(asset).transferFrom(fundManager, address(this), amount),
            "Conduit/transfer-failed"
        );
    }

    function payInterest(address asset, uint256 amount) external isFundManager {
        totalInterestEarned[asset] += amount;

        require(
            ERC20Like(asset).transferFrom(fundManager, admin, amount),
            "Conduit/transfer-failed"
        );
    }

    /**********************************************************************************************/
    /*** View Functions                                                                         ***/
    /**********************************************************************************************/

    function maxDeposit(bytes32 ilk, address asset) external view returns (uint256 maxDeposit_) {}

    function maxWithdraw(bytes32 ilk, address asset) external view returns (uint256 maxWithdraw_) {}

    function isCancelable(uint256 fundRequestId) external view returns (bool isCancelable_) {}

    function fundRequestStatus(uint256 fundRequestId) external returns (bytes32 ilk, FundRequest memory fundRequest) {}

    function activeFundRequests(bytes32 ilk) external returns (uint256[] memory fundRequestIds, uint256 totalAmount) {}

    function totalActiveFundRequests() external returns (uint256 totalAmount) {}

}

// TODO: Add FIFO logic for requests
