#CMN="--compilation_steps_only"
#CMN="--server staging"



echo
echo "1: invariants.conf"
certoraRun $CMN certora/conf/rewards/invariants.conf --rule distributionEnd_NEQ_0 \
           --msg "invariant 1. distributionEnd_NEQ_0"

echo
echo "2: invariants.conf"
certoraRun $CMN certora/conf/rewards/invariants.conf --rule all_rewars_are_different \
           --msg "invariant 2. all_rewars_are_different"

echo
echo "3: invariants.conf"
certoraRun $CMN certora/conf/rewards/invariants.conf --rule same_distributionEnd_values \
           --msg "invariant 3. same_distributionEnd_values"

echo
echo "4: invariants.conf"
certoraRun $CMN certora/conf/rewards/invariants.conf --rule lastUpdateTimestamp_LEQ_current_time \
           --msg "invariant 4. lastUpdateTimestamp_LEQ_current_time"

echo
echo "5: invariants.conf"
certoraRun $CMN certora/conf/rewards/invariants.conf --rule accrued_is_0_for_non_existing_reward \
           --msg "invariant 5.accrued_is_0_for_non_existing_reward"

echo
echo "6: invariants.conf"
certoraRun $CMN certora/conf/rewards/invariants.conf --rule userIndex_is_0_for_non_existing_reward \
           --msg "invariant 6.userIndex_is_0_for_non_existing_reward"

echo
echo "7: invariants.conf"
certoraRun $CMN certora/conf/rewards/invariants.conf --rule distributionEnd_is_0_for_non_existing_reward \
           --msg "invariant 7.distributionEnd_is_0_for_non_existing_reward"

echo
echo "8: invariants.conf"
certoraRun $CMN certora/conf/rewards/invariants.conf --rule rewardIndex_is_0_for_non_existing_reward \
           --msg "invariant 8.rewardIndex_is_0_for_non_existing_reward"

echo
echo "9: invariants.conf"
certoraRun $CMN certora/conf/rewards/invariants.conf --rule userIndex_LEQ_rewardIndex \
           --msg "invariant 9.userIndex_LEQ_rewardIndex"

echo
echo "10: invariants.conf"
certoraRun $CMN certora/conf/rewards/invariants.conf --rule targetLiquidity_NEQ_0 \
           --msg "invariant 10.targetLiquidity_NEQ_0"

