import "base.spec";
import "invariants.spec";


function nice_values() {
  require currentContract == 10;
  require ASSET == 20;
  require REWARD0 == 30;
  require REWARD1 == 31;
}


function limitation_on_addresses(env e) {
  require e.msg.sender != currentContract;
  require e.msg.sender != 0;
}


// ====================================================================
// Rule: rewardIndex_can_never_decrease
// Description: The index of a reward can never be decreased
// Status: PASS
// ====================================================================
rule rewardIndex_can_never_decrease(method f) filtered {f ->
    f.contract == currentContract
    && !f.isView
    && !is_harness_function(f)
    }
{
  env e; address asset;
  
  single_RewardToken_setup(asset);

  address reward;
  uint144 index_pre = get_rewardIndex(asset,reward);
  
  calldataarg args;
  f(e, args);

  uint144 index_post = get_rewardIndex(asset,reward);

  assert index_pre <= index_post;
}


// ====================================================================
// Rule: userIndex_can_never_decrease
// Description: The index of a user can never be decreased
// Status: PASS
// ====================================================================
rule userIndex_can_never_decrease(method f) filtered {f ->
    f.contract == currentContract
    && !f.isView
    && !is_harness_function(f)
    }
{
  env e; address asset;
  single_RewardToken_setup(asset);

  address reward; address user;
  uint144 index_pre = get_userIndex(asset,reward,user);
  
  calldataarg args;
  f(e, args);

  uint144 index_post = get_userIndex(asset,reward,user);

  assert index_pre <= index_post;
}


// ====================================================================
// Rule: not_enough_rewards_must_revert
// Description: if the balance of the payer is below the amount that should be paied
// the protocol must revert
// Status: PASS
// ====================================================================
rule not_enough_rewards_must_revert() {
  env e; address asset; address receiver;
  single_RewardToken_setup(asset);
  limitation_on_addresses(e);
  
  requireInvariant same_distributionEnd_values(asset);
  
  uint256 _claimable_pre = calculateCurrentUserReward(e, asset, REWARD0, e.msg.sender);
  address _payer0 = get_rewardPayer(asset,REWARD0);
  require REWARD0.balanceOf(_payer0) < _claimable_pre;

  address[] all_rewards; uint256[] all_amounts;
  (all_rewards, all_amounts) = claimAllRewards@withrevert(e, asset, receiver);

  assert lastReverted;
}



// ====================================================================
// Rule: integrity_of_claimAllRewards__1reward
// Description: We check the following aspects of the function claimAllRewards.
//    - The calculateCurrentUserReward(..) is consistant with the actual claimed amount.
//    - The balance of the reciever can't decrease.
//    - After claiming the rewards, the calculate-reward is 0.
//    - The claimable amount equals to the difference of the balance of the payer.
// Status: PASS
// ====================================================================
rule integrity_of_claimAllRewards__1reward() {
  env e; address asset; address receiver;
  single_RewardToken_setup(asset);
  limitation_on_addresses(e);
  
  requireInvariant same_distributionEnd_values(asset);
  
  uint256 _bal_reciever_pre = REWARD0.balanceOf(receiver);
  uint256 _claimable_pre = calculateCurrentUserReward(e, asset, REWARD0, e.msg.sender);

  address[] all_rewards; uint256[] all_amounts;
  (all_rewards, all_amounts) = claimAllRewards(e, asset, receiver);

  uint _all_rewards_length = all_rewards.length;
  uint _all_amounts_length = all_amounts.length;
  address _the_reward = all_rewards[0];
  uint256 _actual_claimable = all_amounts[0];

  assert _claimable_pre == _actual_claimable;

   
  uint256 _bal_reciever_post = REWARD0.balanceOf(receiver);
  uint256 _claimable_post = calculateCurrentUserReward(e, asset, REWARD0, e.msg.sender);
        
  assert _bal_reciever_post >= _bal_reciever_pre;
  assert _claimable_post ==0;

  mathint _rewardsGiven = _bal_reciever_post - _bal_reciever_pre;
  address payer = get_rewardPayer(asset,REWARD0);
  // We demand that receiver != payer because otherwise it's the same person who pays to itself
  assert receiver != payer => _claimable_pre == _rewardsGiven;
}





