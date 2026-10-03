#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_build_dir=$(mktemp -d /tmp/pratilekh-v130-posthoc.XXXXXX)
trap 'rm -rf "$task_build_dir"' EXIT

# Intelligence V1.30 -- S3 post-hoc detail dump (NON-PREREGISTERED, NON-SCORING). Same execution source set as the S3 analyzer;
# no model, no network, no LLMClient, no benchmark.
#   scripts/intelligence_v1_s3_posthoc.sh --records PATH [--write PATH]
task_sources="
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

# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_sources Evaluation/Intelligence/ComparisonPostHoc/S3PostHocDump.swift \
    -o "$task_build_dir/v130-posthoc"
"$task_build_dir/v130-posthoc" "$@"
