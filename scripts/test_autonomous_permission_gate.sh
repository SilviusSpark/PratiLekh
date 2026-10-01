#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-autonomous-permission-gate-tests.XXXXXX)

# Intelligence V1.16 -- AutonomousPermissionGate. Two binaries:
#   1. Focused, isolated gate rule tests (Safety/ sources only).
#   2. Production-parity replay against the three FROZEN, READ-ONLY V1.14/V1.15
#      corpora (development.json, validation.json, fresh.json under
#      Evaluation/References/autonomous-edit-policy/) -- needs the LegalLanguage
#      sources too, for real normalization. This file never writes those corpora;
#      it only reads them and asserts the production gate reproduces the exact
#      aggregate counts already reported in the V1.14/V1.15 findings documents.

task_safety_sources="
Sources/Fluid/Intelligence/Safety/IntelligenceProposal.swift
Sources/Fluid/Intelligence/Safety/ProtectedSpan.swift
Sources/Fluid/Intelligence/Safety/IntelligenceEditClassifier.swift
Sources/Fluid/Intelligence/Safety/AutonomousPermissionGate.swift
Sources/Fluid/Intelligence/Safety/ProposalDisposition.swift
Sources/Fluid/Intelligence/Safety/IntelligenceSafetyAuthority.swift
"

# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_safety_sources \
    Tests/AutonomousPermissionGateTests.swift \
    -o "$task_test_dir/AutonomousPermissionGateTests"
"$task_test_dir/AutonomousPermissionGateTests"

task_parity_sources="
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
Sources/Fluid/Intelligence/Safety/ProtectedSpan.swift
Sources/Fluid/Intelligence/Safety/IntelligenceEditClassifier.swift
Sources/Fluid/Intelligence/Safety/AutonomousPermissionGate.swift
Sources/Fluid/Intelligence/Safety/ProposalDisposition.swift
Sources/Fluid/Intelligence/Safety/IntelligenceSafetyAuthority.swift
Sources/Fluid/Intelligence/Addressing/ModelFacingEdit.swift
Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingResolver.swift
Sources/Fluid/Intelligence/Provenance/ProtectedSpanDerivation.swift
Sources/Fluid/Intelligence/Protection/NumericStructuralProtection.swift
"

# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_parity_sources \
    Tests/AutonomousPermissionGateProductionParityTests.swift \
    -o "$task_test_dir/AutonomousPermissionGateProductionParityTests"
"$task_test_dir/AutonomousPermissionGateProductionParityTests"
