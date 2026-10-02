import Foundation

/// Intelligence V1.28 -- Candidate Acquisition & Identity Verification (stage S1).
///
/// Offline verifier for the S1 acquisition/identity artifact. It compares the recorded local identity
/// of every registered candidate with the **frozen V1.27 registry** (`candidates.json`, read-only) and
/// fails closed on any mismatch, substitution or inference evidence. It never reads either evaluation
/// corpus, never contacts Ollama and never loads a model. The optional local check re-hashes the
/// recorded blobs on disk.
enum AcquisitionVerifier {
    static let frozenDirectory = "Evaluation/References/intelligence-v1-comparison-dev"
    static let artifactDirectory = "Evaluation/References/intelligence-v1-comparison-s1"
    static let artifactName = "acquisition_identity.json"
    static let requiredCandidateIDs = ["CAND-BASE", "CAND-001", "CAND-002", "CAND-003", "CAND-004"]

    // MARK: - Helpers

    static func json(_ url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
    }

    static func fileHash(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).map { CapabilitySHA256.hex($0) }
    }

    /// `a >= b` for dotted numeric versions ("0.34.4" >= "0.13.1").
    static func version(_ a: String, atLeast b: String) -> Bool {
        let x = a.split(separator: ".").compactMap { Int($0) }
        let y = b.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(x.count, y.count) {
            let l = index < x.count ? x[index] : 0
            let r = index < y.count ? y[index] : 0
            if l != r {
                return l > r
            }
        }
        return true
    }

    private static func layerList(_ value: Any?) -> [[String: String]] {
        ((value as? [[String: Any]]) ?? []).map { item in
            ["mediaType": item["mediaType"] as? String ?? "", "digest": item["digest"] as? String ?? "", "size": "\(item["size"] as? Int ?? -1)"]
        }
    }

    // MARK: - Offline checks (committed artifact vs frozen registry)

    static func checks(repoRoot: URL) -> [CapabilityPreflightCheck] {
        let frozen = repoRoot.appendingPathComponent(self.frozenDirectory)
        let candidatesURL = frozen.appendingPathComponent("candidates.json")
        let registry = self.json(candidatesURL)
        let artifact = self.json(repoRoot.appendingPathComponent(self.artifactDirectory).appendingPathComponent(self.artifactName))
        let manifest = self.json(frozen.appendingPathComponent("FREEZE_MANIFEST.json"))
        var checks: [CapabilityPreflightCheck] = []
        guard !artifact.isEmpty, !registry.isEmpty, !manifest.isEmpty else {
            return [CapabilityPreflightCheck(name: "S1 artifact, frozen registry and freeze manifest readable", passed: false, detail: "missing or malformed")]
        }

        // The frozen V1.27 artifacts must still equal what the freeze manifest recorded (nothing was edited at S1).
        let recorded = (manifest["artifactSHA256"] as? [String: String]) ?? [:]
        var unchanged = !recorded.isEmpty
        for (path, hash) in recorded where self.fileHash(repoRoot.appendingPathComponent(path)) != hash {
            unchanged = false
        }
        checks.append(CapabilityPreflightCheck(name: "V1.27 frozen artifacts still match FREEZE_MANIFEST.json (candidates.json etc. not edited)", passed: unchanged, detail: "\(recorded.count) artifacts"))
        let frozenInputs = artifact["frozenInputs"] as? [String: Any]
        checks.append(CapabilityPreflightCheck(
            name: "artifact pins the frozen registry it was verified against",
            passed: frozenInputs?["candidatesJSONSHA256"] as? String == self.fileHash(candidatesURL)
                && frozenInputs?["freezeManifestSHA256"] as? String == self.fileHash(frozen.appendingPathComponent("FREEZE_MANIFEST.json")),
            detail: "candidates.json + FREEZE_MANIFEST.json"
        ))

        // No inference, no model load, no corpus exposure.
        let inference = artifact["inferenceEvidence"] as? [String: Any]
        let runtime = artifact["runtime"] as? [String: Any]
        checks.append(CapabilityPreflightCheck(
            name: "zero generation/chat calls, zero models loaded, no loaded model before or after acquisition",
            passed: inference?["generationCalls"] as? Int == 0 && inference?["chatOrCompletionRequests"] as? Int == 0 && inference?["modelsLoaded"] as? Int == 0
                && (runtime?["loadedModelsBefore"] as? [Any])?.isEmpty == true && (runtime?["loadedModelsAfter"] as? [Any])?.isEmpty == true,
            detail: "inferenceEvidence + runtime process listings"
        ))
        let serverVersion = runtime?["serverVersion"] as? String ?? ""
        checks.append(CapabilityPreflightCheck(
            name: "runtime version equals the frozen registry runtime",
            passed: serverVersion == (registry["runtime"] as? [String: Any])?["ollamaVersion"] as? String && !serverVersion.isEmpty,
            detail: serverVersion
        ))

        // Per-candidate identity, exactly as registered.
        let registered = Dictionary(uniqueKeysWithValues: ((registry["candidates"] as? [[String: Any]]) ?? []).compactMap { item -> (String, [String: Any])? in
            guard let id = item["id"] as? String else { return nil }
            return (id, item)
        })
        let recordedCandidates = (artifact["candidates"] as? [[String: Any]]) ?? []
        checks.append(CapabilityPreflightCheck(
            name: "exactly the registered primary candidates and baseline, no substitution",
            passed: recordedCandidates.compactMap { $0["id"] as? String } == self.requiredCandidateIDs
                && recordedCandidates.allSatisfy { $0["ollamaTag"] as? String == registered[$0["id"] as? String ?? ""]?["ollamaTag"] as? String },
            detail: recordedCandidates.compactMap { $0["ollamaTag"] as? String }.joined(separator: ",")
        ))
        for candidate in recordedCandidates {
            let id = candidate["id"] as? String ?? "?"
            let entry = registered[id] ?? [:]
            let observed = entry["registryObserved"] as? [String: Any] ?? [:]
            let local = candidate["localManifest"] as? [String: Any] ?? [:]
            let verification = candidate["verification"] as? [String: Any]
            checks.append(CapabilityPreflightCheck(
                name: "\(id): verified, no recorded failure",
                passed: verification?["status"] as? String == "verified" && verification?["failure"] is NSNull,
                detail: verification?["status"] as? String ?? "missing"
            ))
            let layersEqual = self.layerList(local["layers"]) == self.layerList(observed["layers"]) && !self.layerList(local["layers"]).isEmpty
            checks.append(CapabilityPreflightCheck(
                name: "\(id): local manifest config + every layer (digest, size, media type) equals the frozen registry observation",
                passed: layersEqual && local["configDigest"] as? String == observed["configDigest"] as? String,
                detail: "\(self.layerList(local["layers"]).count) layers"
            ))
            let blobs = candidate["blobs"] as? [[String: Any]] ?? []
            let expectedDigests = Set(self.layerList(observed["layers"]).map { $0["digest"] ?? "" })
            checks.append(CapabilityPreflightCheck(
                name: "\(id): every layer blob re-hashed from disk equals its digest and size",
                passed: !blobs.isEmpty && Set(blobs.compactMap { $0["digest"] as? String }) == expectedDigests
                    && blobs.allSatisfy { $0["matchesDigest"] as? Bool == true && $0["digest"] as? String == "sha256:\($0["sha256Recomputed"] as? String ?? "")" && $0["fileBytes"] as? Int == $0["size"] as? Int },
                detail: "\(blobs.count) blobs"
            ))
            let paramsExpected = self.layerList(observed["layers"]).contains { $0["mediaType"] == "application/vnd.ollama.image.params" }
            checks.append(CapabilityPreflightCheck(
                name: "\(id): params layer presence matches the registry; its content is recorded when present",
                passed: (candidate["paramsLayer"] as? [String: Any])?["present"] as? Bool == paramsExpected
                    && (!paramsExpected || (candidate["paramsLayer"] as? [String: Any])?["content"] is [String: Any]),
                detail: "params layer expected: \(paramsExpected)"
            ))
            let compatibility = candidate["compatibility"] as? [String: Any]
            let minimum = entry["minOllama"] as? String ?? "999"
            checks.append(CapabilityPreflightCheck(
                name: "\(id): runtime compatibility (Ollama >= \(minimum))",
                passed: compatibility?["satisfied"] as? Bool == true && self.version(serverVersion, atLeast: minimum),
                detail: "server \(serverVersion)"
            ))
            let license = candidate["license"] as? [String: Any]
            checks.append(CapabilityPreflightCheck(
                name: "\(id): license layer identifies as the registered license",
                passed: license?["consistent"] as? Bool == true && license?["registeredLicense"] as? String == entry["license"] as? String,
                detail: "\(license?["identifiedAs"] as? String ?? "?") vs \(entry["license"] as? String ?? "?")"
            ))
            let metadata = candidate["metadata"] as? [String: Any]
            checks.append(CapabilityPreflightCheck(
                name: "\(id): model metadata recorded (architecture, context, quantization, capabilities)",
                passed: ["architecture", "contextLength", "quantizationLevel", "capabilities", "parameterSize"].allSatisfy { metadata?[$0] != nil },
                detail: "\(metadata?["architecture"] as? String ?? "?")"
            ))
            if id == "CAND-BASE" {
                let template = (candidate["templateLayer"] as? [String: Any])?["digest"] as? String
                checks.append(CapabilityPreflightCheck(
                    name: "CAND-BASE: baseline identity equals the frozen V1.23A pins",
                    passed: local["sha256"] as? String == CapabilityFrozenRun.ollamaManifestSHA256
                        && self.layerList(local["layers"]).contains { $0["digest"] == "sha256:\(CapabilityFrozenRun.ggufBlobSHA256)" }
                        && local["configDigest"] as? String == "sha256:\(CapabilityFrozenRun.configBlobSHA256)"
                        && template == "sha256:\(CapabilityFrozenRun.templateBlobSHA256)",
                    detail: "manifest \(local["sha256"] as? String ?? "?")"
                ))
            }
        }
        return checks
    }

    // MARK: - Local re-hash (reads ~/.ollama/models; never contacts Ollama)

    static func localBlobChecks(repoRoot: URL, modelsDirectory: URL) -> [CapabilityPreflightCheck] {
        let artifact = self.json(repoRoot.appendingPathComponent(self.artifactDirectory).appendingPathComponent(self.artifactName))
        var checks: [CapabilityPreflightCheck] = []
        for candidate in (artifact["candidates"] as? [[String: Any]]) ?? [] {
            let id = candidate["id"] as? String ?? "?"
            var allMatch = true
            var count = 0
            for blob in (candidate["blobs"] as? [[String: Any]]) ?? [] {
                let digest = (blob["digest"] as? String ?? "").replacingOccurrences(of: "sha256:", with: "")
                let url = modelsDirectory.appendingPathComponent("blobs/sha256-\(digest)")
                count += 1
                if CapabilityPreflight.streamingSHA256(of: url) != digest {
                    allMatch = false
                }
            }
            let local = candidate["localManifest"] as? [String: Any]
            let relative = local?["relativePath"] as? String ?? ""
            let manifestHash = self.fileHash(modelsDirectory.appendingPathComponent("manifests/\(relative)"))
            checks.append(CapabilityPreflightCheck(
                name: "\(id): on-disk blobs and manifest still hash to the recorded identity",
                passed: allMatch && count > 0 && manifestHash == local?["sha256"] as? String,
                detail: "\(count) blobs, manifest \(manifestHash ?? "missing")"
            ))
        }
        return checks
    }
}
