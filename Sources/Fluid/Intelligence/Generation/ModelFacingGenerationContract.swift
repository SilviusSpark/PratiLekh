import Foundation

/// The V1.7 model-facing generation contract: what a future local model is
/// asked to do, and the exact tool schema it must use to say it. It
/// **replaces nothing**: `IntelligenceGenerationContract` (V1.2, the
/// internal UTF-16-offset contract) remains committed and in use by its own
/// adapter and tests; this is a distinct contract with a distinct tool name
/// so the two can never be confused at a provider boundary.
///
/// Behavioral guidance only -- it grants a model no authority. Every
/// response is still forced through `ModelFacingEditTransportParser`
/// (structural), `IntelligenceAddressingResolver` (where does this apply?)
/// and `IntelligenceSafetyAuthority` (may it proceed?), exactly as if this
/// contract did not exist. The model never supplies a UTF-16 offset, an id,
/// or a claimed category.
///
/// No model is invoked by anything in this file; it only *describes* a
/// request.
enum ModelFacingGenerationContract {
    /// Distinct from `IntelligenceGenerationContract.toolName`.
    static let toolName = "propose_literal_transcript_edits"

    /// OpenAI-compatible function/tool definition in the same `[String: Any]`
    /// shape as `IntelligenceGenerationContract.toolDefinition`. Field names,
    /// requiredness, types, and the edit-count bound mirror
    /// `ModelFacingEditTransportParser` exactly (asserted by
    /// `ModelFacingGenerationContractTests`).
    ///
    /// Advisory: a model may ignore it or misuse it; the parser treats every
    /// payload as untrusted. Notably the schema does not declare
    /// `"minimum": 1` on `occurrence`: the 1-based rule is stated in the
    /// instructions and enforced by addressing (not the wire parser -- see
    /// `ModelFacingEditTransportParser` for the ownership boundary).
    static var toolDefinition: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": self.toolName,
                "description": """
                Propose surface-level edits to the supplied judicial dictation text by quoting the exact \
                text to change. Call this tool exactly once. Prefer proposing zero edits (an empty "edits" \
                array) when nothing clearly needs changing. Only propose punctuation, capitalization, or \
                whitespace/formatting corrections. Never change a word, name, date, amount, statute \
                reference, statutory number, case identifier, or witness/exhibit identifier. Never return a \
                corrected transcript or an explanation.
                """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "schemaVersion": [
                            "type": "integer",
                            "description": "Must be exactly 1.",
                        ],
                        "edits": [
                            "type": "array",
                            "description": "Zero or more proposed surface edits. An empty array is valid and preferred when nothing needs changing.",
                            "maxItems": ModelFacingEditTransportLimits.maxEditCount,
                            "items": [
                                "type": "object",
                                "properties": [
                                    "sourceText": [
                                        "type": "string",
                                        "description": "The smallest span of the supplied text needed to express this correction, copied exactly, character for character (same case, spelling, punctuation and spacing).",
                                    ],
                                    "replacementText": [
                                        "type": "string",
                                        "description": "The exact text that should replace sourceText.",
                                    ],
                                    "occurrence": [
                                        "type": "integer",
                                        "description": "Only when sourceText appears more than once in the supplied text: which appearance you mean, "
                                            + "counting from 1 in reading order (first = 1, second = 2, third = 3). Never 0. "
                                            + "Omit when sourceText appears exactly once.",
                                    ],
                                    "leftContext": [
                                        "type": "string",
                                        "description": "Optional. The exact text immediately before the appearance you mean, copied exactly. Extra evidence only. Omit if not needed.",
                                    ],
                                    "rightContext": [
                                        "type": "string",
                                        "description": "Optional. The exact text immediately after the appearance you mean, copied exactly. Extra evidence only. Omit if not needed.",
                                    ],
                                ],
                                "required": ["sourceText", "replacementText"],
                                "additionalProperties": false,
                            ],
                        ],
                    ],
                    "required": ["schemaVersion", "edits"],
                    "additionalProperties": false,
                ],
            ],
        ]
    }

    /// Task instructions. Kept independent of any provider's prompt
    /// formatting; a future live-model milestone decides how this text is
    /// delivered. The "smallest correction-bearing span" guidance is a
    /// prompt-level instruction only -- nothing downstream shrinks or
    /// reinterprets a span the model chooses.
    static let instructions = """
    The supplied text is immutable source text from a judicial dictation, already deterministically \
    legal-normalized. Propose edits to it by calling \(toolName) exactly once.

    Only propose punctuation, capitalization, or whitespace/formatting edits. Do not change any \
    word, name, date, amount, statute reference, statutory number, case identifier, or \
    witness/exhibit identifier. Do not rewrite sentences. Do not return a corrected transcript, and \
    do not explain your answer -- return only structured edits.

    Identify each edit by quoting the source text literally. sourceText must be copied exactly, \
    character for character, from the supplied text: same case, spelling, punctuation and spacing. \
    Never paraphrase, correct, or normalize it. Choose the smallest span of source text needed to \
    express the correction -- for example a single word for a capitalization fix, or a punctuation \
    mark with only as much neighboring text as you need -- not a whole sentence, unless a larger span \
    is genuinely required. replacementText is the exact text that should replace sourceText.

    If sourceText appears more than once in the supplied text, include occurrence to say which \
    appearance you mean: a whole number counting from 1 in reading order (the first appearance is \
    1, the second is 2, the third is 3). Never use 0. If sourceText appears exactly once, omit \
    occurrence. leftContext and rightContext are optional: they may give the exact literal text \
    immediately before and after the appearance you mean, as extra evidence, and must also be \
    copied exactly. Omit any optional field you do not need; do not send null or empty values.

    Do not provide UTF-16 offsets, character positions, ids, or edit categories. They are not part \
    of this contract, and a response containing any field other than those described is rejected \
    entirely.

    Prefer proposing zero edits (an empty "edits" array) when nothing clearly needs changing.

    Every tool call you make must include the top-level field "schemaVersion": 1. A tool call that omits schemaVersion is invalid.
    """
}