// ====================================================================
// Rule: integrity_of_claimSelectedRewards__1reward
// Note: We allow the caller to pass any array of rewards, with size upto 2. It may
//       contain duplicated rewards, and it may contain non-existing rewards.
// Description: We check the following aspects of the function claimAllRewards.
//    - The calculateCurrentUserReward(..) is consistant with the actual claimed amount.
//    - The balance of the reciever can't decrease.
//    - After claiming the rewards, the calculate-reward is 0.
//    - The claimable amount equals to the difference of the balance of the payer.
//    - Claiming from non-existing reward yields 0 amonut.
// Status: PASS
// ====================================================================
rule integrity_of_claimSelectedRewards__1reward() {
  env e; address asset; address receiver;
  single_RewardToken_setup(asset);  limitation_on_addresses(e);
  nice_values();

  address[] rewards_array;
  require rewards_array.length <= 2;
  uint _rewards_arr_length = rewards_array.length;
  address _rwrdA=0; address _rwrdB=0;
  if (rewards_array.length >= 1)  _rwrdA = rewards_array[0];
  if (rewards_array.length >= 2)  _rwrdB = rewards_array[1];
    
  requireInvariant all_rewars_are_different(asset);
  requireInvariant distributionEnd_NEQ_0(asset);
  requireInvariant same_distributionEnd_values(asset);
  requireInvariant accrued_is_0_for_non_existing_reward(asset);
  requireInvariant distributionEnd_is_0_for_non_existing_reward(asset);
  requireInvariant rewardIndex_is_0_for_non_existing_reward(asset);
  requireInvariant userIndex_is_0_for_non_existing_reward(asset);
  
  uint256 _bal0_reciever_pre = REWARD0.balanceOf(receiver);
  uint256 _calculatedA_pre = 0; uint256 _calculatedB_pre = 0;
  if (rewards_array.length >= 1)  _calculatedA_pre = calculateCurrentUserReward(e, asset, rewards_array[0], e.msg.sender);
  if (rewards_array.length >= 2)  _calculatedB_pre = calculateCurrentUserReward(e, asset, rewards_array[1], e.msg.sender);

  uint256[] _claimed_arr;
  _claimed_arr = claimSelectedRewards(e, asset, rewards_array, receiver);
  assert _claimed_arr.length == rewards_array.length;
  uint256 _claimedA = 0; uint256 _claimedB = 0;
  if (rewards_array.length >= 1)  _claimedA = _claimed_arr[0];
  if (rewards_array.length >= 2)  _claimedB = _claimed_arr[1];
  
  uint256 _bal0_reciever_post = REWARD0.balanceOf(receiver);
  
  uint256 _calculatedA_post = 0; uint256 _calculatedB_post = 0;
  if (rewards_array.length >= 1)  _calculatedA_post = calculateCurrentUserReward(e, asset, rewards_array[0], e.msg.sender);
  if (rewards_array.length >= 2)  _calculatedB_post = calculateCurrentUserReward(e, asset, rewards_array[1], e.msg.sender);

  assert _bal0_reciever_post >= _bal0_reciever_pre;

  assert _calculatedA_pre == _claimedA;
  assert _rwrdA!=_rwrdB ? _calculatedB_pre == _claimedB : true;
  
  address payer = get_rewardPayer(asset,REWARD0);

  assert _rwrdA != REWARD0  => _claimedA==0;
  assert _rwrdA == REWARD0 && payer != receiver =>
    _claimedA==_bal0_reciever_post-_bal0_reciever_pre  &&  _calculatedA_post==0;
     
  assert _rwrdB != REWARD0  => _claimedB==0;
  assert _rwrdB == REWARD0 && _rwrdB != _rwrdA && payer != receiver =>
    _claimedB==_bal0_reciever_post-_bal0_reciever_pre  &&  _calculatedB_post==0;
}




