// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IArrangerConduit } from "../../src/interfaces/IArrangerConduit.sol";

import { ArrangerConduitHarness } from "./ArrangerConduitHarness.sol";

import "./ConduitTestBase.sol";

contract ArrangerConduit_DrawableFundsTest is ConduitAssetTestBase {

    ArrangerConduitHarness conduitHarness;

    function setUp() public override {
        UpgradeableProxy       conduitProxy          = new UpgradeableProxy();
        ArrangerConduitHarness conduitImplementation = new ArrangerConduitHarness();

        conduitProxy.setImplementation(address(conduitImplementation));

        conduitHarness = ArrangerConduitHarness(address(conduitProxy));
    }

    function testFuzz_drawableFunds(
        uint256 mintAmount1,
        uint256 withdrawableFundsAmount1,
        uint256 mintAmount2,
        uint256 withdrawableFundsAmount2
    )
        external
    {
        // `withdrawableFunds` can never be higher than balance
        mintAmount1 = _bound(mintAmount1, withdrawableFundsAmount1, type(uint256).max);
        mintAmount2 = _bound(mintAmount2, withdrawableFundsAmount2, type(uint256).max);

        asset1.mint(address(conduitHarness), mintAmount1);
        asset2.mint(address(conduitHarness), mintAmount2);

        conduitHarness.__setTotalWithdrawableFunds(address(asset1), withdrawableFundsAmount1);
        conduitHarness.__setTotalWithdrawableFunds(address(asset2), withdrawableFundsAmount2);

        assertEq(
            conduitHarness.availableFunds(address(asset1)),
            asset1.balanceOf(address(conduitHarness)) - withdrawableFundsAmount1
        );
        assertEq(
            conduitHarness.availableFunds(address(asset2)),
            asset2.balanceOf(address(conduitHarness)) - withdrawableFundsAmount2
        );
    }

}

contract ArrangerConduit_GetFundRequestTest is ConduitAssetTestBase {

    function test_getFundRequest() external {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 100);

        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        IArrangerConduit.FundRequest memory fundRequest = conduit.getFundRequest(0);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk1);
        assertEq(fundRequest.amountRequested, 100);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info");

        conduit.requestFunds(ilk1, address(asset1), 200, "info2");

        fundRequest = conduit.getFundRequest(1);

        assertTrue(fundRequest.status == IArrangerConduit.StatusEnum.PENDING);

        assertEq(fundRequest.asset,           address(asset1));
        assertEq(fundRequest.ilk,             ilk1);
        assertEq(fundRequest.amountRequested, 200);
        assertEq(fundRequest.amountFilled,    0);
        assertEq(fundRequest.info,            "info2");
    }

}

contract ArrangerConduit_GetFundRequestsLengthTest is ConduitAssetTestBase {

    function test_getFundRequestsLength() external {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        conduit.deposit(ilk1, address(asset1), 100);

        assertEq(conduit.getFundRequestsLength(), 0);

        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        assertEq(conduit.getFundRequestsLength(), 1);

        conduit.requestFunds(ilk1, address(asset1), 100, "info");

        assertEq(conduit.getFundRequestsLength(), 2);

        vm.stopPrank();

        vm.startPrank(arranger);

        conduit.drawFunds(address(asset1), broker1, 100);
        asset1.mint(address(conduit), 100);
        conduit.returnFunds(0, 40);

        assertEq(conduit.getFundRequestsLength(), 2);  // Returning funds does not change length
    }

}

contract ArrangerConduit_IsCancelableTest is ConduitAssetTestBase {

    ArrangerConduitHarness conduitHarness;

    function setUp() public override {
        super.setUp();

        ArrangerConduitHarness conduitImplementation = new ArrangerConduitHarness();

        conduitProxy.setImplementation(address(conduitImplementation));

        conduitHarness = ArrangerConduitHarness(address(conduitProxy));
    }

    function test_isCancelable() external {
        asset1.mint(buffer1, 100);

        vm.startPrank(operator1);

        conduitHarness.deposit(ilk1, address(asset1), 100);

        conduitHarness.requestFunds(ilk1, address(asset1), 100, "info");

        IArrangerConduit.FundRequest memory fundRequest = conduitHarness.getFundRequest(0);

        assertEq(uint256(fundRequest.status), uint256(IArrangerConduit.StatusEnum.PENDING));

        assertEq(conduitHarness.isCancelable(0), true);

        conduitHarness.__setFundRequestStatus(0, IArrangerConduit.StatusEnum.CANCELLED);

        assertEq(conduitHarness.isCancelable(0), false);

        conduitHarness.__setFundRequestStatus(0, IArrangerConduit.StatusEnum.COMPLETED);

        assertEq(conduitHarness.isCancelable(0), false);
    }

}

contract ArrangerConduit_MaxDepositTests is ConduitTestBase {

    function testFuzz_maxDepositTest(bytes32 ilk, address asset) external {
        assertEq(conduit.maxDeposit(ilk, asset), type(uint256).max);
    }

}

contract ArrangerConduit_MaxWithdrawTest is ConduitAssetTestBase {

    ArrangerConduitHarness conduitHarness;

    function setUp() public override {
        UpgradeableProxy       conduitProxy          = new UpgradeableProxy();
        ArrangerConduitHarness conduitImplementation = new ArrangerConduitHarness();

        conduitProxy.setImplementation(address(conduitImplementation));

        conduitHarness = ArrangerConduitHarness(address(conduitProxy));
    }

    function testFuzz_maxWithdraw(
        address asset1_,
        address asset2_,
        uint256 amount1,
        uint256 amount2,
        uint256 amount3
    )
        external
    {
        vm.assume(asset1_ != asset2_);

        conduitHarness.__setWithdrawableFunds(ilk1, asset1_, amount1);
        conduitHarness.__setWithdrawableFunds(ilk1, asset2_, amount2);

        assertEq(conduitHarness.maxWithdraw(ilk1, asset1_), amount1);
        assertEq(conduitHarness.maxWithdraw(ilk1, asset2_), amount2);

        amount3 = _bound(amount3, 0, type(uint256).max - amount1);

        conduitHarness.__setWithdrawableFunds(ilk1, asset1_, amount1 + amount3);

        assertEq(conduitHarness.maxWithdraw(ilk1, asset1_), amount1 + amount3);
    }

}
