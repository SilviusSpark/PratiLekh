import Foundation

/// The parsed structure of a statutory-provision reference, independent of
/// how it will eventually be rendered into text. Provision order is
/// preserved exactly as dictated -- never sorted, deduplicated, or
/// inferred. `statute` is nil when none was dictated (format what was
/// dictated, never complete what was not).
///
/// This is the minimum representation needed for Phase 3C's grammar, kept
/// deliberately small -- not a general AST. It exists so that recognized
/// input shape (e.g. whether a list happened to use commas) can never
/// implicitly select an output drafting style: parsing produces this
/// structure, and a separate renderer (`StatutoryProvisionRenderer`)
/// decides how it becomes text.
struct StatutoryProvisionReference: Equatable {
    let provisionNumbers: [String]
    let statute: String?
    let range: NSRange
}

/// Renders a parsed reference into text. Phase 3C ships exactly one
/// renderer -- a neutral, expanded default -- with no preference mechanism.
/// A future phase can add a second renderer (e.g. the compact
/// "u/s 294/323/.../of <statute>" style) and a way to choose between them
/// without touching `StatutoryProvisionNormalizer` at all: the parser only
/// ever needs to produce a `StatutoryProvisionReference`, never a string.
enum StatutoryProvisionRenderer {
    static func renderDefault(_ reference: StatutoryProvisionReference) -> String {
        let word = reference.provisionNumbers.count == 1 ? "Section" : "Sections"
        let numbers = englishList(reference.provisionNumbers)
        if let statute = reference.statute {
            return "\(word) \(numbers) \(statute)"
        }
        return "\(word) \(numbers)"
    }

    /// "302" / "302 and 304" / "294, 323, 341 and 506" -- comma-separated
    /// with a final "and", no comma before "and" for exactly two items.
    /// The same rendering applies whether the dictated list used commas,
    /// "and" alone, or both -- input punctuation never selects a different
    /// output style.
    private static func englishList(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }
}