// ====================================================================
// Rule: bob_cant_affect_the_claimed_amount_of_alice
// Description: If alice is eilgible to claim some amount of money,
//              any action from bob side won't affect that amount.
// Status: PASS
// ====================================================================
rule bob_cant_affect_the_claimed_amount_of_alice(method f) filtered {f ->
    f.contract == currentContract
    && !f.isView
    && !is_harness_function(f)
    && !is_permit_function(f) // with permit function alice can allow bob to do things from her side.
    // configureAssetWithReward (admin function) is the only function that can actually affect alice rewards.
    && f.selector != sig:configureAssetWithRewards(address,uint256,IRewardsStructs.RewardSetupConfig[]).selector
    }
{
  env e1; env e2; address asset;
  require e1.msg.sender != e2.msg.sender;
  require e2.msg.sender != asset;
  require e2.block.timestamp == e1.block.timestamp;
  address bob = e2.msg.sender; address alice = e1.msg.sender;
  require isClaimerAuthorized(alice, bob)==false;
  require alice != currentContract;

  single_RewardToken_setup(asset);

  requireInvariant same_distributionEnd_values(asset);
  requireInvariant distributionEnd_NEQ_0(asset);
  requireInvariant accrued_is_0_for_non_existing_reward(asset);
  requireInvariant ASSET_inv_sumOfBalances_eq_totalSupply();

  
  uint256 calculated_pre;
  calculated_pre = calculateCurrentUserReward(e1, asset, REWARD0, alice);

  if (f.selector != sig:emergencyTokenTransfer(address,address,uint256).selector) {
    calldataarg args;
    f(e2, args); // bob do something
  }
  else {
    address _erc20; address _to; uint _amount;
    // We assume that no emergency transfer whould transfer token to the ASSET (which is the StakeToken)
    require _to != ASSET;
    emergencyTokenTransfer(e2, _erc20, _to, _amount);
  }

  uint256 calculated_post;
  calculated_post = calculateCurrentUserReward(e1, asset, REWARD0, alice);

  assert calculated_pre <= calculated_post;
}






// ====================================================================
// Rule: bob_cant_DOS_alice_to_claim
// Description: If the system has enough money to pay both alice and bob, then bob
//              can't make alice claa to revert.
// 
// Status: PASS
// ====================================================================
rule bob_cant_DOS_alice_to_claim(method f) filtered {f ->
    f.contract == currentContract
    && !f.isView 
    && !is_admin_function(f)  // admin functions can affect alice rewards. For example in configureAssetWithReward
                              // the distributionEnd might be changed.
    && !is_permit_function(f) // with permit function alice can allow bob to do things from her side.
    && !is_OnBehalf_function(f) // with these functions bob can claim on behalf of some other user that is eligible
                                // for a "lot" of money and drain the system. If we restrict it s.t. bob can't claim
                                // on behalf of anyone, we get a vacuity error.
    // We treat the following 2 functions seperately. 
    && f.selector != sig:claimAllRewards(address,address).selector
    && f.selector != sig:claimSelectedRewards(address,address[],address).selector
    // The following 2 functions are just the "batch" versions of the usual claimAllRewards and claimSelectedRewards
    // hence we omit them.
    && f.selector != sig:claimAllRewards(address[],address).selector
    && f.selector != sig:claimSelectedRewards(address[],address[][],address).selector
    && !is_harness_function(f)
    }
{
  env e1; env e2; address asset;
  require e1.block.timestamp==e2.block.timestamp;
  address alice = e1.msg.sender; address bob = e2.msg.sender; 
  require alice != bob;  require bob != asset;  require bob != 0 && alice != 0;
  require bob != currentContract; require alice != currentContract;

  single_RewardToken_setup(asset);

  requireInvariant same_distributionEnd_values(asset);
  requireInvariant distributionEnd_NEQ_0(asset);
  requireInvariant accrued_is_0_for_non_existing_reward(asset);
    
  
  uint256 calculated_alice_pre = calculateCurrentUserReward(e1, asset, REWARD0, alice);
  uint256 calculated_bob_pre = calculateCurrentUserReward(e2, asset, REWARD0, bob);
  // We require that the system has enough money to pay both alice and bob
  require REWARD0.balanceOf(get_rewardPayer(asset,REWARD0)) >= calculated_bob_pre + calculated_alice_pre;

  storage initialStorage = lastStorage;
  
  // alice claim her rewards
  address receiver;
  claimAllRewards(e1, asset, receiver);

  // Now we start it all over, and let bob to call some function before alice claims her rewards
  calldataarg args;
  f(e2, args) at initialStorage; // bob do something

  claimAllRewards@withrevert(e1, asset, receiver);
  assert !lastReverted;
}


