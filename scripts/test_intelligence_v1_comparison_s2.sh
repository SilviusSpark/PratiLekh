#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-v129-s2-tests.XXXXXX)
trap 'rm -rf "$task_test_dir"' EXIT

# Intelligence V1.29 (S2) -- tests for the comparison execution tooling. Offline and deterministic: no Ollama, no model,
# no network. Three parts:
#   A. execution build (the exact source set of the S3 runner, minus the LLMClient-linked files): mechanics, isolation,
#      scoring, analysis, plan -- run with synthetic tooling fixtures only;
#   B. parity build (the real frozen scoring code, V1.25 evaluator, harness provider and LLMClient): scoring parity,
#      request parity, shadow-type parity, fixture/corpus disjointness. Never part of the execution path;
#   C. negative-compile checks proving the execution build cannot name the V1.23 benchmark loader or its artifacts.
#   scripts/test_intelligence_v1_comparison_s2.sh [--write-plan]
exec_sources="
Sources/Fluid/LegalLanguage/Packs/LanguagePack.swift
Sources/Fluid/LegalLanguage/Packs/PackLoader.swift
Sources/Fluid/LegalLanguage/Packs/PackRepository.swift
Sources/Fluid/LegalLanguage/Resolution/ResolvedLanguageResources.swift
Sources/Fluid/LegalLanguage/Resolution/PrecedenceResolver.swift
Sources/Fluid/LegalLanguage/Recognition/ProviderRecognitionCapability.swift
Sources/Fluid/LegalLanguage/Recognition/ProviderCapabilityResolver.swift
Sources/Fluid/LegalLanguage/Recognition/RecognitionVocabularyAdapter.swift
Sources/Fluid/LegalLanguage/Normalization/NormalizationContext.swift
Sources/Fluid/LegalLanguage/Normalization/LegalNormalizer.swift
Sources/Fluid/LegalLanguage/Normalization/LookupTableNormalizer.swift
Sources/Fluid/LegalLanguage/Normalization/NormalizationOutcome.swift
Sources/Fluid/LegalLanguage/Normalization/NormalizationReplay.swift
Sources/Fluid/LegalLanguage/Normalization/WordTokenizer.swift
Sources/Fluid/LegalLanguage/Normalization/SpokenNumberParser.swift
Sources/Fluid/LegalLanguage/Normalization/StatuteRecognizer.swift
Sources/Fluid/LegalLanguage/Normalization/StatutoryProvisionReference.swift
Sources/Fluid/LegalLanguage/Normalization/StatutoryProvisionNormalizer.swift
Sources/Fluid/LegalLanguage/Normalization/WitnessReferenceNormalizer.swift
Sources/Fluid/LegalLanguage/LegalLanguageCoordinator.swift
Sources/Fluid/LegalLanguage/Packs/BuiltInPacks.swift
Sources/Fluid/LegalLanguage/LegalDictationProcessor.swift
Sources/Fluid/Intelligence/Safety/IntelligenceProposal.swift
Sources/Fluid/Intelligence/Safety/AutonomousPermissionGate.swift
Sources/Fluid/Intelligence/Safety/ProtectedSpan.swift
Sources/Fluid/Intelligence/Safety/IntelligenceEditClassifier.swift
Sources/Fluid/Intelligence/Safety/ProposalDisposition.swift
Sources/Fluid/Intelligence/Safety/IntelligenceSafetyAuthority.swift
Sources/Fluid/Intelligence/Transport/RawJSONObjectKeyScanner.swift
Sources/Fluid/Intelligence/Transport/IntelligenceProposalTransportParser.swift
Sources/Fluid/Intelligence/Transport/ModelFacingEditTransportParser.swift
Sources/Fluid/Intelligence/Generation/IntelligenceGenerationContract.swift
Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponse.swift
Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponseAdapter.swift
Sources/Fluid/Intelligence/Generation/ModelFacingGenerationContract.swift
Sources/Fluid/Intelligence/Generation/ModelFacingResponseAdapter.swift
Sources/Fluid/Intelligence/Addressing/ModelFacingEdit.swift
Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingResolver.swift
Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingBridge.swift
Sources/Fluid/Intelligence/Composition/IntelligenceEditComposition.swift
Sources/Fluid/Intelligence/Provenance/ProtectedSpanDerivation.swift
Sources/Fluid/Intelligence/Protection/NumericStructuralProtection.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessTypes.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessPipeline.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessLegalPack.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityAdjudication.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityMetrics.swift
Evaluation/Intelligence/CapabilitySupplementary/SupplementaryOutcome.swift
Evaluation/Intelligence/ComparisonProtocol/ComparisonCorpus.swift
Evaluation/Intelligence/ComparisonProtocol/ComparisonFixtures.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonExecutionEntryTypes.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonExecutionPlan.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonExecutionRecords.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonExecutor.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonScoring.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonAnalysis.swift
"
parity_sources="
Sources/Fluid/Services/FileLogger.swift
Sources/Fluid/Services/DebugLogger.swift
Sources/Fluid/Services/ThinkingParsers.swift
Sources/Fluid/Services/LLMClient.swift
Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponse+LLMClientBridge.swift
Sources/Fluid/LegalLanguage/Packs/LanguagePack.swift
Sources/Fluid/LegalLanguage/Packs/PackLoader.swift
Sources/Fluid/LegalLanguage/Packs/PackRepository.swift
Sources/Fluid/LegalLanguage/Resolution/ResolvedLanguageResources.swift
Sources/Fluid/LegalLanguage/Resolution/PrecedenceResolver.swift
Sources/Fluid/LegalLanguage/Recognition/ProviderRecognitionCapability.swift
Sources/Fluid/LegalLanguage/Recognition/ProviderCapabilityResolver.swift
Sources/Fluid/LegalLanguage/Recognition/RecognitionVocabularyAdapter.swift
Sources/Fluid/LegalLanguage/Normalization/NormalizationContext.swift
Sources/Fluid/LegalLanguage/Normalization/LegalNormalizer.swift
Sources/Fluid/LegalLanguage/Normalization/LookupTableNormalizer.swift
Sources/Fluid/LegalLanguage/Normalization/NormalizationOutcome.swift
Sources/Fluid/LegalLanguage/Normalization/NormalizationReplay.swift
Sources/Fluid/LegalLanguage/Normalization/WordTokenizer.swift
Sources/Fluid/LegalLanguage/Normalization/SpokenNumberParser.swift
Sources/Fluid/LegalLanguage/Normalization/StatuteRecognizer.swift
Sources/Fluid/LegalLanguage/Normalization/StatutoryProvisionReference.swift
Sources/Fluid/LegalLanguage/Normalization/StatutoryProvisionNormalizer.swift
Sources/Fluid/LegalLanguage/Normalization/WitnessReferenceNormalizer.swift
Sources/Fluid/LegalLanguage/LegalLanguageCoordinator.swift
Sources/Fluid/LegalLanguage/Packs/BuiltInPacks.swift
Sources/Fluid/LegalLanguage/LegalDictationProcessor.swift
Sources/Fluid/Intelligence/Safety/IntelligenceProposal.swift
Sources/Fluid/Intelligence/Safety/AutonomousPermissionGate.swift
Sources/Fluid/Intelligence/Safety/ProtectedSpan.swift
Sources/Fluid/Intelligence/Safety/IntelligenceEditClassifier.swift
Sources/Fluid/Intelligence/Safety/ProposalDisposition.swift
Sources/Fluid/Intelligence/Safety/IntelligenceSafetyAuthority.swift
Sources/Fluid/Intelligence/Transport/RawJSONObjectKeyScanner.swift
Sources/Fluid/Intelligence/Transport/IntelligenceProposalTransportParser.swift
Sources/Fluid/Intelligence/Transport/ModelFacingEditTransportParser.swift
Sources/Fluid/Intelligence/Generation/IntelligenceGenerationContract.swift
Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponse.swift
Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponseAdapter.swift
Sources/Fluid/Intelligence/Generation/ModelFacingGenerationContract.swift
Sources/Fluid/Intelligence/Generation/ModelFacingResponseAdapter.swift
Sources/Fluid/Intelligence/Addressing/ModelFacingEdit.swift
Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingResolver.swift
Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingBridge.swift
Sources/Fluid/Intelligence/Composition/IntelligenceEditComposition.swift
Sources/Fluid/Intelligence/Provenance/ProtectedSpanDerivation.swift
Sources/Fluid/Intelligence/Protection/NumericStructuralProtection.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessTypes.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessPipeline.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessLegalPack.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessProvider.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityCorpus.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityAdjudication.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityMetrics.swift
Evaluation/Intelligence/CapabilitySupplementary/SupplementaryOutcome.swift
Evaluation/Intelligence/CapabilitySupplementary/SupplementaryEvaluator.swift
Evaluation/Intelligence/ComparisonProtocol/ComparisonCorpus.swift
Evaluation/Intelligence/ComparisonProtocol/ComparisonFixtures.swift
Evaluation/Intelligence/ComparisonProtocol/ComparisonOverlap.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonExecutionPlan.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonExecutionRecords.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonExecutor.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonScoring.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonAnalysis.swift
Evaluation/Intelligence/ComparisonExecution/ComparisonProvider.swift
"

