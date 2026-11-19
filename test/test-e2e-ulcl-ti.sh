#!/bin/bash
set -u
source ./ulcl-case.sh || exit 1

suite_exit_code=0
for mode in offline online; do
    run_ulcl_case TestULCLTrafficInfluence "json/webconsole-subscription-data-ti-$mode.json"
done

for overlap in full partial mixed; do
    for mode in offline online; do
        run_ulcl_case "TestTrafficInfluenceFlowRuleOverlap${overlap^}" \
            "json/webconsole-subscription-data-ti-$overlap-$mode.json"
    done
done
exit "$suite_exit_code"
