import Foundation

/// Loads packs bundled with the app. This is the smallest seam needed to make
/// a built-in pack available to `LegalLanguageCoordinator` -- it does not
/// touch `ASRService`, any `TranscriptionProvider`, or wire anything into the
/// live transcription pipeline. Nothing in the app calls this yet; it exists
/// to be exercised by tests and by whichever later phase decides to actually
/// construct a production `PackRepository` with it.
enum BuiltInPacks {
    static func indianLegalCore(bundle: Bundle = .main) -> LanguagePack? {
        guard let url = bundle.url(forResource: "indian_legal_core.default", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? PackLoader.load(from: data)
    }
}
