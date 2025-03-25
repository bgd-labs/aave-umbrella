#CMN="--compilation_steps_only"


echo
echo "1: invariants.conf"
certoraRun $CMN  certora/conf/stakeToken/invariants.conf \
            --msg "1. stakeToken::invariants.conf"

echo
echo "2: rules.conf"
certoraRun $CMN  certora/conf/stakeToken/rules.conf \
            --msg "2. stakeToken::rules.conf"





