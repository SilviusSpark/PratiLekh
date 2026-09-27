import Foundation

/// The narrow, model-facing contract for PratiLekh Intelligence V1: what a
/// future local model is asked to do, and the exact tool schema it must use
/// to say it. This is **behavioral guidance only** -- it grants a model no
/// authority whatsoever. Every response is still forced through the
/// committed `IntelligenceProposalTransportParser` (structural) and
/// `IntelligenceSafetyAuthority` (semantic) exactly as if this contract did
/// not exist. A model that ignores every word here can still only ever
/// produce proposals that both of those already-committed authorities
/// independently accept or reject on their own terms.
///
/// No model is invoked by anything in this file. This type only *describes*
/// a request; it does not send one.
enum IntelligenceGenerationContract {
    /// Stable across the V1 generation contract. A future schema revision
    /// would need its own tool name or version signal, decided elsewhere.
    static let toolName = "propose_transcript_edits"

    /// An OpenAI-compatible function/tool definition, in the same
    /// `[String: Any]` literal shape already used by
    /// `TerminalService.toolDefinition` with `LLMClient.Config.tools`.
    /// Mirrors the committed V1.1 wire contract's field names, schema
    /// version, and category enum **exactly** -- see
    /// `IntelligenceProposalTransportParserTests`'s
    /// `testSchemaMatchesV1TransportContract`, which fails to compile if
    /// `IntelligenceEditCategory` ever gains or loses a case without this
    /// schema being updated to match.
    ///
    /// This schema is advisory. A model may ignore it, misuse it, or omit
    /// required fields entirely -- `IntelligenceProposalTransportParser`
    /// treats every resulting payload as fully untrusted regardless of
    /// whether the model appeared to follow this shape.
    static var toolDefinition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": self.toolName,
                "description": """
                Propose surface-level edits to the supplied judicial dictation text. Call this \
                tool exactly once. Prefer proposing zero edits (an empty "proposals" array) when \
                nothing clearly needs changing -- that is the expected, preferred response for \
                already-correct text. Only propose punctuation, capitalization, or \
                whitespace/formatting corrections. Never change a word, name, date, amount, \
                statute reference, statutory number, case identifier, or witness/exhibit \
                identifier. Never rewrite a sentence, and never return a corrected transcript or \
                an explanation -- return only structured edit proposals referencing the exact \
                original text.
                """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "schemaVersion": [
                            "type": "integer",
                            "description": "Must be exactly 1.",
                        ],
                        "proposals": [
                            "type": "array",
                            "description": "Zero or more proposed surface edits, in any order. An empty array is valid and preferred when nothing needs changing.",
                            "maxItems": IntelligenceProposalTransportLimits.maxProposalCount,
                            "items": [
                                "type": "object",
                                "properties": [
                                    "id": [
                                        "type": "string",
                                        "description": "A short identifier for this proposal (need not be globally unique).",
                                    ],
                                    "rangeStart": [
                                        "type": "integer",
                                        "description": "UTF-16 offset into the supplied source text where this edit begins.",
                                    ],
                                    "rangeLength": [
                                        "type": "integer",
                                        "description": "UTF-16 length of the exact text being replaced. Use 0 for a pure insertion.",
                                    ],
                                    "expectedSourceText": [
                                        "type": "string",
                                        "description": "The exact text present at rangeStart/rangeLength in the supplied source. Must match exactly, or this proposal will be rejected.",
                                    ],
                                    "replacementText": [
                                        "type": "string",
                                        "description": "The text that should replace expectedSourceText.",
                                    ],
                                    "claimedCategory": [
                                        "type": "string",
                                        "enum": ["punctuation", "capitalization", "whitespace", "other"],
                                        "description": "What kind of edit this is. Use \"other\" only when none of the first three genuinely apply -- such proposals are never applied automatically.",
                                    ],
                                ],
                                "required": ["id", "rangeStart", "rangeLength", "expectedSourceText", "replacementText", "claimedCategory"],
                                "additionalProperties": false,
                            ],
                        ],
                    ],
                    "required": ["schemaVersion", "proposals"],
                    "additionalProperties": false,
                ],
            ],
        ]
    }

    /// The minimal V1 task instructions. Deliberately short -- this is not
    /// a general legal-writing prompt, and no example transcripts are
    /// included (none were found to be necessary for contract clarity at
    /// this scope). Kept independent of any specific provider's prompt
    /// formatting conventions; a future live-model milestone decides how
    /// this text is actually delivered (system message, user message,
    /// developer message, ...).
    static let instructions = """
    The supplied text is immutable source text from a judicial dictation, already deterministically \
    legal-normalized. Propose edits to it by calling \(toolName) exactly once.

    Only propose punctuation, capitalization, or whitespace/formatting edits. Do not change any \
    word, name, date, amount, statute reference, statutory number, case identifier, or \
    witness/exhibit identifier. Do not rewrite sentences. Do not return a corrected transcript, and \
    do not explain your answer -- return only structured edit proposals.

    Every proposal must reference the exact source text at its stated range, using UTF-16 offsets. \
    expectedSourceText must equal the source exactly at that range, or the proposal will be rejected.

    Prefer proposing zero edits (an empty "proposals" array) when nothing clearly needs changing.
    """
}
