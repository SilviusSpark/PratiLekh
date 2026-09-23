import Foundation

/// End-to-end proof of the complete Phase 1 flow using fixture packs:
/// fixture pack -> loading/repository -> precedence resolution ->
/// recognition adaptation -> deterministic normalization -> NormalizationOutcome.
@main
enum LegalLanguageCoordinatorTests {
    static func main() {
        testFullFlowFromFixtureJSONThroughNormalization()
        testFullFlowWithMixedAppliedAndDeclinedChanges()
        testRecognitionHintAdaptsThroughRepositoryAndResolver()
        testUnknownProviderNameYieldsNoHint()
        print("PASS: LegalLanguageCoordinator end-to-end fixture-pack flow")
    }

    private static func fixtureData(_ json: String) -> Data {
        Data(json.utf8)
    }

    private static func testFullFlowFromFixtureJSONThroughNormalization() {
        let builtinJSON = """
        {
          "id": "fixture.builtin",
          "version": "1.0.0",
          "kind": "builtin",
          "displayName": "Fixture Builtin",
          "recognitionEntries": [{"canonical": "BNS", "aliases": ["bee en es"]}],
          "normalizationEntries": [{"trigger": "sec.", "canonicalReplacement": "Section"}]
        }
        """
        let userJSON = """
        {
          "id": "fixture.user",
          "version": "1.0.0",
          "kind": "user",
          "displayName": "Fixture User",
          "recognitionEntries": [],
          "normalizationEntries": [{"trigger": "distt.", "canonicalReplacement": "District"}]
        }
        """

        guard let builtinPack = try? PackLoader.load(from: fixtureData(builtinJSON)),
              let userPack = try? PackLoader.load(from: fixtureData(userJSON))
        else {
            preconditionFailure("Expected both fixture packs to load")
        }

        let repository = PackRepository()
        repository.add(builtinPack)
        repository.add(userPack)

        let coordinator = LegalLanguageCoordinator(repository: repository)
        let outcome = coordinator.normalize("see sec. 302, distt. court")

        precondition(outcome.recognized == "see sec. 302, distt. court", "Original recognizer input must be preserved")
        precondition(outcome.normalized == "see Section 302, District court")
        precondition(outcome.appliedChanges.count == 2)
        precondition(outcome.declinedChanges.isEmpty)
        precondition(!outcome.isUnchanged)
    }

    private static func testFullFlowWithMixedAppliedAndDeclinedChanges() {
        // Two jurisdiction packs disagree on "distt." (same rank, different
        // value) while agreeing there's no ambiguity about "sec.". The
        // resulting outcome must apply the safe change and separately
        // record the declined one -- not decline the whole call.
        let builtinPack = LanguagePack(
            id: "fixture.builtin", version: "1.0.0", kind: .builtin, displayName: "Fixture Builtin",
            recognitionEntries: [],
            normalizationEntries: [NormalizationEntry(trigger: "sec.", canonicalReplacement: "Section")]
        )
        let jurisdictionA = LanguagePack(
            id: "fixture.jurisdiction-a", version: "1.0.0", kind: .jurisdiction, displayName: "A",
            recognitionEntries: [],
            normalizationEntries: [NormalizationEntry(trigger: "distt.", canonicalReplacement: "District")]
        )
        let jurisdictionB = LanguagePack(
            id: "fixture.jurisdiction-b", version: "1.0.0", kind: .jurisdiction, displayName: "B",
            recognitionEntries: [],
            normalizationEntries: [NormalizationEntry(trigger: "distt.", canonicalReplacement: "Dist.")]
        )

        let repository = PackRepository()
        repository.add(builtinPack)
        repository.add(jurisdictionA)
        repository.add(jurisdictionB)

        let coordinator = LegalLanguageCoordinator(repository: repository)
        let outcome = coordinator.normalize("sec. 302, distt. court")

        precondition(outcome.normalized == "Section 302, distt. court", "Safe change applied, conflicted one left as-is")
        precondition(outcome.appliedChanges.count == 1 && outcome.appliedChanges[0].trigger == "sec.")
        precondition(outcome.declinedChanges.count == 1 && outcome.declinedChanges[0].trigger == "distt.")
    }

    private static func testRecognitionHintAdaptsThroughRepositoryAndResolver() {
        let repository = PackRepository()
        repository.add(
            LanguagePack(
                id: "fixture.builtin",
                version: "1.0.0",
                kind: .builtin,
                displayName: "Fixture Builtin",
                recognitionEntries: [RecognitionEntry(canonical: "BNS", aliases: ["bee en es"])],
                normalizationEntries: []
            )
        )
        let coordinator = LegalLanguageCoordinator(repository: repository)

        guard case let .terms(terms) = coordinator.recognitionHint(forProviderNamed: "FluidAudio (Apple Silicon Optimized)") else {
            preconditionFailure("Expected the real FluidAudio provider name to receive a weighted term list hint")
        }
        precondition(terms.map(\.text) == ["BNS"])

        // A real provider name with no confirmed hint mechanism must safely
        // yield no hint at all, not a fabricated one.
        precondition(coordinator.recognitionHint(forProviderNamed: "Whisper (Universal)") == .none)
    }

    private static func testUnknownProviderNameYieldsNoHint() {
        let repository = PackRepository()
        repository.add(
            LanguagePack(
                id: "fixture.builtin",
                version: "1.0.0",
                kind: .builtin,
                displayName: "Fixture Builtin",
                recognitionEntries: [RecognitionEntry(canonical: "BNS", aliases: [])],
                normalizationEntries: []
            )
        )
        let coordinator = LegalLanguageCoordinator(repository: repository)
        precondition(coordinator.recognitionHint(forProviderNamed: "Some Future Engine") == .none)
    }
}
