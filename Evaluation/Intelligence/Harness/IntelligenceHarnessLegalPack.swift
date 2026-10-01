import Foundation

/// Intelligence V1.17 -- Controlled Local-Model Integration Harness.
///
/// Loads the real, committed Indian Legal Core pack from its on-disk JSON
/// resource, exactly as `Evaluation/Runner/EvalRunner.swift` already does for
/// the Phase 3E.1 evaluation framework. Duplicated here (rather than shared)
/// because each standalone tool in this repo compiles its own closed source
/// list -- the existing convention for `scripts/test_*.sh`/`scripts/*_run.sh`
/// runners, which this harness follows rather than introducing a new shared
/// module.
enum IntelligenceHarnessLegalPack {
    struct LoadFailure: Error {
        let message: String
    }

    static func load(repoRoot: String) throws -> LanguagePack {
        let resources = URL(fileURLWithPath: repoRoot).appendingPathComponent("Sources/Fluid/Resources").path
        guard let bundle = Bundle(path: resources), let pack = BuiltInPacks.indianLegalCore(bundle: bundle) else {
            throw LoadFailure(message: "could not load the Indian Legal Core pack from \(resources) (run from the repository root)")
        }
        return pack
    }

    static func makeProcessor(repoRoot: String) throws -> LegalDictationProcessor {
        LegalDictationProcessor(builtinPack: try self.load(repoRoot: repoRoot))
    }
}
