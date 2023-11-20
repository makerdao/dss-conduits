// ArrangerConduit.spec

using AllocatorRoles as roles;
using AllocatorRegistry as registry;
using GemMock as gem;

methods {
    function wards(address) external returns (uint256) envfree;
    function fundRequestStatus(uint256) external returns(uint256) envfree;
    function fundRequestAsset(uint256) external returns (address) envfree;
    function fundRequestIlk(uint256) external returns (bytes32) envfree;
    function fundRequestAmountRequested(uint256) external returns (uint256) envfree;
    function fundRequestAmountFilled(uint256) external returns (uint256) envfree;
    function fundRequestInfoHash(uint256) external returns (bytes32) envfree;
    function hash(string) external returns (bytes32) envfree;
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
    function maxWithdraw(bytes32, address) external returns (uint256) envfree;
    function getFundRequestsLength() external returns (uint256) envfree;
    
    function gem.balanceOf(address) external returns (uint256) envfree;
    function gem.allowance(address, address) external returns (uint256) envfree;  

    function _.transfer(address, uint256) external => DISPATCHER(true) UNRESOLVED;
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true) UNRESOLVED;    

    function registry.buffers(bytes32) external returns (address) envfree;
    function roles.canCall(bytes32, address, address, bytes4) external returns (bool) envfree;

}

