#!/bin/bash
set -u
source ./ulcl-case.sh || exit 1

case "${1:-}" in
    TestULCLMultiPathUe1) ue=1 ;;
    TestULCLMultiPathUe2) ue=2 ;;
    *) echo 'Expected TestULCLMultiPathUe1 or TestULCLMultiPathUe2' >&2; exit 2 ;;
esac

suite_exit_code=0
for suffix in '' '-full' '-partial'; do
    run_ulcl_case "$1" "json/webconsole-subscription-data-mp-${ue}${suffix}.json"
done
exit "$suite_exit_code"
