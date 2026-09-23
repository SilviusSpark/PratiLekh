import Foundation

/// One-time migration for the FluidVoice -> PratiLekh rebrand.
///
/// All persisted app state (custom dictionary, transcription history, vocabulary,
/// audio history) lived under `~/Library/Application Support/FluidVoice`. Renaming
/// the app without moving this folder would silently orphan an existing user's data,
/// so on first launch after the rebrand we move the whole folder in one shot.
enum AppSupportMigration {
    static func migrateFluidVoiceDataIfNeeded() {
        let fileManager = FileManager.default
        guard let base = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }

        let oldURL = base.appendingPathComponent("FluidVoice", isDirectory: true)
        let newURL = base.appendingPathComponent("PratiLekh", isDirectory: true)

        guard fileManager.fileExists(atPath: oldURL.path) else { return }
        guard !fileManager.fileExists(atPath: newURL.path) else { return }

        try? fileManager.moveItem(at: oldURL, to: newURL)
    }
}