// ====================================================================
// Rule: bob_cant_DOS_alice_to_claim__claimSelectedRewards
// Description: If the system has enough money to pay both alice and bob, then bob
//              can't make alice claim to revert, by calling to claimSelectedRewards(...)
// Status: PASS
// ====================================================================
rule bob_cant_DOS_alice_to_claim__claimSelectedRewards() {
  env e1; env e2; address asset;
  require e1.block.timestamp==e2.block.timestamp;
  address alice = e1.msg.sender; address bob = e2.msg.sender; 
  require alice != bob;  require bob != asset;  require bob != 0 && alice != 0;
  require bob != currentContract; require alice != currentContract;

  single_RewardToken_setup(asset);

  requireInvariant same_distributionEnd_values(asset);
  requireInvariant distributionEnd_NEQ_0(asset);
  requireInvariant accrued_is_0_for_non_existing_reward(asset);
  
  storage initialStorage = lastStorage; // recording the storage at this point

  uint256 calculated_alice_pre = calculateCurrentUserReward(e1, asset, REWARD0, alice);
  uint256 calculated_bob_pre = calculateCurrentUserReward(e2, asset, REWARD0, bob);
  // We require that the system has enough money to pay both alice and bob
  require REWARD0.balanceOf(get_rewardPayer(asset,REWARD0)) >= calculated_bob_pre + calculated_alice_pre;
 
  // alice claim her rewards
  address receiver_of_alice;
  claimAllRewards(e1, asset, receiver_of_alice);

  // We need the following in order to make sure that the payer can transfer to receiver_of_bob
  // the amount calculated_bob_pre. (Thus eliminating reverts due to non-sufficient allowance in the ERC20)
  env e;  require e.msg.sender == currentContract;
  address receiver_of_bob;
  REWARD0.transferFrom(e, get_rewardPayer(asset,REWARD0), receiver_of_bob, calculated_bob_pre);

  // The following is bob's call
  address asset2; address[] rewards; uint _rewards_len = rewards.length;
  claimSelectedRewards(e2, asset2, rewards, receiver_of_bob) at initialStorage; 

  claimAllRewards@withrevert(e1, asset, receiver_of_alice);
  assert !lastReverted;
}




// ====================================================================
// Rule: bob_cant_DOS_alice_to_claim__claimAllRewards
// Description: If the system has enough money to pay both alice and bob, then bob
//              can't make alice claim to revert, by calling to claimAllRewards(...)
// Status: PASS
// ====================================================================
rule bob_cant_DOS_alice_to_claim__claimAllRewards() {
  env e1; env e2; address asset;
  require e1.block.timestamp==e2.block.timestamp;
  address alice = e1.msg.sender; address bob = e2.msg.sender; 
  require alice != bob;  require bob != asset;  require bob != 0 && alice != 0;
  require bob != currentContract; require alice != currentContract;

  single_RewardToken_setup(asset);  // Assuming double reward

  requireInvariant same_distributionEnd_values(asset);
  requireInvariant distributionEnd_NEQ_0(asset);
  requireInvariant accrued_is_0_for_non_existing_reward(asset);
  
  storage initialStorage = lastStorage; // recording the storage at this point

  uint256 calculated_alice_pre = calculateCurrentUserReward(e1, asset, REWARD0, alice);
  uint256 calculated_bob_pre = calculateCurrentUserReward(e2, asset, REWARD0, bob);
  // We require that the system has enough money to pay both alice and bob
  require REWARD0.balanceOf(get_rewardPayer(asset,REWARD0)) >= calculated_bob_pre + calculated_alice_pre;

  
  // alice claim her rewards
  address receiver_of_alice; 
  claimAllRewards(e1, asset, receiver_of_alice);


  // We need the following in order to make sure that the payer can transfer to receiver_of_bob
  // the amount calculated_bob_pre. (Thus eliminating reverts due to non-sufficient allowance in the ERC20)
  env e;  require e.msg.sender == currentContract;
  address receiver_of_bob;
  REWARD0.transferFrom(e, get_rewardPayer(asset,REWARD0), receiver_of_bob, calculated_bob_pre);

  // The following is bob's call
  address asset2;
  claimAllRewards(e2, asset2, receiver_of_bob) at initialStorage; 

  claimAllRewards@withrevert(e1, asset, receiver_of_alice);
  assert !lastReverted;
}



