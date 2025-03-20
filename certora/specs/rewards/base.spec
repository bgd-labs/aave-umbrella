
// ===========================================================================================
// StakeTokenMock is a simple ERC4624 contract.
// RewardToken0/1 are sile ERC20 contracts.
// ===========================================================================================
using StakeTokenMock as ASSET;
using RewardToken0 as REWARD0;
using RewardToken1 as REWARD1;

methods {
  function _.totalAssets() external => DISPATCHER(true);
  function _.totalSupply() external => DISPATCHER(true);
  function _.balanceOf(address usr) external => DISPATCHER(true);
  
  function _.transfer(address to, uint256 value) external => DISPATCHER(true);
  function _.transferFrom(address from, address to, uint256 value) external => DISPATCHER(true);
  function _.decimals() external => DISPATCHER(true);

  function _.havoc_all_contracts_dummy() external => HAVOC_ALL;
}


// envfree declarations
methods {
  function REWARD0.balanceOf(address) external returns (uint256) envfree;
  function REWARD0.allowance(address,address) external returns (uint256) envfree;
  function REWARD1.balanceOf(address) external returns (uint256) envfree;
  function ASSET.balanceOf(address) external returns (uint256) envfree;

  function ASSET.totalSupply() external returns (uint256) envfree;
  function ASSET.totalAssets() external returns (uint256) envfree;

  function get_rewardsInfo_length(address asset) external returns (uint) envfree;
  function get_targetLiquidity(address asset) external returns (uint160) envfree;
  function get_rewardPayer(address asset, address reward) external returns (address) envfree;
  function get_distributionEnd__map(address asset, address reward) external returns (uint32) envfree;
  function get_rewardIndex(address asset, address reward) external returns (uint144) envfree;
  function get_maxEmissionPerSecondScaled(address asset, address reward) external returns (uint72) envfree;
  function get_decimalsScaling(address asset, address reward) external returns (uint8) envfree;
  function get_addr(address asset, uint ind) external returns (address) envfree;
  function get_distributionEnd__arr(address asset, uint ind) external returns (uint32) envfree;
  function get_lastUpdateTimestamp(address asset) external returns (uint32) envfree;
  function isClaimerAuthorized(address user, address claimer) external returns (bool) envfree;
  function get_accrued(address asset, address reward, address user) external returns (uint112) envfree;
  function get_userIndex(address asset, address reward, address user) external returns (uint144) envfree;
  function isClaimerAuthorized(address user, address claimer) external returns (bool) envfree;
  function havoc_other_contracts() external envfree;
  function havoc_all_contracts() external envfree;
}



// ==============================================================================================
// NOTE: in our setup (for most of the rules) we have a single asset - the ASSET.
// this asset can have 1 or 2 rewards attached to it: REWARD0 or REWARD0 and REWARD1.
//
// When one wants to use one of this setup in a rule, he simply need to call one of the following
// 2 functions:
// ==============================================================================================

function single_RewardToken_setup(address asset) {
  require asset == ASSET;

  require get_rewardsInfo_length(asset)==1;
  require get_addr(asset,0)==REWARD0;
}

function double_RewardToken_setup(address asset) {
  require asset == ASSET;

  require get_rewardsInfo_length(asset)==2;
  require get_addr(asset,0)==REWARD0;
  require get_addr(asset,1)==REWARD1;
}



// ==============================================================================================
// Mirrors: since we can't use inside quatifiers calls to the contract's function, we need to mirror
// storage variables that we want to access inside a quantifier.
// ==============================================================================================


// mirror_asset_rewardsInfo_len[asset] is: assetsData[asset].rewardsInfo.length
ghost mapping(address => uint) mirror_asset_rewardsInfo_len {
  init_state axiom forall address a. mirror_asset_rewardsInfo_len[a] == 0;
}
hook Sstore RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 32).(offset 0) uint newLen (uint oldLen)  {
  mirror_asset_rewardsInfo_len[asset] = newLen;
}
hook Sload uint len RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 32).(offset 0)  {
  require mirror_asset_rewardsInfo_len[asset] == len;
}


