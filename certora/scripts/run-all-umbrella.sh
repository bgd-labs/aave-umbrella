#CMN="--compilation_steps_only"
#CMN="--server staging"


echo
echo "1: invariant.conf"
certoraRun $CMN  certora/conf/umbrella/invariants.conf \
           --msg "1. umbrella::invariants.conf"

echo
echo "2: Umbrella.conf"
certoraRun $CMN  certora/conf/umbrella/Umbrella.conf \
            --msg "2. umbrella::Umbrella.conf"





