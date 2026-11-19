#!/usr/bin/env bash
set -euo pipefail

ausf=free5gc/NFs/ausf
api=free5gc/openapi-token-diagnostic
patches="$PWD/test/patches"
[[ "$(git -C "$ausf" rev-parse HEAD)" == fa367119a4a24e5beda9b9049b18c47645f81745 ]]
git init -q "$api"
git -C "$api" fetch --depth=1 https://github.com/free5gc/openapi.git 7fad8e868cb23863719dea4b43db36ef54655454
git -C "$api" checkout --detach FETCH_HEAD
git -C "$api" apply "$patches/openapi-token-diagnostic.patch"
git -C "$ausf" apply "$patches/ausf-token-diagnostic.patch"
