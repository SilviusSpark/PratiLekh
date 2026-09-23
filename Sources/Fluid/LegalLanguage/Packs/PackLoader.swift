import Foundation

enum PackLoaderError: Error, Equatable {
    case invalidJSON(String)
    case emptyID
    case invalidVersion(String)
}

/// Parses and validates a `LanguagePack` from raw data. Phase 1 has no notion
/// of *where* that data comes from (bundled resource, user file, fixture) --
/// that's a later-phase wiring concern. This type only turns bytes into a
/// validated pack, or a clear error.
enum PackLoader {
    static func load(from data: Data) throws -> LanguagePack {
        let pack: LanguagePack
        do {
            pack = try JSONDecoder().decode(LanguagePack.self, from: data)
        } catch {
            throw PackLoaderError.invalidJSON(String(describing: error))
        }
        try validate(pack)
        return pack
    }

    static func validate(_ pack: LanguagePack) throws {
        guard !pack.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PackLoaderError.emptyID
        }
        guard isValidSemanticVersion(pack.version) else {
            throw PackLoaderError.invalidVersion(pack.version)
        }
    }

    /// Deliberately minimal: "major.minor.patch" of digits. No comparison
    /// operators or ordering are needed in Phase 1 since nothing diffs or
    /// auto-upgrades packs yet.
    private static func isValidSemanticVersion(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }
}