// mirror_targetLiquidity[asset] is: assetsData[asset].targetLiquidity
ghost mapping(address => uint160) mirror_targetLiquidity {
  init_state axiom forall address a. mirror_targetLiquidity[a] == 0;
}
hook Sstore RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 64) uint160 newVal (uint160 o)  {
  mirror_targetLiquidity[asset] = newVal;
}
hook Sload uint160 val RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 64)  {
  require mirror_targetLiquidity[asset] == val;
}


// mirror_asset_index_2_addr[asset][index] is: assetsData[asset].rewardsInfo[index].addr
ghost mapping(address => mapping(uint=>address)) mirror_asset_index_2_addr {
  init_state axiom forall address asset. forall uint ind. mirror_asset_index_2_addr[asset][ind] == 0;
}
hook Sstore RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 32)[INDEX uint256 i].(offset 0) address newAddr (address oldAddr)  {
  mirror_asset_index_2_addr[asset][i] = newAddr;
}
hook Sload address addr
RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 32)[INDEX uint256 i].(offset 0) {
  require mirror_asset_index_2_addr[asset][i]==addr;
}


// mirror_asset_distributionEnd__map[asset][index] is: assetsData[asset].data[reward].rewardData.distributionEnd
ghost mapping(address => mapping(address=>uint32)) mirror_asset_distributionEnd__map {
  init_state axiom forall address asset. forall address reward. mirror_asset_distributionEnd__map[asset][reward] == 0;
}
hook Sstore RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 0)[KEY address reward].(offset 0).(offset 27) uint32 newDistEnd (uint32 o)  {
  mirror_asset_distributionEnd__map[asset][reward] = newDistEnd;
}
hook Sload uint32 distEnd
RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 0)[KEY address reward].(offset 27) {
  require mirror_asset_distributionEnd__map[asset][reward]==distEnd;
}

// mirror_asset_reward_2_rewardIndex[asset][reward] is: assetsData[asset].data[reward].rewardData.index
ghost mapping(address => mapping(address=>uint144)) mirror_asset_reward_2_rewardIndex {
  init_state axiom forall address asset. forall address reward. mirror_asset_reward_2_rewardIndex[asset][reward] == 0;
}
hook Sstore RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 0)[KEY address reward].(offset 0).(offset 0) uint144 newIndex (uint144 o)  {
  mirror_asset_reward_2_rewardIndex[asset][reward] = newIndex;
}
hook Sload uint144 index
RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 0)[KEY address reward].(offset 0).(offset 0) {
  require mirror_asset_reward_2_rewardIndex[asset][reward]==index;
}


// mirror_asset_distributionEnd__arr[asset][ind] is: assetsData[asset].rewardsInfo[ind].distributionEnd
ghost mapping(address => mapping(uint=>uint32)) mirror_asset_distributionEnd__arr {
  init_state axiom forall address asset. forall uint ind. mirror_asset_distributionEnd__arr[asset][ind] == 0;
}
hook Sstore RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 32)[INDEX uint ind].(offset 20) uint32 newDistEnd (uint32 o)  {
  mirror_asset_distributionEnd__arr[asset][ind] = newDistEnd;
}
hook Sload uint32 distEnd
RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 32)[INDEX uint ind].(offset 20) {
  require mirror_asset_distributionEnd__arr[asset][ind]==distEnd;
}


// mirror_asset_reward_user_2_accrued[asset][reward][user] is: assetsData[asset].data[reward].userData[user].accrued
ghost mapping(address => mapping(address=>mapping(address=>uint112))) mirror_asset_reward_user_2_accrued {
  init_state axiom
    forall address asset. forall address reward. forall address user.
    mirror_asset_reward_user_2_accrued[asset][reward][user] == 0;
}
hook Sstore RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 0)[KEY address reward].(offset 32)[KEY address user].(offset 18)
  uint112 newAccrued (uint112 o)  {
  mirror_asset_reward_user_2_accrued[asset][reward][user] = newAccrued;
}
hook Sload uint112 newAccrued
RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 0)[KEY address reward].(offset 32)[KEY address user].(offset 18) {
  require mirror_asset_reward_user_2_accrued[asset][reward][user] == newAccrued;
}

