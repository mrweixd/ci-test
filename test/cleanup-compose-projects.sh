#!/usr/bin/env bash
set -euo pipefail

# Caller holds the host's ci-test lock. Only reclaim projects whose containers
# all identify one of this checkout's six known Compose files.
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
allowed=$(printf '%s\n' \
    "$root"/composes/build/docker-compose-{it,e2e-basic,e2e-ulcl}.yaml \
    "$root"/composes/docker-compose-ci-{it,e2e-basic,e2e-ulcl}.yaml |
    jq -R . | jq -s .)
ids=$(timeout -k 5s 15s docker ps -aq --filter label=com.docker.compose.project)
[[ -n "$ids" ]] || exit 0
# Docker IDs contain only hexadecimal characters.
containers=$(timeout -k 5s 20s docker inspect $ids)
projects=$(jq -r --argjson allowed "$allowed" '
    [.[] | select(.Config.Labels["com.docker.compose.project.config_files"] as $file |
        $allowed | index($file))]
    | .[].Config.Labels["com.docker.compose.project"]' <<< "$containers" | sort -u)
while IFS= read -r project; do
    [[ -n "$project" ]] || continue
    if ! jq -e --arg project "$project" --argjson allowed "$allowed" '
        [.[] | select(.Config.Labels["com.docker.compose.project"] == $project)] |
        all(.Config.Labels["com.docker.compose.project.config_files"] as $file |
            $allowed | index($file) != null)' <<< "$containers" >/dev/null; then
        echo "Refusing to clean mixed or foreign Compose project $project" >&2
        exit 1
    fi
    config=$(jq -r --arg project "$project" '
        [.[] | select(.Config.Labels["com.docker.compose.project"] == $project)]
        | .[0].Config.Labels["com.docker.compose.project.config_files"]' <<< "$containers")
    echo "Cleaning previous ci-test project $project"
    timeout -k 5s 2m docker compose --project-name "$project" -f "$config" down --remove-orphans -v
done <<< "$projects"
