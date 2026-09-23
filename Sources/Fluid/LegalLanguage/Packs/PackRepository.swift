import Foundation

/// In-memory holder of currently loaded packs. Phase 1 is deliberately a pure
/// container with no filesystem/Application-Support access of its own -- it is
/// populated by whoever loads packs (tests use fixtures directly). Wiring this
/// to bundled built-in resources or the live user dictionary is a Phase 2+
/// decision, not made here.
final class PackRepository {
    private(set) var packs: [LanguagePack]

    init(packs: [LanguagePack] = []) {
        self.packs = packs
    }

    /// Adds a pack, replacing any existing pack with the same id.
    func add(_ pack: LanguagePack) {
        packs.removeAll { $0.id == pack.id }
        packs.append(pack)
    }

    func remove(id: String) {
        packs.removeAll { $0.id == id }
    }

    func packs(of kind: PackKind) -> [LanguagePack] {
        packs.filter { $0.kind == kind }
    }
}
