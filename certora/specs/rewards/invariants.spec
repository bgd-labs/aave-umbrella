import "base.spec";




// ====================================================================
// Invariant: distributionEnd_NEQ_0
// Description: For every reward that exists in the array assetsData[asset].rewardsInfo
// it holds that: assetsData[asset].data[reward].rewardData.distributionEnd != 0
// Status: PASS
// ====================================================================
invariant distributionEnd_NEQ_0(address asset)
  forall uint i. (i < mirror_asset_rewardsInfo_len[asset]) =>
                 (mirror_asset_distributionEnd__map[asset][mirror_asset_index_2_addr[asset][i]]!=0)
  filtered {f -> f.contract == currentContract && !is_harness_function(f)}
  {
    preserved with (env e) {
      require e.block.timestamp != 0;
    }
  }


// ====================================================================
// Invariant: all_rewars_are_different
// Description: All the (addresses of) rewards that appear in the array assetsData[asset].rewardsInfo
// are different from each other.
// Status: PASS
// ====================================================================
invariant all_rewars_are_different(address asset)
  forall uint i1. forall uint i2.
  (i1 != i2 && i1 < mirror_asset_rewardsInfo_len[asset] && i2 < mirror_asset_rewardsInfo_len[asset]) =>
  (mirror_asset_index_2_addr[asset][i1] != mirror_asset_index_2_addr[asset][i2])
  filtered {f -> f.contract == currentContract && !is_harness_function(f)}
  {
    preserved with (env e) {
      require e.block.timestamp != 0;
      requireInvariant distributionEnd_NEQ_0(asset);
    }
  }


// ====================================================================
// Invariant: same_distributionEnd_values
// Description: For every reward that exists in the array assetsData[asset].rewardsInfo,
// the fields distributionEnd (that exists in both structs RewardData and RewardAddrAndDistrEnd)
// has the same value.
// Status: PASS
// ====================================================================
invariant same_distributionEnd_values(address asset)
  forall uint i. forall address reward.
  (i < mirror_asset_rewardsInfo_len[asset]) =>
  mirror_asset_distributionEnd__map[asset][mirror_asset_index_2_addr[asset][i]] == mirror_asset_distributionEnd__arr[asset][i]
filtered {f -> f.contract == currentContract && !is_harness_function(f)}
  {
    preserved with (env e) {
      require e.block.timestamp != 0;
      requireInvariant all_rewars_are_different(asset);
      requireInvariant distributionEnd_NEQ_0(asset);
    }
  }


// ====================================================================
// Invariant: lastUpdateTimestamp_LEQ_current_time
// Description: The field lastUpdateTimestamp can't exceed current timestamp
// Status: PASS
// ====================================================================
invariant lastUpdateTimestamp_LEQ_current_time(env e, address asset)
  get_lastUpdateTimestamp(asset) <= e.block.timestamp
  filtered {f -> f.contract == currentContract && !is_harness_function(f)}
{
  preserved with (env inv_e) {
    require inv_e.block.timestamp == e.block.timestamp;
  }
}


// ====================================================================
// Invariant: accrued_is_0_for_non_existing_reward
// Description: For every reward that doesn't exist in the array assetsData[asset].rewardsInfo
// it holds that assetsData[asset].data[reward][user].accrued == 0
// Note: we only check it for rewardsInfo array upto size 2.
// Status: PASS
// ====================================================================
invariant accrued_is_0_for_non_existing_reward(address asset)
  forall address reward. forall address user.
  (mirror_asset_rewardsInfo_len[asset]==0 => mirror_asset_reward_user_2_accrued[asset][reward][user]==0)
  &&
  ((mirror_asset_rewardsInfo_len[asset]==1 && reward != mirror_asset_index_2_addr[asset][0])
   => mirror_asset_reward_user_2_accrued[asset][reward][user]==0)
  &&
  ((mirror_asset_rewardsInfo_len[asset]==2 &&
    reward != mirror_asset_index_2_addr[asset][0] && reward != mirror_asset_index_2_addr[asset][1])
   => mirror_asset_reward_user_2_accrued[asset][reward][user]==0)
  filtered {f -> f.contract == currentContract && !is_harness_function(f)}
{
  preserved with (env e) {
    require e.block.timestamp != 0;
    requireInvariant all_rewars_are_different(asset);
    requireInvariant distributionEnd_NEQ_0(asset);
    requireInvariant same_distributionEnd_values(asset);
  }
}

