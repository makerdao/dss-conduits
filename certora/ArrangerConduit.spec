// ArrangerConduit.spec

using AllocatorRoles as roles;
using AllocatorRegistry as registry;
using MockERC20 as gem;
using Auxiliar as aux;

methods {
    function wards(address) external returns (uint256) envfree;
    function arranger() external returns (address) envfree;
    function registry() external returns (address) envfree;
    function roles() external returns (address) envfree;
    function totalDeposits(address) external returns (uint256) envfree;
    function totalRequestedFunds(address) external returns (uint256) envfree;
    function totalWithdrawableFunds(address) external returns (uint256) envfree;
    function totalWithdrawals(address) external returns (uint256) envfree;
    function isBroker(address, address) external returns (bool) envfree;
    function deposits(address, bytes32) external returns (uint256) envfree;
    function requestedFunds(address, bytes32) external returns (uint256) envfree;
    function withdrawableFunds(address, bytes32) external returns (uint256) envfree;
    function withdrawals(address, bytes32) external returns (uint256) envfree;
    function getFundRequestsLength() external returns (uint256) envfree;
    function getFundRequest(uint256) external returns (IArrangerConduit.FundRequest) envfree;
 
    // needed for resolving calls in the spec
    function gem.balanceOf(address) external returns (uint256) envfree;
    function gem.allowance(address, address) external returns (uint256) envfree;  
    function registry.buffers(bytes32) external returns (address) envfree;
    function roles.canCall(bytes32, address, address, bytes4) external returns (bool) envfree;
    function aux.hashString(string) external returns (bytes32) envfree;

    // needed for resolving calls in the contract
    function _.balanceOf(address) external => DISPATCHER(true) UNRESOLVED;
    function _.transfer(address, uint256) external => DISPATCHER(true) UNRESOLVED;
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true) UNRESOLVED;    
}

definition min(mathint x, mathint y) returns mathint = x < y ? x : y;

// -----------------------------------------------------------------------------
/**
 * Verifying the string encoding
 * =============================
 * Whenever Solidity reads a string from storage, it verifies that it is properly
 * encoded, otherwise it reverts. Note that this occurs also when writing a string
 * to the storage.
 * The encoding of a string is as follows:
 * 1. If the first 32-bytes are even (the very last bit is 0) then:
 *    - The length of the string is less than 32 bytes
 *    - The first 31 bytes contain the string
 *    - The last byte is twice the length of the string
 * 2. If the first 32-bytes are odd (the very last bit is 1) then:
 *    - The length of the string is 32 bytes or more
 *    - The first 32-bytes are twice the length of the string plus 1!
 *    - The string itself is in the following bytes
 *
 * So, an encoding is illegal if either:
 * - the first 32-bytes are even and the value of the last byte >= 64, or
 * - the first 32-bytes are odd but as an integer they are less than 65.
 *
 * One solution is to require that there are no illegal strings in storage, using
 * a hook.
 */


/** This hook is called whenever the `info` field of a `FundRequest` in `fundRequests`
 *  is read. To be precise, whenever the first 32 bytes of `info` are read.
 *  To create the hook we needed to find the offset of `info` in the `FundRequest`
 *  struct, here is the calculation:
    struct FundRequest {
        StatusEnum status; // 1 byte
        address    asset;  // 20 bytes
        bytes32    ilk;  // 32 bytes
        uint256    amountRequested; // 32 bytes
        uint256    amountFilled;  // 32 bytes
        string     info;
    }
  * The storage is 32-bytes aligned.
  * Since the `status` and `asset` fields are packed together the offset is 32 * 4 = 128.
*/
hook Sload bytes32 str fundRequests[INDEX uint256 index].(offset 128) STORAGE {
    uint256 read;
    require to_bytes32(read) == str;
    mathint strLen = (read % 256) / 2;  // The string length for short strings only
    bool isOdd = read % 2 == 1;
    require (read > 64 && isOdd) || (strLen <= 31 && !isOdd);
}

