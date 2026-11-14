#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
IOS_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tracker-list-regressions.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -swift-version 6 -default-isolation MainActor -parse-as-library \
    -module-cache-path "$TEST_DIR/module-cache" \
    "$IOS_DIR/Tracker/Models/MediaType.swift" \
    "$IOS_DIR/Tracker/Models/APIModels.swift" \
    "$IOS_DIR/Tracker/ViewModels/ListDetailViewModel.swift" \
    "$SCRIPT_DIR/RegressionTests.swift" \
    -o "$TEST_DIR/list-regressions"
"$TEST_DIR/list-regressions"
