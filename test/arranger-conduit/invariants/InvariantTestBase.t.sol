// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { AllocatorRegistry } from "dss-allocator/AllocatorRegistry.sol";
import { AllocatorRoles }    from "dss-allocator/AllocatorRoles.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { UpgradeableProxy } from "upgradeable-proxy/UpgradeableProxy.sol";

import { ArrangerConduit } from "../../../src/ArrangerConduit.sol";

import { ArrangerHandlerBounded }   from "./handlers/Arranger.sol";
import { OperatorHandlerBounded }   from "./handlers/Operator.sol";
import { TransfererHandlerBounded } from "./handlers/Transferer.sol";

contract InvariantTestBase is Test {

    uint8 ROLE = 0;

    address[] public assets;
    address[] public brokers;

    bytes32[] public ilks;

    ArrangerConduit public conduit;

    ArrangerHandlerBounded   public arrangerHandler;
    OperatorHandlerBounded   public operatorHandler1;
    OperatorHandlerBounded   public operatorHandler2;
    OperatorHandlerBounded   public operatorHandler3;
    TransfererHandlerBounded public transfererHandler;

    AllocatorRegistry public registry              = new AllocatorRegistry();
    AllocatorRoles    public roles                 = new AllocatorRoles();
    ArrangerConduit   public conduitImplementation = new ArrangerConduit();
    UpgradeableProxy  public conduitProxy          = new UpgradeableProxy();

    function setUp() public virtual {
        conduitProxy.setImplementation(address(conduitImplementation));

        conduit = ArrangerConduit(address(conduitProxy));

        // TODO: temporary
        _addAsset();
        _addAsset();
        _addAsset();
        _addBroker(assets[0]);
        _addBroker(assets[1]);
        _addBroker(assets[2]);
        _addIlk();
        _addIlk();
        _addIlk();

        arrangerHandler   = new ArrangerHandlerBounded(address(conduit), address(this));
        operatorHandler1  = new OperatorHandlerBounded(address(conduit), ilks[0], address(this));
        operatorHandler2  = new OperatorHandlerBounded(address(conduit), ilks[1], address(this));
        operatorHandler3  = new OperatorHandlerBounded(address(conduit), ilks[2], address(this));
        transfererHandler = new TransfererHandlerBounded(address(conduit), address(this));

        // TODO: This is temporary
        _setupOperatorRole(ilks[0], address(operatorHandler1));
        _setupOperatorRole(ilks[1], address(operatorHandler2));
        _setupOperatorRole(ilks[2], address(operatorHandler3));

        conduit.file("arranger", address(arrangerHandler));
        conduit.file("registry", address(registry));
        conduit.file("roles",    address(roles));

        // NOTE: Buffer == operator here, should change with broader integration testing
        registry.file(ilks[0], "buffer", address(operatorHandler1));
        registry.file(ilks[1], "buffer", address(operatorHandler2));
        registry.file(ilks[2], "buffer", address(operatorHandler3));

        targetContract(address(arrangerHandler));
        targetContract(address(operatorHandler1));
        targetContract(address(operatorHandler2));
        targetContract(address(operatorHandler3));
    }

    /**********************************************************************************************/
    /*** Core Invariants (should hold in any situation)                                         ***/
    /**********************************************************************************************/

    function invariant_A_B_C_D() external {
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 sumDeposits;
            uint256 sumRequestedFunds;
            uint256 sumWithdrawableFunds;
            uint256 sumWithdrawals;

            for (uint256 j = 0; j < ilks.length; j++) {
                sumDeposits          += conduit.deposits(ilks[j], assets[i]);
                sumRequestedFunds    += conduit.requestedFunds(ilks[j], assets[i]);
                sumWithdrawableFunds += conduit.withdrawableFunds(ilks[j], assets[i]);
                sumWithdrawals       += conduit.withdrawals(ilks[j], assets[i]);
            }

            assertEq(conduit.totalDeposits(assets[i]),          sumDeposits);
            assertEq(conduit.totalRequestedFunds(assets[i]),    sumRequestedFunds);
            assertEq(conduit.totalWithdrawableFunds(assets[i]), sumWithdrawableFunds);
            assertEq(conduit.totalWithdrawals(assets[i]),       sumWithdrawals);
        }
    }

    function invariant_E() external {
        for (uint256 i = 0; i < assets.length; i++) {
            MockERC20 asset = MockERC20(assets[i]);

            assertGe(asset.balanceOf(address(conduit)), conduit.totalWithdrawableFunds(assets[i]));
        }
    }

    function invariant_F() external {
        for (uint256 i = 0; i < assets.length; i++) {
            assertEq(
                conduit.totalWithdrawableFunds(assets[i]),
                arrangerHandler.returnedFunds(assets[i]) - conduit.totalWithdrawals(assets[i])
            );
        }
    }

    /**********************************************************************************************/
    /*** View Functions                                                                         ***/
    /**********************************************************************************************/

    function getAssetsLength() public view returns (uint256) {
        return assets.length;
    }

    function getBrokersLength() public view returns (uint256) {
        return brokers.length;
    }

    function getIlksLength() public view returns (uint256) {
        return ilks.length;
    }

    /**********************************************************************************************/
    /*** Utility Functions                                                                      ***/
    /**********************************************************************************************/

    function _addAsset() internal {
        assets.push(address(new MockERC20("asset", "ASSET", 18)));
    }

    function _addBroker(address asset) internal {
        address broker = makeAddr(string.concat("ilk", vm.toString(ilks.length)));
        brokers.push(broker);
        conduit.setBroker(broker, asset, true);  // TODO: Use handler
    }

    function _addIlk() internal {
        ilks.push(bytes32(bytes(string.concat("ilk", vm.toString(ilks.length)))));
    }

    function _setupOperatorRole(bytes32 ilk_, address operator_) internal {
        // Ensure address(this) can always set for a new ilk
        roles.setIlkAdmin(ilk_, address(this));

        roles.setUserRole(ilk_, operator_, ROLE, true);

        address conduit_ = address(conduit);

        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.deposit.selector,           true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.withdraw.selector,          true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.requestFunds.selector,      true);
        roles.setRoleAction(ilk_, ROLE, conduit_, conduit.cancelFundRequest.selector, true);
    }

}
