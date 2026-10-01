#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-autonomous-edit-policy-investigation.XXXXXX)

# EXPERIMENTAL -- Intelligence V1.14/V1.15 investigation only. Deterministic, model-free.
# Not part of the normal acceptance gate; run on demand:
#   scripts/test_autonomous_edit_policy_investigation.sh
# It needs the LegalLanguage sources (real normalization), the Intelligence chain
# (classifier, Authority, resolver, V1.11 derivation, V1.13 numeric protection).
#
# ARCHIVED PRE-V1.16 MEASUREMENT: this script's pinned `precondition`s (including
# the fresh-tier V1.15 additions) were measured against the classifier/Authority
# as it existed before V1.16 added AutonomousPermissionGate. Since that gate
# shipped, this script's pinned numbers no longer match -- expected, not a
# regression; see Evaluation/Intelligence/V1_16_AUTONOMOUS_PERMISSION_GATE.md
# section 6. Do not repin this script's expectations against current behavior;
# the current, authoritative measurement is scripts/test_autonomous_permission_gate.sh.

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
Sources/Fluid/Intelligence/Addressing/ModelFacingEdit.swift
Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingResolver.swift
Sources/Fluid/Intelligence/Provenance/ProtectedSpanDerivation.swift
Sources/Fluid/Intelligence/Protection/NumericStructuralProtection.swift
Evaluation/Intelligence/Experimental/AutonomousEditInvariants.swift
"

# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_sources \
    Evaluation/Intelligence/Experimental/AutonomousEditPolicyInvestigation.swift \
    -o "$task_test_dir/AutonomousEditPolicyInvestigation"
"$task_test_dir/AutonomousEditPolicyInvestigation"
