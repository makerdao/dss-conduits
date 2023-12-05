// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { AllocatorRegistry } from "dss-allocator/AllocatorRegistry.sol";
import { AllocatorRoles }    from "dss-allocator/AllocatorRoles.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { UpgradeableProxy } from "upgradeable-proxy/UpgradeableProxy.sol";

import { ArrangerConduit } from "../../../src/ArrangerConduit.sol";

import { IArrangerHandlerLike, ITransfererHandlerLike } from "./interfaces/Interfaces.sol";

contract InvariantTestBase is Test {

    uint8 ROLE = 0;

    uint256 NUM_ASSETS = 3;
    uint256 NUM_ILKS   = 3;

    address public arrangerHandler;
    address public operatorHandler1;
    address public operatorHandler2;
    address public operatorHandler3;
    address public transfererHandler;

    address[] public assets;
    address[] public brokers;

    bytes32[] public ilks;

    ArrangerConduit public conduit;

    AllocatorRegistry public registry              = new AllocatorRegistry();
    AllocatorRoles    public roles                 = new AllocatorRoles();
    ArrangerConduit   public conduitImplementation = new ArrangerConduit();
    UpgradeableProxy  public conduitProxy          = new UpgradeableProxy();

    function setUp() public virtual {
        conduitProxy.setImplementation(address(conduitImplementation));

        conduit = ArrangerConduit(address(conduitProxy));

        for (uint256 i; i < NUM_ASSETS; i++) {
            uint8 decimals = uint8(_bound(uint256(keccak256(abi.encodePacked(bytes32(i)))), 4, 18));

            assets.push(address(new MockERC20("asset", "ASSET", decimals)));
            address broker = makeAddr(string.concat("ilk", vm.toString(ilks.length)));
            brokers.push(broker);
            conduit.setBroker(broker, assets[i], true);  // TODO: Use handler
        }

        for (uint256 i; i < NUM_ILKS; i++) {
            ilks.push(bytes32(bytes(string.concat("ilk", vm.toString(i)))));
        }

        conduit.file("registry", address(registry));
        conduit.file("roles",    address(roles));
    }

    // NOTE: Requires handlers to be deployed in child contract
    function configureHandlers() internal {
        _setupOperatorRole(ilks[0], operatorHandler1);
        _setupOperatorRole(ilks[1], operatorHandler2);
        _setupOperatorRole(ilks[2], operatorHandler3);

        conduit.file("arranger", arrangerHandler);

        // NOTE: Buffer == operator here, should change with broader integration testing
        registry.file(ilks[0], "buffer", operatorHandler1);
        registry.file(ilks[1], "buffer", operatorHandler2);
        registry.file(ilks[2], "buffer", operatorHandler3);

        targetContract(arrangerHandler);
        targetContract(operatorHandler1);
        targetContract(operatorHandler2);
        targetContract(operatorHandler3);
        targetContract(transfererHandler);
    }

    /**********************************************************************************************/
    /*** Invariant Assertion Helpers                                                            ***/
    /**********************************************************************************************/

    function assert_invariant_A_B_C_D() internal {
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 sumDeposits;
            uint256 sumRequestedFunds;
            uint256 sumWithdrawableFunds;
            uint256 sumWithdrawals;

            for (uint256 j = 0; j < ilks.length; j++) {
                sumDeposits          += conduit.deposits(assets[i], ilks[j]);
                sumRequestedFunds    += conduit.requestedFunds(assets[i], ilks[j]);
                sumWithdrawableFunds += conduit.withdrawableFunds(assets[i], ilks[j]);
                sumWithdrawals       += conduit.withdrawals(assets[i], ilks[j]);
            }

            assertEq(conduit.totalDeposits(assets[i]),          sumDeposits);
            assertEq(conduit.totalRequestedFunds(assets[i]),    sumRequestedFunds);
            assertEq(conduit.totalWithdrawableFunds(assets[i]), sumWithdrawableFunds);
            assertEq(conduit.totalWithdrawals(assets[i]),       sumWithdrawals);
        }
    }

    function assert_invariant_E() internal {
        for (uint256 i = 0; i < assets.length; i++) {
            MockERC20 asset = MockERC20(assets[i]);

            assertGe(asset.balanceOf(address(conduit)), conduit.totalWithdrawableFunds(assets[i]));
        }
    }

    function assert_invariant_F() internal {
        IArrangerHandlerLike arrangerHandler_ = IArrangerHandlerLike(arrangerHandler);
        for (uint256 i = 0; i < assets.length; i++) {
            assertEq(
                conduit.totalWithdrawableFunds(assets[i]),
                arrangerHandler_.returnedFunds(assets[i]) - conduit.totalWithdrawals(assets[i])
            );
        }
    }

    // NOTE: Interesting finding, if there are transfers and returnFunds calls before
    //       the first deposit, there can be a situation where returnedFunds > totalDeposits
    //       very early in a sequence.
    // NOTE: Had to add a transferredFunds ghost variable because drawnFunds can actually be higher
    //       than totalDeposits and returnedFunds if transfer + draw happens early enough.
    function assert_invariant_G() internal {
        IArrangerHandlerLike   arrangerHandler_   = IArrangerHandlerLike(arrangerHandler);
        ITransfererHandlerLike transfererHandler_ = ITransfererHandlerLike(transfererHandler);

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 netBalance =
                conduit.totalDeposits(assets[i])
                + arrangerHandler_.returnedFunds(assets[i])
                // + transfererHandler_.transferredFunds(assets[i])
                - arrangerHandler_.drawnFunds(assets[i])
                - conduit.totalWithdrawals(assets[i]);

            assertEq(MockERC20(assets[i]).balanceOf(address(conduit)), netBalance);
        }
    }

    function assert_invariant_H() internal {
        for (uint256 i = 0; i < assets.length; i++) {
            assertEq(
                MockERC20(assets[i]).balanceOf(address(conduit)),
                conduit.availableFunds(assets[i]) + conduit.totalWithdrawableFunds(assets[i])
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
