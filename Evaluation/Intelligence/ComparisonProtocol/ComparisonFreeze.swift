import Foundation

/// Intelligence V1.27 -- Model Comparison Development Corpus & Protocol.
///
/// Validation and content-addressing of the pre-registered comparison artifacts. Deterministic;
/// no model, no network. Produces `FREEZE_MANIFEST.json`'s content: the SHA-256 of every frozen
/// artifact and of the checking tooling, the baseline contract identity, and the overlap-check summary.
enum ComparisonFreeze {
    static let directory = "Evaluation/References/intelligence-v1-comparison-dev"
    static let artifactNames = ["corpus.json", "hazard_fixture.json", "candidates.json", "contract_variant.json", "protocol.json"]
    static let toolingPaths = [
        "Evaluation/Intelligence/ComparisonProtocol/ComparisonCorpus.swift",
        "Evaluation/Intelligence/ComparisonProtocol/ComparisonOverlap.swift",
        "Evaluation/Intelligence/ComparisonProtocol/ComparisonFixtures.swift",
        "Evaluation/Intelligence/ComparisonProtocol/ComparisonFreeze.swift",
        "Evaluation/Intelligence/ComparisonProtocol/ComparisonFreezeRunner.swift",
    ]
    static let manifestName = "FREEZE_MANIFEST.json"
    static let frozenBenchmarkRelativePath = "Evaluation/References/intelligence-v1-capability/corpus.json"

    // MARK: - JSON helpers

    /// Parsed JSON object, or an empty dictionary when the file is missing or malformed (callers then fail their checks).
    static func jsonObject(_ url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
    }

    static func canonical(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
    }

    // MARK: - Overlap

    struct OverlapSummary {
        let subjectsChecked: Int
        let frozenEntries: Int
        let violations: [ComparisonOverlap.Violation]
        let internalDuplicates: [ComparisonOverlap.Violation]
    }

    /// Subjects = every development entry plus every stored-hazard-fixture text.
    static func subjects(corpus: ComparisonCorpus, fixtures: ComparisonFixtureFile) -> [ComparisonOverlap.Subject] {
        corpus.entries.map { ComparisonOverlap.Subject(id: $0.id, text: $0.text, corrections: $0.expectedCorrections, group: $0.expectation) }
            + fixtures.fixtures.map { ComparisonOverlap.Subject(id: $0.id, text: $0.text, corrections: []) }
    }

    static func overlap(corpus: ComparisonCorpus, fixtures: ComparisonFixtureFile, frozen: [CapabilityCorpus.Entry]) -> OverlapSummary {
        let all = self.subjects(corpus: corpus, fixtures: fixtures)
        // Fixture texts deliberately re-use development entry texts (entryRef); only dev-internal duplicates among entries count.
        let devOnly = corpus.entries.map { ComparisonOverlap.Subject(id: $0.id, text: $0.text, corrections: $0.expectedCorrections, group: $0.expectation) }
        return OverlapSummary(
            subjectsChecked: all.count,
            frozenEntries: frozen.count,
            violations: ComparisonOverlap.check(subjects: all, frozen: frozen),
            internalDuplicates: ComparisonOverlap.internalDuplicates(devOnly)
        )
    }

    // MARK: - Contract baseline and variant

    static func contractChecks(repoRoot: URL) -> [CapabilityPreflightCheck] {
        var checks = CapabilityPreflight.contractChecks()
        let doc = self.jsonObject(repoRoot.appendingPathComponent(self.directory).appendingPathComponent("contract_variant.json"))
        guard let baseline = doc["baseline"] as? [String: Any],
              let variant = doc["variant"] as? [String: Any],
              let construction = variant["construction"] as? [String: Any],
              let find = construction["find"] as? String,
              let replacement = construction["replaceWith"] as? String
        else {
            checks.append(CapabilityPreflightCheck(name: "contract_variant.json readable", passed: false, detail: "missing or malformed"))
            return checks
        }
        let instructions = ModelFacingGenerationContract.instructions
        checks.append(CapabilityPreflightCheck(
            name: "baseline instructions hash in contract_variant.json == V1.21",
            passed: baseline["instructionsSHA256"] as? String == CapabilitySHA256.hex(of: instructions),
            detail: baseline["instructionsSHA256"] as? String ?? "missing"
        ))
        let occurrences = instructions.components(separatedBy: find).count - 1
        checks.append(CapabilityPreflightCheck(name: "variant: the replaced sentence occurs exactly once in the baseline", passed: occurrences == 1, detail: "\(occurrences)"))
        let rebuilt = instructions.replacingOccurrences(of: find, with: replacement)
        checks.append(CapabilityPreflightCheck(
            name: "variant instructions hash == pre-registered",
            passed: variant["instructionsSHA256"] as? String == CapabilitySHA256.hex(of: rebuilt),
            detail: CapabilitySHA256.hex(of: rebuilt)
        ))
        checks.append(CapabilityPreflightCheck(
            name: "variant differs from the baseline only by that replacement",
            passed: rebuilt != instructions && rebuilt.replacingOccurrences(of: replacement, with: find) == instructions,
            detail: "one-sentence replacement"
        ))
        checks.append(CapabilityPreflightCheck(
            name: "variant keeps the schemaVersion sentence and leaves tool/parser/schema unchanged",
            passed: rebuilt.contains("\"schemaVersion\": 1") && variant["toolDefinitionChanged"] as? Bool == false && variant["parserChanged"] as? Bool == false && variant["schemaChanged"] as? Bool == false,
            detail: "toolDefinitionChanged=false"
        ))
        return checks
    }