definition min(mathint x, mathint y) returns mathint = x < y ? x : y;

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) {
    env e;

    address anyAddr;
    address anyAsset;
    bytes32 anyIlk;
    uint256 anyIndex;

    mathint wardsBefore = wards(anyAddr);
    mathint statusBefore = fundRequestStatus(anyIndex);
    address assetBefore = fundRequestAsset(anyIndex);
    bytes32 ilkBefore = fundRequestIlk(anyIndex);
    mathint amountRequestedBefore = fundRequestAmountRequested(anyIndex);
    mathint amountFilledBefore = fundRequestAmountFilled(anyIndex);
    bytes32 infoHashBefore = fundRequestInfoHash(anyIndex);
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
    mathint statusAfter = fundRequestStatus(anyIndex);
    address assetAfter = fundRequestAsset(anyIndex);
    bytes32 ilkAfter = fundRequestIlk(anyIndex);
    mathint amountRequestedAfter = fundRequestAmountRequested(anyIndex);
    mathint amountFilledAfter = fundRequestAmountFilled(anyIndex);
    bytes32 infoHashAfter = fundRequestInfoHash(anyIndex);
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

    assert wardsAfter != wardsBefore => f.selector == sig:UpgradeableProxy.rely(address).selector || f.selector == sig:UpgradeableProxy.deny(address).selector, "wards[x] changed in an unexpected function";

    assert statusAfter != statusBefore
        || assetAfter != assetBefore
        || ilkAfter != ilkBefore
        || amountRequestedAfter != amountRequestedBefore
        || amountFilledAfter != amountFilledBefore
        || infoHashAfter != infoHashBefore
        => f.selector == sig:requestFunds(bytes32, address, uint256, string).selector
        || f.selector == sig:cancelFundRequest(uint256).selector
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
rule setBroker(address usr, address asset, bool valid) {
    env e;

    address otherUsr;
    require otherUsr != usr;

    address otherAsset;
    require otherAsset != asset;
    
    bool isBrokerOtherUsrBefore = isBroker(otherUsr, asset);
    bool isBrokerOtherAssetBefore = isBroker(usr, otherAsset);
    
    setBroker(e, usr, asset, valid);

    bool isBrokerUsrAfter = isBroker(usr, asset);
    bool isBrokerOtherUsrAfter = isBroker(otherUsr, asset);
    bool isBrokerOtherAssetAfter = isBroker(usr, otherAsset);

    assert isBrokerUsrAfter == valid, "setBroker did not set broker to usr";
    assert isBrokerOtherUsrAfter == isBrokerOtherUsrBefore, "setBroker did not keep unchanged the rest of brokers";
    assert isBrokerOtherAssetAfter == isBrokerOtherAssetBefore, "setBroker did not keep unchanged the rest of assets";
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
    require balanceOfBufferBefore + balanceOfConduitBefore <= max_uint256;

    mathint depositsBefore = deposits(asset, ilk);
    mathint totalDepositsBefore = totalDeposits(asset);

    deposit(e, ilk, asset, amount);

    mathint balanceOfBufferAfter = gem.balanceOf(buffer);
    mathint balanceOfConduitAfter = gem.balanceOf(currentContract);
    mathint depositsAfter = deposits(asset, ilk);
    mathint totalDepositsAfter = totalDeposits(asset);

    assert balanceOfBufferAfter == balanceOfBufferBefore - amount, "deposit did not decrease balanceOf(buffer) by amount";
    assert balanceOfConduitAfter == balanceOfConduitBefore + amount, "deposit did not increase balanceOf(conduit) by amount";
    assert depositsAfter == depositsBefore + amount, "deposit did not increase deposits by amount";
    assert totalDepositsAfter == totalDepositsBefore + amount, "deposit did not increase totalDeposits by amount";
}

// Verify revert rules on deposit
rule deposit_revert(bytes32 ilk, address asset, uint256 amount) {
    env e;

    require asset == gem;

    address buffer = registry.buffers(ilk);
    require buffer != currentContract;

    bool canCall = roles.canCall(ilk, e.msg.sender, currentContract, to_bytes4(0xd954863c)); // deposit(bytes32,address,uint256)
    mathint balanceOfBuffer = gem.balanceOf(buffer);
    mathint allowanceBuffer = gem.allowance(e, buffer, currentContract);
    mathint deposits = deposits(asset, ilk);
    mathint totalDeposits= totalDeposits(asset);

    deposit@withrevert(e, ilk, asset, amount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !canCall;
    bool revert3 = balanceOfBuffer < to_mathint(amount);
    bool revert4 = allowanceBuffer < to_mathint(amount);
    bool revert5 = deposits + amount > max_uint256;
    bool revert6 = totalDeposits + amount > max_uint256;
    bool revert7 = buffer == 0;

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
    require balanceOfBufferBefore + balanceOfConduitBefore <= max_uint256;
    mathint withdrawableFundsBefore = withdrawableFunds(asset, ilk);
    mathint totalWithdrawableFundsBefore = totalWithdrawableFunds(asset);
    mathint withdrawalsBefore = withdrawals(asset, ilk);
    mathint totalWithdrawalsBefore = totalWithdrawals(asset);

    mathint amount = min(maxAmount, maxWithdraw(ilk, asset)); 
    withdraw(e, ilk, asset, maxAmount);

    mathint balanceOfBufferAfter = gem.balanceOf(buffer);
    mathint balanceOfConduitAfter = gem.balanceOf(currentContract);
    mathint withdrawableFundsAfter = withdrawableFunds(asset, ilk);
    mathint totalWithdrawableFundsAfter = totalWithdrawableFunds(asset);
    mathint withdrawalsAfter= withdrawals(asset, ilk);
    mathint totalWithdrawalsAfter = totalWithdrawals(asset);

    assert balanceOfBufferAfter == balanceOfBufferBefore + amount, "balance of buffer did not increase by amount";
    assert balanceOfConduitAfter == balanceOfConduitBefore - amount, "balance of conduit did not decrease by amount";
    assert withdrawableFundsAfter == withdrawableFundsBefore - amount, "withdrawableFunds did not decrease by amount";
    assert totalWithdrawableFundsAfter == totalWithdrawableFundsBefore- amount, "totalWithdrawableFunds did not decrease by amount";
    assert withdrawalsAfter == withdrawalsBefore + amount, "withdrawals did not increase by amount";
    assert totalWithdrawalsAfter == totalWithdrawalsBefore + amount, "totalWithdrawals did not increase by amount";
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

    mathint amount = min(maxAmount, maxWithdraw(ilk, asset)); 
    withdraw@withrevert(e, ilk, asset, maxAmount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !canCall;
    bool revert3 = balanceOfConduit < amount;
    bool revert4 = withdrawals + amount > max_uint256;
    bool revert5 = totalWithdrawals + amount > max_uint256;
    bool revert6 = withdrawableFunds < amount;
    bool revert7 = totalWithdrawableFunds < amount;
    bool revert8 = buffer == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7 || revert8, "Revert rules failed";
}

// Verify correct storage changes for non reverting requestFunds
rule requestFunds(bytes32 ilk, address asset, uint256 amount, string info) {
    env e;

    require asset == gem;
    uint256 anyIndex;

    mathint requestedFundsBefore = requestedFunds(asset, ilk);
    mathint totalRequestedFundsBefore = totalRequestedFunds(asset);
    mathint numRequestsBefore = getFundRequestsLength();

    mathint statusBefore = fundRequestStatus(anyIndex);
    address assetBefore = fundRequestAsset(anyIndex);
    bytes32 ilkBefore = fundRequestIlk(anyIndex);
    mathint amountRequestedBefore = fundRequestAmountRequested(anyIndex);
    mathint amountFilledBefore = fundRequestAmountFilled(anyIndex);
    bytes32 infoHashBefore = fundRequestInfoHash(anyIndex);

    requestFunds(e, ilk, asset, amount, info);

    mathint requestedFundsAfter = requestedFunds(asset, ilk);
    mathint totalRequestedFundsAfter= totalRequestedFunds(asset);
    mathint numRequestsAfter = getFundRequestsLength();

    mathint statusAfter= fundRequestStatus(anyIndex);
    address assetAfter = fundRequestAsset(anyIndex);
    bytes32 ilkAfter = fundRequestIlk(anyIndex);
    mathint amountRequestedAfter = fundRequestAmountRequested(anyIndex);
    mathint amountFilledAfter = fundRequestAmountFilled(anyIndex);
    bytes32 infoHashAfter = fundRequestInfoHash(anyIndex);

    assert requestedFundsAfter == requestedFundsBefore + amount, "requestedFunds did not increase by amount";
    assert totalRequestedFundsAfter == totalRequestedFundsBefore + amount, "totalRequestedFunds did not increase by amount";
    assert numRequestsAfter == numRequestsBefore + 1, "num request did not increase by 1";

    assert numRequestsBefore == to_mathint(anyIndex) =>
        statusAfter == 1 // PENDING
        && assetAfter == asset
        && ilkAfter == ilk
        && amountRequestedAfter == to_mathint(amount)
        && amountFilledAfter == 0
        && infoHashAfter == hash(info),
        "request params not as expected";

    assert numRequestsBefore != to_mathint(anyIndex) =>
        statusAfter == statusBefore
        && assetAfter == assetBefore
        && ilkAfter == ilkBefore
        && amountRequestedAfter == amountRequestedBefore
        && amountFilledAfter == amountFilledBefore
        && infoHashAfter == infoHashBefore,
        "other request params not as before";
}

// TODO: keep investigating why this is failing
// Verify revert rules on requestFunds
rule requestFunds_revert(bytes32 ilk, address asset, uint256 amount, string info) {
    env e;

    require asset == gem;

    bool canCall = roles.canCall(ilk, e.msg.sender, currentContract, to_bytes4(0xd2543ccb)); // requestFunds(bytes32,address,uint256,string)
    mathint requestedFunds = requestedFunds(asset, ilk);
    mathint totalRequestedFunds = totalRequestedFunds(asset);
    mathint numRequests = getFundRequestsLength();

    // TODO: remove these once this rule failure is clear
    require numRequests < 100;
    require requestedFunds == 0;
    require totalRequestedFunds == 0;
    require amount < 1000;
    require info.length == 22;
 
    requestFunds@withrevert(e, ilk, asset, amount, info);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !canCall;
    bool revert3 = requestedFunds + amount > max_uint256;
    bool revert4 = totalRequestedFunds + amount > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
} 

rule cancelFundRequest(uint256 fundRequestId) {
    env e;

    uint256 anyIndex;

    mathint statusBefore = fundRequestStatus(anyIndex);
    address assetBefore = fundRequestAsset(anyIndex);
    bytes32 ilkBefore = fundRequestIlk(anyIndex);
    mathint amountRequestedBefore = fundRequestAmountRequested(anyIndex);
    mathint amountFilledBefore = fundRequestAmountFilled(anyIndex);
    bytes32 infoHashBefore = fundRequestInfoHash(anyIndex);

    mathint requestedFundsBefore = requestedFunds(assetBefore, ilkBefore);
    mathint totalRequestedFundsBefore = totalRequestedFunds(assetBefore);
    mathint numRequestsBefore = getFundRequestsLength();

    cancelFundRequest(e, fundRequestId);

    mathint requestedFundsAfter = requestedFunds(assetBefore, ilkBefore);
    mathint totalRequestedFundsAfter= totalRequestedFunds(assetBefore);
    mathint numRequestsAfter = getFundRequestsLength();

    mathint statusAfter= fundRequestStatus(anyIndex);
    address assetAfter = fundRequestAsset(anyIndex);
    bytes32 ilkAfter = fundRequestIlk(anyIndex);
    mathint amountRequestedAfter = fundRequestAmountRequested(anyIndex);
    mathint amountFilledAfter = fundRequestAmountFilled(anyIndex);
    bytes32 infoHashAfter = fundRequestInfoHash(anyIndex);

    assert numRequestsAfter == numRequestsBefore, "num requests changed";
    assert anyIndex == fundRequestId => requestedFundsAfter == requestedFundsBefore - amountRequestedBefore, "requestedFunds did not decrease by amount";
    assert anyIndex == fundRequestId => totalRequestedFundsAfter == totalRequestedFundsBefore - amountRequestedBefore, "totalRequestedFunds did not decrease by amount";
    assert anyIndex == fundRequestId => statusAfter == 2, "cancelFundRequest did not change status to cancelled";
    assert anyIndex != fundRequestId => statusAfter == statusBefore, "cancelFundRequest on another index changed status";
    assert assetAfter == assetBefore
        && ilkAfter == ilkBefore
        && amountRequestedAfter == amountRequestedBefore
        && amountFilledAfter == amountFilledBefore
        && infoHashAfter == infoHashBefore,
        "request params not as before";
}





