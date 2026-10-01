#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-intelligence-harness-tests.XXXXXX)

# Intelligence V1.17 -- Controlled Local-Model Integration Harness: the
# deterministic, model-free self-test required before any substantive
# model-quality evaluation (see Evaluation/Intelligence/Harness/). Needs the
# LegalLanguage sources (real normalization) and the full Intelligence chain
# (Safety/Transport/Generation/Addressing/Composition/Provenance/Protection),
# plus the harness's own pipeline/types/fixtures/formatter/legal-pack files.
# Deliberately does NOT link LLMClient/DebugLogger/FileLogger/ThinkingParsers
# -- this is the harness-plumbing gate, independent of any real provider; see
# scripts/intelligence_harness_run.sh for the live-model-capable runner.
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
Evaluation/Intelligence/Harness/IntelligenceHarnessFixtures.swift
Evaluation/Intelligence/Harness/IntelligenceHarnessReportFormatter.swift
"

# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_sources Tests/IntelligenceHarnessPipelineTests.swift \
    -o "$task_test_dir/IntelligenceHarnessPipelineTests"
"$task_test_dir/IntelligenceHarnessPipelineTests"
