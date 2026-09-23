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
Sources/Fluid/LegalLanguage/Normalization/LegalNormalizer.swift
Sources/Fluid/LegalLanguage/Normalization/LookupTableNormalizer.swift
Sources/Fluid/LegalLanguage/Normalization/NormalizationOutcome.swift
Sources/Fluid/LegalLanguage/LegalLanguageCoordinator.swift
"

for task_test_file in \
    Tests/LanguagePackTests.swift \
    Tests/PrecedenceResolverTests.swift \
    Tests/RecognitionVocabularyAdapterTests.swift \
    Tests/LookupTableNormalizerTests.swift \
    Tests/LegalLanguageCoordinatorTests.swift \
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
