import Foundation

/// Built-in AI Enhancement prompt starting points for Indian court dictation:
/// judgment/order drafting, recording evidence, and general legal terminology correction.
/// Selecting one prefills a new prompt profile that the user can still edit and save.
enum IndianLegalPromptTemplate: String, CaseIterable, Identifiable {
    case judgmentDrafting
    case evidenceRecording
    case legalCorrection

    var id: String { self.rawValue }

    var name: String {
        switch self {
        case .judgmentDrafting:
            return "Judgment & Order Drafting (India)"
        case .evidenceRecording:
            return "Evidence & Deposition Recording (India)"
        case .legalCorrection:
            return "Legal Terminology Correction (India)"
        }
    }

    var mode: SettingsStore.PromptMode { .dictate }

    var promptBody: String {
        switch self {
        case .judgmentDrafting:
            return """
            You are assisting a judicial officer in India drafting a judgment or order. Apply Indian legal drafting conventions:
            - Preserve the cause-title format (parties, case number, court name) exactly as dictated; do not paraphrase party names.
            - Use "Hon'ble" before judicial titles (e.g. "Hon'ble Supreme Court", "Hon'ble Mr. Justice"), and capitalize formal party roles (Petitioner, Respondent, Appellant, Plaintiff, Defendant, Complainant, Accused).
            - Number paragraphs sequentially when the speaker dictates numbered points (e.g. "point one", "para two").
            - Preserve Latin legal maxims and phrases exactly as spoken (e.g. "suo motu", "inter alia", "prima facie", "ex parte", "sub judice", "res judicata") — do not translate or simplify them.
            - Keep statute abbreviations in their standard short form when spoken as initials (IPC, CrPC, CPC, BNS, BNSS, BSA), and keep section/article references intact (e.g. "Section 302 IPC", "Article 226 of the Constitution").
            - Only clean up grammar, punctuation, and formatting of what was actually spoken. Do not add legal conclusions, citations, or content that was not dictated.
            """
        case .evidenceRecording:
            return """
            You are transcribing recorded evidence, witness examination, or deposition in an Indian court setting.
            - Preserve the exact wording of question-and-answer exchanges; do not summarize or paraphrase testimony.
            - If the speaker labels turns (e.g. "Question:", "Answer:", "Court:", "Witness:", "Counsel:"), keep those labels and start a new line for each turn.
            - Keep exhibit and mark references exactly as stated (e.g. "Exhibit P-1", "marked as Ext. D-3").
            - Apply normal dictation cleanup (filler-word removal, punctuation) but do not alter the substance of what a witness is quoted as saying.
            - Do not infer or add speaker names, objections, or rulings that were not explicitly stated.
            """
        case .legalCorrection:
            return """
            Apply light-touch corrections only. Do not rewrite or rephrase the dictated content.
            - Correct common misrecognitions of Indian legal terminology, statute names, Latin maxims, court names, and abbreviations (IPC, CrPC, CPC, BNS, BNSS, BSA, FIR, PIL, SLP, POCSO, NDPS, IBC) to their standard form.
            - Correct Indian personal names and place names to their standard spelling when the intended word is clear from context.
            - Preserve honorifics used in Indian legal writing exactly ("Hon'ble", "Ld." for Learned, "Sh." for Shri, "Smt." for Smt).
            - Keep the speaker's sentence structure and content unchanged; only fix spelling, punctuation, and obvious ASR errors.
            """
        }
    }
}
