import Foundation

@main
enum LanguagePackTests {
    static func main() {
        testRoundTrip()
        testRejectsEmptyID()
        testRejectsInvalidVersion()
        testRejectsMalformedJSON()
        print("PASS: LanguagePack encode/decode round trip and PackLoader validation")
    }

    private static func testRoundTrip() {
        let pack = LanguagePack(
            id: "test.pack",
            version: "1.0.0",
            kind: .builtin,
            displayName: "Test Pack",
            recognitionEntries: [RecognitionEntry(canonical: "BNS", aliases: ["bee en es"])],
            normalizationEntries: [NormalizationEntry(trigger: "sec.", canonicalReplacement: "Section")]
        )
        guard let data = try? JSONEncoder().encode(pack) else {
            preconditionFailure("Expected pack to encode")
        }
        guard let loaded = try? PackLoader.load(from: data) else {
            preconditionFailure("Expected pack to decode and validate")
        }
        precondition(loaded == pack, "Round-tripped pack must equal the original")
    }

    private static func testRejectsEmptyID() {
        let pack = LanguagePack(
            id: "   ",
            version: "1.0.0",
            kind: .builtin,
            displayName: "Test Pack",
            recognitionEntries: [],
            normalizationEntries: []
        )
        do {
            try PackLoader.validate(pack)
            preconditionFailure("Expected empty id to be rejected")
        } catch PackLoaderError.emptyID {
            // expected
        } catch {
            preconditionFailure("Expected .emptyID, got \(error)")
        }
    }

    private static func testRejectsInvalidVersion() {
        for badVersion in ["1.0", "1.0.0.0", "v1.0.0", ""] {
            let pack = LanguagePack(
                id: "test.pack",
                version: badVersion,
                kind: .builtin,
                displayName: "Test Pack",
                recognitionEntries: [],
                normalizationEntries: []
            )
            do {
                try PackLoader.validate(pack)
                preconditionFailure("Expected version '\(badVersion)' to be rejected")
            } catch PackLoaderError.invalidVersion {
                // expected
            } catch {
                preconditionFailure("Expected .invalidVersion for '\(badVersion)', got \(error)")
            }
        }
    }

    private static func testRejectsMalformedJSON() {
        let data = Data("{ not json".utf8)
        do {
            _ = try PackLoader.load(from: data)
            preconditionFailure("Expected malformed JSON to be rejected")
        } catch PackLoaderError.invalidJSON {
            // expected
        } catch {
            preconditionFailure("Expected .invalidJSON, got \(error)")
        }
    }
}
