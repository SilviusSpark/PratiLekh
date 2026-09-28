#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-v1-4b-policy-tests.XXXXXX)

# EXPERIMENTAL -- Intelligence V1.4B architecture investigation only.
# Deterministic-only (no Ollama/model) tests for the Candidate B+C
# contradiction policies. Not part of the normal acceptance gate; run on
# demand only.

task_sources="
Evaluation/Intelligence/Experimental/V1_4_ModelFacingResolver.swift
Evaluation/Intelligence/Experimental/V1_4B_PolicyExperiments.swift
"

xcrun swiftc -parse-as-library $task_sources \
    Evaluation/Intelligence/Experimental/V14BResolverTests.swift \
    -o "$task_test_dir/V14BResolverTests"
"$task_test_dir/V14BResolverTests"
