# Shared by the ULCL subscription suites. A fixture failure leaves the database
# state uncertain, so stop the suite. Go failures are collected across cases.
run_ulcl_case() {
    local test_name="$1" fixture="$2"
    echo "Running $test_name with $fixture"
    ./api-webconsole-subscribtion-data-action.sh post "$fixture" || exit 1

    if ! (
        set -o pipefail
        cd goTest || exit 1
        go test -count=1 -v -vet=off -run "^${test_name}$" |
            awk -v name="$test_name" '
                { print }
                $1 == "---" && $2 == "PASS:" && $3 == name { passed = 1 }
                END {
                    if (!passed) print "Missing top-level PASS for " name > "/dev/stderr"
                    exit !passed
                }
            '
    ); then
        suite_exit_code=1
    fi
    ./api-webconsole-subscribtion-data-action.sh delete "$fixture" || exit 1
}
