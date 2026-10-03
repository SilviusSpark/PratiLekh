import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling: execution-build tests (part A).
///
/// Compiled with exactly the S3 runner's source set (minus its LLMClient-linked files), i.e. **without**
/// `CapabilityCorpus.swift`, so nothing here can read the V1.23 benchmark. Runs the real pinned plan builder
/// against the committed frozen artifacts (no corpus text is sent anywhere) and exercises the executor, scoring and
/// analysis with synthetic tooling fixtures and scripted stand-in proposers. No Ollama, no model, no network.
/// Run via `scripts/test_intelligence_v1_comparison_s2.sh [--write-plan]`.
@main
enum IntelligenceV1ComparisonS2Tests {
    static func main() async throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if CommandLine.arguments.contains("--write-plan") {
            try self.writePlan(repoRoot)
            return
        }
        let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
        let corpus = try ComparisonCorpus.load(from: repoRoot.appendingPathComponent(ComparisonCorpus.relativePath))
        let plan = try ComparisonExecutionPlan.build(repoRoot: repoRoot, corpus: corpus)
        try self.testPlan(repoRoot, corpus, plan)
        try self.testContractArmsAreSeparate(repoRoot)
        try await self.testExecutorMechanics(processor)
        try await self.testScoringAndAnalysis(processor)
        try self.testIsolationGuards(repoRoot)
        print(
            "PASS: Intelligence V1.29 S2 comparison execution tooling (execution build) -- all offline checks passed (no model, no network, benchmark not compiled in)"
        )
    }

    private static func writePlan(_ repoRoot: URL) throws {
        let corpus = try ComparisonCorpus.load(from: repoRoot.appendingPathComponent(ComparisonCorpus.relativePath))
        let plan = try ComparisonExecutionPlan.build(repoRoot: repoRoot, corpus: corpus)
        try plan.prettyJSON().write(to: repoRoot.appendingPathComponent(ComparisonExecutionPlan.proposedPlanPath), atomically: true, encoding: .utf8)
        try print("wrote \(ComparisonExecutionPlan.proposedPlanPath)\nplan SHA-256: \(plan.sha256())")
    }

    // MARK: - Plan

    private static func testPlan(_ repoRoot: URL, _ corpus: ComparisonCorpus, _ plan: ComparisonExecutionPlan) throws {
        precondition(plan.arm == .baselineV121, "S3 is the baseline contract arm")
        precondition(plan.candidates.map(\.id) == ["CAND-BASE", "CAND-001", "CAND-002", "CAND-003", "CAND-004"], "registry/S1 order, baseline first")
        precondition(plan.candidates.map(\.ollamaTag) == [
            "granite4:3b",
            "granite4.1:3b",
            "qwen3:4b-instruct-2507-q4_K_M",
            "phi4-mini:latest",
            "ministral-3:3b",
        ])
        precondition(plan.steps.count == 5 * (66 + 12) && plan.corpusEntryIDs.count == 66 && plan.auditEntryIDs.count == 12)
        precondition(plan.steps.map(\.sequence) == Array(1...390), "global sequence is contiguous")
        for candidate in plan.candidates {
            let own = plan.steps.filter { $0.candidateID == candidate.id }
            precondition(
                own.count == 78 && own.prefix(66).allSatisfy { $0.phase == .screening } && own.suffix(12).allSatisfy { $0.phase == .audit },
                "one full pass then the fixed audit, per candidate"
            )
            precondition(own.prefix(66).map(\.entryID) == corpus.entries.map(\.id), "screening follows corpus order")
            precondition(own.suffix(12).map(\.entryID) == plan.auditEntryIDs, "audit follows the protocol's fixed order")
        }
        var seenCandidates: [String] = []
        for step in plan.steps where seenCandidates.last != step.candidateID {
            precondition(!seenCandidates.contains(step.candidateID), "a candidate's steps are contiguous: one model resident at a time")
            seenCandidates.append(step.candidateID)
        }
        precondition(plan.auditEntryIDs == [
            "DEV-PUNC-001",
            "DEV-PUNC-009",
            "DEV-CAP-001",
            "DEV-CAP-006",
            "DEV-WS-001",
            "DEV-MULTI-002",
            "DEV-MULTI-005",
            "DEV-MSENT-002",
            "DEV-MSENT-005",
            "DEV-CTRL-001",
            "DEV-CTRL-011",
            "DEV-HAZ-NUM-001",
        ])
        // Deterministic: same inputs, same hash; and the committed proposed plan equals the recomputed one.
        let again = try ComparisonExecutionPlan.build(repoRoot: repoRoot, corpus: corpus)
        let firstHash = try plan.sha256(), secondHash = try again.sha256()
        let firstJSON = try plan.canonicalJSON(), secondJSON = try again.canonicalJSON()
        precondition(firstHash == secondHash && firstJSON == secondJSON)
        let committed = try String(contentsOf: repoRoot.appendingPathComponent(ComparisonExecutionPlan.proposedPlanPath), encoding: .utf8)
        let pretty = try plan.prettyJSON()
        precondition(
            committed == pretty,
            "S3_PROPOSED_RUN_PLAN.json is stale: re-run the S2 test script with --write-plan and have the architect re-approve the hash"
        )
        let manifest = try plan.manifest()
        precondition((manifest["contract"] as? [String: Any])?["arm"] as? String == "V1.21-production")
        precondition(manifest["freezeManifestRawSHA256"] as? String == "e5426006dc85b068c653ee86fb4633fd0255d119a45084abd7691a1ea059f8bd")

        // Pinned inputs are verified: a tampered registry, a wrong corpus and a broken S1 artifact are refused.
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("v129-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        for relative in [ComparisonExecutionPlan.directory, "Evaluation/References/intelligence-v1-comparison-s1"] {
            try FileManager.default.createDirectory(
                at: scratch.appendingPathComponent(relative).deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(at: repoRoot.appendingPathComponent(relative), to: scratch.appendingPathComponent(relative))
        }
        _ = try ComparisonExecutionPlan.build(repoRoot: scratch, corpus: corpus)
        func refused(_ file: String, _ detail: String) {
            let url = scratch.appendingPathComponent(file)
            let original = (try? Data(contentsOf: url)) ?? Data()
            defer { try? original.write(to: url) }
            try? (original + Data(" ".utf8)).write(to: url)
            do {
                _ = try ComparisonExecutionPlan.build(repoRoot: scratch, corpus: corpus)
                preconditionFailure("tampered \(detail) must be refused")
            } catch is ComparisonExecutionPlan.PlanError {
            } catch {
                preconditionFailure("unexpected error \(error)")
            }
        }
        refused(ComparisonExecutionPlan.directory + "/candidates.json", "candidate registry")
        refused(ComparisonExecutionPlan.directory + "/protocol.json", "protocol")
        refused(ComparisonExecutionPlan.directory + "/contract_variant.json", "contract variant")
        refused(ComparisonExecutionPlan.s1Path, "S1 artifact")
        let wrongCorpus = ComparisonCorpus(entries: corpus.entries, sha256: String(repeating: "0", count: 64))
        do {
            _ = try ComparisonExecutionPlan.build(repoRoot: repoRoot, corpus: wrongCorpus)
            preconditionFailure("a non-pinned corpus must be refused")
        } catch is ComparisonExecutionPlan.PlanError {}
        do {
            _ = try ComparisonCorpus.load(
                from: repoRoot.appendingPathComponent(ComparisonCorpus.relativePath),
                expectedSHA256: String(repeating: "0", count: 64)
            )
            preconditionFailure("the loader must verify its pin")
        } catch ComparisonCorpus.LoadError.hashMismatch {}
    }

    // MARK: - Baseline and variant arms are separate

    private static func testContractArmsAreSeparate(_ repoRoot: URL) throws {
        let baseline = ModelFacingGenerationContract.instructions
        let base = try ComparisonExecutionPlan.instructions(for: .baselineV121, baseline: baseline, repoRoot: nil)
        precondition(base == baseline && CapabilitySHA256.hex(of: base) == ComparisonExecutionPlan.baselineInstructionsSHA256)
        let variant = try ComparisonExecutionPlan.instructions(for: .variantBalancedAbstention, baseline: baseline, repoRoot: repoRoot)
        precondition(
            CapabilitySHA256.hex(of: variant) == ComparisonExecutionPlan.variantInstructionsSHA256 && variant != baseline,
            "the pre-registered variant reconstructs to its pinned hash"
        )
        precondition(
            variant.components(separatedBy: "schemaVersion").count == baseline.components(separatedBy: "schemaVersion").count,
            "the schemaVersion sentence is kept"
        )
        do {
            _ = try ComparisonExecutionPlan.instructions(for: .baselineV121, baseline: variant, repoRoot: nil)
            preconditionFailure("the baseline arm must refuse any text but the pinned V1.21 instructions")
        } catch is ComparisonExecutionPlan.PlanError {}
        do {
            _ = try ComparisonExecutionPlan.instructions(for: .variantBalancedAbstention, baseline: baseline + " x", repoRoot: repoRoot)
            preconditionFailure("the variant must refuse a baseline that differs from V1.21")
        } catch is ComparisonExecutionPlan.PlanError {}
        precondition(ComparisonExecutionPlan.ContractArm.baselineV121 != .variantBalancedAbstention)
        // `build` takes no flag that mixes arms: S3's plan is the baseline arm and says so in its hashed manifest.
        let manifestJSON = try String(contentsOf: repoRoot.appendingPathComponent(ComparisonExecutionPlan.proposedPlanPath), encoding: .utf8)
        precondition(
            manifestJSON.contains("V1.21-production") && !manifestJSON.contains(ComparisonExecutionPlan.variantInstructionsSHA256),
            "the S3 plan never names the variant text"
        )
    }

    // MARK: - Executor mechanics (scripted stand-ins)

    private static let fixtureCandidates = [
        ("CAND-BASE", "base:test", 400), ("CAND-001", "one:test", 200), ("CAND-002", "two:test", 250), ("CAND-003", "three:test", 300), (
            "CAND-004",
            "four:test",
            100
        ),
    ].map { ComparisonExecutionPlan.Candidate(
        id: $0.0,
        ollamaTag: $0.1,
        manifestSHA256: String(repeating: "a", count: 64),
        modelLayerDigest: "sha256:x",
        onDiskBytes: $0.2,
        paramsLayerContent: [:]
    ) }

    private static func fixtureCorpus() -> ComparisonCorpus {
        ComparisonCorpus(entries: S2ToolingFixtures.entries(), sha256: S2ToolingFixtures.corpusSHA256)
    }

    private static func fixturePlan() -> ComparisonExecutionPlan {
        ComparisonExecutionPlan.fixturePlan(
            candidates: self.fixtureCandidates,
            corpusEntryIDs: S2ToolingFixtures.specs.map(\.id),
            auditEntryIDs: S2ToolingFixtures.auditIDs
        )
    }

    /// Runs the fixture plan with a scripted proposer. `behavior` gets (candidateID, entry, attempt number for that pair).
    private static func runFixture(
        _ processor: LegalDictationProcessor,
        arm: ComparisonExecutionPlan.ContractArm = .baselineV121,
        behavior: @escaping (String, CapabilityCorpus.Entry, Int) -> ComparisonProposerOutcome,
        onCall: (() -> Void)? = nil
    ) async throws -> (records: [ComparisonCallRecord], calls: Int) {
        let corpus = self.fixtureCorpus()
        let byNormalized = Dictionary(uniqueKeysWithValues: corpus.entries.map { (processor.process($0.text).normalized, $0) })
        var attempts: [String: Int] = [:]
        var calls = 0
        var records: [ComparisonCallRecord] = []
        let plan = self.fixturePlan()
        try await ComparisonExecutor.execute(
            plan: plan,
            corpus: corpus,
            evidence: .toolingFixture,
            processor: processor,
            runID: "tooling-test",
            instructions: ModelFacingGenerationContract.instructions,
            proposer: { request in
                calls += 1
                onCall?()
                guard let entry = byNormalized[request.userText] else { preconditionFailure("unknown user text") }
                let key = request.candidate.id + "|" + entry.id
                attempts[key, default: 0] += 1
                return behavior(request.candidate.id, entry, attempts[key] ?? 0)
            },
            sink: { records.append($0) }
        )
        return (records, calls)
    }

    private static func response(_ arguments: String) -> ComparisonProposerOutcome {
        .success(IntelligenceProviderResponse(toolCalls: [IntelligenceProviderToolCall(
            name: ModelFacingGenerationContract.toolName,
            rawArguments: arguments
        )]))
    }

    private static func testExecutorMechanics(_ processor: LegalDictationProcessor) async throws {
        let plan = self.fixturePlan()
        precondition(plan.steps.count == 5 * (13 + 3))
        let run = try await self.runFixture(processor) { _, entry, _ in self.response(S2ToolingFixtures.oracleArguments(for: entry)) }
        precondition(run.calls == plan.steps.count && run.records.count == plan.steps.count, "exactly one proposer call per step; never a repeat")
        precondition(
            run.records.map(\.sequence) == Array(1...plan.steps.count) && zip(run.records, plan.steps)
                .allSatisfy { $0.candidateID == $1.candidateID && $0.phase == $1.phase.rawValue && $0.entryID == $1.entryID },
            "records follow the plan exactly"
        )
        precondition(run.records
            .allSatisfy {
                $0.evidenceKind == "toolingFixture" && $0.stage == "S3" && $0.contractArm == "V1.21-production" && $0.latencyMilliseconds != nil && $0
                    .requestFingerprintSHA256 != nil
            })
        precondition(
            Set(run.records.map(\.requestFingerprintSHA256)).count == 5 * 13,
            "fingerprint distinguishes candidate and text, and is identical across a pair's two attempts"
        )
        precondition(run.records.first?.toolDefinitionSHA256 == ComparisonExecutionPlan.baselineToolDefinitionSHA256)

        // A provider failure is recorded, never retried, and the run continues in plan order.
        var failedOnce = false
        let failing = try await self.runFixture(processor) { candidate, entry, attempt in
            if candidate == "CAND-002", entry.id == "TF-P1", attempt == 1 {
                failedOnce = true
                return .failure("timed out")
            }
            return self.response(S2ToolingFixtures.oracleArguments(for: entry))
        }
        precondition(failedOnce && failing.calls == plan.steps.count, "a failed call is not re-attempted")
        let failedRecord = failing.records.first { $0.candidateID == "CAND-002" && $0.entryID == "TF-P1" && $0.phase == "screening" }
        precondition(failedRecord?.providerFailure == "timed out" && failedRecord?.rawToolCallArguments.isEmpty == true)
        precondition(
            failing.records.first { $0.candidateID == "CAND-002" && $0.entryID == "TF-P1" && $0.phase == "audit" }?.providerFailure == nil,
            "the audit is its own planned step, not a retry"
        )

        // Outputs never change what runs next: scripted different behavior never alters count or order.
        let reversed = try await self.runFixture(processor) { _, _, _ in self.response(S2ToolingFixtures.emptyArguments) }
        precondition(reversed.records.map(\.entryID) == run.records.map(\.entryID) && reversed.calls == run.calls)

        // Hooks fire around each candidate in order; a throwing hook refuses the candidate before any call for it.
        var events: [String] = []
        var hooks = ComparisonExecutionHooks()
        hooks.candidateWillStart = { events.append("start:\($0.id)") }
        hooks.candidateDidFinish = { events.append("finish:\($0.id)") }
        hooks.runtimeObservation = { "ps:\($0.id)" }
        let corpus = self.fixtureCorpus()
        var observed: [ComparisonCallRecord] = []
        try await ComparisonExecutor.execute(
            plan: plan,
            corpus: corpus,
            evidence: .toolingFixture,
            processor: processor,
            runID: "hooks",
            instructions: ModelFacingGenerationContract.instructions,
            proposer: { _ in self.response(S2ToolingFixtures.emptyArguments) },
            hooks: hooks,
            sink: { observed.append($0) }
        )
        precondition(events == [
            "start:CAND-BASE",
            "finish:CAND-BASE",
            "start:CAND-001",
            "finish:CAND-001",
            "start:CAND-002",
            "finish:CAND-002",
            "start:CAND-003",
            "finish:CAND-003",
            "start:CAND-004",
            "finish:CAND-004",
        ])
        precondition(observed.filter { $0.runtimeObservation != nil }.count == 10, "a runtime observation after each candidate's first and last call")
        var blockedCalls = 0
        hooks.candidateWillStart = {
            if $0.id == "CAND-002" {
                throw ComparisonExecutor.ExecutionError.refused("resident model")
            }
        }
        do {
            try await ComparisonExecutor.execute(
                plan: plan,
                corpus: corpus,
                evidence: .toolingFixture,
                processor: processor,
                runID: "hooks",
                instructions: ModelFacingGenerationContract.instructions,
                proposer: { _ in blockedCalls += 1; return self.response(S2ToolingFixtures.emptyArguments) },
                hooks: hooks,
                sink: { _ in }
            )
            preconditionFailure("a throwing start hook must abort")
        } catch ComparisonExecutor.ExecutionError.refused {}
        precondition(blockedCalls == 2 * 16, "nothing runs for the refused candidate or after it")

        // Refusals: a development-corpus run needs the pinned corpus and the full plan; arm/instructions must agree.
        do {
            try await ComparisonExecutor.execute(
                plan: plan,
                corpus: corpus,
                evidence: .developmentCorpus,
                processor: processor,
                runID: "x",
                instructions: ModelFacingGenerationContract.instructions,
                proposer: { _ in preconditionFailure("must not be called") },
                sink: { _ in }
            )
            preconditionFailure("fixtures can never be run as development evidence")
        } catch ComparisonExecutor.ExecutionError.refused {}
        do {
            try await ComparisonExecutor.execute(
                plan: plan,
                corpus: corpus,
                evidence: .toolingFixture,
                processor: processor,
                runID: "x",
                instructions: ModelFacingGenerationContract.instructions + " tampered",
                proposer: { _ in preconditionFailure("must not be called") },
                sink: { _ in }
            )
            preconditionFailure("instructions must match the arm")
        } catch ComparisonExecutor.ExecutionError.refused {}

        // JSONL round trip is lossless.
        let text = ComparisonRecordCoding.jsonLines(run.records)
        let decoded = try ComparisonRecordCoding.decode(jsonLines: text)
        precondition(decoded == run.records)
        precondition(ComparisonExecutor.toolDefinitionSHA256() == ComparisonExecutionPlan.baselineToolDefinitionSHA256)
    }

    // MARK: - Scoring and analysis (scripted stand-ins over tooling fixtures)

    private static func testScoringAndAnalysis(_ processor: LegalDictationProcessor) async throws {
        let corpus = self.fixtureCorpus()
        let plan = self.fixturePlan()
        let foreign = S2ToolingFixtures.rawArguments([("the peon", "The peon")]) // capitalization-only on an abstention-expected control
        // CAND-BASE abstains; CAND-001 oracle; CAND-002 oracle with one provider failure; CAND-003 oracle but unlicensed edit on a control;
        // CAND-004 oracle but its audit answers differ on two entries (nondeterminism).
        let run = try await self.runFixture(processor, behavior: { candidate, entry, attempt in
            switch candidate {
            case "CAND-BASE": self.response(S2ToolingFixtures.emptyArguments)
            case "CAND-002" where entry.id == "TF-P2" && attempt == 1: .failure("timed out")
            case "CAND-003" where entry.id == "TF-K1" && attempt == 1: self.response(foreign)
            case "CAND-004" where attempt == 2 && ["TF-P1", "TF-C1"].contains(entry.id): self.response(S2ToolingFixtures.emptyArguments)
            default: self.response(S2ToolingFixtures.oracleArguments(for: entry))
            }
        })
        let results = try ComparisonAnalysis.assemble(
            records: run.records,
            plan: plan,
            corpus: corpus,
            processor: processor,
            requireEvidenceKind: "toolingFixture"
        )
        precondition(results.count == 5 && results.allSatisfy { $0.screening.count == 13 && $0.audit.count == 3 && $0.auditComparisons.count == 3 })

        // Per-entry scoring semantics on the oracle candidate.
        let oracle = results[1]
        for score in oracle.screening where score.entry.isScoredCorrectionWarranted {
            precondition(
                score.autonomousState == .complete && score.trialKind == .evaluated && score.exactPairViolations == 0 && score
                    .parserCompliant && score.toolEngaged,
                "\(score.entry.id): oracle output is complete and autonomously accepted"
            )
        }
        precondition(oracle.screening.filter(\.entry.isScoredAbstentionExpected).allSatisfy { $0.autonomousState == .unchanged })
        precondition(oracle.screening.first { $0.entry.id == "TF-A1" }?.autonomousState == nil, "manual entries are never scored")
        precondition(oracle.screening.allSatisfy { $0.replayMismatch == nil })

        /// Malformed / protocol outcomes are recorded from raw text, never repaired.
        func score(_ entry: String, names: [String], arguments: [String], text: String? = nil) throws -> ComparisonEntryScore {
            guard let spec = S2ToolingFixtures.entries().first(where: { $0.id == entry }) else { preconditionFailure("fixture") }
            guard var record = run.records.first(where: { $0.entryID == entry && $0.candidateID == "CAND-001" && $0.phase == "screening" })
            else { preconditionFailure("record") }
            record.toolCallNames = names
            record.rawToolCallArguments = arguments
            record.modelTextContent = text
            return try ComparisonScoring.score(entry: spec, record: record, processor: processor)
        }
        let missingVersion = try score("TF-P1", names: [ModelFacingGenerationContract.toolName], arguments: ["{\"edits\":[]}"])
        precondition(
            missingVersion.trialKind == .protocolFailure && missingVersion.toolEngaged && missingVersion.reachedParser && !missingVersion
                .parserCompliant,
            "a missing required field fails the strict parser, as recorded"
        )
        let noTool = try score("TF-P1", names: [], arguments: [], text: "The text needs a period.")
        precondition(noTool.trialKind == .protocolFailure && !noTool.toolEngaged && !noTool.reachedParser)
        let twoCalls = try score(
            "TF-P1",
            names: [ModelFacingGenerationContract.toolName, ModelFacingGenerationContract.toolName],
            arguments: [S2ToolingFixtures.emptyArguments, S2ToolingFixtures.emptyArguments]
        )
        precondition(twoCalls.trialKind == .protocolFailure && twoCalls.toolEngaged && !twoCalls.reachedParser)
        let wrongName = try score("TF-P1", names: ["other_tool"], arguments: [S2ToolingFixtures.emptyArguments])
        precondition(wrongName.trialKind == .protocolFailure && !wrongName.toolEngaged)
        let wide = try score(
            "TF-P1",
            names: [ModelFacingGenerationContract.toolName],
            arguments: [S2ToolingFixtures.rawArguments([("the surveyor measured the boundary wall", "the surveyor measured the boundary wall.")])]
        )
        precondition(
            wide.spanWidths == [ComparisonSpanWidth.wholeText] && wide.exactPairViolations == 1,
            "a whole-text rewrite is width wholeText and matches no expected pair (U0, report-only)"
        )
        precondition(
            wide.autonomousState == .complete,
            "outcome correctness and edit form are separate: the resulting text is still the licensed one"
        )
        precondition(ComparisonSpanWidth.classify(
            sourceText: "the porter locked the gate.",
            normalized: "the porter locked the gate. the cook served tea"
        ) == .wholeSentence)
        precondition(ComparisonSpanWidth.classify(sourceText: "gate", normalized: "the porter locked the gate. the cook served tea") == .minimal)
        precondition(ComparisonSpanWidth
            .classify(sourceText: "the cook served tea", normalized: "the porter locked the gate. the cook served tea") == .wholeSentence)

        // Audit comparison.
        let aligned = ComparisonAudit.compare(screening: oracle.screening[0], audit: oracle.audit[0])
        precondition(!aligned.disagrees && !aligned.rawOutputDiffers)
        let flaky = results[4].auditComparisons.filter(\.disagrees).map(\.entryID)
        precondition(flaky == ["TF-P1", "TF-C1"], "only the scripted disagreements are reported")

        // McNemar: exact two-sided, p = 1 without discordant pairs.
        precondition(ComparisonAnalysis.mcNemarTwoSided(baselineOnly: 0, candidateOnly: 0) == 1)
        precondition(abs(ComparisonAnalysis.mcNemarTwoSided(baselineOnly: 0, candidateOnly: 5) - 0.0625) < 1e-12)
        precondition(abs(ComparisonAnalysis.mcNemarTwoSided(baselineOnly: 1, candidateOnly: 6) - 0.125) < 1e-12)
        precondition(abs(ComparisonAnalysis.mcNemarTwoSided(baselineOnly: 3, candidateOnly: 3) - 1.0) < 1e-12)
        precondition(abs(ComparisonAnalysis.mcNemarTwoSided(baselineOnly: 0, candidateOnly: 9) - 2.0 / 512) < 1e-12)

        // Gates, advancement, ranking, probe, halt.
        guard let analysis = ComparisonAnalysis.screen(results: results, fixturesContained: true) else { preconditionFailure("baseline present") }
        precondition(
            analysis.baseline.completeCount == 0 && analysis.baseline.warranted == 9 && analysis.baseline.perCorrection.denominator == 10,
            "9 warranted entries, 10 corrections (the multi-edit entry counts both)"
        )
        let byID: [String: ComparisonScreeningAnalysis.CandidateAssessment] = Dictionary(uniqueKeysWithValues: analysis.assessments.map { (
            $0.summary.result.candidate.id,
            $0
        ) })
        precondition(byID["CAND-001"]?.eligible == true && byID["CAND-001"]?.a1Pass == true && byID["CAND-001"]?.summary.completeCount == 9)
        precondition(
            byID["CAND-002"]?.gates.g2Pass == false && byID["CAND-002"]?.eligible == false && byID["CAND-002"]?.summary.providerFailures.count == 1,
            "a provider failure fails G2"
        )
        precondition(
            byID["CAND-003"]?.gates.g3Pass == false && byID["CAND-003"]?.summary.u1Entries == ["TF-K1"] && byID["CAND-003"]?.summary
                .u0 == 1 && byID["CAND-003"]?.eligible == false,
            "an unlicensed autonomous edit on a control is U1 and fails G3"
        )
        precondition(byID["CAND-004"]?.eligible == true && byID["CAND-004"]?.summary.nondeterminismFlag == true)
        precondition(
            analysis.ranking == ["CAND-004", "CAND-001"],
            "complete, punctuation non-empty and slow calls tie; the smaller on-disk model ranks first"
        )
        precondition(analysis.finalist == "CAND-004", "at most one finalist")
        precondition(
            analysis.probeTriggered && analysis.probeModels == ["CAND-BASE", "CAND-004", "CAND-001"],
            "baseline non-empty rate 0/9 < 0.50: baseline plus the top two screened"
        )
        precondition(analysis.haltBeforeS5, "two audit disagreements stop the experiment before S5")
        let withoutFixtures = ComparisonAnalysis.screen(results: results, fixturesContained: false)
        precondition(
            withoutFixtures?.ranking.isEmpty == true && withoutFixtures?.finalist == nil,
            "an uncontained hazard fixture fails G3 for every candidate: no finalist"
        )
        let report = ComparisonAnalysis.markdown(analysis, runLabel: "tooling fixture")
        precondition(report.contains("CAND-003") && report.contains("finalist: CAND-004") && report.contains("PO-2"))

        /// Ranking has only the four V1.27 keys. Exact ties are never broken (registry order is presentation only).
        func withBytes(_ overrides: [String: Int]) -> [ComparisonModelResult] {
            results.map { result in
                guard let bytes = overrides[result.candidate.id] else { return result }
                let c = result.candidate
                let resized = ComparisonExecutionPlan.Candidate(
                    id: c.id,
                    ollamaTag: c.ollamaTag,
                    manifestSHA256: c.manifestSHA256,
                    modelLayerDigest: c.modelLayerDigest,
                    onDiskBytes: bytes,
                    paramsLayerContent: c.paramsLayerContent
                )
                return ComparisonModelResult(
                    candidate: resized,
                    screening: result.screening,
                    audit: result.audit,
                    auditComparisons: result.auditComparisons
                )
            }
        }
        guard let firstPlaceTie = ComparisonAnalysis.screen(results: withBytes(["CAND-001": 100]), fixturesContained: true)
        else { preconditionFailure("baseline") }
        precondition(
            firstPlaceTie.ranking == ["CAND-001", "CAND-004"] && firstPlaceTie.finalist == nil,
            "an exact first-place tie selects no finalist"
        )
        precondition(firstPlaceTie.finalistTie == ["CAND-001", "CAND-004"] && firstPlaceTie.haltBeforeS5, "and stops for review")
        precondition(firstPlaceTie.reviewStops.contains { $0.contains("exact tie for first place") })
        precondition(firstPlaceTie.probeModels == ["CAND-BASE", "CAND-001", "CAND-004"], "a tie inside the top two does not straddle the cutoff")
        guard let straddle = ComparisonAnalysis.screen(results: withBytes(["CAND-003": 200]), fixturesContained: true)
        else { preconditionFailure("baseline") }
        precondition(
            straddle.probeTriggered && straddle.probeModels.isEmpty && straddle.probeCutoffTie == ["CAND-001", "CAND-003"],
            "a tie across the S4 cutoff is not broken"
        )
        precondition(straddle.finalist == "CAND-004" && straddle.reviewStops.contains { $0.contains("S4 probe cutoff") } && straddle.haltBeforeS5)
        guard let rehabilitation = ComparisonAnalysis.screen(results: withBytes(["CAND-003": 50]), fixturesContained: true)
        else { preconditionFailure("baseline") }
        precondition(
            rehabilitation.probeModels == ["CAND-BASE", "CAND-003", "CAND-004"],
            "top two come from all screened non-baseline candidates, eligible or not"
        )
        precondition(rehabilitation.assessments.first { $0.summary.result.candidate.id == "CAND-003" }?.eligible == false)
        precondition(
            !rehabilitation.ranking.contains("CAND-003") && rehabilitation.finalist != "CAND-003",
            "probing never rehabilitates an S3-ineligible candidate"
        )
        precondition(report.contains("review stops") && report.contains("registry order is presentation only"))
        precondition(analysis.finalistTie.isEmpty && analysis.probeCutoffTie.isEmpty, "a size difference (key 4) resolves what keys 1-3 leave tied")

        /// Lifecycle (unload) evidence is separate from proposer evidence and auditable.
        func lifecycle(_ mutate: (inout [ComparisonLifecycleEvent]) -> Void = { _ in }, records overridden: [ComparisonCallRecord] = []) -> [String] {
            var events: [ComparisonLifecycleEvent] = []
            func add(
                _ kind: ComparisonLifecycleEvent.Kind,
                _ candidate: ComparisonExecutionPlan.Candidate,
                _ endpoint: String,
                body: String? = nil,
                resident: [String] = [],
                observed: Bool = false
            ) {
                events.append(ComparisonLifecycleEvent(
                    runID: "tooling-test",
                    sequence: events.count + 1,
                    kind: kind,
                    candidateID: candidate.id,
                    ollamaTag: candidate.ollamaTag,
                    endpoint: endpoint,
                    requestBody: body,
                    startedAt: "2999-01-01T00:00:00Z",
                    finishedAt: "2999-01-01T00:00:00Z",
                    httpStatus: 200,
                    residentModelsAfter: resident,
                    residentObserved: observed,
                    countsAsInference: false,
                    note: nil
                ))
            }
            for candidate in plan.candidates {
                add(.residentCheck, candidate, "GET /api/ps", observed: true)
                add(.unloadRequest, candidate, "POST /api/generate", body: ComparisonLifecycleCoding.unloadBody(tag: candidate.ollamaTag))
                add(.unloadVerification, candidate, "GET /api/ps", observed: true)
            }
            mutate(&events)
            return ComparisonLifecycleAudit.verify(events: events, records: overridden.isEmpty ? run.records : overridden, plan: plan).problems
        }
        precondition(lifecycle().isEmpty, "unload requests are verified as one keep_alive-0, prompt-free, non-inference request per candidate")
        precondition(ComparisonLifecycleCoding.unloadBody(tag: "x:1") == "{\"keep_alive\":0,\"model\":\"x:1\"}")
        precondition(!lifecycle { $0[1].countsAsInference = true }.isEmpty, "a lifecycle event marked as inference is refused")
        precondition(
            !lifecycle { $0.remove(at: 4) }.isEmpty && !lifecycle { $0.remove(at: 5) }.isEmpty,
            "a missing unload or verification is refused"
        )
        precondition(
            !lifecycle { $0[1].requestBody = "{\"keep_alive\":0,\"model\":\"base:test\",\"prompt\":\"hi\"}" }.isEmpty,
            "an unload carrying a prompt is refused"
        )
        precondition(!lifecycle { $0[2].residentModelsAfter = ["base:test"] }.isEmpty, "an unload that leaves a model resident is refused")
        precondition(!lifecycle { $0[2].residentObserved = false }.isEmpty, "an unobserved (assumed-empty) verification is refused")
        precondition(
            !lifecycle { $0[1].startedAt = "1970-01-01T00:00:00Z" }.isEmpty,
            "an unload before the candidate's last proposer call is refused"
        )
        precondition(!lifecycle { $0[1].endpoint = "POST /api/chat" }.isEmpty && !lifecycle { $0[0].runID = "other" }.isEmpty)
        precondition(
            !lifecycle(records: Array(run.records.dropLast())).isEmpty,
            "proposer accounting must equal the plan, independent of lifecycle events"
        )
        precondition(
            lifecycle {
                var extra = $0[1]
                extra.sequence = $0.count + 1
                $0.append(extra)
            }.contains { $0.contains("unload requests") },
            "an extra unload is refused"
        )
        precondition(
            ComparisonLifecycleAudit.verify(events: [], records: run.records, plan: plan).lines.contains { $0.contains("FAILED") },
            "no lifecycle evidence fails verification"
        )
        let sample = ComparisonLifecycleEvent(
            runID: "r",
            sequence: 1,
            kind: .unloadRequest,
            candidateID: "c",
            ollamaTag: "t",
            endpoint: "POST /api/generate",
            requestBody: "{}",
            startedAt: "a",
            finishedAt: "b",
            httpStatus: 200,
            residentModelsAfter: [],
            residentObserved: false,
            countsAsInference: false,
            note: nil
        )
        let decodedEvents = try ComparisonLifecycleCoding.decode(jsonLines: ComparisonLifecycleCoding.line(sample) + "\n")
        precondition(decodedEvents == [sample])
        precondition(ComparisonAnalysis.markdown(analysis, runLabel: "x", lifecycleLines: ["- lifecycle line"])
            .contains("Runtime lifecycle accounting"))

        /// The hard gates are raw-count conditions: 18/19 engagement passes, 17/19 does not.
        func gates(_ engaged: Int, _ total: Int) -> Bool {
            engaged * 100 >= total * 95
        }
        precondition(gates(19, 19) && gates(95, 100) && !gates(94, 100))

        // Records not matching the plan are refused (missing step, reordered, mixed evidence).
        var short = run.records
        short.removeLast()
        do { _ = try ComparisonAnalysis.assemble(
            records: short,
            plan: plan,
            corpus: corpus,
            processor: processor,
            requireEvidenceKind: "toolingFixture"
        ); preconditionFailure("missing record") } catch is ComparisonAnalysis.AnalysisError {}
        do {
            _ = try ComparisonAnalysis
                .assemble(
                    records: run.records,
                    plan: plan,
                    corpus: corpus,
                    processor: processor
                ); preconditionFailure("fixture evidence is never accepted as development evidence")
        } catch is ComparisonAnalysis
            .AnalysisError {}
        var swapped = run.records
        swapped.swapAt(0, 1)
        swapped[0].sequence = 1
        swapped[1].sequence = 2
        do { _ = try ComparisonAnalysis.assemble(
            records: swapped,
            plan: plan,
            corpus: corpus,
            processor: processor,
            requireEvidenceKind: "toolingFixture"
        ); preconditionFailure("reordered steps") } catch is ComparisonAnalysis.AnalysisError {}
    }

    // MARK: - Isolation guards

    private static func text(_ repoRoot: URL, _ path: String) -> String {
        guard let value = try? String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        else { preconditionFailure("cannot read \(path)") }
        return value
    }

    private static func scriptList(_ repoRoot: URL, script: String, variable: String) -> [String] {
        let body = self.text(repoRoot, script)
        guard let start = body.range(of: "\(variable)=\"\n"),
              let end = body.range(of: "\n\"", range: start.upperBound..<body.endIndex) else { preconditionFailure("no \(variable) in \(script)") }
        return body[start.upperBound..<end.lowerBound].split(separator: "\n").map(String.init)
    }

    private static func testIsolationGuards(_ repoRoot: URL) throws {
        let chain = ComparisonExecutionSources.chainSources
        let core = ComparisonExecutionSources.coreTooling
        let llm = [
            "Sources/Fluid/Services/FileLogger.swift",
            "Sources/Fluid/Services/DebugLogger.swift",
            "Sources/Fluid/Services/ThinkingParsers.swift",
            "Sources/Fluid/Services/LLMClient.swift",
            "Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponse+LLMClientBridge.swift",
        ]
        let provider = ComparisonExecutionSources.providerTooling
        // The build scripts compile exactly the declared source sets, and none contains a forbidden file.
        let runList = self.scriptList(repoRoot, script: "scripts/intelligence_v1_comparison_s3_run.sh", variable: "task_sources")
        let analyzeList = self.scriptList(repoRoot, script: "scripts/intelligence_v1_comparison_s3_analyze.sh", variable: "task_sources")
        let testList = self.scriptList(repoRoot, script: "scripts/test_intelligence_v1_comparison_s2.sh", variable: "exec_sources")
        precondition(runList == llm + chain + core + provider, "the live runner compiles exactly the declared execution set")
        precondition(analyzeList == chain + core && testList == chain + core, "analyzer and execution tests compile exactly the declared set")
        for (name, list) in [("run", runList), ("analyze", analyzeList), ("test", testList)] {
            for path in list {
                precondition(
                    !ComparisonExecutionSources.forbiddenSourceFiles.contains((path as NSString).lastPathComponent),
                    "\(name) build includes forbidden file \(path)"
                )
            }
        }
        precondition(!chain.contains { $0.hasSuffix("CapabilityCorpus.swift") } && chain.contains { $0.hasSuffix("CapabilityAdjudication.swift") })
        // No execution-path file mentions the benchmark, its loader, pin, results, or any V1.23 artifact.
        let all = llm + chain + core + provider + [ComparisonExecutionSources.liveRunner, ComparisonExecutionSources.analysisRunner]
        var references = Set<String>()
        for path in all {
            let body = self.text(repoRoot, path)
            for token in ComparisonExecutionSources.forbiddenTokens {
                precondition(!body.contains(token), "\(path) references forbidden token \(token)")
            }
            if let regex = try? NSRegularExpression(pattern: "Evaluation/References/[A-Za-z0-9_.-]+") {
                for match in regex.matches(in: body, range: NSRange(body.startIndex..., in: body)) {
                    if let range = Range(match.range, in: body) {
                        references.insert(String(body[range]))
                    }
                }
            }
        }
        let allowedReferences: Set = [
            "Evaluation/References/intelligence-v1-comparison-dev",
            "Evaluation/References/intelligence-v1-comparison-s1",
            "Evaluation/References/intelligence-v1-comparison-s2",
        ]
        precondition(
            references.isSubset(of: allowedReferences) && references.contains("Evaluation/References/intelligence-v1-comparison-dev"),
            "execution code names only the development, S1 and S2 reference folders: \(references)"
        )
        // The core tooling (everything but the provider/runners) has no network, process or LLMClient symbol.
        for path in core {
            let body = self.text(repoRoot, path)
            for symbol in ["URLSession", "LLMClient.", "Process(", "URLRequest"] {
                precondition(!body.contains(symbol), "\(path) contains \(symbol): only the provider and runner may touch a model or network")
            }
        }
        // The executor calls the proposer in exactly one place, inside the successful-preflight branch.
        let executor = self.text(repoRoot, "Evaluation/Intelligence/ComparisonExecution/ComparisonExecutor.swift")
        precondition(executor.components(separatedBy: "await proposer(").count == 2, "exactly one proposer call site")
        let executorCode = executor.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
        precondition(
            !executorCode.contains("while ") && !executorCode.contains("repeat {") && executorCode.components(separatedBy: "for step in plan.steps")
                .count == 3,
            "no retry/repeat loop in the executor: only for-loops over the plan's steps"
        )
        // The only LLMClient-linked execution files are the provider and the live runner.
        for path in core + chain {
            precondition(!self.text(repoRoot, path).contains("LLMClient.shared"), "\(path) must not call LLMClient")
        }
        // The shadow type exposes no loader/pin/path (also proved by the negative-compile probes in the script).
        let shadow = self.text(repoRoot, "Evaluation/Intelligence/ComparisonExecution/ComparisonExecutionEntryTypes.swift")
        for member in ["static func load", "static let frozen", "relativePath", "frozenSHA256"] {
            precondition(!shadow.contains(member), "the corpus-isolation seam must not define \(member)")
        }
    }
}
