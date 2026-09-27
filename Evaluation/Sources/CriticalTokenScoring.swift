import Foundation

/// Where a critical token stands in one stage's text.
enum TokenState: String, Codable {
    /// The exact canonical form is present.
    case canonical
    /// The right words were dictated/recognized in a spoken, non-canonical form.
    case spoken
    /// Neither form is present (missing, or a different value).
    case wrong
}

enum TokenTransition: String, Codable {
    /// correct -> correct
    case preserved
    /// not yet canonical (wrong or spoken) -> canonical
    case recovered
    /// not canonical -> not canonical (including spoken -> spoken and wrong -> spoken)
    case unrecovered
    /// content that was right (canonical or spoken) -> wrong, or canonical -> spoken
    case corrupted
}

struct StageTokenState: Codable, Equatable {
    let stage: String
    let state: TokenState
}

struct TokenTransitionRecord: Codable, Equatable {
    let fromStage: String
    let toStage: String
    let fromState: TokenState
    let toState: TokenState
    let transition: TokenTransition
}

struct CriticalTokenResult: Codable, Equatable {
    let type: CriticalTokenType
    let expected: String
    let states: [StageTokenState]
    let transitions: [TokenTransitionRecord]
}

/// Exact, presence-based critical token scoring. A token is right only if its
/// canonical form (case-sensitive) or a listed spoken form is present at word
/// boundaries; a different value (302 vs 304) is simply wrong. The evaluator
/// never substitutes a legally "better" value for the dictated one.
enum CriticalTokenScoring {
    static func state(of token: CriticalToken, in text: String) -> TokenState {
        if self.contains(token.expected, in: text, caseInsensitive: false) { return .canonical }
        if token.spokenForms.contains(where: { self.contains($0, in: text, caseInsensitive: true) }) { return .spoken }
        return .wrong
    }

    static func transition(from: TokenState, to: TokenState) -> TokenTransition {
        switch (from, to) {
        case (.canonical, .canonical): return .preserved
        case (.spoken, .canonical), (.wrong, .canonical): return .recovered
        case (.canonical, .spoken), (.canonical, .wrong), (.spoken, .wrong): return .corrupted
        case (.spoken, .spoken), (.wrong, .spoken), (.wrong, .wrong): return .unrecovered
        }
    }

    /// `stages` are in pipeline order; transitions are between adjacent stages.
    static func score(token: CriticalToken, stages: [(name: String, text: String)]) -> CriticalTokenResult {
        let states = stages.map { StageTokenState(stage: $0.name, state: self.state(of: token, in: $0.text)) }
        var transitions: [TokenTransitionRecord] = []
        for index in 1..<max(states.count, 1) {
            let from = states[index - 1]
            let to = states[index]
            transitions.append(TokenTransitionRecord(
                fromStage: from.stage,
                toStage: to.stage,
                fromState: from.state,
                toState: to.state,
                transition: self.transition(from: from.state, to: to.state)
            ))
        }
        return CriticalTokenResult(type: token.type, expected: token.expected, states: states, transitions: transitions)
    }

    private static func contains(_ needle: String, in text: String, caseInsensitive: Bool) -> Bool {
        guard !needle.isEmpty else { return false }
        let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: needle) + "(?![\\p{L}\\p{N}])"
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}
