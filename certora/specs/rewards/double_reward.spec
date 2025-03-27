import "base.spec";
import "invariants.spec";


function nice_values() {
  require currentContract == 10;
  require ASSET == 20;
  require REWARD0 == 30;
  require REWARD1 == 31;
}


function limitation_on_addresses(env e) {
  require e.msg.sender != currentContract;  //
  require e.msg.sender != 0;
}


// ====================================================================
// Rule: rewardIndex_can_never_decrease
// Description: The index of a reward can never be decreased
// Status: PASS
// ====================================================================
rule rewardIndex_can_never_decrease(method f) filtered {f ->
    f.contract == currentContract &&
    !f.isView
    && !is_harness_function(f)
    }
{
  env e; address asset;
  
  double_RewardToken_setup(asset); // Assuming double reward

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

  double_RewardToken_setup(asset); // Assuming double reward

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
  double_RewardToken_setup(asset);
  limitation_on_addresses(e);
  
  requireInvariant same_distributionEnd_values(asset);
  
  uint256 _claimable_pre = calculateCurrentUserReward(e, asset, REWARD1, e.msg.sender);
  address _payer1 = get_rewardPayer(asset,REWARD1);
  require REWARD1.balanceOf(_payer1) < _claimable_pre;

  claimAllRewards@withrevert(e, asset, receiver);

  assert lastReverted;
}






