import "base.spec";



rule mirror_asset_rewardsInfo_len__correct__rule(method f)
{
  address asset;
  assert mirror_asset_rewardsInfo_len[asset] == get_rewardsInfo_length(asset);
}


rule mirror_targetLiquidity__correctness {
  address asset;
  assert mirror_targetLiquidity[asset] == get_targetLiquidity(asset);
}


rule mirror_asset_index_2_addr__correct__rule(method f)
{
  address asset; uint256 i;
  assert mirror_asset_index_2_addr[asset][i] == get_addr(asset,i);
}


rule mirror_asset_distributionEnd__map__correctness(method f)
{
  address asset; address reward;
  assert mirror_asset_distributionEnd__map[asset][reward] == get_distributionEnd__map(asset,reward);
}

rule mirror_asset_reward_2_rewardIndex__correctness(method f)
{
  address asset; address reward;
  assert mirror_asset_reward_2_rewardIndex[asset][reward] == get_rewardIndex(asset,reward);
}

rule mirror_asset_distributionEnd__arr__correctness(method f)
{
  address asset; uint ind;
  assert mirror_asset_distributionEnd__arr[asset][ind] == get_distributionEnd__arr(asset,ind);
}

rule mirror_asset_reward_user_2_accrued__correctness(method f)
{
  address asset; address reward; address user;
  assert mirror_asset_reward_user_2_accrued[asset][reward][user] == get_accrued(asset,reward,user);
}

rule mirror_asset_reward_user_2_userIndex__correctness(method f)
{
  address asset; address reward; address user;
  assert mirror_asset_reward_user_2_userIndex[asset][reward][user] == get_userIndex(asset,reward,user);
}


rule mirror_authorizedClaimers__correctness(method f) 
{
  address user; address claimer;
  assert mirror_authorizedClaimers[user][claimer] == isClaimerAuthorized(user,claimer);
}
