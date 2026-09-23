import Foundation

/// Validates the production Indian Legal Core pack JSON. Run via
/// scripts/test_legal_language.sh, which passes the pack's file path as
/// CommandLine.arguments[1] -- this standalone test binary has no app
/// bundle, so it reads the JSON file directly rather than exercising
/// BuiltInPacks' Bundle.main lookup (that thin glue is exercised by running
/// the real app, not by this harness).
@main
enum IndianLegalCorePackTests {
    static func main() {
        guard CommandLine.arguments.count > 1 else {
            fatalError("Expected the indian_legal_core.default.json path as argv[1]")
        }
        let path = CommandLine.arguments[1]
        guard let data = FileManager.default.contents(atPath: path) else {
            fatalError("Could not read pack file at \(path)")
        }

        let pack = testLoadsAndValidates(data)
        testRepresentativeTermsPresentAcrossCategories(pack)
        testExcludedAppellateTermsAbsent(pack)
        testNoSpeculativePhoneticAliases(pack)
        testCurrentAndLegacyStatutesCoexistWithoutConversion(pack)
        testWrittenVariantsResolveAsIntended(pack)
        testResolvesThroughPhase1Architecture(pack)

        print("PASS: Indian Legal Core pack loads, validates, and matches the approved corpus")
    }

    private static func testLoadsAndValidates(_ data: Data) -> LanguagePack {
        guard let pack = try? PackLoader.load(from: data) else {
            fatalError("Expected the production pack to load and pass schema/version validation")
        }
        precondition(pack.id == "indian-legal-core")
        precondition(pack.kind == .builtin)
        precondition(pack.version == "1.0.0")
        return pack
    }

    private static func canonicals(_ pack: LanguagePack) -> Set<String> {
        Set(pack.recognitionEntries.map(\.canonical))
    }

    private static func allAliases(_ pack: LanguagePack) -> [String] {
        pack.recognitionEntries.flatMap(\.aliases)
    }

    private static func testRepresentativeTermsPresentAcrossCategories(_ pack: LanguagePack) {
        let names = canonicals(pack)
        let representative = [
            "Bharatiya Nyaya Sanhita, 2023", "Bharatiya Nagarik Suraksha Sanhita, 2023", "Bharatiya Sakshya Adhiniyam, 2023",
            "Indian Penal Code, 1860", "Code of Criminal Procedure, 1973", "Indian Evidence Act, 1872",
            "Code of Civil Procedure, 1908", "Plaint", "Decree", "Res judicata",
            "Cognizance", "First Information Report", "Charge-sheet", "Anticipatory bail", "Case diary", "Panchnama",
            "Prosecution Witness", "Defence Witness", "Station House Officer",
            "Suo motu", "Prima facie", "Bona fide",
        ]
        for term in representative {
            precondition(names.contains(term), "Expected representative term '\(term)' in the production pack")
        }
        precondition(pack.recognitionEntries.count == 77, "Expected exactly the approved 77-entry corpus, found \(pack.recognitionEntries.count)")
    }

    private static func testExcludedAppellateTermsAbsent(_ pack: LanguagePack) {
        let names = canonicals(pack)
        let allText = Set(names).union(allAliases(pack))
        let excluded = [
            "Ratio decidendi", "Obiter dictum", "Obiter dicta", "Stare decisis", "De novo",
            "Review petition", "Curative petition", "Cross-objection", "First appeal",
            "In limine", "Ipso facto", "Ld.", "IEA",
        ]
        for term in excluded {
            precondition(!allText.contains(term), "Excluded/deferred term '\(term)' must not appear in the production pack")
        }
    }

    private static func testNoSpeculativePhoneticAliases(_ pack: LanguagePack) {
        let bannedPhoneticAliases = [
            "bee en es", "bee en es es", "bee es ay", "eye pea sea", "cr pea sea", "sea pea sea",
            "eff eye are", "eye oh", "en bee double-u", "eye ay", "pea double-u", "dee double-u", "ess aitch oh",
        ]
        let aliases = Set(allAliases(pack))
        for banned in bannedPhoneticAliases {
            precondition(!aliases.contains(banned), "Speculative phonetic alias '\(banned)' must not be encoded")
        }
        // General shape check: no alias should contain "double-u" (a phonetic
        // spelling artifact), since every real abbreviation in this corpus is
        // a short written form, not a spelled-out pronunciation.
        precondition(!aliases.contains { $0.contains("double-u") })
    }

    private static func testCurrentAndLegacyStatutesCoexistWithoutConversion(_ pack: LanguagePack) {
        let names = canonicals(pack)
        precondition(names.contains("Bharatiya Nyaya Sanhita, 2023") && names.contains("Indian Penal Code, 1860"))
        precondition(names.contains("Bharatiya Nagarik Suraksha Sanhita, 2023") && names.contains("Code of Criminal Procedure, 1973"))
        precondition(names.contains("Bharatiya Sakshya Adhiniyam, 2023") && names.contains("Indian Evidence Act, 1872"))
        precondition(pack.normalizationEntries.isEmpty, "Phase 2 ships zero normalization entries -- in particular, no current<->legacy statute conversion mapping")
    }

    private static func testWrittenVariantsResolveAsIntended(_ pack: LanguagePack) {
        func aliases(for canonical: String) -> [String] {
            pack.recognitionEntries.first { $0.canonical == canonical }?.aliases ?? []
        }
        precondition(Set(aliases(for: "Charge-sheet")) == Set(["chargesheet", "charge sheet"]))
        precondition(aliases(for: "Panchnama") == ["panchanama"])
        precondition(aliases(for: "Suo motu") == ["suo moto"])
        precondition(aliases(for: "Bharatiya Nyaya Sanhita, 2023") == ["BNS"])
        precondition(aliases(for: "Prosecution Witness") == ["PW"])
        precondition(aliases(for: "Exhibit") == ["Ex."])
    }

    private static func testResolvesThroughPhase1Architecture(_ pack: LanguagePack) {
        // End-to-end proof that the built-in pack flows through the same
        // Phase 1 resolver/coordinator machinery as any other pack.
        let repository = PackRepository(packs: [pack])
        let coordinator = LegalLanguageCoordinator(repository: repository)

        let vocabulary = PrecedenceResolver.resolveRecognitionVocabulary(from: repository.packs)
        precondition(vocabulary.entries.count == 77)

        let outcome = coordinator.normalize("the accused filed for anticipatory bail")
        precondition(outcome.recognized == outcome.normalized, "Zero normalization entries means text always passes through unchanged")
        precondition(outcome.isUnchanged)
    }
}