// -----------------------------------------------------------------------------

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) {
    env e;

    address anyAddr;
    address anyAsset;
    bytes32 anyIlk;
    uint256 anyIndex;

    mathint wardsBefore = wards(anyAddr);

    IArrangerConduit.FundRequest requestBefore = getFundRequest(anyIndex);
    bytes32 infoHashBefore = aux.hashString(requestBefore.info);

    address arrangerBefore = arranger();
    address registryBefore = registry();
    address rolesBefore = roles();
    mathint totalDepositsBefore = totalDeposits(anyAsset);
    mathint totalRequestedFundsBefore = totalRequestedFunds(anyAsset);
    mathint totalWithdrawableFundsBefore = totalWithdrawableFunds(anyAsset);
    mathint totalWithdrawalsBefore = totalWithdrawals(anyAsset);
    bool isBrokerBefore = isBroker(anyAddr, anyAsset);   
    mathint depositsBefore = deposits(anyAddr, anyIlk);
    mathint requestedFundsBefore = requestedFunds(anyAddr, anyIlk);
    mathint withdrawableFundsBefore = withdrawableFunds(anyAddr, anyIlk);
    mathint withdrawalsBefore = withdrawals(anyAddr, anyIlk);

    calldataarg args;
    f(e, args);

    mathint wardsAfter = wards(anyAddr);

    IArrangerConduit.FundRequest requestAfter = getFundRequest(anyIndex);
    bytes32 infoHashAfter = aux.hashString(requestAfter.info);

    address arrangerAfter= arranger();
    address registryAfter= registry();
    address rolesAfter = roles();
    mathint totalDepositsAfter = totalDeposits(anyAsset);
    mathint totalRequestedFundsAfter = totalRequestedFunds(anyAsset);
    mathint totalWithdrawableFundsAfter = totalWithdrawableFunds(anyAsset);
    mathint totalWithdrawalsAfter = totalWithdrawals(anyAsset);
    bool isBrokerAfter = isBroker(anyAddr, anyAsset);
    mathint depositsAfter = deposits(anyAddr, anyIlk);
    mathint requestedFundsAfter = requestedFunds(anyAddr, anyIlk);
    mathint withdrawableFundsAfter = withdrawableFunds(anyAddr, anyIlk);
    mathint withdrawalsAfter = withdrawals(anyAddr, anyIlk);

    assert wardsAfter == wardsBefore, "wards changed unexpectedly through the proxied contract";

    assert requestAfter.status != requestBefore.status
        || requestAfter.asset != requestBefore.asset
        || requestAfter.ilk != requestBefore.ilk
        || requestAfter.amountRequested != requestBefore.amountRequested
        || requestAfter.amountFilled != requestBefore.amountFilled
        || infoHashAfter != infoHashBefore
        => f.selector == sig:requestFunds(bytes32, address, uint256, string).selector
        || f.selector == sig:cancelFundRequest(uint256).selector
        || f.selector == sig:returnFunds(uint256, uint256).selector
        , "fundRequests list content changed in an unexpected function";

    assert arrangerAfter != arrangerBefore => f.selector == sig:file(bytes32, address).selector, "arranger changed in an unexpected function";
    assert registryAfter != registryBefore => f.selector == sig:file(bytes32, address).selector, "registry changed in an unexpected function";
    assert rolesAfter != rolesBefore => f.selector == sig:file(bytes32, address).selector, "roles changed in an unexpected function";
    assert totalDepositsAfter != totalDepositsBefore => f.selector == sig:deposit(bytes32, address, uint256).selector, "totalDeposits changed in an unexpected function";

    assert totalRequestedFundsAfter != totalRequestedFundsBefore =>
        f.selector == sig:requestFunds(bytes32, address, uint256, string).selector
        || f.selector == sig:cancelFundRequest(uint256).selector
        || f.selector == sig:returnFunds(uint256, uint256).selector
        , "totalRequestedFunds changed in an unexpected function";

    assert totalWithdrawableFundsAfter != totalWithdrawableFundsBefore =>
        f.selector == sig:withdraw(bytes32, address, uint256).selector
        || f.selector == sig:returnFunds(uint256, uint256).selector
        , "totalWithdrawableFunds changed in an unexpected function";

    assert totalWithdrawalsAfter != totalWithdrawalsBefore => f.selector == sig:withdraw(bytes32, address, uint256).selector, "totalWithdrawals changed in an unexpected function";
    assert isBrokerAfter != isBrokerBefore => f.selector == sig:setBroker(address, address, bool).selector, "isBroker changed in an unexpected function";
    assert depositsAfter != depositsBefore => f.selector == sig:deposit(bytes32, address, uint256).selector, "deposits changed in an unexpected function";

    assert requestedFundsAfter != requestedFundsBefore =>
        f.selector == sig:requestFunds(bytes32, address, uint256, string).selector
        || f.selector == sig:cancelFundRequest(uint256).selector
        || f.selector == sig:returnFunds(uint256, uint256).selector
        , "requestedFunds changed in an unexpected function";

    assert withdrawableFundsAfter != withdrawableFundsBefore =>
        f.selector == sig:withdraw(bytes32, address, uint256).selector
        || f.selector == sig:returnFunds(uint256, uint256).selector
        , "withdrawableFunds changed in an unexpected function";

    assert withdrawalsAfter != withdrawalsBefore => f.selector == sig:withdraw(bytes32, address, uint256).selector, "withdrawals changed in an unexpected function";
}

