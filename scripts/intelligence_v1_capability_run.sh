#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_build_dir=$(mktemp -d /tmp/pratilekh-v123-capability-run.XXXXXX)
trap 'rm -rf "$task_build_dir"' EXIT

# Intelligence V1.23 -- Frozen Capability Evaluation: LIVE runner. NOT TO BE RUN WITHOUT
# EXPLICIT ARCHITECT AUTHORIZATION (V1.23B). It refuses to run unless --execute-manifest equals the
# manifest hash recomputed from the repository (obtain it from
# scripts/intelligence_v1_capability_preflight.sh), the working tree is clean, every preflight
# check passes, and the running Ollama matches the frozen version/model digest.
# Built (compiled) in V1.23A; never executed there.
#   scripts/intelligence_v1_capability_run.sh --execute-manifest SHA256 --out DIR [--run-label TEXT]
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
Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponse+LLMClientBridge.swift
Sources/Fluid/Intelligence/Generation/ModelFacingGenerationContract.swift
Sources/Fluid/Intelligence/Generation/ModelFacingResponseAdapter.swift
Sources/Fluid/Intelligence/Addressing/ModelFacingEdit.swift
Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingResolver.swift
Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingBridge.swift
Sources/Fluid/Intelligence/Composition/IntelligenceEditComposition.swift
Sources/Fluid/Intelligence/Provenance/ProtectedSpanDerivation.swift
Sources/Fluid/Intelligence/Protection/NumericStructuralProtection.swift
Sources/Fluid/Services/FileLogger.swift
Sources/Fluid/Services/DebugLogger.swift
Sources/Fluid/Services/ThinkingParsers.swift
Sources/Fluid/Services/LLMClient.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessTypes.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessPipeline.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessLegalPack.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessReportFormatter.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessProvider.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityCorpus.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityAdjudication.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityMetrics.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityEvaluationDriver.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityManifest.swift
Evaluation/Intelligence/CapabilityEvaluation/CapabilityReport.swift
"

# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_sources Evaluation/Intelligence/CapabilityEvaluation/CapabilityLiveRunner.swift \
    -o "$task_build_dir/v123-capability-run"
"$task_build_dir/v123-capability-run" "$@"
