#CMN="--compilation_steps_only"


echo
echo "1: invariant.conf"
certoraRun $CMN  certora/conf/umbrella/invariants.conf \
           --msg "1. umbrella::invariants.conf"

echo
echo "2: Umbrella.conf: slashing_cant_DOS_other_functions"
certoraRun $CMN  certora/conf/umbrella/Umbrella.conf --rule slashing_cant_DOS_other_functions \
            --msg "2. umbrella::Umbrella.conf::slashing_cant_DOS_other_functions"

echo
echo "3: Umbrella.conf: slashing_cant_DOS__coverDeficitOffset"
certoraRun $CMN  certora/conf/umbrella/Umbrella.conf --rule slashing_cant_DOS__coverDeficitOffset \
            --msg "3. umbrella::Umbrella.conf::slashing_cant_DOS__coverDeficitOffset"

echo
echo "4: Umbrella.conf: other rules"
certoraRun $CMN  certora/conf/umbrella/Umbrella.conf \
           --exclude_rule slashing_cant_DOS_other_functions slashing_cant_DOS__coverDeficitOffset \
            --msg "4. umbrella::Umbrella.conf: other rules"





