#CMN="--compilation_steps_only"
#CMN="--server staging"


echo
echo "1: mirrors.conf"
certoraRun $CMN  certora/conf/rewards/mirrors.conf \
            --msg "1. rewards/mirrors.conf"

#echo
#echo "2: invariants.conf"
#certoraRun $CMN  certora/conf/rewards/invariants.conf \
  #          --msg "2. rewards/invariants.conf"

echo
echo "3: double_reward.conf"
certoraRun $CMN  certora/conf/rewards/double_reward.conf \
            --msg "3. rewards/double_reward.conf"


echo
echo "4: single_reward.conf"
certoraRun $CMN  certora/conf/rewards/single_reward.conf \
           --exclude_rule bob_cant_DOS_alice_to_claim bob_cant_DOS_alice_to_claim__claimSelectedRewards bob_cant_DOS_alice_to_claim__claimAllRewards bob_cant_affect_the_claimed_amount_of_alice \
            --msg "4. rewards/single_reward.conf: not excluded rules"

echo
echo "5: single_reward-depth0.conf DOS1"
certoraRun $CMN  certora/conf/rewards/single_reward-depth0.conf \
           --rule bob_cant_DOS_alice_to_claim \
            --msg "5. rewards/single_reward-depth0.conf: bob_cant_DOS_alice_to_claim"


echo
echo "6: single_reward-depth0.conf DOS2"
certoraRun $CMN  certora/conf/rewards/single_reward-depth0.conf \
           --rule bob_cant_DOS_alice_to_claim__claimAllRewards \
            --msg "6. rewards/single_reward-depth0.conf: bob_cant_DOS_alice_to_claim__claimAllRewards"
 
echo
echo "7: single_reward-depth0.conf DOS3"
certoraRun $CMN  certora/conf/rewards/single_reward-depth0.conf \
           --rule bob_cant_DOS_alice_to_claim__claimSelectedRewards \
            --msg "7. rewards/single_reward-depth0.conf: bob_cant_DOS_alice_to_claim__claimSelectedRewards"
 
echo
echo "8: single_reward-special_config.conf bob_cant_affect_the_claimed_amount_of_alice"
certoraRun $CMN  certora/conf/rewards/single_reward-special_config.conf \
           --rule bob_cant_affect_the_claimed_amount_of_alice \
            --msg "8. rewards/single_rewad-special_config.conf: bob_cant_affect_the_claimed_amount_of_alice"
 




