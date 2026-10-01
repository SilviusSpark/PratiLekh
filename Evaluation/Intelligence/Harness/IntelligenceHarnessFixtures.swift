import Foundation

/// Intelligence V1.17 -- Controlled Local-Model Integration Harness.
///
/// Deterministic, hand-written fixtures used only by
/// `Tests/IntelligenceHarnessPipelineTests.swift` (via
/// `scripts/test_intelligence_harness.sh`) to prove the harness's own
/// plumbing end-to-end -- real `LegalDictationProcessor` normalization, real
/// `ProtectedSpanDerivation`/`NumericStructuralProtection`, real
/// `ModelFacingResponseAdapter`/`ModelFacingEditTransportParser`/
/// `IntelligenceAddressingBridge`/`IntelligenceSafetyAuthority` -- with a
/// **stand-in provider response** in place of a real model call, so an
/// integration bug in this harness can never be confused with a real model's
/// behavior (the "verify the harness itself with deterministic/synthetic
/// fixtures" requirement). No network, no `LLMClient`, no model.
///
/// Each fixture's raw tool-call argument text is a literal JSON string, not
/// a `JSONSerialization`-built value, specifically so adversarial cases
/// (duplicate keys) reach the parser exactly as a real provider's raw bytes
/// would -- `JSONSerialization` would silently collapse a duplicate key
/// before the parser ever saw it.
enum IntelligenceHarnessFixtures {
    struct Fixture {
        let id: String
        let rawInputText: String
        let response: IntelligenceProviderResponse
        /// One line describing what this fixture proves and the disposition
        /// the test asserts -- not machine-checked, just keeps the fixture
        /// and its assertion co-located for a reader.
        let proves: String
    }

    private static func toolCall(_ rawArguments: String) -> IntelligenceProviderResponse {
        IntelligenceProviderResponse(toolCalls: [
            IntelligenceProviderToolCall(name: ModelFacingGenerationContract.toolName, rawArguments: rawArguments),
        ])
    }

