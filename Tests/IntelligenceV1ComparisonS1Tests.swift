import Foundation

/// Intelligence V1.28 -- Candidate Acquisition & Identity Verification (S1).
///
/// Offline tests for the S1 provenance verifier. They check the committed S1 artifact against the frozen
/// V1.27 registry and show that every guard fails closed on tampering (identity mismatch, substitution,
/// failed verification, inference evidence, a loaded model, an edited frozen registry, an unsupported
/// runtime). No Ollama, no model, no corpus, no network. Run via `scripts/test_intelligence_v1_comparison_s1.sh`.
@main
enum IntelligenceV1ComparisonS1Tests {
    static func main() throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        self.testCommittedArtifactVerifies(repoRoot)
        try self.testTamperingIsRefused(repoRoot)
        try self.testLocalBlobRehash()
        self.testVersionComparison()
        self.testStaticGuards(repoRoot)
        print("PASS: Intelligence V1.28 S1 acquisition/identity verifier -- all offline checks passed (no model, no corpus, no network)")
    }

    // MARK: - Committed artifact

    private static func testCommittedArtifactVerifies(_ repoRoot: URL) {
        let checks = AcquisitionVerifier.checks(repoRoot: repoRoot)
        precondition(checks.count >= 30, "the verifier must actually evaluate every candidate (\(checks.count) checks)")
        precondition(checks.allSatisfy(\.passed), "S1 artifact verification failed: \(checks.filter { !$0.passed }.map(\.name))")
        let artifact = AcquisitionVerifier.json(repoRoot.appendingPathComponent(AcquisitionVerifier.artifactDirectory).appendingPathComponent(AcquisitionVerifier.artifactName))
        precondition((artifact["candidates"] as? [[String: Any]])?.count == 5 && (artifact["summary"] as? [String: Any])?["allVerified"] as? Bool == true)
    }

    // MARK: - Tampering is refused

    /// A scratch repo root holding the frozen V1.27 directory verbatim (optionally with one registry edit) and the
    /// S1 artifact after `mutateArtifact`, so any refusal is caused by the mutation alone.
    private static func copyRoot(
        _ repoRoot: URL,
        mutateArtifact: (inout [String: Any]) -> Void,
        mutateRegistry: ((inout [String: Any]) -> Void)? = nil
    ) throws -> URL {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("v128-\(UUID().uuidString)")
        let frozenTarget = scratch.appendingPathComponent(AcquisitionVerifier.frozenDirectory)
        let artifactTarget = scratch.appendingPathComponent(AcquisitionVerifier.artifactDirectory)
        try FileManager.default.createDirectory(at: frozenTarget, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: artifactTarget, withIntermediateDirectories: true)
        let frozenSource = repoRoot.appendingPathComponent(AcquisitionVerifier.frozenDirectory)
        for name in try FileManager.default.contentsOfDirectory(atPath: frozenSource.path) where name.hasSuffix(".json") {
            if name == "candidates.json", let mutateRegistry {
                var object = AcquisitionVerifier.json(frozenSource.appendingPathComponent(name))
                mutateRegistry(&object)
                try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: frozenTarget.appendingPathComponent(name))
            } else {
                try FileManager.default.copyItem(at: frozenSource.appendingPathComponent(name), to: frozenTarget.appendingPathComponent(name))
            }
        }
        var artifact = AcquisitionVerifier.json(repoRoot.appendingPathComponent(AcquisitionVerifier.artifactDirectory).appendingPathComponent(AcquisitionVerifier.artifactName))
        mutateArtifact(&artifact)
        try JSONSerialization.data(withJSONObject: artifact, options: [.sortedKeys]).write(to: artifactTarget.appendingPathComponent(AcquisitionVerifier.artifactName))
        return scratch
    }

    private static func mutateCandidate(_ artifact: inout [String: Any], _ id: String, _ change: (inout [String: Any]) -> Void) {
        var candidates = (artifact["candidates"] as? [[String: Any]]) ?? []
        for index in candidates.indices where candidates[index]["id"] as? String == id {
            change(&candidates[index])
        }
        artifact["candidates"] = candidates
    }

    private static func testTamperingIsRefused(_ repoRoot: URL) throws {
        func refused(_ label: String, _ mutate: @escaping (inout [String: Any]) -> Void) throws {
            let root = try self.copyRoot(repoRoot, mutateArtifact: mutate)
            defer { try? FileManager.default.removeItem(at: root) }
            precondition(AcquisitionVerifier.checks(repoRoot: root).contains { !$0.passed }, "\(label) must be refused")
        }
        // The un-mutated copy must pass, so a refusal below is caused by the mutation alone.
        let pristine = try self.copyRoot(repoRoot, mutateArtifact: { _ in })
        defer { try? FileManager.default.removeItem(at: pristine) }
        precondition(AcquisitionVerifier.checks(repoRoot: pristine).allSatisfy(\.passed), "a faithful copy verifies")

        try refused("a changed model-layer digest") { artifact in
            self.mutateCandidate(&artifact, "CAND-002") { candidate in
                var local = candidate["localManifest"] as? [String: Any] ?? [:]
                var layers = local["layers"] as? [[String: Any]] ?? []
                layers[0]["digest"] = "sha256:" + String(repeating: "a", count: 64)
                local["layers"] = layers
                candidate["localManifest"] = local
            }
        }
        try refused("a changed layer size") { artifact in
            self.mutateCandidate(&artifact, "CAND-003") { candidate in
                var local = candidate["localManifest"] as? [String: Any] ?? [:]
                var layers = local["layers"] as? [[String: Any]] ?? []
                layers[0]["size"] = 1
                local["layers"] = layers
                candidate["localManifest"] = local
            }
        }
        try refused("a blob that does not re-hash to its digest") { artifact in
            self.mutateCandidate(&artifact, "CAND-001") { candidate in
                var blobs = candidate["blobs"] as? [[String: Any]] ?? []
                blobs[0]["matchesDigest"] = false
                candidate["blobs"] = blobs
            }
        }
        try refused("a recorded verification failure") { artifact in
            self.mutateCandidate(&artifact, "CAND-004") { $0["verification"] = ["status": "failed", "failure": "digest mismatch"] }
        }
        try refused("a substituted tag") { artifact in
            self.mutateCandidate(&artifact, "CAND-003") { $0["ollamaTag"] = "phi4-mini:3.8b" }
        }
        try refused("a missing candidate") { artifact in
            artifact["candidates"] = ((artifact["candidates"] as? [[String: Any]]) ?? []).filter { $0["id"] as? String != "CAND-004" }
        }
        try refused("a baseline that drifts from V1.23A") { artifact in
            self.mutateCandidate(&artifact, "CAND-BASE") { candidate in
                var local = candidate["localManifest"] as? [String: Any] ?? [:]
                local["sha256"] = String(repeating: "c", count: 64)
                candidate["localManifest"] = local
            }
        }
        try refused("a missing params layer record") { artifact in
            self.mutateCandidate(&artifact, "CAND-002") { candidate in
                var params = candidate["paramsLayer"] as? [String: Any] ?? [:]
                params["content"] = NSNull()
                candidate["paramsLayer"] = params
            }
        }
        try refused("an unsatisfied runtime requirement") { artifact in
            self.mutateCandidate(&artifact, "CAND-004") { $0["compatibility"] = ["satisfied": false] }
        }
        try refused("a license that does not match the registration") { artifact in
            self.mutateCandidate(&artifact, "CAND-003") { candidate in
                var license = candidate["license"] as? [String: Any] ?? [:]
                license["registeredLicense"] = "Proprietary"
                candidate["license"] = license
            }
        }
        try refused("inference evidence") { artifact in
            artifact["inferenceEvidence"] = ["generationCalls": 1, "chatOrCompletionRequests": 0, "modelsLoaded": 0]
        }
        try refused("a model left loaded") { artifact in
            var runtime = artifact["runtime"] as? [String: Any] ?? [:]
            runtime["loadedModelsAfter"] = [["name": "granite4.1:3b"]]
            artifact["runtime"] = runtime
        }
        try refused("a different runtime than the frozen registry") { artifact in
            var runtime = artifact["runtime"] as? [String: Any] ?? [:]
            runtime["serverVersion"] = "0.1.0"
            artifact["runtime"] = runtime
        }

        // Editing the frozen registry (candidates.json) is detected against FREEZE_MANIFEST.json.
        let editedRegistry = try self.copyRoot(repoRoot, mutateArtifact: { _ in }, mutateRegistry: { object in object["description"] = "edited after the freeze" })
        defer { try? FileManager.default.removeItem(at: editedRegistry) }
        precondition(AcquisitionVerifier.checks(repoRoot: editedRegistry).contains { !$0.passed }, "an edited frozen registry must be refused")
    }

    // MARK: - Local blob re-hash

    private static func testLocalBlobRehash() throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("v128-models-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        try FileManager.default.createDirectory(at: scratch.appendingPathComponent("blobs"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: scratch.appendingPathComponent("manifests/registry.ollama.ai/library/x"), withIntermediateDirectories: true)
        let content = Data("blob-content".utf8)
        let digest = CapabilitySHA256.hex(content)
        try content.write(to: scratch.appendingPathComponent("blobs/sha256-\(digest)"))
        precondition(CapabilityPreflight.streamingSHA256(of: scratch.appendingPathComponent("blobs/sha256-\(digest)")) == digest)
        try Data("tampered".utf8).write(to: scratch.appendingPathComponent("blobs/sha256-\(digest)"))
        precondition(CapabilityPreflight.streamingSHA256(of: scratch.appendingPathComponent("blobs/sha256-\(digest)")) != digest, "a modified blob no longer hashes to its digest")
        let missing = CapabilityPreflight.streamingSHA256(of: scratch.appendingPathComponent("blobs/sha256-absent"))
        precondition(missing == nil, "a missing blob is never treated as verified")
    }

    private static func testVersionComparison() {
        precondition(AcquisitionVerifier.version("0.34.4", atLeast: "0.13.1") && AcquisitionVerifier.version("0.34.4", atLeast: "0.5.13"))
        precondition(AcquisitionVerifier.version("0.34.4", atLeast: "0.34.4") && !AcquisitionVerifier.version("0.13.0", atLeast: "0.13.1"))
        precondition(!AcquisitionVerifier.version("0.5.9", atLeast: "0.5.13") && AcquisitionVerifier.version("1.0", atLeast: "0.99.9"))
    }

    // MARK: - Static guards

    private static func testStaticGuards(_ repoRoot: URL) {
        let directory = repoRoot.appendingPathComponent("Evaluation/Intelligence/ComparisonAcquisition")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path).filter({ $0.hasSuffix(".swift") }), files.count == 2 else {
            preconditionFailure("expected 2 acquisition sources")
        }
        for name in files {
            guard let full = try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8) else { preconditionFailure("read \(name)") }
            let code = full.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            for forbidden in ["URLSession", "URLRequest", "URLProtocol", "LLMClient", "IntelligenceHarnessProvider", "Process()", ".propose(", "/api/chat", "/api/generate", "chat/completions"] {
                precondition(!code.contains(forbidden), "\(name) must have no provider/network/inference path (found \(forbidden))")
            }
            precondition(!code.contains("corpus.json") && !code.contains("ComparisonCorpus") && !code.contains("CapabilityCorpus.load"), "\(name) must never reference either evaluation corpus")
        }
        let frozenManifest = AcquisitionVerifier.json(repoRoot.appendingPathComponent(AcquisitionVerifier.frozenDirectory).appendingPathComponent("FREEZE_MANIFEST.json"))
        precondition((frozenManifest["artifactSHA256"] as? [String: String])?.count == 5, "the V1.27 freeze manifest is intact")
    }
}
