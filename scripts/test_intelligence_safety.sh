#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-intelligence-safety-tests.XXXXXX)

task_sources="
Sources/Fluid/Intelligence/Safety/IntelligenceProposal.swift
Sources/Fluid/Intelligence/Safety/AutonomousPermissionGate.swift
Sources/Fluid/Intelligence/Safety/ProtectedSpan.swift
Sources/Fluid/Intelligence/Safety/IntelligenceEditClassifier.swift
Sources/Fluid/Intelligence/Safety/ProposalDisposition.swift
Sources/Fluid/Intelligence/Safety/IntelligenceSafetyAuthority.swift
Sources/Fluid/Intelligence/Transport/RawJSONObjectKeyScanner.swift
Sources/Fluid/Intelligence/Transport/IntelligenceProposalTransportParser.swift
Sources/Fluid/Intelligence/Generation/IntelligenceGenerationContract.swift
Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponse.swift
Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponseAdapter.swift
Sources/Fluid/Intelligence/Addressing/ModelFacingEdit.swift
Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingResolver.swift
Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingBridge.swift
Sources/Fluid/Intelligence/Transport/ModelFacingEditTransportParser.swift
Sources/Fluid/Intelligence/Generation/ModelFacingGenerationContract.swift
Sources/Fluid/Intelligence/Generation/ModelFacingResponseAdapter.swift
Sources/Fluid/Intelligence/Composition/IntelligenceEditComposition.swift
"

for task_test_file in \
    Tests/EditClassificationTests.swift \
    Tests/IntelligenceSafetyAuthorityTests.swift \
    Tests/IntelligenceProposalTransportParserTests.swift \
    Tests/IntelligenceGenerationContractTests.swift \
    Tests/IntelligenceProviderResponseAdapterTests.swift \
    Tests/IntelligenceAddressingResolverTests.swift \
    Tests/IntelligenceAddressingBridgeTests.swift \
    Tests/ModelFacingEditTransportParserTests.swift \
    Tests/ModelFacingGenerationContractTests.swift \
    Tests/ModelFacingResponseAdapterTests.swift \
    Tests/IntelligenceEditCompositionTests.swift \
; do
    task_binary_name=$(basename "$task_test_file" .swift)
    # shellcheck disable=SC2086
    xcrun swiftc -parse-as-library $task_sources "$task_test_file" -o "$task_test_dir/$task_binary_name"
    "$task_test_dir/$task_binary_name"
done
