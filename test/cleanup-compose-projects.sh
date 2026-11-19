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
containers='[]'
if [[ -n "$ids" ]]; then
    # Docker IDs contain only hexadecimal characters.
    containers=$(timeout -k 5s 20s docker inspect $ids)
fi
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

# Canceled Compose startup can leave networks without any container labels.
# Reclaim only empty networks matching the legacy CI project, logical network,
# exact Docker name, and fixture subnet. These contain no persistent data.
network_ids=$(timeout -k 5s 15s docker network ls -q)
[[ -n "$network_ids" ]] || exit 0
networks=$(timeout -k 5s 20s docker network inspect $network_ids)
echo "Docker network inventory before CI startup/cleanup"
jq -r '.[] | [.Name, (.Labels["com.docker.compose.project"] // ""),
    ((.IPAM.Config // []) | map(.Subnet // "") | join(",")),
    ((.Containers // {}) | length | tostring)] | @tsv' <<< "$networks"
candidates=$(jq -r '
    {"privnet":"10.100.200.0/24", "ran-ue":"10.0.2.0/24",
     "ran-ue-0":"10.0.0.0/24", "ran-ue-1":"10.0.1.0/24",
     "ran-ue-2":"10.0.2.0/24", "mec-net":"10.100.100.0/24",
     "n6-net":"10.100.50.0/24"} as $subnets |
    .[] |
    .Labels["com.docker.compose.project"] as $project |
    .Labels["com.docker.compose.network"] as $logical |
    select(($project == "build" or $project == "composes") and $logical != null) |
    select(.Name == ($project + "_" + $logical)) |
    select((.Containers | type) == "object" and (.Containers | length) == 0) |
    select((.IPAM.Config | length) == 1 and
        .IPAM.Config[0].Subnet == $subnets[$logical] and $subnets[$logical] != null) |
    .Id' <<< "$networks")
while IFS= read -r network; do
    [[ -n "$network" ]] || continue
    # Docker checks again that the network has no attached containers.
    timeout -k 5s 15s docker network rm "$network"
done <<< "$candidates"
