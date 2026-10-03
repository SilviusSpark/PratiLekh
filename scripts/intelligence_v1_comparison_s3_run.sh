#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_build_dir=$(mktemp -d /tmp/pratilekh-v129-s3-run.XXXXXX)
trap 'rm -rf "$task_build_dir"' EXIT

# Intelligence V1.29 (S2) -- guarded S3 live runner. BUILT IN S2, NOT RUN IN S2. Refuses unless the approved plan
# hash matches, the tree is clean, --out is outside the repository and the running Ollama serves the S1-verified
# candidates (see ComparisonLiveRunner.swift). The source list below deliberately omits CapabilityCorpus.swift and every
# other file that can read the V1.23 benchmark: it is not compiled into this binary.
#   scripts/intelligence_v1_comparison_s3_run.sh --execute-plan SHA256 --out DIR [--run-label TEXT] [--preflight-only]
task_sources="
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
Evaluation/Intelligence/ComparisonExecution/ComparisonProvider.swift
"

# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_sources Evaluation/Intelligence/ComparisonExecution/ComparisonLiveRunner.swift \
    -o "$task_build_dir/v129-s3-run"
"$task_build_dir/v129-s3-run" "$@"
