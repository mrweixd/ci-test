#!/bin/bash

##########################
#
# usage:
# ./test-it-tngf.sh
#
# e.g. ./test-it-tngf.sh
#
##########################

echo "Running IT TNGF test"

# post ue data to db
./api-webconsole-subscribtion-data-action.sh post json/webconsole-subscription-data-it.json
if [ $? -ne 0 ]; then
    echo "Failed to post subscription data"
    exit 1
fi

output=$(mktemp) || exit 1
trap 'rm -f -- "$output"' EXIT
go_test_exit_code=0
(cd goTest && go test -count=1 -v -vet=off -run '^(TestTngf|TestNasTCPFraming|TestNasTCPConfigurationAndAccept)$') > "$output" 2>&1 || go_test_exit_code=1
cat "$output"
for required in TestTngf TestNasTCPFraming TestNasTCPConfigurationAndAccept; do
    grep -Eq "^--- PASS: $required \(" "$output" || go_test_exit_code=1
done

# delete ue data from db
./api-webconsole-subscribtion-data-action.sh delete json/webconsole-subscription-data-it.json
if [ $? -ne 0 ]; then
    echo "Failed to delete subscription data"
    exit 1
fi

# return the test exit code
exit $go_test_exit_code