    /// A: zero proposed edits -- valid, and the contract's own preferred
    /// outcome when nothing needs changing.
    static let zeroEdits = Fixture(
        id: "F-A-zero-edits",
        rawInputText: "The accused was present in court.",
        response: toolCall(#"{"schemaVersion":1,"edits":[]}"#),
        proves: "a well-formed zero-edit response evaluates with isZeroProposal == true and an unchanged wouldBeOutput"
    )

    /// B: a safe, terminal punctuation-only edit outside the V1.16 gate's
    /// five blocks (not intra-token, not a merge, not a case change).
    static let safePunctuation = Fixture(
        id: "F-B-safe-punctuation",
        rawInputText: "The witness said yes, the accused agreed",
        response: toolCall(#"{"schemaVersion":1,"edits":[{"sourceText":"agreed","replacementText":"agreed."}]}"#),
        proves: "a terminal, routine-punctuation edit with no protected-span intersection is autonomouslyAccepted(punctuationOnly)"
    )

    /// C: the single most important safety property -- a proposal that
    /// looks locally plausible (changing a statutory number) but intersects
    /// a `.deterministicallyResolved` span (the applied `Section 302 IPC`
    /// normalization) must be rejected outright, never autonomous, never
    /// even review-only.
    static let intersectsResolvedSpan = Fixture(
        id: "F-C-intersects-resolved-span",
        // Spelled-out digits, not the literal numerals "302": the statutory
        // normalizer's `SpokenNumberParser` only recognizes digit/tens WORDS
        // ("three zero two"); a literal "302" already in the text is left
        // untouched (no applied/declined record at all -- the real D01
        // finding this fixture is deliberately built to avoid repeating).
        rawInputText: "the accused was charged under section three zero two IPC",
        response: toolCall(#"{"schemaVersion":1,"edits":[{"sourceText":"302","replacementText":"304"}]}"#),
        proves: "a proposal changing a statutory number inside an applied statutory-provision normalization is rejected(intersectsResolvedSpan), never accepted"
    )

    /// D: a genuine lexical/content change -- never one of V1's three
    /// autonomous categories, regardless of protected spans.
    static let unsupportedCategory = Fixture(
        id: "F-D-unsupported-category",
        rawInputText: "The witness identified the accused.",
        response: toolCall(#"{"schemaVersion":1,"edits":[{"sourceText":"accused","replacementText":"defendant"}]}"#),
        proves: "a word-level content change classifies as .other and is rejected(unsupportedEditCategory)"
    )

    /// E: a hallucinated/stale quote -- text that never appears in the
    /// immutable source at all.
    static let addressingNoMatch = Fixture(
        id: "F-E-addressing-no-match",
        rawInputText: "The accused pleaded not guilty.",
        response: toolCall(#"{"schemaVersion":1,"edits":[{"sourceText":"pled","replacementText":"pleaded"}]}"#),
        proves: "sourceText with no literal occurrence in the source is addressingRejected(noLiteralMatch), never relocated by fuzzy search"
    )

    /// F: an adversarial wire payload -- a duplicate top-level key, which
    /// `JSONSerialization` would silently collapse but the strict V1.7
    /// parser must reject outright, failing the whole response.
    static let malformedDuplicateKey = Fixture(
        id: "F-F-malformed-duplicate-key",
        rawInputText: "The accused was present in court.",
        response: toolCall(#"{"schemaVersion":1,"schemaVersion":1,"edits":[]}"#),
        proves: "a duplicate top-level JSON key fails the whole response (wholeResponseRejected), never silently resolved to the last value"
    )

    /// G: free text instead of a tool call -- a model that explained itself
    /// instead of calling the required tool.
    static let freeTextInsteadOfToolCall = Fixture(
        id: "F-G-free-text-instead-of-tool-call",
        rawInputText: "The accused was present in court.",
        response: IntelligenceProviderResponse(textContent: "This text looks fine, no changes needed.", toolCalls: []),
        proves: "a response with text content and no tool call fails the whole response as unexpectedTextContent"
    )

    /// I: the V1.16 autonomous-permission gate specifically -- a whitespace
    /// edit that merges two words, outside any protected span, classified
    /// whitespaceOnly, downgraded to review-only by the W-A1 rule.
    static let gateBlocksWordMerge = Fixture(
        id: "F-I-gate-blocks-word-merge",
        rawInputText: "Ram Das appeared as a witness.",
        response: toolCall(#"{"schemaVersion":1,"edits":[{"sourceText":"Ram Das","replacementText":"RamDas"}]}"#),
        proves: "a word-boundary-merging whitespace edit, outside any protected span, is reviewOnly(wordBoundaryMerged) via V1.16's gate -- not autonomous, not rejected"
    )

    /// J: repeated source text resolved by an explicit 1-based occurrence,
    /// proving the full V1.6 addressing contract (not just unique matches)
    /// flows correctly through the harness.
    static let repeatedTextByOccurrence = Fixture(
        id: "F-J-repeated-text-by-occurrence",
        rawInputText: "The accused said he was not present. He said it again: he was not present",
        response: toolCall(#"{"schemaVersion":1,"edits":[{"sourceText":"not present","replacementText":"not present.","occurrence":2}]}"#),
        proves: "occurrence=2 on twice-repeated sourceText resolves to the second occurrence (basis: occurrence) and is autonomouslyAccepted(punctuationOnly)"
    )

    static let all: [Fixture] = [
        IntelligenceHarnessFixtures.zeroEdits,
        IntelligenceHarnessFixtures.safePunctuation,
        IntelligenceHarnessFixtures.intersectsResolvedSpan,
        IntelligenceHarnessFixtures.unsupportedCategory,
        IntelligenceHarnessFixtures.addressingNoMatch,
        IntelligenceHarnessFixtures.malformedDuplicateKey,
        IntelligenceHarnessFixtures.freeTextInsteadOfToolCall,
        IntelligenceHarnessFixtures.gateBlocksWordMerge,
        IntelligenceHarnessFixtures.repeatedTextByOccurrence,
    ]
}
