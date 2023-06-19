// function withdraw_OLD(
//     bytes32 ilk,
//     address asset,
//     address destination,
//     uint256 withdrawAmount
// )
//     external
// {
//     // Will underflow if aggregate of positions is less than withdrawAmount
//     positions[ilk][asset] -= withdrawAmount;
//     totalPositions[asset]       -= withdrawAmount;

//     uint256 fundsRemaining = withdrawAmount;

//     uint256[] memory fundRequestIds = new uint256[](latestFundRequestId[asset] - startingFundRequestId[asset]);

//     // For all of an ilk's fund requests, fill as much as possible
//     // Maintain the order of the fund requests array and update after all fills are complete.
//     for (uint256 i = startingFundRequestId[asset]; i < fundRequests[asset].length; i++) {
//         FundRequest storage fundRequest = fundRequests[asset][i];

//         if (fundRequest.ilk != ilk) continue;

//         if (
//             fundRequest.status == StatusEnum.CANCELLED ||
//             fundRequest.status == StatusEnum.COMPLETED
//         ) continue;

//         uint256 fillAmount = fundRequest.amountRequested - fundRequest.amountFilled;

//         if (fillAmount > fundsRemaining) {
//             fillAmount = fundsRemaining;
//         }

//         fundsRemaining           -= fillAmount;
//         fundRequest.amountFilled += fillAmount;

//         if (fundsRemaining == 0) break;
//     }

//     emit Withdraw(ilk, asset, destination, withdrawAmount);

//     require(
//         ERC20Like(asset).transfer(destination, withdrawAmount),
//         "Conduit/transfer-failed"
//     );
// }

// // SPDX-License-Identifier: AGPL-3.0-or-later
// pragma solidity ^0.8.13;

// import { Test } from "../lib/forge-std/src/Test.sol";

// import { MockERC20 } from "../lib/mock-erc20/src/MockERC20.sol";

// import { IConduit } from "../src/IConduit.sol";
// import { Conduit }  from "../src/Conduit.sol";

// contract ConduitTestBase is Test {

//     address admin       = makeAddr("admin");
//     address fundManager = makeAddr("fundManager");

//     Conduit conduit;

//     function setUp() public virtual {
//         conduit = new Conduit(admin, fundManager);
//     }

// }

// contract Conduit_ConstructorTest is ConduitTestBase {

//     function test_constructor() public {
//         assertEq(conduit.admin(),       admin);
//         assertEq(conduit.fundManager(), fundManager);
//     }
// }

// contract Conduit_SetIsValidRouterTest is ConduitTestBase {

//     function test_setIsValidRouter_notAdmin() public {
//         vm.expectRevert("Conduit/not-admin");
//         conduit.setIsValidRouter(address(1), true);
//     }

//     function test_setIsValidRouter() public {
//         vm.startPrank(admin);

//         assertTrue(!conduit.isValidRouter(address(1)));

//         conduit.setIsValidRouter(address(1), true);
//         assertTrue(conduit.isValidRouter(address(1)));

//         conduit.setIsValidRouter(address(1), false);
//         assertTrue(!conduit.isValidRouter(address(1)));
//     }

// }

// contract Conduit_SetRouterOwnerTest is ConduitTestBase {

//     function test_setRouterOwner_notAdmin() public {
//         vm.expectRevert("Conduit/not-admin");
//         conduit.setRouterOwner(address(1), "SUBDAO_ONE");
//     }

//     function test_setRouterOwner_notValidRouter() public {
//         vm.startPrank(admin);

//         vm.expectRevert("Conduit/not-router");
//         conduit.setRouterOwner(address(1), "SUBDAO_ONE");
//     }

//     function test_setRouterOwner() public {
//         vm.startPrank(admin);

//         address router = makeAddr("router");

//         conduit.setIsValidRouter(router, true);

//         assertEq(conduit.routerOwner(router), bytes32(0));

//         conduit.setRouterOwner(router, "SUBDAO_ONE");
//         assertEq(conduit.routerOwner(router), "SUBDAO_ONE");

//         conduit.setRouterOwner(router, "SUBDAO_TWO");
//         assertEq(conduit.routerOwner(router), "SUBDAO_TWO");
//     }

// }

// contract Conduit_DrawFundsTest is ConduitTestBase {

//     MockERC20 asset1;
//     MockERC20 asset2;

//     function setUp() public override {
//         super.setUp();
//         asset1 = new MockERC20("asset1", "A1", 18);
//         asset2 = new MockERC20("asset2", "A2", 18);
//     }

//     function test_drawFunds_notFundManager() public {
//         vm.expectRevert("Conduit/not-fund-manager");
//         conduit.drawFunds(add(address(1), "SUBDAO_ONE");
//     }

//     function test_drawFunds_insufficientFundsBoundary() public {
//         vm.startPrank(fundManager);

//         asset1.mint(conduit, 99);

//         vm.expectRevert("Conduit/insufficient-funds");
//         conduit.drawFunds(asset1, 100);
//     }

//     function test_setRouterOwner() public {
//         vm.startPrank(admin);

//         address router = makeAddr("router");

//         conduit.setIsValidRouter(router, true);

//         assertEq(conduit.routerOwner(router), bytes32(0));

//         conduit.setRouterOwner(router, "SUBDAO_ONE");
//         assertEq(conduit.routerOwner(router), "SUBDAO_ONE");

//         conduit.setRouterOwner(router, "SUBDAO_TWO");
//         assertEq(conduit.routerOwner(router), "SUBDAO_TWO");
//     }

// }