    // MARK: - Candidate registry

    static func candidateChecks(repoRoot: URL) -> [CapabilityPreflightCheck] {
        let doc = self.jsonObject(repoRoot.appendingPathComponent(self.directory).appendingPathComponent("candidates.json"))
        guard let candidates = doc["candidates"] as? [[String: Any]]
        else { return [CapabilityPreflightCheck(name: "candidates.json readable", passed: false, detail: "missing or malformed")] }
        let hex = { (value: String?) -> Bool in
            guard let value else { return false }
            let digest = value.replacingOccurrences(of: "sha256:", with: "")
            return digest.count == 64 && digest.allSatisfy { $0.isHexDigit && !$0.isUppercase }
        }
        var checks: [CapabilityPreflightCheck] = []
        let ids = candidates.compactMap { $0["id"] as? String }
        checks.append(CapabilityPreflightCheck(name: "candidate ids unique", passed: Set(ids).count == ids.count && !ids.isEmpty, detail: ids.joined(separator: ",")))
        let baselines = candidates.filter { $0["role"] as? String == "baseline-control" }
        let identity = baselines.first?["identity"] as? [String: Any]
        checks.append(CapabilityPreflightCheck(
            name: "exactly one baseline, pinned to the V1.23A identity",
            passed: baselines.count == 1 && baselines.first?["ollamaTag"] as? String == CapabilityFrozenRun.modelName
                && identity?["ollamaManifestSHA256"] as? String == CapabilityFrozenRun.ollamaManifestSHA256
                && identity?["ggufBlobSHA256"] as? String == CapabilityFrozenRun.ggufBlobSHA256
                && identity?["templateBlobSHA256"] as? String == CapabilityFrozenRun.templateBlobSHA256,
            detail: "\(baselines.count) baseline(s)"
        ))
        var allObserved = true
        var noFabricatedLocalDigest = true
        for candidate in candidates where candidate["role"] as? String != "baseline-control" && candidate["status"] as? String != "optional-not-registered" {
            guard let observed = candidate["registryObserved"] as? [String: Any], hex(observed["configDigest"] as? String),
                  let layers = observed["layers"] as? [[String: Any]], layers.contains(where: { $0["mediaType"] as? String == "application/vnd.ollama.image.model" && hex($0["digest"] as? String) })
            else { allObserved = false; continue }
            if (candidate["identity"] as? [String: Any])?["ollamaManifestSHA256"] is String {
                noFabricatedLocalDigest = false
            }
        }
        checks.append(CapabilityPreflightCheck(name: "non-baseline candidates carry registry-observed digests", passed: allObserved, detail: "config + model layer, hex"))
        checks.append(CapabilityPreflightCheck(name: "no local manifest digest is claimed for a model that was never pulled", passed: noFabricatedLocalDigest, detail: "null until an authorized pull"))
        let licenseRecorded = candidates.allSatisfy { ($0["license"] as? String)?.isEmpty == false && ($0["licenseSource"] as? String)?.isEmpty == false }
        checks.append(CapabilityPreflightCheck(
            name: "every candidate records its license and license source (acceptability for production use is decided before adoption, not at screening)",
            passed: licenseRecorded,
            detail: Set(candidates.compactMap { $0["license"] as? String }).sorted().joined(separator: ",")
        ))
        let primary = candidates.filter { ["same-family-successor", "strongest-non-thinking-dense-candidate", "different-family-planned-in-V1.3C-ladder", "mistral-family-edge-model"].contains($0["role"] as? String ?? "") }
        checks.append(CapabilityPreflightCheck(name: "four primary candidates registered per V1.26", passed: primary.count == 4, detail: primary.compactMap { $0["ollamaTag"] as? String }.joined(separator: ",")))
        return checks
    }

    // MARK: - Protocol

