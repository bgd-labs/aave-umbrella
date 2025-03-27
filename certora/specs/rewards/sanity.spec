import "base.spec";
import "invariant.spec";

rule sanity_claimAllRewards() {
  address asset; address receiver;

  double_RewardToken_setup(asset);
  
  env e;
  claimAllRewards(e, asset, receiver);
  satisfy true;
}


rule sanity(method f) filtered {f -> f.contract==currentContract}
{
  env e;
  calldataarg arg;
  f(e, arg);
  satisfy true;
}

