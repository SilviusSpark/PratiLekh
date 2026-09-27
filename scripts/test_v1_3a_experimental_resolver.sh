#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-v1-3a-resolver-tests.XXXXXX)

# EXPERIMENTAL -- Intelligence V1.3A architecture investigation only. Runs
# the deterministic-addressing resolver prototype under
# Evaluation/Intelligence/Experimental/, NOT the committed V1.0/V1.1/V1.2
# code. Not part of the normal acceptance gate; run on demand only.

task_sources="
Evaluation/Intelligence/Experimental/DeterministicAddressingResolver.swift
"

xcrun swiftc -parse-as-library $task_sources \
    Evaluation/Intelligence/Experimental/ResolverPrototypeTests.swift \
    -o "$task_test_dir/ResolverPrototypeTests"
"$task_test_dir/ResolverPrototypeTests"
