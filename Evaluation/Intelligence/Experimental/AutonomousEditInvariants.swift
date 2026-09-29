import Foundation

// EXPERIMENTAL -- Intelligence V1.14 investigation only. NOT production code and
// not a policy proposal: these are the candidate structural invariants defined in
// `Evaluation/References/autonomous-edit-policy/README.md`, implemented so the
// investigation can MEASURE their safety benefit and cost. Nothing under
// `Sources/` references this file and no classifier/Authority behaviour changes.
// The file's SHA-256 is pinned by the harness: it is the rule freeze.

enum AutonomousEditInvariant: String, CaseIterable {
    case wsNoTokenBoundaryChange = "W-A"
    case wsNoMerge = "W-A1"
    case wsNoSplit = "W-A2"
    case wsAllowlist = "W-B"
    case punctAllowlist = "P-A"
    case punctNoIntraToken = "P-B"
    case capNoAcronymLowering = "C-A"
    case capNoMultiCapitalLowering = "C-A2"
    case capFirstLetterOnly = "C-B"
    case capNoIdentifier = "C-C"
    case capRaiseOnly = "C-D"

    static let bundles: [(name: String, members: [AutonomousEditInvariant])] = [
        ("core", [.wsNoTokenBoundaryChange, .punctNoIntraToken, .capNoMultiCapitalLowering, .capNoIdentifier]),
        ("core+P-A", [.wsNoTokenBoundaryChange, .punctNoIntraToken, .punctAllowlist, .capNoMultiCapitalLowering, .capNoIdentifier]),
        ("core-merge-only+P-A", [.wsNoMerge, .punctNoIntraToken, .punctAllowlist, .capNoMultiCapitalLowering, .capNoIdentifier]),
        ("allowlist", [.wsAllowlist, .punctAllowlist, .capRaiseOnly]),
    ]

    /// Whether the edit may stay autonomous under this invariant. Invariants
    /// only constrain their own class; any other class is allowed here.
    func allows(before: String, expected: String, replacement: String, after: String, classification: IntelligenceEditClassification) -> Bool {
        let original = Array((before + expected + after).unicodeScalars)
        let edited = Array((before + replacement + after).unicodeScalars)
        switch self {
        case .wsNoTokenBoundaryChange, .wsNoMerge, .wsNoSplit, .wsAllowlist:
            guard classification == .whitespaceOnly else { return true }
            return self.whitespaceAllows(original, edited)
        case .punctAllowlist, .punctNoIntraToken:
            guard classification == .punctuationOnly else { return true }
            return self.punctuationAllows(original, edited)
        case .capNoAcronymLowering, .capNoMultiCapitalLowering, .capFirstLetterOnly, .capNoIdentifier, .capRaiseOnly:
            guard classification == .capitalizationOnly else { return true }
            return self.capitalizationAllows(original, edited)
        }
    }

    // MARK: - Character classes

