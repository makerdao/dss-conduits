// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Conduit
 * @dev A contract that handles the deposit, withdrawal, and management of funds from third-party Arrangers or RWA protocols.
 */
contract Conduit {
    enum StatusEnum { Inactive, Active, Completed }

    struct WithdrawalRequest {
        address owner;
        uint256 amount;
        StatusEnum status;
    }

    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
    uint256 public totalWithdrawalRequests;

    mapping(address => bool) public routers;

    /**
     * @dev Modifier to restrict access to only authorized routers.
     */
    modifier onlyRouter() {
        require(routers[msg.sender], "Only authorized routers can call this function");
        _;
    }

    /**
     * @dev Adds a router to the list of authorized routers.
     * @param router The address of the router to add.
     */
    function addRouter(address router) external {
        require(router != address(0), "Invalid router address");
        routers[router] = true;
    }

    /**
     * @dev Removes a router from the list of authorized routers.
     * @param router The address of the router to remove.
     */
    function removeRouter(address router) external {
        delete routers[router];
    }

    /**
     * @dev Deposits funds into the FundManager.
     * Only authorized routers can call this function.
     * @param amount The amount of funds to deposit.
     */
    function deposit(uint256 amount) external onlyRouter {
        // Implement the logic to deposit funds into the FundManager
    }

    /**
     * @dev Checks if a withdrawal request can be canceled.
     * @param withdrawalId The ID of the withdrawal request.
     * @return Whether the withdrawal request can be canceled.
     */
    function isCancelable(uint256 withdrawalId) external view returns (bool) {
        WithdrawalRequest storage request = withdrawalRequests[withdrawalId];
        return request.status == StatusEnum.Active;
    }

    /**
     * @dev Initiates a withdrawal request from the FundManager.
     * Only authorized routers can call this function.
     * @param amount The amount of funds to withdraw.
     * @return The ID of the withdrawal request.
     */
    function initiateWithdraw(uint256 amount) external onlyRouter returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");

        uint256 withdrawalId = totalWithdrawalRequests + 1;
        withdrawalRequests[withdrawalId] = WithdrawalRequest(msg.sender, amount, StatusEnum.Active);
        totalWithdrawalRequests++;

        return withdrawalId;
    }

    /**
     * @dev Cancels a withdrawal request.
     * Only authorized routers can call this function.
     * @param withdrawalId The ID of the withdrawal request to cancel.
     */
    function cancelWithdraw(uint256 withdrawalId) external onlyRouter {
        WithdrawalRequest storage request = withdrawalRequests[withdrawalId];
        require(request.status == StatusEnum.Active, "Withdrawal request is not active");

        request.status = StatusEnum.Inactive;
    }

    /**
     * @dev Withdraws funds from the FundManager.
     * Only authorized routers can call this function.
     * @param withdrawalId The ID of the withdrawal request.
     * @return The ID of the completed withdrawal request.
     */
    function withdraw(uint256 withdrawalId) external onlyRouter returns (uint256) {
        WithdrawalRequest storage request = withdrawalRequests[withdrawalId];
        require(request.status == StatusEnum.Active, "Withdrawal request is not active");

        // Implement the logic to withdraw funds from the FundManager

        request.status = StatusEnum.Completed;
        return withdrawalId;
    }

    /**
     * @dev Retrieves the status of a withdrawal request.
     * @param withdrawalId The ID of the withdrawal request.
     * @return The owner address, amount, and status of the withdrawal request.
     */
    function withdrawStatus(uint256 withdrawalId) external view returns (address, uint256, StatusEnum) {
        WithdrawalRequest storage request = withdrawalRequests[withdrawalId];
        return (request.owner, request.amount, request.status);
    }

    /**
     * @dev Retrieves the active withdrawal requests for a specific owner.
     * @param owner The address of the owner.
     * @return An array of withdrawal request IDs and the total amount of active withdrawal requests.
     */
    function activeWithdraws(address owner) external view returns (uint256[] memory, uint256) {
        uint256[] memory withdrawIds = new uint256[](totalWithdrawalRequests);
        uint256 count;

        for (uint256 i = 1; i <= totalWithdrawalRequests; i++) {
            if (withdrawalRequests[i].owner == owner && withdrawalRequests[i].status == StatusEnum.Active) {
                withdrawIds[count] = i;
                count++;
            }
        }

        uint256 totalAmount;
        for (uint256 i = 0; i < count; i++) {
            totalAmount += withdrawalRequests[withdrawIds[i]].amount;
        }

        return (withdrawIds, totalAmount);
    }

    /**
     * @dev Retrieves the total number of active withdrawal requests.
     * @return The total number of active withdrawal requests.
     */
    function totalActiveWithdraws() external view returns (uint256) {
        uint256 count;

        for (uint256 i = 1; i <= totalWithdrawalRequests; i++) {
            if (withdrawalRequests[i].status == StatusEnum.Active) {
                count++;
            }
        }

        return count;
    }
}
