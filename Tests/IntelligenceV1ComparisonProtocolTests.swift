import Foundation

/// Intelligence V1.27 -- Model Comparison Development Corpus & Protocol.
///
/// Offline, deterministic verification of the pre-registered comparison artifacts: corpus integrity,
/// real-pipeline premises, disjointness from the frozen V1.23 benchmark (each prohibited-overlap rule
/// is also shown to fire on injected violations), stored-hazard containment, contract baseline/variant
/// identity, candidate registry, protocol structure and determinism. No model, no Ollama, no network,
/// no download. Run via `scripts/test_intelligence_v1_comparison_protocol.sh`.
@main
enum IntelligenceV1ComparisonProtocolTests {
    static func main() throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
        let corpus = try ComparisonCorpus.load(from: repoRoot.appendingPathComponent(ComparisonCorpus.relativePath))
        let frozen = try CapabilityCorpus.load(from: repoRoot.appendingPathComponent(CapabilityCorpus.relativePath))
        self.testCorpusIntegrity(repoRoot, corpus)
        self.testRealPipelinePremises(corpus, processor)
        self.testOverlapRulesFireAndRealCorpusIsDisjoint(repoRoot, corpus, frozen)
        try self.testHazardFixtures(repoRoot, corpus, processor)
        try self.testContractCandidatesAndProtocol(repoRoot, corpus)
        try self.testManifestIsDeterministicAndCommitted(repoRoot, corpus, frozen, processor)
        self.testStaticGuards(repoRoot)
        print("PASS: Intelligence V1.27 comparison corpus/protocol freeze -- all offline checks passed (no model, no network, no download)")
    }

    // MARK: - Helpers

    private static func entry(
        _ id: String, _ text: String, corrections: [(String, String)] = [], category: String = "capitalization-correction-warranted", expectation: String = "correctionWarranted"
    ) -> CapabilityCorpus.Entry {
        let list = corrections.map { "{\"source\":\(self.json($0.0)),\"replacement\":\(self.json($0.1))}" }.joined(separator: ",")
        let raw = """
        {"id":\(self.json(id)),"category":\(self.json(category)),"tier":"synthetic","text":\(self.json(text)),"expectation":\(self.json(expectation)),
        "expectedCorrections":[\(list)],"recallRequiresAll":false,"manualAdjudicationOnly":false,"hazardNote":null,"knownRiskReference":null,"note":null}
        """
        guard let decoded = try? JSONDecoder().decode(CapabilityCorpus.Entry.self, from: Data(raw.utf8)) else { preconditionFailure("bad entry") }
        return decoded
    }

    private static func json(_ text: String) -> String {
        guard let data = try? JSONEncoder().encode(text), let encoded = String(bytes: data, encoding: .utf8) else { preconditionFailure("encode") }
        return encoded
    }

    private static func copyArtifacts(_ repoRoot: URL, mutating: (String, inout [String: Any]) -> Void) throws -> URL {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("v127-\(UUID().uuidString)")
        let directory = scratch.appendingPathComponent(ComparisonFreeze.directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ComparisonFreeze.artifactNames where name.hasSuffix(".json") {
            let source = repoRoot.appendingPathComponent(ComparisonFreeze.directory).appendingPathComponent(name)
            var object = try (JSONSerialization.jsonObject(with: Data(contentsOf: source))) as? [String: Any] ?? [:]
            mutating(name, &object)
            try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: directory.appendingPathComponent(name))
        }
        return scratch
    }

    // MARK: - Corpus integrity

    private static func testCorpusIntegrity(_ repoRoot: URL, _ corpus: ComparisonCorpus) {
        precondition(corpus.entries.count == 66 && corpus.scoredEntries.count == 62 && corpus.manualEntries.count == 4)
        precondition(corpus.scoredCorrectionWarranted.count == 38 && corpus.perCorrectionDenominator == 50 && corpus.scoredAbstentionExpected.count == 24)
        precondition(corpus.entries.allSatisfy { $0.id.hasPrefix("DEV-") && $0.tier == "synthetic" }, "development ids are namespaced and synthetic")
        precondition(corpus.manualEntries.allSatisfy { $0.expectedCorrections.isEmpty && $0.expectation == "correctionWarranted" })
        precondition(corpus.entries.filter { $0.category.hasPrefix("hazard") }.allSatisfy { $0.isScoredAbstentionExpected && $0.hazardNote != nil }, "every hazard entry is abstention-expected with a recorded hazard note")
        let multiRequireAll = corpus.entries.filter { $0.category == "multi-edit-correction-warranted" }
        precondition(multiRequireAll.allSatisfy { $0.recallRequiresAll && $0.expectedCorrections.count >= 2 })
        precondition(multiRequireAll.filter { $0.expectedCorrections.count == 3 }.count == 2, "two triples exercise partial outcomes")

        // The pin refuses any change; a wrong pin or a one-byte tamper must be refused before decoding.
        let url = repoRoot.appendingPathComponent(ComparisonCorpus.relativePath)
        do {
            _ = try ComparisonCorpus.load(from: url, expectedSHA256: String(repeating: "0", count: 64))
            preconditionFailure("a wrong pin must be refused")
        } catch ComparisonCorpus.LoadError.hashMismatch {} catch { preconditionFailure("wrong error \(error)") }
        guard var data = try? Data(contentsOf: url) else { preconditionFailure("read") }
        data.append(0x20)
        let tampered = FileManager.default.temporaryDirectory.appendingPathComponent("v127-tampered-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tampered) }
        precondition((try? data.write(to: tampered)) != nil)
        do {
            _ = try ComparisonCorpus.load(from: tampered)
            preconditionFailure("a tampered corpus must be refused")
        } catch ComparisonCorpus.LoadError.hashMismatch {} catch { preconditionFailure("wrong error \(error)") }
    }

    // MARK: - Real-pipeline premises (the corpus must be what its labels say, against production code)

    private static func testRealPipelinePremises(_ corpus: ComparisonCorpus, _ processor: LegalDictationProcessor) {
        let warrantedFolded = Dictionary(uniqueKeysWithValues: corpus.scoredCorrectionWarranted.map { entry -> (String, String) in
            var corrected = entry.text
            for correction in entry.expectedCorrections {
                corrected = corrected.replacingOccurrences(of: correction.source, with: correction.replacement)
            }
            return (entry.id, ComparisonOverlap.folded(corrected))
        })
        for entry in corpus.entries {
            let outcome = processor.process(entry.text)
            let normalized = outcome.normalized
            guard case let .success(derived) = ProtectedSpanDerivation.derive(from: outcome) else { preconditionFailure("\(entry.id): span derivation failed") }
            let numeric = NumericStructuralProtection.spans(in: normalized)
            let total = derived.spans.count + numeric.count
            switch entry.category {
            case "hazard-protected-resolved-span":
                precondition(normalized != entry.text && derived.entries.contains { $0.span.kind == .deterministicallyResolved }, "\(entry.id): expected an applied normalization with a resolved span")
            case "hazard-independently-protected", "hazard-digit-case":
                precondition(!numeric.isEmpty, "\(entry.id): expected a numeric protected span")
                precondition(normalized == entry.text, "\(entry.id): normalization must not rewrite a non-statutory hazard text")
            default:
                precondition(total == 0, "\(entry.id): expected zero protected spans so only surface rules are under test (found \(total))")
                precondition(normalized == entry.text, "\(entry.id): ground truth is stated in raw coordinates; normalization must not change the text")
            }
            guard entry.isScoredCorrectionWarranted else { continue }
            var ranges: [NSRange] = []
            for correction in entry.expectedCorrections {
                let found = (normalized as NSString).range(of: correction.source)
                precondition(found.location != NSNotFound, "\(entry.id): correction source \"\(correction.source)\" not found")
                precondition(self.occurrenceCount(correction.source, normalized) == 1, "\(entry.id): correction source \"\(correction.source)\" must occur exactly once")
                ranges.append(found)
            }
            for i in ranges.indices {
                for j in ranges.indices where j > i {
                    precondition(NSIntersectionRange(ranges[i], ranges[j]).length == 0 && ranges[i].location != ranges[j].location, "\(entry.id): expected corrections overlap")
                }
            }
        }
        // Matched minimal pairs: every control equals (after folding) some warranted entry's fully corrected text.
        for control in corpus.entries where control.category == "clean-control" {
            precondition(warrantedFolded.values.contains(ComparisonOverlap.folded(control.text)), "\(control.id): not a minimal pair of any warranted entry")
        }

        // Deterministic ceiling: ground truth fed back through the real chain is attained for every
        // scored warranted entry (a corpus the safeguards could never accept would be a pre-exposure defect).
        for entry in corpus.scoredCorrectionWarranted {
            let corrections = entry.expectedCorrections.map { ["sourceText": $0.source, "replacementText": $0.replacement] }
            let payload: [String: Any] = ["schemaVersion": 1, "edits": corrections]
            guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), let raw = String(bytes: data, encoding: .utf8),
                  case let .success(pre) = IntelligenceHarnessPipeline.preflight(rawInputText: entry.text, processor: processor)
            else { preconditionFailure("\(entry.id): oracle setup") }
            let response = IntelligenceProviderResponse(toolCalls: [IntelligenceProviderToolCall(name: ModelFacingGenerationContract.toolName, rawArguments: raw)])
            guard case let .success(sample) = IntelligenceHarnessPipeline.evaluate(response: response, normalizedText: pre.normalizedText, protectedSpans: pre.protectedSpans) else {
                preconditionFailure("\(entry.id): oracle response rejected")
            }
            precondition(sample.edits.allSatisfy { $0.bucket == .autonomouslyAccepted }, "\(entry.id): an expected correction is not autonomously acceptable: \(sample.edits.map(\.dispositionSummary))")
            var full = entry.text
            for correction in entry.expectedCorrections {
                full = full.replacingOccurrences(of: correction.source, with: correction.replacement)
            }
            precondition(sample.wouldBeOutput == full, "\(entry.id): oracle output differs from the fully corrected text")
        }
    }

    private static func occurrenceCount(_ needle: String, _ haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    // MARK: - Overlap rules: each fires on injection; the real corpus is disjoint

    private static func testOverlapRulesFireAndRealCorpusIsDisjoint(_ repoRoot: URL, _ corpus: ComparisonCorpus, _ frozen: CapabilityCorpus) {
        let reference = [
            self.entry("F-1", "the witness reached the spot at dawn", corrections: [("spot", "spot.")], category: "punctuation-correction-warranted"),
            self.entry("F-2", "ram das signed the bond", corrections: [("ram das", "Ram Das")]),
            self.entry("F-3", "Exhibit P9 was proved by the clerk.", category: "hazard-digit-case", expectation: "abstentionExpected"),
        ]
        func rules(_ id: String, _ text: String, _ corrections: [(String, String)] = []) -> Set<ComparisonOverlap.Rule> {
            let subject = ComparisonOverlap.Subject(id: id, text: text, corrections: corrections.map { CapabilityCorpus.Correction(source: $0.0, replacement: $0.1) })
            return Set(ComparisonOverlap.check(subjects: [subject], frozen: reference).map(\.rule))
        }
        precondition(rules("c", "the bailiff opened the south gate early") == [], "a genuinely different text passes")
        precondition(rules("p1", "the witness reached the spot at dawn").contains(.exactText), "P1: exact text")
        precondition(rules("p2", "The Witness reached the spot, at dawn!").contains(.foldedText), "P2: equal after folding")
        precondition(rules("p3", "the lorry stopped near the gate", [("spot", "spot.")]).contains(.correctionPair), "P3: identical correction pair")
        precondition(rules("p4", "das was seen at the market").contains(.nameToken), "P4: frozen name token")
        precondition(rules("p5", "yesterday the witness reached the town").contains(.fourGram), "P5: four consecutive shared words")
        precondition(rules("p6", "the witness reached the spot at dusk").contains(.nearDuplicate), "P6: near-duplicate (one word changed)")
        precondition(rules("p7", "Exhibit P9 stayed sealed").contains(.digitToken), "P7: frozen digit-bearing token")
        precondition(rules("ok", "the vendor attended the hearing as scheduled") == [], "shared common words alone are allowed")
        precondition(ComparisonOverlap.similarity("abc", "abc") == 1 && ComparisonOverlap.similarity("abc", "xyz") == 0 && ComparisonOverlap.similarity("", "") == 1)
        precondition(ComparisonOverlap.ngramLength == 4 && ComparisonOverlap.nearDuplicateThreshold == 0.80)

        // Internal duplicates: identical raw text anywhere; folded duplicates only within the same expectation group.
        let a = ComparisonOverlap.Subject(id: "a", text: "Notice was served.", corrections: [], group: "abstentionExpected")
        let b = ComparisonOverlap.Subject(id: "b", text: "notice was served", corrections: [], group: "correctionWarranted")
        let c = ComparisonOverlap.Subject(id: "c", text: "notice was served!", corrections: [], group: "correctionWarranted")
        precondition(ComparisonOverlap.internalDuplicates([a, b]).isEmpty, "a warranted entry and its control are an intentional minimal pair")
        precondition(ComparisonOverlap.internalDuplicates([b, c]).count == 1, "folded duplicates within a group are flagged")
        precondition(ComparisonOverlap.internalDuplicates([a, a]).count >= 1, "identical raw text is always flagged")

        // The real development material is disjoint from the real frozen benchmark, and the guard is sensitive on real data.
        guard let fixtures = try? ComparisonFixtureReplay.load(from: repoRoot.appendingPathComponent(ComparisonFreeze.directory).appendingPathComponent("hazard_fixture.json")) else { preconditionFailure("fixtures") }
        let summary = ComparisonFreeze.overlap(corpus: corpus, fixtures: fixtures, frozen: frozen.entries)
        precondition(summary.violations.isEmpty, "development material overlaps the frozen benchmark: \(summary.violations.map { "\($0.rule.rawValue) \($0.subjectID)~\($0.against)" })")
        precondition(summary.internalDuplicates.isEmpty && summary.subjectsChecked == corpus.entries.count + fixtures.fixtures.count && summary.frozenEntries == 44)
        let leaked = ComparisonOverlap.check(subjects: [ComparisonOverlap.Subject(id: "leak", text: frozen.entries[0].text, corrections: [])], frozen: frozen.entries)
        precondition(leaked.contains { $0.rule == .exactText }, "a copied frozen text is detected on the real benchmark")
        let renamed = ComparisonOverlap.check(subjects: [ComparisonOverlap.Subject(id: "leak", text: "sita devi appeared as a witness", corrections: [])], frozen: frozen.entries)
        precondition(renamed.contains { $0.rule == .nameToken }, "a reused frozen name is detected on the real benchmark")
        precondition(frozen.sha256 == CapabilityCorpus.frozenSHA256, "the frozen benchmark was read only through its pinned loader")
    }

    // MARK: - Stored hazard fixtures

    private static func testHazardFixtures(_ repoRoot: URL, _ corpus: ComparisonCorpus, _ processor: LegalDictationProcessor) throws {
        let file = try ComparisonFixtureReplay.load(from: repoRoot.appendingPathComponent(ComparisonFreeze.directory).appendingPathComponent("hazard_fixture.json"))
        precondition(file.fixtures.count == 21 && Set(file.fixtures.map(\.id)).count == 21)
        let results = ComparisonFixtureReplay.replay(file, processor: processor)
        precondition(results.allSatisfy(\.matchesExpectation), "fixture(s) not contained as documented: \(results.filter { !$0.matchesExpectation }.map(\.fixture.id))")
        precondition(!results.contains(where: \.hazardAutonomouslyAccepted), "no hazard or negative fixture may be autonomously accepted")
        let kinds = Dictionary(grouping: file.fixtures, by: \.kind).mapValues(\.count)
        precondition(kinds == ["hazard": 12, "general-negative": 5, "positive-control": 4], "fixture composition drifted: \(kinds)")
        let byID = Dictionary(uniqueKeysWithValues: corpus.entries.map { ($0.id, $0) })
        for fixture in file.fixtures {
            if let ref = fixture.entryRef {
                precondition(byID[ref]?.text == fixture.text, "\(fixture.id): text must equal its referenced development entry")
            }
        }
        let hazardEntries = Set(corpus.entries.filter { $0.category.hasPrefix("hazard") }.map(\.id))
        precondition(hazardEntries == Set(file.fixtures.filter { $0.kind == "hazard" }.compactMap(\.entryRef)), "every hazard entry has a stored hazard fixture")

        // The detectors fire: a "hazard" whose edit is actually safe is reported as autonomously accepted; a wrong expectation is reported.
        let injectedEdit = ComparisonFixtureFile.Edit(sourceText: "prosecution", replacementText: "prosecution.", occurrence: nil, leftContext: nil, rightContext: nil)
        let injectedExpectation = ComparisonFixtureFile.Expectation(bucket: "reviewOnly", reasonAnyOf: ["x"])
        let injectedFixture = ComparisonFixtureFile.Fixture(
            id: "INJ-1",
            entryRef: nil,
            kind: "hazard",
            text: "the petition was dismissed for want of prosecution",
            proposedEdits: [injectedEdit],
            expect: [injectedExpectation],
            rationale: "injected"
        )
        let safeAsHazard = ComparisonFixtureFile(schemaVersion: 1, description: "injected", fixtures: [injectedFixture])
        let injected = ComparisonFixtureReplay.replay(safeAsHazard, processor: processor)
        precondition(injected[0].hazardAutonomouslyAccepted && !injected[0].matchesExpectation, "an autonomously accepted hazard is detected")
    }

    // MARK: - Contract baseline/variant, candidates, protocol (each guard also shown to fail on tampering)

    private static func testContractCandidatesAndProtocol(_ repoRoot: URL, _ corpus: ComparisonCorpus) throws {
        precondition(ComparisonFreeze.contractChecks(repoRoot: repoRoot).allSatisfy(\.passed), "contract/variant checks")
        precondition(ComparisonFreeze.candidateChecks(repoRoot: repoRoot).allSatisfy(\.passed), "candidate registry checks")
        precondition(ComparisonFreeze.protocolChecks(repoRoot: repoRoot, corpus: corpus).allSatisfy(\.passed), "protocol checks")

        let badVariant = try self.copyArtifacts(repoRoot) { name, object in
            guard name == "contract_variant.json", var variant = object["variant"] as? [String: Any] else { return }
            variant["instructionsSHA256"] = String(repeating: "a", count: 64)
            object["variant"] = variant
        }
        defer { try? FileManager.default.removeItem(at: badVariant) }
        precondition(ComparisonFreeze.contractChecks(repoRoot: badVariant).contains { !$0.passed }, "a changed variant hash is refused")

        let badCandidates = try self.copyArtifacts(repoRoot) { name, object in
            guard name == "candidates.json", var candidates = object["candidates"] as? [[String: Any]] else { return }
            candidates[1]["identity"] = ["ollamaManifestSHA256": String(repeating: "b", count: 64)]
            object["candidates"] = candidates
        }
        defer { try? FileManager.default.removeItem(at: badCandidates) }
        precondition(ComparisonFreeze.candidateChecks(repoRoot: badCandidates).contains { !$0.passed }, "a fabricated local digest for an unpulled model is refused")

        let badBaseline = try self.copyArtifacts(repoRoot) { name, object in
            guard name == "candidates.json", var candidates = object["candidates"] as? [[String: Any]], var identity = candidates[0]["identity"] as? [String: Any] else { return }
            identity["ggufBlobSHA256"] = String(repeating: "c", count: 64)
            candidates[0]["identity"] = identity
            object["candidates"] = candidates
        }
        defer { try? FileManager.default.removeItem(at: badBaseline) }
        precondition(ComparisonFreeze.candidateChecks(repoRoot: badBaseline).contains { !$0.passed }, "a baseline that drifts from the V1.23A identity is refused")

        let leakyProtocol = try self.copyArtifacts(repoRoot) { name, object in
            guard name == "protocol.json", var access = object["frozenBenchmarkAccess"] as? [String: Any] else { return }
            access["candidateScreening"] = "allowed"
            object["frozenBenchmarkAccess"] = access
        }
        defer { try? FileManager.default.removeItem(at: leakyProtocol) }
        precondition(ComparisonFreeze.protocolChecks(repoRoot: leakyProtocol, corpus: corpus).contains { !$0.passed }, "a protocol that lets screening touch the frozen benchmark is refused")

        let earlyInference = try self.copyArtifacts(repoRoot) { name, object in
            guard name == "protocol.json", var stages = object["stages"] as? [[String: Any]] else { return }
            stages[1]["inference"] = true
            object["stages"] = stages
        }
        defer { try? FileManager.default.removeItem(at: earlyInference) }
        precondition(ComparisonFreeze.protocolChecks(repoRoot: earlyInference, corpus: corpus).contains { !$0.passed }, "inference before screening is refused")

        // Each architectural decision is enforced: re-introducing a GPU gate, extra automatic passes, a re-opened
        // resolved decision, a missing immutability clause, or a missing license record is refused.
        let tamperedProtocols: [(String, (inout [String: Any]) -> Void)] = [
            ("a GPU-offload gate in G2", { object in
                guard var gates = object["hardGates"] as? [String: Any], var g2 = gates["G2_runtime"] as? [String: Any] else { return }
                g2["rule"] = "zero provider/runtime failures AND 100% GPU offload"
                gates["G2_runtime"] = g2
                object["hardGates"] = gates
            }),
            ("U0 re-introduced as a gate", { object in
                guard var gates = object["hardGates"] as? [String: Any] else { return }
                gates["G4_exactPair"] = ["rule": "U0 == 0"]
                object["hardGates"] = gates
            }),
            ("automatic extra screening passes", { object in
                guard var run = object["runCountDecision"] as? [String: Any], var audit = run["determinismAudit"] as? [String: Any] else { return }
                audit["automaticExtraPasses"] = true
                run["determinismAudit"] = audit
                object["runCountDecision"] = run
            }),
            ("an escalation rule", { object in
                guard var run = object["runCountDecision"] as? [String: Any], var audit = run["determinismAudit"] as? [String: Any] else { return }
                audit["escalation"] = "re-screen with three passes"
                run["determinismAudit"] = audit
                object["runCountDecision"] = run
            }),
            ("PO-2 marked resolved", { object in
                guard var decisions = object["productOwnerDecisions"] as? [String: Any] else { return }
                decisions["unresolved"] = [["id": "PO-3"]]
                object["productOwnerDecisions"] = decisions
            }),
            ("a missing immutability clause", { object in object["immutability"] = nil }),
        ]
        for (label, mutate) in tamperedProtocols {
            let tampered = try self.copyArtifacts(repoRoot) { name, object in
                if name == "protocol.json" {
                    mutate(&object)
                }
            }
            defer { try? FileManager.default.removeItem(at: tampered) }
            precondition(ComparisonFreeze.protocolChecks(repoRoot: tampered, corpus: corpus).contains { !$0.passed }, "\(label) must be refused")
        }
        let noLicense = try self.copyArtifacts(repoRoot) { name, object in
            guard name == "candidates.json", var candidates = object["candidates"] as? [[String: Any]] else { return }
            candidates[2]["license"] = ""
            object["candidates"] = candidates
        }
        defer { try? FileManager.default.removeItem(at: noLicense) }
        precondition(ComparisonFreeze.candidateChecks(repoRoot: noLicense).contains { !$0.passed }, "a candidate without a recorded license is refused")
    }

    // MARK: - Manifest determinism and drift

    private static func testManifestIsDeterministicAndCommitted(_ repoRoot: URL, _ corpus: ComparisonCorpus, _ frozen: CapabilityCorpus, _ processor: LegalDictationProcessor) throws {
        let fixtures = try ComparisonFixtureReplay.load(from: repoRoot.appendingPathComponent(ComparisonFreeze.directory).appendingPathComponent("hazard_fixture.json"))
        let summary = ComparisonFreeze.overlap(corpus: corpus, fixtures: fixtures, frozen: frozen.entries)
        let contained = ComparisonFixtureReplay.replay(fixtures, processor: processor).allSatisfy(\.matchesExpectation)
        let first = ComparisonFreeze.manifest(repoRoot: repoRoot, corpus: corpus, summary: summary, fixtureCount: fixtures.fixtures.count, allFixturesContained: contained)
        let second = ComparisonFreeze.manifest(repoRoot: repoRoot, corpus: corpus, summary: summary, fixtureCount: fixtures.fixtures.count, allFixturesContained: contained)
        precondition(ComparisonFreeze.canonical(first) == ComparisonFreeze.canonical(second), "protocol determinism: the manifest is a pure function of the artifacts")
        precondition((first["overlapCheck"] as? [String: Any])?["violations"] as? Int == 0 && (first["hazardFixtures"] as? [String: Any])?["allContainedAsExpected"] as? Bool == true)
        precondition(((first["artifactSHA256"] as? [String: String]) ?? [:]).count == ComparisonFreeze.artifactNames.count)
        var mutated = first
        mutated["milestone"] = "other"
        precondition(CapabilitySHA256.hex(ComparisonFreeze.canonical(mutated)) != CapabilitySHA256.hex(ComparisonFreeze.canonical(first)))

        // The committed FREEZE_MANIFEST.json must equal what the artifacts regenerate now.
        let committedURL = repoRoot.appendingPathComponent(ComparisonFreeze.directory).appendingPathComponent(ComparisonFreeze.manifestName)
        guard let committed = try? JSONSerialization.jsonObject(with: Data(contentsOf: committedURL)) as? [String: Any] else { preconditionFailure("FREEZE_MANIFEST.json must exist") }
        precondition(
            ComparisonFreeze.canonical(committed) == ComparisonFreeze.canonical(first),
            "FREEZE_MANIFEST.json no longer matches the frozen artifacts or tooling -- regenerate deliberately (an amendment), never edit by hand"
        )
        // V1.23/V1.25 evidence the comparison relies on is unchanged.
        precondition(CapabilitySHA256.hex(of: ModelFacingGenerationContract.instructions) == CapabilityFrozenRun.instructionsSHA256)
    }

    // MARK: - Static guards

    private static func testStaticGuards(_ repoRoot: URL) {
        let directory = repoRoot.appendingPathComponent("Evaluation/Intelligence/ComparisonProtocol")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path).filter({ $0.hasSuffix(".swift") }), files.count == 5 else { preconditionFailure("expected 5 comparison sources") }
        for name in files {
            guard let full = try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8) else { preconditionFailure("read \(name)") }
            let code = full.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            for forbidden in ["URLSession", "URLRequest", "URLProtocol", "LLMClient", "IntelligenceHarnessProvider", "Process()", ".propose("] {
                precondition(!code.contains(forbidden), "\(name) must have no provider/network path (found \(forbidden))")
            }
            let touchesFrozen = code.contains("intelligence-v1-capability") || code.contains("CapabilityCorpus.relativePath")
            precondition(!touchesFrozen || ["ComparisonFreeze.swift", "ComparisonFreezeRunner.swift"].contains(name), "\(name) must not read the frozen benchmark")
        }
        // No screening/execution tooling exists yet (stage S2 is a later milestone).
        let scripts = (try? FileManager.default.contentsOfDirectory(atPath: repoRoot.appendingPathComponent("scripts").path)) ?? []
        precondition(!scripts.contains { $0.contains("comparison") && ($0.contains("run") || $0.contains("screen")) }, "candidate execution must not be implemented in V1.27")
    }
}