// ====================================================================
// Rule: claimed_rewards_cant_decrease_with_time
// Description: The claimed reward of a user, can only increase as time evolves.
// Note: When we combine this rule with the rule "bob_cant_affect_the_claimed_amount_of_alice"
//       we conclude that the claimed reward of a user can never be decreased (up to the
//       limitations of that rule)
// Status: PASS
// ====================================================================
rule claimed_rewards_cant_decrease_with_time() {
  env e1; env e2; address asset; address bob;
  single_RewardToken_setup(asset);
  limitation_on_addresses(e1);
  require e2.block.timestamp > e1.block.timestamp;
  
  requireInvariant same_distributionEnd_values(asset);
  
  uint256 _claimable_1 = calculateCurrentUserReward(e1, asset, REWARD0, bob);
  uint256 _claimable_2 = calculateCurrentUserReward(e2, asset, REWARD0, bob);

  assert _claimable_2 >= _claimable_1;
}


// ====================================================================
// Rule: rewards_are_monotone_in_balance
// Description: Users with more balance (in ASSET) are aligible to more rewards
// Status: PASS 
// ====================================================================
rule rewards_are_monotone_in_balance() {
  env e1;
  address asset; address bob; address alice;
  single_RewardToken_setup(asset);
  limitation_on_addresses(e1);
  require bob != 0; require alice != 0;
  
  requireInvariant same_distributionEnd_values(asset);
  requireInvariant lastUpdateTimestamp_LEQ_current_time(e1,asset);
  requireInvariant userIndex_LEQ_rewardIndex(asset);

  require get_accrued(asset,REWARD0,alice)==get_accrued(asset,REWARD0,bob);
  require get_userIndex(asset,REWARD0,alice)==get_userIndex(asset,REWARD0,bob);

  uint _bob_bal = ASSET.balanceOf(bob);
  uint _alice_bal = ASSET.balanceOf(alice);
  require _alice_bal <= _bob_bal;
   
  uint256 _claimable_bob = calculateCurrentUserReward(e1, asset, REWARD0, bob);
  uint256 _claimable_alice = calculateCurrentUserReward(e1, asset, REWARD0, alice);

  assert _claimable_alice <= _claimable_bob;
}


// ====================================================================
// Rule: current_emission_cant_exceed_max_emission
// Description: The emission can't exceed that value of maxEmissionPerSecondScaled
// Status: PASS
// ====================================================================
rule current_emission_cant_exceed_max_emission() {
  env e; address asset; 
  single_RewardToken_setup(asset);
  limitation_on_addresses(e);

  requireInvariant same_distributionEnd_values(asset);
  requireInvariant lastUpdateTimestamp_LEQ_current_time(e,asset);

  assert calculateCurrentEmissionScaled(e,asset,REWARD0) <= get_maxEmissionPerSecondScaled(asset,REWARD0);

  assert (ASSET.totalAssets()==get_targetLiquidity(asset) &&
          e.block.timestamp <= get_distributionEnd__map(asset,REWARD0)) =>
    calculateCurrentEmissionScaled(e,asset,REWARD0) == get_maxEmissionPerSecondScaled(asset,REWARD0);
}



// ====================================================================
// Rule: claimAllRewards_must_succeed
// Description: Under the following requirements, a call to claimAllRewards must not revert:
//   - The payer has enough balance 
//   - currentContract is allowed to transfer enough money on behalf of the payer
//   - The reciever of the rewards can recieve the money (namely, its balance won't overflaw)
//   - The timestamp is below 2^32
// Status: PASS
// ====================================================================
rule claimAllRewards_must_succeed() {
  env e; address asset; address alice = e.msg.sender; 
  require alice != 0; require alice != currentContract;

  single_RewardToken_setup(asset);  // Assuming double reward

  requireInvariant same_distributionEnd_values(asset);
  requireInvariant distributionEnd_NEQ_0(asset);
  requireInvariant accrued_is_0_for_non_existing_reward(asset);
  requireInvariant targetLiquidity_NEQ_0(asset);
  
  uint256 calculated_alice_pre = calculateCurrentUserReward(e, asset, REWARD0, alice);
  // The following are the 4 requirements mensioned in the description
  require REWARD0.balanceOf(get_rewardPayer(asset,REWARD0)) >= calculated_alice_pre;
  require REWARD0.allowance(get_rewardPayer(asset,REWARD0),currentContract) >= calculated_alice_pre;
  require REWARD0.balanceOf(alice) < 2^256-1-calculated_alice_pre;
  require e.block.timestamp < 2^32;

  claimAllRewards@withrevert(e, asset, alice);
  assert !lastReverted;
}