    static func protocolChecks(repoRoot: URL, corpus: ComparisonCorpus) -> [CapabilityPreflightCheck] {
        let doc = self.jsonObject(repoRoot.appendingPathComponent(self.directory).appendingPathComponent("protocol.json"))
        guard !doc.isEmpty else { return [CapabilityPreflightCheck(name: "protocol.json readable", passed: false, detail: "missing or malformed")] }
        var checks: [CapabilityPreflightCheck] = []
        let stages = (doc["stages"] as? [[String: Any]]) ?? []
        let boundaries = (doc["freezeBoundaries"] as? [[String: Any]]) ?? []
        checks.append(CapabilityPreflightCheck(name: "stages S0..S6 in order", passed: stages.compactMap { $0["id"] as? String } == ["S0", "S1", "S2", "S3", "S4", "S5", "S6"], detail: "\(stages.count) stages"))
        let stageInference = Dictionary(uniqueKeysWithValues: stages.compactMap { stage -> (String, Bool)? in
            guard let id = stage["id"] as? String, let inference = stage["inference"] as? Bool else { return nil }
            return (id, inference)
        })
        checks.append(CapabilityPreflightCheck(
            name: "no inference before S3; S0, S1, S2, S5 are inference-free",
            passed: ["S0", "S1", "S2", "S5"].allSatisfy { stageInference[$0] == false } && stageInference["S3"] == true,
            detail: "S3 first inference stage"
        ))
        checks.append(CapabilityPreflightCheck(name: "freeze boundaries FB0..FB5", passed: boundaries.compactMap { $0["id"] as? String } == ["FB0", "FB1", "FB2", "FB3", "FB4", "FB5"], detail: "\(boundaries.count) boundaries"))
        let access = doc["frozenBenchmarkAccess"] as? [String: Any]
        checks.append(CapabilityPreflightCheck(
            name: "frozen benchmark forbidden for screening, contract development, variant development and selection; one confirmation run",
            passed: ["candidateScreening", "contractDevelopment", "variantDevelopment", "selectionAndTuning"].allSatisfy { access?[$0] as? String == "forbidden" }
                && (access?["confirmation"] as? String)?.contains("exactly one run") == true
                && access?["sha256"] as? String == CapabilityCorpus.frozenSHA256,
            detail: "sha256 pinned"
        ))
        let groups = ((doc["metrics"] as? [String: Any])?["groups"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
        checks.append(CapabilityPreflightCheck(
            name: "four separate metric groups; no blended score",
            passed: groups == ["protocol-and-provider", "edit-form-adherence", "outcome-correctness", "deterministic-containment-runtime-safety"],
            detail: groups.joined(separator: ",")
        ))
        let corpusInfo = doc["corpus"] as? [String: Any]
        checks.append(CapabilityPreflightCheck(
            name: "protocol corpus figures equal the corpus",
            passed: corpusInfo?["entries"] as? Int == corpus.entries.count && corpusInfo?["scoredEntries"] as? Int == corpus.scoredEntries.count
                && corpusInfo?["scoredCorrectionWarranted"] as? Int == corpus.scoredCorrectionWarranted.count
                && corpusInfo?["perCorrectionDenominator"] as? Int == corpus.perCorrectionDenominator
                && corpusInfo?["scoredAbstentionExpected"] as? Int == corpus.scoredAbstentionExpected.count
                && corpusInfo?["manualAdjudicationOnly"] as? Int == corpus.manualEntries.count,
            detail: "\(corpus.entries.count) entries"
        ))
        let decisions = doc["productOwnerDecisions"] as? [String: Any]
        let resolved = (decisions?["resolved"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
        let unresolved = (decisions?["unresolved"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
        checks.append(CapabilityPreflightCheck(
            name: "Product Owner decisions: PO-1, PO-4, PO-5 resolved; PO-2, PO-3 explicitly unresolved",
            passed: resolved == ["PO-1", "PO-4", "PO-5"] && unresolved == ["PO-2", "PO-3"],
            detail: "resolved \(resolved.joined(separator: ",")); unresolved \(unresolved.joined(separator: ","))"
        ))
        let gates = doc["hardGates"] as? [String: Any]
        let g2Rule = (gates?["G2_runtime"] as? [String: Any])?["rule"] as? String ?? ""
        let u0Policy = (gates?["U0_exactPair"] as? [String: Any])?["policy"] as? String ?? ""
        let g3Rule = (gates?["G3_containment"] as? [String: Any])?["rule"] as? String ?? ""
        checks.append(CapabilityPreflightCheck(
            name: "gates G1-G3 only: G2 is zero provider failures (no GPU-offload gate); U0 report-only; G3 zero-tolerance for foreign outcomes",
            passed: ["G1_protocol", "G2_runtime", "G3_containment"].allSatisfy { gates?[$0] != nil } && gates?["G4_exactPair"] == nil
                && g2Rule == "zero provider/runtime failures on the full pass" && !g2Rule.contains("GPU")
                && u0Policy.hasPrefix("report-only") && g3Rule.hasPrefix("U1 = 0"),
            detail: "G2: \(g2Rule)"
        ))
        let audit = ((doc["runCountDecision"] as? [String: Any])?["determinismAudit"] as? [String: Any]) ?? [:]
        let ids = Set(corpus.entries.map(\.id))
        let auditIDs = audit["entryIds"] as? [String] ?? []
        checks.append(CapabilityPreflightCheck(
            name: "determinism audit: one fixed 12-entry second attempt, no automatic extra passes, halt for review on material nondeterminism",
            passed: auditIDs.count == 12 && Set(auditIDs).count == 12 && Set(auditIDs).isSubset(of: ids)
                && audit["automaticExtraPasses"] as? Bool == false && audit["escalation"] == nil
                && (audit["onMaterialNondeterminism"] as? String)?.hasPrefix("Stop before finalist selection") == true
                && (doc["runCountDecision"] as? [String: Any])?["screening"] as? String == "exactly one full pass per candidate (and the baseline) per entry",
            detail: "\(auditIDs.count) ids"
        ))
        let immutability = doc["immutability"] as? [String: Any]
        checks.append(CapabilityPreflightCheck(
            name: "immutability: frozen artifacts are immutable once committed; later defects are disclosed, not silently repaired",
            passed: (immutability?["statement"] as? String)?.contains("immutable") == true
                && (immutability?["defectsDiscoveredLater"] as? String)?.contains("never silently repaired") == true
                && Set(immutability?["frozenArtifacts"] as? [String] ?? []) == Set(self.artifactNames),
            detail: "candidates.json is not edited at S1"
        ))
        let probe = doc["contractProbe"] as? [String: Any]
        checks.append(CapabilityPreflightCheck(name: "contract probe names exactly the one pre-registered variant", passed: probe?["variantId"] as? String == "V-balanced-abstention", detail: "V-balanced-abstention"))
        return checks
    }

    // MARK: - Manifest

    static func fileHash(_ repoRoot: URL, _ relative: String) -> String? {
        (try? Data(contentsOf: repoRoot.appendingPathComponent(relative))).map { CapabilitySHA256.hex($0) }
    }

    static func manifest(repoRoot: URL, corpus: ComparisonCorpus, summary: OverlapSummary, fixtureCount: Int, allFixturesContained: Bool) -> [String: Any] {
        var artifacts: [String: String] = [:]
        for name in self.artifactNames {
            artifacts["\(self.directory)/\(name)"] = self.fileHash(repoRoot, "\(self.directory)/\(name)") ?? "missing"
        }
        var tooling: [String: String] = [:]
        for path in self.toolingPaths {
            tooling[path] = self.fileHash(repoRoot, path) ?? "missing"
        }
        let overlapRules: [String] = ComparisonOverlap.Rule.allCases.map(\.rawValue)
        let composition: [String: Int] = ComparisonCorpus.frozenComposition
        let frozenBenchmark: [String: Any] = [
            "path": self.frozenBenchmarkRelativePath,
            "sha256": CapabilityCorpus.frozenSHA256,
            "access": "text-level overlap check only; unavailable to candidate screening, contract development and variant development; one confirmatory run by a frozen finalist in a separately authorized milestone",
        ]
        let baseline: [String: Any] = [
            "instructionsSHA256": CapabilityFrozenRun.instructionsSHA256,
            "toolDefinitionSHA256": CapabilityFrozenRun.toolDefinitionSHA256,
        ]
        let corpusInfo: [String: Any] = [
            "sha256": corpus.sha256,
            "entries": corpus.entries.count,
            "composition": composition,
        ]
        let overlapInfo: [String: Any] = [
            "rules": overlapRules,
            "ngramLength": ComparisonOverlap.ngramLength,
            "nearDuplicateThreshold": ComparisonOverlap.nearDuplicateThreshold,
            "subjectsChecked": summary.subjectsChecked,
            "frozenEntriesCompared": summary.frozenEntries,
            "violations": summary.violations.count,
            "internalDuplicates": summary.internalDuplicates.count,
        ]
        let fixtureInfo: [String: Any] = ["count": fixtureCount, "allContainedAsExpected": allFixturesContained]
        return [
            "manifestSchemaVersion": 1,
            "milestone": "V1.27",
            "status": "frozen-preregistration; no inference, no model download, no candidate execution",
            "artifactSHA256": artifacts,
            "toolingSourceSHA256": tooling,
            "developmentCorpus": corpusInfo,
            "frozenBenchmark": frozenBenchmark,
            "baselineContract": baseline,
            "overlapCheck": overlapInfo,
            "hazardFixtures": fixtureInfo,
        ]
    }
}