// ====================================================================
// Rule: integrity_of_claimAllRewards__2rewards
// Description: We check the following aspects of the function claimAllRewards.
//    - The calculateCurrentUserReward(..) is consistant with the actual claimed amount.
//    - The balance of the reciever can't decrease.
//    - After claiming the rewards, the calculate-reward is 0.
//    - The claimable amounts equals to the differences of the balances of the payers.
// Status: PASS
// ====================================================================
rule integrity_of_claimAllRewards__2rewards() {
  env e; address asset; address receiver;
  double_RewardToken_setup(asset);
  limitation_on_addresses(e);
  
  requireInvariant same_distributionEnd_values(asset);
  
  uint256 _bal0_reciever_pre = REWARD0.balanceOf(receiver);
  uint256 _bal1_reciever_pre = REWARD1.balanceOf(receiver);
  
  address[] all_rewards_pre; uint256[] all_amounts_pre;
  (all_rewards_pre, all_amounts_pre) = calculateCurrentUserRewards(e, asset, e.msg.sender);
  assert all_rewards_pre.length==2; assert all_amounts_pre.length==2;

  address[] all_rewards; uint256[] all_amounts;
  (all_rewards, all_amounts) = claimAllRewards(e, asset, receiver);
  assert all_rewards.length==2; assert all_amounts.length==2;
  assert all_amounts_pre[0]==all_amounts[0] && all_amounts_pre[1]==all_amounts[1];

  uint256 _bal0_reciever_post = REWARD0.balanceOf(receiver);
  uint256 _bal1_reciever_post = REWARD1.balanceOf(receiver);
  
  address[] all_rewards_post; uint256[] all_amounts_post;
  (all_rewards_post, all_amounts_post) = calculateCurrentUserRewards(e, asset, e.msg.sender);
  assert all_rewards_post.length==2;  assert all_amounts_post.length==2;
  assert all_amounts_post[0]==0 && all_amounts_post[1]==0;
        
  assert _bal0_reciever_post >= _bal0_reciever_pre && _bal1_reciever_post >= _bal1_reciever_pre;

  address payer0 = get_rewardPayer(asset,REWARD0);
  address payer1 = get_rewardPayer(asset,REWARD1);

  assert receiver != payer0 => all_amounts_pre[0] == _bal0_reciever_post - _bal0_reciever_pre;
  assert receiver != payer1 => all_amounts_pre[1] == _bal1_reciever_post - _bal1_reciever_pre;
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
rule integrity_of_claimSelectedRewards__2rewards() {
  env e; address asset; address receiver;

  double_RewardToken_setup(asset);
  limitation_on_addresses(e);
  //nice_values();

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
  uint256 _bal1_reciever_pre = REWARD1.balanceOf(receiver);
  
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
  uint256 _bal1_reciever_post = REWARD1.balanceOf(receiver);
  
  uint256 _calculatedA_post = 0; uint256 _calculatedB_post = 0;
  if (rewards_array.length >= 1)  _calculatedA_post = calculateCurrentUserReward(e, asset, rewards_array[0], e.msg.sender);
  if (rewards_array.length >= 2)  _calculatedB_post = calculateCurrentUserReward(e, asset, rewards_array[1], e.msg.sender);

  assert _bal0_reciever_post >= _bal0_reciever_pre  && _bal1_reciever_post >= _bal1_reciever_pre;

  assert _calculatedA_pre == _claimedA;
  assert _rwrdA!=_rwrdB ? _calculatedB_pre == _claimedB : true;
  
  address payer0 = get_rewardPayer(asset,REWARD0);
  address payer1 = get_rewardPayer(asset,REWARD1);
  
  assert _rwrdA != REWARD0 && _rwrdA != REWARD1 => _claimedA==0;
  assert _rwrdA == REWARD0 && payer0 !=receiver =>
    _claimedA==_bal0_reciever_post-_bal0_reciever_pre  &&  _calculatedA_post==0;
  assert _rwrdA == REWARD1 && payer1 !=receiver =>
   _claimedA==_bal1_reciever_post-_bal1_reciever_pre  &&  _calculatedA_post==0;
     
  assert _rwrdB != REWARD0 && _rwrdB != REWARD1 => _claimedB==0;
  assert _rwrdB == REWARD0 && _rwrdB != _rwrdA && payer0 != receiver =>
    _claimedB==_bal0_reciever_post-_bal0_reciever_pre  &&  _calculatedB_post==0;
  assert _rwrdB == REWARD1 && _rwrdB != _rwrdA && payer1 != receiver =>
   _claimedB==_bal1_reciever_post-_bal1_reciever_pre  &&  _calculatedB_post==0;
}



// ====================================================================
// Rule: bob_cant_affect_the_claimed_amount_of_alice__2rewards
// Description: If alice is eilgible to claim some amount of money,
//              any action from bob side won't affect that amount.
// Status: PASS
// ====================================================================
rule bob_cant_affect_the_claimed_amount_of_alice__2rewards(method f) filtered {f ->
    f.contract == currentContract
    && !f.isView
    && !is_admin_function(f)    // admin functions can affect alice rewards. For example in configureAssetWithReward
                                // the distributionEnd might be changed.
    && !is_permit_function(f)   // with permit function alice can allow bob to do things from her side.
    && !is_harness_function(f)
    }
{
  env e1; env e2; address asset;
  require e1.msg.sender != e2.msg.sender;
  require e2.msg.sender != asset;
  require e1.block.timestamp==e2.block.timestamp;
  address bob = e2.msg.sender; address alice = e1.msg.sender;
  require isClaimerAuthorized(alice, bob)==false;

  double_RewardToken_setup(asset);

  requireInvariant same_distributionEnd_values(asset);
  requireInvariant distributionEnd_NEQ_0(asset);
  requireInvariant accrued_is_0_for_non_existing_reward(asset);
    
  
  address[] all_rewards_pre; uint256[] calculated_pre;
  (all_rewards_pre, calculated_pre) = calculateCurrentUserRewards(e1, asset, alice);
  assert all_rewards_pre.length==2; assert calculated_pre.length==2;

  calldataarg args;
  f(e2, args); // bob do something

  address[] all_rewards_post; uint256[] calculated_post;
  (all_rewards_post, calculated_post) = calculateCurrentUserRewards(e1, asset, alice);
  assert all_rewards_post.length==2; assert calculated_post.length==2;

  assert calculated_post[0] == calculated_pre[0];
  assert calculated_post[1] == calculated_pre[1];
}