# A. execution build.
# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $exec_sources Tests/IntelligenceV1ComparisonS2Fixtures.swift Tests/IntelligenceV1ComparisonS2Tests.swift -o "$task_test_dir/v129-s2-exec-tests"
"$task_test_dir/v129-s2-exec-tests" "$@"

# B. parity build (real frozen scoring code and LLMClient; compares, never executes a model).
# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $parity_sources Tests/IntelligenceV1ComparisonS2Fixtures.swift Tests/IntelligenceV1ComparisonS2ParityTests.swift -o "$task_test_dir/v129-s2-parity-tests"
"$task_test_dir/v129-s2-parity-tests"

# C. negative compiles: each probe must FAIL to type-check against the execution source set.
probe() {
    printf '%s\n' "import Foundation" "func probe() { $1 }" > "$task_test_dir/probe.swift"
    # shellcheck disable=SC2086
    if xcrun swiftc -typecheck -parse-as-library $exec_sources "$task_test_dir/probe.swift" >/dev/null 2>&1; then
        echo "FAIL: the execution build can reference: $1" >&2
        exit 1
    fi
}
probe '_ = CapabilityCorpus.load'
probe '_ = CapabilityCorpus.frozenSHA256'
probe '_ = CapabilityCorpus.relativePath'
probe '_ = CapabilityCorpus.frozenEntryCount'
probe '_ = SupplementaryArtifacts.directory'
probe '_ = CapabilityRunManifest.self'
probe '_ = CapabilityFrozenRun.modelName'
probe '_ = CapabilityPreflight.self'
probe '_ = ComparisonFreeze.directory'
probe '_ = ComparisonOverlap.self'
# Positive control: the same harness compiles when the probe names something that does exist.
printf '%s\n' "import Foundation" "func probe() { _ = ComparisonCorpus.frozenSHA256 }" > "$task_test_dir/probe.swift"
# shellcheck disable=SC2086
xcrun swiftc -typecheck -parse-as-library $exec_sources "$task_test_dir/probe.swift"
echo "PASS: 10 negative-compile probes failed to type-check against the execution build (positive control compiled)"