// Verify correct storage changes for non reverting file
rule file_address(bytes32 what, address data) {
    env e;

    address arrangerBefore = arranger();
    address registryBefore = registry();
    address rolesBefore = roles();

    file(e, what, data);

    address arrangerAfter = arranger();
    address registryAfter = registry();
    address rolesAfter = roles();

    assert what == to_bytes32(0x617272616e676572000000000000000000000000000000000000000000000000)
           => arrangerAfter == data, "file did not set arranger";
    assert what != to_bytes32(0x617272616e676572000000000000000000000000000000000000000000000000)
           => arrangerAfter == arrangerBefore, "file did not keep unchanged arranger";

    assert what == to_bytes32(0x7265676973747279000000000000000000000000000000000000000000000000)
           => registryAfter == data, "file did not set registry";
    assert what != to_bytes32(0x7265676973747279000000000000000000000000000000000000000000000000)
           => registryAfter == registryBefore, "file did not keep unchanged registry";

    assert what == to_bytes32(0x726f6c6573000000000000000000000000000000000000000000000000000000)
           => rolesAfter == data, "file did not set roles";
    assert what != to_bytes32(0x726f6c6573000000000000000000000000000000000000000000000000000000)
           => rolesAfter == rolesBefore, "file did not keep unchanged roles";
}