// mirror_asset_reward_user_2_userIndex[asset][reward][user] is: assetsData[asset].data[reward].userData[user].index
ghost mapping(address => mapping(address=>mapping(address=>uint144))) mirror_asset_reward_user_2_userIndex {
  init_state axiom
    forall address asset. forall address reward. forall address user.
    mirror_asset_reward_user_2_userIndex[asset][reward][user] == 0;
}
hook Sstore RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 0)[KEY address reward].(offset 32)[KEY address user].(offset 0)
  uint112 newAccrued (uint144 o)  {
  mirror_asset_reward_user_2_userIndex[asset][reward][user] = newAccrued;
}
hook Sload uint144 newAccrued
RewardsControllerHarness.(slot 0x7a5f91582c97dd0b2921808fbdbab73d3de091aefc8bf8607868e058abb2e300).
  (offset 0)[KEY address asset].(offset 0)[KEY address reward].(offset 32)[KEY address user].(offset 0) {
  require mirror_asset_reward_user_2_userIndex[asset][reward][user] == newAccrued;
}



// mirror_authorizedClaimers[user][claimer] is: authorizedClaimers[user][claimer];
ghost mapping(address => mapping(address=>bool)) mirror_authorizedClaimers {
  init_state axiom forall address user. forall address claimer. mirror_authorizedClaimers[user][claimer] == false;
}
hook Sstore RewardsControllerHarness.(slot 0x21b0411c7d97c506a34525b56b49eed70b15d28e22527c4589674c84ba9a5200).
  (offset 0)[KEY address user][KEY address claimer] bool newVal (bool o)  {
  mirror_authorizedClaimers[user][claimer] = newVal;
}
hook Sload bool val
RewardsControllerHarness.(slot 0x21b0411c7d97c506a34525b56b49eed70b15d28e22527c4589674c84ba9a5200).
  (offset 0)[KEY address user][KEY address claimer] {
  require mirror_authorizedClaimers[user][claimer]==val;
}




ghost mathint ASSET_sumOfBalances {
    init_state axiom ASSET_sumOfBalances == 0;
}
hook Sstore ASSET._balances[KEY address account] uint256 balance (uint256 balance_old) {
  ASSET_sumOfBalances = ASSET_sumOfBalances + balance - balance_old;
}
hook Sload uint256 balance ASSET._balances[KEY address account] {
  require balance <= ASSET_sumOfBalances;
}

// ======================================================================================
// Invariant: inv_sumOfBalances_eq_totalSupply
// Description: The total supply of the ASSET equals the sum of all users' balances.
// Status: PASS
// ======================================================================================
invariant ASSET_inv_sumOfBalances_eq_totalSupply()
  ASSET_sumOfBalances == ASSET.totalSupply();

// ======================================================================================
// Invariant: total_supply_GEQ_user_bal
// Description: The total supply amount of shares is greater or equal to any user's share balance.
// Status: PASS
// ======================================================================================
invariant ASSET_total_supply_GEQ_user_bal(address user)
    ASSET.totalSupply() >= ASSET.balanceOf(user)
{
    preserved {
        requireInvariant ASSET_inv_sumOfBalances_eq_totalSupply();
    }
}




definition is_admin_function(method f) returns bool =
    f.selector == sig:configureAssetWithRewards(address,uint256,IRewardsStructs.RewardSetupConfig[]).selector ||
    f.selector == sig:setClaimer(address,address,bool).selector ||
    f.selector == sig:configureRewards(address,IRewardsStructs.RewardSetupConfig[]).selector ||
    f.selector == sig:emergencyTokenTransfer(address,address,uint256).selector
      ;    


definition is_permit_function(method f) returns bool =
  f.selector == sig:claimAllRewardsPermit(address,address,address,uint256,IRewardsStructs.SignatureParams).selector ||
  f.selector == sig:claimSelectedRewardsPermit(address,address[],address,address,uint256,IRewardsStructs.SignatureParams).selector
    ;


definition is_OnBehalf_function(method f) returns bool =
  f.selector == sig:claimAllRewardsOnBehalf(address,address,address).selector ||
  f.selector == sig:claimAllRewardsOnBehalf(address[],address,address).selector ||
  f.selector == sig:claimSelectedRewardsOnBehalf(address,address[],address,address).selector ||
  f.selector == sig:claimSelectedRewardsOnBehalf(address[],address[][],address,address).selector
    ;


definition is_harness_function(method f) returns bool =
  f.selector == sig:havoc_other_contracts().selector ||
  f.selector == sig:havoc_all_contracts().selector
    ;


