#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-legal-language-tests.XXXXXX)

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
Sources/Fluid/LegalLanguage/Normalization/WordTokenizer.swift
Sources/Fluid/LegalLanguage/Normalization/SpokenNumberParser.swift
Sources/Fluid/LegalLanguage/Normalization/StatuteRecognizer.swift
Sources/Fluid/LegalLanguage/Normalization/StatutoryProvisionReference.swift
Sources/Fluid/LegalLanguage/Normalization/StatutoryProvisionNormalizer.swift
Sources/Fluid/LegalLanguage/Normalization/WitnessReferenceNormalizer.swift
Sources/Fluid/LegalLanguage/LegalLanguageCoordinator.swift
Sources/Fluid/LegalLanguage/Packs/BuiltInPacks.swift
Sources/Fluid/LegalLanguage/LegalDictationProcessor.swift
"

for task_test_file in \
    Tests/LanguagePackTests.swift \
    Tests/PrecedenceResolverTests.swift \
    Tests/RecognitionVocabularyAdapterTests.swift \
    Tests/LookupTableNormalizerTests.swift \
    Tests/LegalLanguageCoordinatorTests.swift \
    Tests/SpokenNumberParserTests.swift \
    Tests/StatutoryProvisionNormalizerTests.swift \
    Tests/WitnessReferenceNormalizerTests.swift \
    Tests/LegalDictationProcessorTests.swift \
; do
    task_binary_name=$(basename "$task_test_file" .swift)
    # shellcheck disable=SC2086
    xcrun swiftc -parse-as-library $task_sources "$task_test_file" -o "$task_test_dir/$task_binary_name"
    "$task_test_dir/$task_binary_name"
done

# IndianLegalCorePackTests reads the production pack JSON directly (this
# standalone binary has no app bundle, so it can't use BuiltInPacks'
# Bundle.main lookup) -- pass the file's path as argv[1].
# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_sources Tests/IndianLegalCorePackTests.swift -o "$task_test_dir/IndianLegalCorePackTests"
"$task_test_dir/IndianLegalCorePackTests" "$(pwd)/Sources/Fluid/Resources/indian_legal_core.default.json"

# Structural checks for the live seam (ContentView cannot be built standalone).
# 1) legal normalization is invoked at exactly the two AI-bearing dictation
#    pipelines, 2) no AI call is fed the pre-legal text, 3) the ASR layer
#    (streaming preview, API, file transcription) never references it.
task_legal_calls=$(grep -c 'LegalDictationProcessor.shared.process(normalizedTranscribedText)' Sources/Fluid/ContentView.swift)
test "$task_legal_calls" -eq 2 || { echo "FAIL: expected 2 legal seam calls in ContentView, found $task_legal_calls"; exit 1; }
if grep -A1 'processTextWithAIMetrics(' Sources/Fluid/ContentView.swift | grep -q '^ *normalizedTranscribedText,'; then
    echo "FAIL: an AI call in ContentView receives pre-legal text"; exit 1
fi
if grep -rq 'LegalDictationProcessor' Sources/Fluid/Services; then
    echo "FAIL: LegalDictationProcessor must not be referenced from Services (ASR/streaming)"; exit 1
fi
echo "PASS: live seam structure (legal normalization precedes AI; ASR layer untouched)"

# Legal normalization vs. inherited first-letter formatters (GAAV, context-aware
# capitalization). The real formatter bodies are extracted verbatim from
# ASRService.swift so the test exercises production code, not a copy.
task_fmt_dir="$task_test_dir/formatting"
mkdir -p "$task_fmt_dir"
{
    echo "import Foundation"
    echo "extension ASRService {"
    awk '/MARK: - GAAV Mode Formatting/{f=1} f&&/^}$/{exit} f' Sources/Fluid/Services/ASRService.swift
    echo "}"
    awk '/^private extension Character \{/{f=1} f{print} f&&/^}$/{exit}' Sources/Fluid/Services/ASRService.swift
} > "$task_fmt_dir/ExtractedFormatters.swift"
grep -q 'func applyGAAVFormatting' "$task_fmt_dir/ExtractedFormatters.swift" || { echo "FAIL: could not extract GAAV formatter"; exit 1; }
grep -q 'func applyContinuousDictationFormatting' "$task_fmt_dir/ExtractedFormatters.swift" || { echo "FAIL: could not extract continuous formatter"; exit 1; }
# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_sources "$task_fmt_dir/ExtractedFormatters.swift" Tests/LegalFormattingInteractionTests.swift -o "$task_fmt_dir/LegalFormattingInteractionTests"
"$task_fmt_dir/LegalFormattingInteractionTests"

# Both ContentView pipelines (live stop and reprocess) must pass the protection
# fact to both formatters, and none of the four calls may omit it.
task_protect_calls=$(grep -c 'protectsLeadingCapitalization(of: finalText)' Sources/Fluid/ContentView.swift)
test "$task_protect_calls" -eq 4 || { echo "FAIL: expected 4 protectsLeadingCapitalization call sites in ContentView, found $task_protect_calls"; exit 1; }
if grep -q 'applyGAAVFormatting(finalText)' Sources/Fluid/ContentView.swift; then
    echo "FAIL: unprotected GAAV call on finalText in ContentView"; exit 1
fi
echo "PASS: ContentView live and reprocess pipelines protect legal leading capitalization"