// Verify revert rules on file
rule file_address_revert(bytes32 what, address data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    file@withrevert(e, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = what != to_bytes32(0x617272616e676572000000000000000000000000000000000000000000000000)
                && what != to_bytes32(0x7265676973747279000000000000000000000000000000000000000000000000)
                && what != to_bytes32(0x726f6c6573000000000000000000000000000000000000000000000000000000);

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting setBroker
// Verify correct storage changes for non reverting setBroker
rule setBroker(address usr, address asset, bool valid) {
    env e;

    address otherUsr;
    address otherAsset;
    require otherUsr != usr || otherAsset != asset;
    
    bool isBrokerOtherBefore = isBroker(otherUsr, otherAsset);
    
    setBroker(e, usr, asset, valid);

    bool isBrokerUsrAfter = isBroker(usr, asset);
    bool isBrokerOtherAfter = isBroker(otherUsr, otherAsset);

    assert isBrokerUsrAfter == valid, "setBroker did not set brokers[usr][asset] to valid";
    assert isBrokerOtherAfter == isBrokerOtherBefore, "setBroker did not keep unchanged the rest of brokers[x][y]";
}

// Verify revert rules on setBroker
rule setBroker_revert(address usr, address asset, bool valid) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    setBroker@withrevert(e, usr, asset, valid);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert lastReverted => revert1 || revert2, "Revert rules are not covering all the cases";
}

// Verify correct storage changes for non reverting deposit
rule deposit(bytes32 ilk, address asset, uint256 amount) {
    env e;

    require asset == gem;

    address buffer = registry.buffers(ilk);
    require buffer != currentContract;

    mathint balanceOfBufferBefore = gem.balanceOf(buffer);
    mathint balanceOfConduitBefore = gem.balanceOf(currentContract);
    mathint depositsBefore = deposits(asset, ilk);
    mathint totalDepositsBefore = totalDeposits(asset);

    bytes32 otherIlk;
    address otherAsset;
    require otherIlk != ilk || otherAsset != asset;
    mathint depositsOtherBefore = deposits(otherAsset, otherIlk);

    address otherAsset2;
    require otherAsset2 != asset;
    mathint totalDepositsOtherBefore = totalDeposits(otherAsset2); 

    require balanceOfBufferBefore + balanceOfConduitBefore <= max_uint256;

    deposit(e, ilk, asset, amount);

    mathint balanceOfBufferAfter = gem.balanceOf(buffer);
    mathint balanceOfConduitAfter = gem.balanceOf(currentContract);
    mathint depositsAfter = deposits(asset, ilk);
    mathint totalDepositsAfter = totalDeposits(asset);

    mathint depositsOtherAfter= deposits(otherAsset, otherIlk);
    mathint totalDepositsOtherAfter = totalDeposits(otherAsset2); 

    assert balanceOfBufferAfter == balanceOfBufferBefore - amount, "deposit did not decrease balance of buffer by amount";
    assert balanceOfConduitAfter == balanceOfConduitBefore + amount, "deposit did not increase balance of conduit by amount";
    assert depositsAfter == depositsBefore + amount, "deposit did not increase deposits by amount";
    assert totalDepositsAfter == totalDepositsBefore + amount, "deposit did not increase totalDeposits by amount";

    assert depositsOtherAfter == depositsOtherBefore, "other deposits changed unexpectedly";
    assert totalDepositsOtherAfter == totalDepositsOtherBefore, "other total deposits changed unexpectedly";
}

// Verify revert rules on deposit
rule deposit_revert(bytes32 ilk, address asset, uint256 amount) {
    env e;

    require asset == gem;

    address buffer = registry.buffers(ilk);
    require buffer != currentContract;

    bool canCall = roles.canCall(ilk, e.msg.sender, currentContract, to_bytes4(0xd954863c)); // deposit(bytes32,address,uint256)
    mathint balanceOfBuffer = gem.balanceOf(buffer);
    mathint allowanceBuffer = gem.allowance(buffer, currentContract);
    mathint deposits = deposits(asset, ilk);
    mathint totalDeposits = totalDeposits(asset);

    deposit@withrevert(e, ilk, asset, amount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !canCall;
    bool revert3 = deposits + amount > max_uint256;
    bool revert4 = totalDeposits + amount > max_uint256;
    bool revert5 = buffer == 0;
    bool revert6 = balanceOfBuffer < to_mathint(amount);
    bool revert7 = allowanceBuffer < to_mathint(amount);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7 , "Revert rules failed";

}

// Verify correct storage changes for non reverting withdraw
rule withdraw(bytes32 ilk, address asset, uint256 maxAmount) {
    env e;

    require asset == gem;

    address buffer = registry.buffers(ilk);
    require buffer != currentContract;

    mathint balanceOfBufferBefore = gem.balanceOf(buffer);
    mathint balanceOfConduitBefore = gem.balanceOf(currentContract);
    mathint withdrawableFundsBefore = withdrawableFunds(asset, ilk);
    mathint totalWithdrawableFundsBefore = totalWithdrawableFunds(asset);
    mathint withdrawalsBefore = withdrawals(asset, ilk);
    mathint totalWithdrawalsBefore = totalWithdrawals(asset);

    bytes32 otherIlk;
    address otherAsset;
    require otherIlk != ilk || otherAsset != asset;
    mathint withdrawableFundsOtherBefore = withdrawableFunds(otherAsset, otherIlk);

    address otherAsset2;
    require otherAsset2 != asset;
    mathint totalWithdrawableFundsOtherBefore = totalWithdrawableFunds(otherAsset2);

    mathint withdrawalsOtherBefore = withdrawals(otherAsset, otherIlk);
    mathint totalWithdrawalsOtherBefore = totalWithdrawals(otherAsset2);

    require balanceOfBufferBefore + balanceOfConduitBefore <= max_uint256;

    mathint amount = min(maxAmount, withdrawableFundsBefore); 
    withdraw(e, ilk, asset, maxAmount);

    mathint balanceOfBufferAfter = gem.balanceOf(buffer);
    mathint balanceOfConduitAfter = gem.balanceOf(currentContract);
    mathint withdrawableFundsAfter = withdrawableFunds(asset, ilk);
    mathint totalWithdrawableFundsAfter = totalWithdrawableFunds(asset);
    mathint withdrawalsAfter = withdrawals(asset, ilk);
    mathint totalWithdrawalsAfter = totalWithdrawals(asset);

    mathint withdrawableFundsOtherAfter = withdrawableFunds(otherAsset, otherIlk);
    mathint totalWithdrawableFundsOtherAfter = totalWithdrawableFunds(otherAsset2);
    mathint withdrawalsOtherAfter = withdrawals(otherAsset, otherIlk);
    mathint totalWithdrawalsOtherAfter = totalWithdrawals(otherAsset2);

    assert balanceOfBufferAfter == balanceOfBufferBefore + amount, "balance of buffer did not increase by amount";
    assert balanceOfConduitAfter == balanceOfConduitBefore - amount, "balance of conduit did not decrease by amount";
    assert withdrawableFundsAfter == withdrawableFundsBefore - amount, "withdrawableFunds did not decrease by amount";
    assert totalWithdrawableFundsAfter == totalWithdrawableFundsBefore - amount, "totalWithdrawableFunds did not decrease by amount";
    assert withdrawalsAfter == withdrawalsBefore + amount, "withdrawals did not increase by amount";
    assert totalWithdrawalsAfter == totalWithdrawalsBefore + amount, "totalWithdrawals did not increase by amount";

    assert withdrawableFundsOtherAfter == withdrawableFundsOtherBefore, "other withdrawable funds changed unexpectedly";
    assert totalWithdrawableFundsOtherAfter == totalWithdrawableFundsOtherBefore, "other total withdrawable funds changed unexpectedly";
    assert withdrawalsOtherAfter == withdrawalsOtherBefore, "other withdrawals changed unexpectedly";
    assert totalWithdrawalsOtherAfter == totalWithdrawalsOtherBefore, "other total withdrawals changed unexpectedly";
}


// Verify revert rules on withdraw
rule withdraw_revert(bytes32 ilk, address asset, uint256 maxAmount) {
    env e;

    require asset == gem;

    address buffer = registry.buffers(ilk);
    require buffer != currentContract;

    bool canCall = roles.canCall(ilk, e.msg.sender, currentContract, to_bytes4(0xa6fb97d1)); // withdraw(bytes32,address,uint256)
    mathint balanceOfConduit = gem.balanceOf(currentContract);
    mathint withdrawals = withdrawals(asset, ilk);
    mathint totalWithdrawals = totalWithdrawals(asset);
    mathint withdrawableFunds = withdrawableFunds(asset, ilk);
    mathint totalWithdrawableFunds = totalWithdrawableFunds(asset);

    mathint amount = min(maxAmount, withdrawableFunds);
    withdraw@withrevert(e, ilk, asset, maxAmount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !canCall;
    bool revert3 = totalWithdrawableFunds < amount;
    bool revert4 = withdrawals + amount > max_uint256;
    bool revert5 = totalWithdrawals + amount > max_uint256;
    bool revert6 = buffer == 0;
    bool revert7 = balanceOfConduit < amount;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7, "Revert rules failed";
}

// Verify correct storage changes for non reverting requestFunds
rule requestFunds(bytes32 ilk, address asset, uint256 amount, string info) {
    env e;

    require asset == gem;
    uint256 anyIndex;

    mathint requestedFundsBefore = requestedFunds(asset, ilk);
    mathint totalRequestedFundsBefore = totalRequestedFunds(asset);
    mathint numRequestsBefore = getFundRequestsLength();

    bytes32 otherIlk;
    address otherAsset;
    require otherIlk != ilk || otherAsset != asset;
    mathint requestedFundsOtherBefore = requestedFunds(otherAsset, otherIlk);

    address otherAsset2;
    require otherAsset2 != asset;
    mathint totalRequestedFundsOtherBefore = totalRequestedFunds(otherAsset2); 

    IArrangerConduit.FundRequest requestBefore = getFundRequest(anyIndex);
    bytes32 infoHashBefore = aux.hashString(requestBefore.info);

    requestFunds(e, ilk, asset, amount, info);

    mathint requestedFundsAfter = requestedFunds(asset, ilk);
    mathint totalRequestedFundsAfter= totalRequestedFunds(asset);
    mathint numRequestsAfter = getFundRequestsLength();

    mathint requestedFundsOtherAfter = requestedFunds(otherAsset, otherIlk);
    mathint totalRequestedFundsOtherAfter = totalRequestedFunds(otherAsset2); 

    IArrangerConduit.FundRequest requestAfter = getFundRequest(anyIndex);
    bytes32 infoHashAfter = aux.hashString(requestAfter.info);

    assert requestedFundsAfter == requestedFundsBefore + amount, "requestedFunds did not increase by amount";
    assert totalRequestedFundsAfter == totalRequestedFundsBefore + amount, "totalRequestedFunds did not increase by amount";
    assert numRequestsAfter == numRequestsBefore + 1, "num request did not increase by 1";

    assert numRequestsBefore == to_mathint(anyIndex) =>
        requestAfter.status == IArrangerConduit.StatusEnum.PENDING
        && requestAfter.asset == asset
        && requestAfter.ilk == ilk
        && requestAfter.amountRequested == amount
        && requestAfter.amountFilled == 0
        && infoHashAfter == aux.hashString(info),
        "the new request params are not as expected";

    assert numRequestsBefore != to_mathint(anyIndex) =>
        requestAfter.status == requestBefore.status
        && requestAfter.asset == requestBefore.asset
        && requestAfter.ilk == requestBefore.ilk
        && requestAfter.amountRequested == requestBefore.amountRequested
        && requestAfter.amountFilled == requestBefore.amountFilled
        && infoHashAfter == infoHashBefore,
        "other request params are not as before";

    assert requestedFundsOtherAfter == requestedFundsOtherBefore, "other requested funds changed unexpectedly";
    assert totalRequestedFundsOtherAfter == totalRequestedFundsOtherBefore, "other total requested funds changed unexpectedly";
}

// Verify revert rules on requestFunds
rule requestFunds_revert(bytes32 ilk, address asset, uint256 amount, string info) {
    env e;

    require asset == gem;

    bool canCall = roles.canCall(ilk, e.msg.sender, currentContract, to_bytes4(0xd2543ccb)); // requestFunds(bytes32,address,uint256,string)
    mathint requestedFunds = requestedFunds(asset, ilk);
    mathint totalRequestedFunds = totalRequestedFunds(asset);
    mathint numRequests = getFundRequestsLength();

    requestFunds@withrevert(e, ilk, asset, amount, info);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !canCall;
    bool revert3 = requestedFunds + amount > max_uint256;
    bool revert4 = totalRequestedFunds + amount > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
} 

// Verify correct storage changes for non reverting requestFunds
rule cancelFundRequest(uint256 fundRequestId) {
    env e;

    uint256 anyIndex;

    IArrangerConduit.FundRequest requestBefore = getFundRequest(anyIndex);
    bytes32 infoHashBefore = aux.hashString(requestBefore.info);

    mathint requestedFundsBefore = requestedFunds(requestBefore.asset, requestBefore.ilk);
    mathint totalRequestedFundsBefore = totalRequestedFunds(requestBefore.asset);
    mathint numRequestsBefore = getFundRequestsLength();

    bytes32 otherIlk;
    address otherAsset;
    require otherIlk != requestBefore.ilk || otherAsset != requestBefore.asset;
    mathint requestedFundsOtherBefore = requestedFunds(otherAsset, otherIlk);

    address otherAsset2;
    require otherAsset2 != requestBefore.asset;
    mathint totalRequestedFundsOtherBefore = totalRequestedFunds(otherAsset2); 

    cancelFundRequest(e, fundRequestId);

    mathint requestedFundsAfter = requestedFunds(requestBefore.asset, requestBefore.ilk);
    mathint totalRequestedFundsAfter= totalRequestedFunds(requestBefore.asset);
    mathint numRequestsAfter = getFundRequestsLength();

    mathint requestedFundsOtherAfter = requestedFunds(otherAsset, otherIlk);
    mathint totalRequestedFundsOtherAfter = totalRequestedFunds(otherAsset2); 

    IArrangerConduit.FundRequest requestAfter = getFundRequest(anyIndex);
    bytes32 infoHashAfter = aux.hashString(requestAfter.info);

    assert numRequestsAfter == numRequestsBefore, "num requests changed";
    assert anyIndex == fundRequestId => requestedFundsAfter == requestedFundsBefore - requestBefore.amountRequested, "cancelFundRequest did not decrease by amount";
    assert anyIndex == fundRequestId => totalRequestedFundsAfter == totalRequestedFundsBefore - requestBefore.amountRequested, "totalRequestedFunds did not decrease by amount";
    assert anyIndex == fundRequestId => requestAfter.status == IArrangerConduit.StatusEnum.CANCELLED, "cancelFundRequest did not change status to CANCELLED";
    assert anyIndex != fundRequestId => requestAfter.status == requestBefore.status, "cancelFundRequest on another index changed status";
    assert requestAfter.asset == requestBefore.asset
        && requestAfter.ilk == requestBefore.ilk
        && requestAfter.amountRequested == requestBefore.amountRequested
        && requestAfter.amountFilled == requestBefore.amountFilled
        && infoHashAfter == infoHashBefore,
        "other request params not as before";

    assert anyIndex == fundRequestId => requestedFundsOtherAfter == requestedFundsOtherBefore, "other requested funds changed unexpectedly";
    assert anyIndex == fundRequestId => totalRequestedFundsOtherAfter == totalRequestedFundsOtherBefore, "other total requested funds changed unexpectedly";
}

// TODO: figure out why this is still not working
// Verify revert rules on cancelFundRequest
rule cancelFundRequest_revert(uint256 fundRequestId) {
    env e;

    IArrangerConduit.FundRequest request = getFundRequest(fundRequestId);

    require request.asset == gem;

    bool canCall = roles.canCall(request.ilk, e.msg.sender, currentContract, to_bytes4(0x933d9476)); // cancelFundRequest(uint256)
    mathint requestedFunds = requestedFunds(request.asset, request.ilk);
    mathint totalRequestedFunds = totalRequestedFunds(request.asset);
    
    cancelFundRequest@withrevert(e, fundRequestId);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !canCall;
    bool revert3 = request.status != IArrangerConduit.StatusEnum.PENDING;
    bool revert4 = requestedFunds < to_mathint(request.amountRequested);
    bool revert5 = totalRequestedFunds < to_mathint(request.amountRequested);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5, "Revert rules failed";

}

// Verify correct storage changes for non reverting requestFunds
rule drawFunds(address asset, address destination, uint256 amount) {
    env e;

    require asset == gem;
    require currentContract != destination;
    
    mathint balanceOfConduitBefore = gem.balanceOf(currentContract);
    mathint balanceOfDestinationBefore = gem.balanceOf(destination);

    require balanceOfConduitBefore + balanceOfDestinationBefore <= max_uint256;

    drawFunds(e, asset, destination, amount);

    mathint balanceOfConduitAfter = gem.balanceOf(currentContract);
    mathint balanceOfDestinationAfter = gem.balanceOf(destination);

    assert balanceOfConduitAfter == balanceOfConduitBefore - amount, "balance of conduit did not decrease by amount";
    assert balanceOfDestinationAfter == balanceOfDestinationBefore + amount, "balance of destination did not increase by amount";
}

// Verify revert rules on drawFunds
rule drawFunds_revert(address asset, address destination, uint256 amount) {
    env e;

    require asset == gem;
    require currentContract != destination;
    
    mathint balanceOfConduit = gem.balanceOf(currentContract);
    mathint totalWithdrawableFunds = totalWithdrawableFunds(asset);
    
    bool isBroker = isBroker(destination, asset);
    address arranger = arranger();

    drawFunds@withrevert(e, asset, destination, amount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = arranger != e.msg.sender;
    bool revert3 = totalWithdrawableFunds > balanceOfConduit;
    bool revert4 = to_mathint(amount) > balanceOfConduit - totalWithdrawableFunds;
    bool revert5 = !isBroker;
    bool revert6 = balanceOfConduit < to_mathint(amount);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6
                            , "Revert rules failed";

}

// Verify correct storage changes for non reverting returnFunds
rule returnFunds(uint256 fundRequestId, uint256 returnAmount) {
    env e;

    uint256 anyIndex;

    IArrangerConduit.FundRequest requestBefore = getFundRequest(anyIndex);
    bytes32 infoHashBefore = aux.hashString(requestBefore.info);

    mathint requestedFundsBefore = requestedFunds(requestBefore.asset, requestBefore.ilk);
    mathint totalRequestedFundsBefore = totalRequestedFunds(requestBefore.asset);
    mathint withdrawableFundsBefore = withdrawableFunds(requestBefore.asset, requestBefore.ilk);
    mathint totalWithdrawableFundsBefore = totalWithdrawableFunds(requestBefore.asset);
    mathint numRequestsBefore = getFundRequestsLength();

    bytes32 otherIlk;
    address otherAsset;
    require otherIlk != requestBefore.ilk || otherAsset != requestBefore.asset;
    mathint requestedFundsOtherBefore = requestedFunds(otherAsset, otherIlk);

    address otherAsset2;
    require otherAsset2 != requestBefore.asset;
    mathint totalRequestedFundsOtherBefore = totalRequestedFunds(otherAsset2);

    mathint withdrawableFundsOtherBefore = withdrawableFunds(otherAsset, otherIlk);
    mathint totalWithdrawableFundsOtherBefore = totalWithdrawableFunds(otherAsset2);

    returnFunds(e, fundRequestId, returnAmount);

    mathint requestedFundsAfter = requestedFunds(requestBefore.asset, requestBefore.ilk);
    mathint totalRequestedFundsAfter= totalRequestedFunds(requestBefore.asset);
    mathint numRequestsAfter = getFundRequestsLength();

    IArrangerConduit.FundRequest requestAfter = getFundRequest(anyIndex);
    bytes32 infoHashAfter = aux.hashString(requestAfter.info);

    mathint withdrawableFundsAfter = withdrawableFunds(requestBefore.asset, requestBefore.ilk);
    mathint totalWithdrawableFundsAfter = totalWithdrawableFunds(requestBefore.asset);

    mathint requestedFundsOtherAfter = requestedFunds(otherAsset, otherIlk);
    mathint totalRequestedFundsOtherAfter= totalRequestedFunds(otherAsset2);
    mathint withdrawableFundsOtherAfter = withdrawableFunds(otherAsset, otherIlk);
    mathint totalWithdrawableFundsOtherAfter = totalWithdrawableFunds(otherAsset2);

    assert numRequestsAfter == numRequestsBefore, "num requests changed";
    assert anyIndex == fundRequestId => requestedFundsAfter == requestedFundsBefore - requestBefore.amountRequested, "returnFunds did not decrease by amount";
    assert anyIndex == fundRequestId => totalRequestedFundsAfter == totalRequestedFundsBefore - requestBefore.amountRequested, "totalRequestedFunds did not decrease by amount";
    assert anyIndex == fundRequestId => withdrawableFundsAfter == withdrawableFundsBefore + returnAmount, "withdrawableFunds did not increase by returnAmount";
    assert anyIndex == fundRequestId => totalWithdrawableFundsAfter == totalWithdrawableFundsBefore + returnAmount, "totalWithdrawableFunds did not increase by returnAmount";
    assert anyIndex == fundRequestId => requestAfter.status == IArrangerConduit.StatusEnum.COMPLETED, "returnFunds did not change status to COMPLETED";
    assert anyIndex != fundRequestId => requestAfter.status == requestBefore.status, "returnFunds on another index changed status";
    assert anyIndex == fundRequestId => requestAfter.amountFilled == returnAmount, "returnFunds did not change amountFilled to returnAmount";
    assert anyIndex != fundRequestId => requestAfter.amountFilled == requestBefore.amountFilled, "returnFunds on another index changed amountFilled";
    assert requestAfter.asset == requestBefore.asset
        && requestAfter.ilk == requestBefore.ilk
        && requestAfter.amountRequested == requestBefore.amountRequested
        && infoHashAfter == infoHashBefore,
        "other request params not as before";

    assert anyIndex == fundRequestId => requestedFundsOtherAfter == requestedFundsOtherBefore, "other requested funds changed unexpectedly";
    assert anyIndex == fundRequestId => totalRequestedFundsOtherAfter == totalRequestedFundsOtherBefore, "other total requested funds changed unexpectedly";
    assert anyIndex == fundRequestId => withdrawableFundsOtherAfter == withdrawableFundsOtherBefore, "other withdrawable funds changed unexpectedly";
    assert anyIndex == fundRequestId => totalWithdrawableFundsOtherAfter == totalWithdrawableFundsOtherBefore, "other total withdrawable funds changed unexpectedly";
}

// Verify revert rules on returnFunds
rule returnFunds_revert(uint256 fundRequestId, uint256 returnAmount) {
    env e;

    address arranger = arranger();
   
    IArrangerConduit.FundRequest request = getFundRequest(fundRequestId);

    mathint balanceOfConduit = gem.balanceOf(currentContract);
    mathint withdrawableFunds = withdrawableFunds(request.asset, request.ilk);
    mathint totalWithdrawableFunds = totalWithdrawableFunds(request.asset);
    mathint requestedFunds = requestedFunds(request.asset, request.ilk);
    mathint totalRequestedFunds = totalRequestedFunds(request.asset);

    returnFunds@withrevert(e, fundRequestId, returnAmount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = arranger != e.msg.sender;
    bool revert3 = request.status != IArrangerConduit.StatusEnum.PENDING;
    bool revert4 = balanceOfConduit - totalWithdrawableFunds < to_mathint(returnAmount);
    bool revert5 = totalWithdrawableFunds > balanceOfConduit;
    bool revert6 = withdrawableFunds + to_mathint(returnAmount) > max_uint256;
    bool revert7 = totalWithdrawableFunds + to_mathint(returnAmount) > max_uint256;
    bool revert8 = requestedFunds < to_mathint(request.amountRequested);
    bool revert9 = totalRequestedFunds < to_mathint(request.amountRequested);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7 || revert8 || revert9,
                            "Revert rules failed";
}

// Verify variables change together
rule changeTogether(method f) {
    env e;

    bytes32 anyIlk;
    address anyAsset;

    mathint depositsBefore = deposits(anyAsset, anyIlk);
    mathint requestedFundsBefore = requestedFunds(anyAsset, anyIlk);
    mathint withdrawableFundsBefore = withdrawableFunds(anyAsset, anyIlk);
    mathint withdrawalsBefore = withdrawals(anyAsset, anyIlk);
    mathint totalDepositsBefore = totalDeposits(anyAsset);
    mathint totalRequestedFundsBefore = totalRequestedFunds(anyAsset);
    mathint totalWithdrawableFundsBefore = totalWithdrawableFunds(anyAsset);
    mathint totalWithdrawalsBefore = totalWithdrawals(anyAsset);

    calldataarg args;
    f(e, args);

    mathint depositsDiff = deposits(anyAsset, anyIlk) - depositsBefore;
    mathint requestedFundsDiff = requestedFunds(anyAsset, anyIlk) - requestedFundsBefore;
    mathint withdrawableFundsDiff = withdrawableFunds(anyAsset, anyIlk) - withdrawableFundsBefore;
    mathint withdrawalsDiff = withdrawals(anyAsset, anyIlk) - withdrawalsBefore;
    mathint totalDepositsDiff = totalDeposits(anyAsset) - totalDepositsBefore;
    mathint totalRequestedFundsDiff= totalRequestedFunds(anyAsset) - totalRequestedFundsBefore;
    mathint totalWithdrawableFundsDiff = totalWithdrawableFunds(anyAsset) - totalWithdrawableFundsBefore;
    mathint totalWithdrawalsDiff = totalWithdrawals(anyAsset) - totalWithdrawalsBefore;

    assert depositsDiff != 0 => depositsDiff == totalDepositsDiff, "deposits and totalDeposit diff differed";
    assert requestedFundsDiff != 0 => requestedFundsDiff == totalRequestedFundsDiff, "requestedFunds and totaRequestedFundsdiff differed";
    assert withdrawableFundsDiff != 0 => withdrawableFundsDiff == totalWithdrawableFundsDiff, "withdrawableFunds and totalWithdrawableFunds diff differed";
    assert withdrawalsDiff != 0 => withdrawalsDiff == totalWithdrawalsDiff, "withdrawals and totalWithdrawals diff differed";
}

// Verify request status change as allowed 
rule statusChanges(method f) {
    env e;
    uint256 anyIndex;

    IArrangerConduit.FundRequest requestBefore = getFundRequest(anyIndex);

    calldataarg args;
    f(e, args);

    IArrangerConduit.FundRequest requestAfter = getFundRequest(anyIndex);
    bool statusSame = requestBefore.status == requestAfter.status;

    assert requestBefore.status == IArrangerConduit.StatusEnum.UNINITIALIZED => statusSame || requestAfter.status == IArrangerConduit.StatusEnum.PENDING, "status changed from UNINITIALIZED to something other than PENDING";
    assert requestBefore.status == IArrangerConduit.StatusEnum.PENDING => statusSame || requestAfter.status == IArrangerConduit.StatusEnum.CANCELLED || requestAfter.status == IArrangerConduit.StatusEnum.COMPLETED, "status changed from PENDING to something other than CANCELLED or COMPLETED";
    assert requestBefore.status == IArrangerConduit.StatusEnum.CANCELLED => statusSame, "status changed from CANCELLED";
    assert requestBefore.status == IArrangerConduit.StatusEnum.COMPLETED => statusSame, "status changed from COMPLETED";
}
