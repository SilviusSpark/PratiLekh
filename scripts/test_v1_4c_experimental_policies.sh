#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-v1-4c-policy-tests.XXXXXX)

# EXPERIMENTAL -- Intelligence V1.4C architecture investigation only.
# Deterministic-only (no Ollama/model) adversarial matrix (A1-A20) for the
# precise P3 decision procedure. Not part of the normal acceptance gate;
# run on demand only.

task_sources="
Evaluation/Intelligence/Experimental/V1_4_ModelFacingResolver.swift
Evaluation/Intelligence/Experimental/V1_4C_P3Adversarial.swift
"

xcrun swiftc -parse-as-library $task_sources \
    Evaluation/Intelligence/Experimental/V14CResolverTests.swift \
    -o "$task_test_dir/V14CResolverTests"
"$task_test_dir/V14CResolverTests"