// ====================================================================
// Invariant: userIndex_is_0_for_non_existing_reward
// Description: For every reward that doesn't exist in the array assetsData[asset].rewardsInfo
// it holds that assetsData[asset].data[reward][user].index == 0
// Note: we only check it for rewardsInfo array upto size 2.
// Status: PASS
// ====================================================================
invariant userIndex_is_0_for_non_existing_reward(address asset)
  forall address reward. forall address user.
  (mirror_asset_rewardsInfo_len[asset]==0 => mirror_asset_reward_user_2_userIndex[asset][reward][user]==0)
  &&
  ((mirror_asset_rewardsInfo_len[asset]==1 && reward != mirror_asset_index_2_addr[asset][0])
   => mirror_asset_reward_user_2_userIndex[asset][reward][user]==0)
  &&
  ((mirror_asset_rewardsInfo_len[asset]==2 &&
    reward != mirror_asset_index_2_addr[asset][0] && reward != mirror_asset_index_2_addr[asset][1])
   => mirror_asset_reward_user_2_userIndex[asset][reward][user]==0)
  filtered {f -> f.contract == currentContract && !is_harness_function(f)}
{
  preserved with (env e) {
    require e.block.timestamp != 0;
    requireInvariant all_rewars_are_different(asset);
    requireInvariant distributionEnd_NEQ_0(asset);
    requireInvariant same_distributionEnd_values(asset);
  }
}

// ====================================================================
// Invariant: distributionEnd_is_0_for_non_existing_reward
// Description: For every reward that doesn't exist in the array assetsData[asset].rewardsInfo
// it holds that assetsData[asset].data[reward].rewardData.distributionEnd == 0
// Note: we only check it for rewardsInfo array upto size 2.
// Status: PASS
// ====================================================================
invariant distributionEnd_is_0_for_non_existing_reward(address asset)
  forall address reward.
  (mirror_asset_rewardsInfo_len[asset]==0 => mirror_asset_distributionEnd__map[asset][reward]==0)
  &&
  ((mirror_asset_rewardsInfo_len[asset]==1 && reward != mirror_asset_index_2_addr[asset][0])
   => mirror_asset_distributionEnd__map[asset][reward]==0)
  &&
  ((mirror_asset_rewardsInfo_len[asset]==2 &&
    reward != mirror_asset_index_2_addr[asset][0] && reward != mirror_asset_index_2_addr[asset][1])
   => mirror_asset_distributionEnd__map[asset][reward]==0)
  filtered {f -> f.contract == currentContract && !is_harness_function(f)}
{
  preserved with (env e) {
    require e.block.timestamp != 0;
    requireInvariant all_rewars_are_different(asset);
    requireInvariant distributionEnd_NEQ_0(asset);
    requireInvariant same_distributionEnd_values(asset);
  }
}


// ====================================================================
// Invariant: rewardIndex_is_0_for_non_existing_reward
// Description: For every reward that doesn't exist in the array assetsData[asset].rewardsInfo
// it holds that assetsData[asset].data[reward].rewardData.index == 0
// Note: we only check it for rewardsInfo array upto size 2.
// Status: PASS
// ====================================================================
invariant rewardIndex_is_0_for_non_existing_reward(address asset)
  forall address reward.
  (mirror_asset_rewardsInfo_len[asset]==0 => mirror_asset_reward_2_rewardIndex[asset][reward]==0)
  &&
  ((mirror_asset_rewardsInfo_len[asset]==1 && reward != mirror_asset_index_2_addr[asset][0])
   => mirror_asset_reward_2_rewardIndex[asset][reward]==0)
  &&
  ((mirror_asset_rewardsInfo_len[asset]==2 &&
    reward != mirror_asset_index_2_addr[asset][0] && reward != mirror_asset_index_2_addr[asset][1])
   => mirror_asset_reward_2_rewardIndex[asset][reward]==0)
  filtered {f -> f.contract == currentContract && !is_harness_function(f)}
{
  preserved with (env e) {
    require e.block.timestamp != 0;
    requireInvariant all_rewars_are_different(asset);
    requireInvariant distributionEnd_NEQ_0(asset);
    requireInvariant same_distributionEnd_values(asset);
  }
}





// ====================================================================
// Invariant: userIndex_LEQ_rewardIndex
// Description: The index of any user (for a specific reward) can't exceed the index of the reward
// Status: PASS
// ====================================================================
invariant userIndex_LEQ_rewardIndex(address asset)
  forall address reward. forall address user.
  mirror_asset_reward_user_2_userIndex[asset][reward][user] <= mirror_asset_reward_2_rewardIndex[asset][reward]
  filtered {f -> f.contract == currentContract && !is_harness_function(f)}


// ====================================================================
// Invariant: targetLiquidity_NEQ_0
// Description: If the asset contains rewards (the rewardsInfo.length>0), then 
//              targetLiquidity!=0
// Status: PASS
// ====================================================================
invariant targetLiquidity_NEQ_0(address asset)
  get_rewardsInfo_length(asset) > 0 => get_targetLiquidity(asset) > 0
  filtered {f -> f.contract == currentContract && !is_harness_function(f)}





