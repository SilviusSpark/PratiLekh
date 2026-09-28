#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-v1-4-resolver-tests.XXXXXX)

# EXPERIMENTAL -- Intelligence V1.4 architecture investigation only. Runs
# the model-facing proposal resolver prototype under
# Evaluation/Intelligence/Experimental/ against the REAL, unmodified
# committed V1.0 Safety Authority sources. Requires no Ollama/model --
# deterministic only. Not part of the normal acceptance gate; run on
# demand only.

task_sources="
Evaluation/Intelligence/Experimental/V1_4_ModelFacingResolver.swift
Sources/Fluid/Intelligence/Safety/IntelligenceProposal.swift
Sources/Fluid/Intelligence/Safety/ProtectedSpan.swift
Sources/Fluid/Intelligence/Safety/IntelligenceEditClassifier.swift
Sources/Fluid/Intelligence/Safety/ProposalDisposition.swift
Sources/Fluid/Intelligence/Safety/IntelligenceSafetyAuthority.swift
"

xcrun swiftc -parse-as-library $task_sources \
    Evaluation/Intelligence/Experimental/V14ResolverTests.swift \
    -o "$task_test_dir/V14ResolverTests"
"$task_test_dir/V14ResolverTests"