    static func isWordForming(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .letterNumber, .otherNumber:
            return true
        default:
            return false
        }
    }

    static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation, .finalPunctuation, .otherPunctuation: return true
        default: return false
        }
    }

    private static let routinePunctuation: Set<UInt32> = [0x2E, 0x2C, 0x3B, 0x3A, 0x3F, 0x21, 0x0964]

    // MARK: - Whitespace (W-A, W-B)

    private func gaps(_ scalars: [Unicode.Scalar]) -> (tokens: [Unicode.Scalar], gaps: [String]) {
        var tokens: [Unicode.Scalar] = []
        var gaps: [String] = [""]
        for scalar in scalars {
            if scalar.properties.isWhitespace {
                gaps[gaps.count - 1].unicodeScalars.append(scalar)
            } else {
                tokens.append(scalar)
                gaps.append("")
            }
        }
        return (tokens, gaps)
    }

    private func whitespaceAllows(_ original: [Unicode.Scalar], _ edited: [Unicode.Scalar]) -> Bool {
        let before = self.gaps(original)
        let after = self.gaps(edited)
        guard before.tokens == after.tokens, before.gaps.count == after.gaps.count else { return false }
        let tokens = before.tokens
        for index in before.gaps.indices where before.gaps[index] != after.gaps[index] {
            let left = index > 0 ? tokens[index - 1] : nil
            let right = index < tokens.count ? tokens[index] : nil
            let oldGap = before.gaps[index]
            let newGap = after.gaps[index]
            switch self {
            case .wsNoTokenBoundaryChange, .wsNoMerge, .wsNoSplit:
                let merges = !oldGap.isEmpty && newGap.isEmpty
                let splits = oldGap.isEmpty && !newGap.isEmpty
                let constrained = self == .wsNoTokenBoundaryChange ? (merges || splits) : (self == .wsNoMerge ? merges : splits)
                if constrained, let left, let right, Self.isWordForming(left), Self.isWordForming(right) { return false }
            default: // W-B: routine repairs only
                let collapse = !oldGap.isEmpty && newGap == " " && oldGap.unicodeScalars.count > 1
                let trim = (left == nil || right == nil) && newGap.isEmpty
                let beforePunctuation = !oldGap.isEmpty && newGap.isEmpty && right.map { Self.routinePunctuation.contains($0.value) } == true
                let afterPunctuation = oldGap.isEmpty && newGap == " " && left.map { Self.routinePunctuation.contains($0.value) } == true && right.map(Self.isWordForming) == true
                if !(collapse || trim || beforePunctuation || afterPunctuation) { return false }
            }
        }
        return true
    }

    // MARK: - Punctuation (P-A, P-B)

    private func runs(_ scalars: [Unicode.Scalar]) -> (tokens: [Unicode.Scalar], runs: [String]) {
        var tokens: [Unicode.Scalar] = []
        var runs: [String] = [""]
        for scalar in scalars {
            if Self.isPunctuation(scalar) {
                runs[runs.count - 1].unicodeScalars.append(scalar)
            } else {
                tokens.append(scalar)
                runs.append("")
            }
        }
        return (tokens, runs)
    }

    private func punctuationAllows(_ original: [Unicode.Scalar], _ edited: [Unicode.Scalar]) -> Bool {
        let before = self.runs(original)
        let after = self.runs(edited)
        guard before.tokens == after.tokens, before.runs.count == after.runs.count else { return false }
        let tokens = before.tokens
        for index in before.runs.indices where before.runs[index] != after.runs[index] {
            switch self {
            case .punctAllowlist:
                if (before.runs[index] + after.runs[index]).unicodeScalars.contains(where: { !Self.routinePunctuation.contains($0.value) }) { return false }
            default: // P-B
                if index > 0, index < tokens.count, Self.isWordForming(tokens[index - 1]), Self.isWordForming(tokens[index]) { return false }
            }
        }
        return true
    }

    // MARK: - Capitalization (C-A .. C-D)

    private func capitalizationAllows(_ original: [Unicode.Scalar], _ edited: [Unicode.Scalar]) -> Bool {
        guard original.count == edited.count else { return false } // fail closed on length-changing case mappings
        for index in original.indices where original[index] != edited[index] {
            // The token (maximal word-forming run) around `index` in the ORIGINAL text.
            var start = index
            while start > 0, Self.isWordForming(original[start - 1]) { start -= 1 }
            var end = index
            while end + 1 < original.count, Self.isWordForming(original[end + 1]) { end += 1 }
            let token = original[start...end]
            let lowering = original[index].properties.isUppercase && edited[index].properties.isLowercase
            switch self {
            case .capRaiseOnly:
                if lowering { return false }
            case .capFirstLetterOnly:
                if index != start { return false }
            case .capNoIdentifier:
                if token.contains(where: { $0.properties.generalCategory == .decimalNumber }) { return false }
            case .capNoMultiCapitalLowering: // C-A2
                if lowering, token.filter({ $0.properties.isUppercase }).count >= 2 { return false }
            default: // C-A
                let cased = token.filter { $0.properties.isUppercase || $0.properties.isLowercase }
                if lowering, cased.count >= 2, cased.allSatisfy({ $0.properties.isUppercase }) { return false }
            }
        }
        return true
    }
}
