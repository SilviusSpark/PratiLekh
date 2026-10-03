# Intelligence V1.33 — Pipeline evidence and deterministic-boundary investigation (FE1 + FE7), with adopted PO-I / PO-K decisions

**Read-only investigation and documentation.** No model was run; no production code, Authority, gate, contract, corpus or result changed; no T2 predicate was
authorized or specified; **no authorization-lifecycle state moved** (every register entry in V1.32 §7.2 remains L0 / NOT AUTHORIZED — see §A for how the
adopted decisions are recorded without editing it); no conformance corpus exists. Evidence = the repository implementation (file and line references are to the
tree at commit `cf3e27d`), read directly; where documentation differs, §8 reports the difference without repairing it. FE2–FE6 are out of scope except where this tree
establishes a fact FE1/FE7 need. `scripts/check_intelligence_v1_33_pipeline_trace.sh` re-verifies the trace's ordering and default-setting claims against the source.

**How to read this document.** §A records the **adopted decisions** (Product Owner / architecture rulings made after the investigation); they are normative inputs to a
future specification version and **govern where they differ from §9–§10**, which are the investigation's findings and the options it found. §1–§8 are evidence. The committed
V1.32 specification is **not edited in place**; its amendment is a later, separately versioned step (§12).

## A. Adopted decisions (these govern)

**PO-I — segment finality.**
- The current hotkey-session segment has **no finality semantics**.
- **Hotkey release is an acquisition boundary, not evidence** of sentence, utterance, paragraph or dictation finality.
- **No future rule may infer finality merely from segment end or hotkey release.**
- **No finality signal and no target-field context is introduced in this milestone** (options I-2 and I-3 of §10 are therefore not adopted here; they remain unexamined future
  possibilities that would need their own decision).

**PO-K — deterministic-processing ownership.**
- **Intelligence does not own terminal punctuation or segment-initial capitalization.** They remain **presentation concerns in the existing downstream formatting layer**.
- This decision **does not classify or validate** the existing GAAV / smart-capitalization formatters as T1 under V1.32 (§7 stays diagnostic; those formatters are not
  promoted, and their lowering/stripping behaviour remains unqualified under I2/I4).
- **Interior sentence-initial capitalization and general whitespace ownership remain unresolved.**
- **Nothing is implemented and no formatting behavior is moved.**

**Register consequences (recorded here; the V1.32 register text is unchanged).** The decisions are *ownership* decisions, not authorizations:
- **A1 terminal-period correction** is **removed from prospective T2 ownership by Intelligence.** It is not an authorization of, or a statement about, current formatter behavior.
- **A2 sentence-initial capitalization is narrowed:** the *segment-initial* letter is outside Intelligence ownership; **interior sentence-initial capitalization remains unresolved and blocked.**
- **A3, A4, A5 are unchanged and unauthorized.**
- No lifecycle state moved; nothing was authorized. The V1.32 register will be updated only by a later specification version (§12).

## 1. The actual pipeline (live dictation, normal route)

```
audio (one hotkey press → release)
 └─ ASRService.stop()                                         Services/ASRService.swift:2816
     ├─ provider.transcribeFinal(pcm)      ONE call, whole recording    :3077     → provider text (opaque origin of punctuation/caps)
     ├─ removeFillerWords          (setting, default ON)               :3115, :5759
     ├─ applyCustomDictionary      (user entries)                      :3118, :5845
     ├─ applySpokenPunctuationFormatting  (setting, default ON, no app context)   :3121
     └─ returns outputText   (no provider text, no timestamps, no confidence retained)
 └─ ContentView.processStoppedTranscription                    ContentView.swift:2561
     ├─ applySpokenPunctuationFormatting  AGAIN, now with app name/bundle/title   :2687
     ├─ SpokenSendParser.parse    (setting, default OFF)           :2693  → strips a trailing "literal <send phrase>" and trailing punctuation
     ├─ LegalDictationProcessor.shared.process(...)               :2702  → NormalizationOutcome (normalized + typed provenance)
     │        ═════ the Intelligence / AI hand-off input is `legalNormalization.normalized` (:2703, passed to the AI call at :2733) ═════
     ├─ [optional AI post-processing on legalNormalizedText]       :2711–2760, call at :2733 (Intelligence is NOT wired in)
     ├─ applyDictationLiteralFormatting (setting, default OFF; slash commands/@mentions, app-dependent)   :2777
     ├─ applyGAAVFormatting        (settings, default OFF: strip final ".", lowercase first letter)     :2785
     ├─ applyContinuousDictationFormatting (settings, default OFF: smart first-letter caps from field context + spacing)   :2791
     └─ applyTerminalLiteralAutocompleteSpacing (terminal apps)    :2796
```

Other paths read: `reprocessDictationText` (AI retry) re-runs spoken punctuation → legal normalization → AI → the same trailing formatters from the *stored post-stop text*
(ContentView.swift:3648–3718, pending text kept at :2986/:3782). The streaming preview is separate and never becomes the final text (stop() uses one full-audio
`transcribeFinal`). The API/evaluation path (`transcribeSamplesForAPI`, ASRService.swift:3246) runs the same fillers → dictionary → spoken-punctuation chain and also
returns the provider's own text (`providerText`) — only there is provider text ever exposed. Command, rewrite and prompt-test modes bypass this chain.

**Default configuration** (SettingsStore): fillers ON (a 17-word list incl. "er", "ah", "eh", "hm", "mm", "ugh"), spoken-punctuation conversion ON with prefix `literal`,
spoken-send OFF, GAAV OFF, continuous spacing/smart-caps OFF, literal formatting OFF. All are user-mutable and unversioned.

## 2. What constitutes a segment, and what establishes finality

| Boundary | What a "segment" is | Finality established? |
|---|---|---|
| Audio capture / `stop()` | one hotkey press→release = one `pcm` buffer; provider called once (any internal chunking is opaque) | **No.** Releasing the key says nothing about sentence or dictation completion. |
| `processStoppedTranscription` | the single string `stop()` returned | **No.** The pipeline has no notion of utterance, document or "complete". |
| Spoken-send | an explicit *send* phrase, if the setting is on, ends the text and triggers delivery | An explicit user act, but its meaning is "send now", not "text is final"; off by default. |
| Continuous dictation | successive recordings chained through the **target app's text before the caret** (`TypingService.textBeforeCursorInFocusedField`, captured only when the context-needing settings are on, ContentView.swift:2100) | Continuation exists **only in the external field**; it is consumed by the trailing formatter and never reaches the hand-off text. |
| AI retry (`reprocess`) | the stored post-stop text of one session | n/a |

So **segment finality is not established anywhere in the pipeline**, and what *would* tell whether a session continues (the focused field context) is captured conditionally,
privately, unversioned, and *after* the hand-off point.

## 3. Origin of punctuation, capitalization and whitespace in the hand-off text

| Surface feature | Origins that can reach the Intelligence input | Distinguishable at the hand-off? |
|---|---|---|
| Punctuation / capitalization | (a) the speech model/provider (opaque; PratiLekh's provider wrappers add no punctuation or casing logic — they return the provider's string, trimmed); (b) marks generated from an explicit spoken command (`literal comma`, default prefix `literal`, `SpokenPunctuationFormatter`); (c) deletion of provider commas/periods *beside* a spoken command ("removingGeneratedCommaNoise…", SpokenPunctuationFormatting.swift:170, :802); (d) custom-dictionary replacement text; (e) legal-normalization rendering (e.g. `Section 302 IPC`); (f) deletion of trailing punctuation by spoken-send | **No.** After conversion, a dictated mark and a provider mark are the same character; nothing records the origin. |
| Whitespace | provider output; filler removal (splits on single spaces and re-joins with one space, collapsing runs of spaces when enabled); spoken-punctuation spacing rules; dictionary patterns that "consume horizontal separators" for whitespace replacements | No origin recorded. |
| Words | provider; filler *deletion* (and any punctuation attached to a filler token); custom-dictionary substitution | No record of what was removed or substituted. |

## 4. Order of transformations before Intelligence, and the irreversible losses

Order: provider → filler removal → custom dictionary → spoken punctuation → (again) spoken punctuation with app context → spoken-send parse → legal normalization. Formatters that
sound like "the deterministic formatting" (GAAV, continuous dictation, literal formatting, terminal spacing) run **after** the hand-off, so they do **not** shape the Intelligence input —
they will reshape its **output**.

Irreversibly lost (relative to the hand-off text; not recoverable from it): the provider's original string (retained only at the API seam; the history store's `rawText` is the *post-stop*,
post-filler/dictionary/spoken-punctuation text, not the provider's); which words were deleted as fillers and which punctuation went with them; which tokens a dictionary entry replaced;
which marks were dictated versus provider-generated; which provider commas/periods were deleted beside commands; the trailing send phrase/punctuation; the active settings; the transcription
model/provider identity (history keeps it only for audio metadata or the AI model); provider confidence (a constant 1.0 for most providers; not carried); any timestamps or alternatives (none
exist). Optional: if the user saves audio with history, the audio survives separately (`DictationAudioMetadata`), not at the hand-off.

What **does** survive: the legal-normalization outcome (typed pass/step and pre-change UTF-16 range for every applied/declined change — V1.10), from which protected spans are derived (V1.11,
V1.13), and the derived `protectsLeadingCapitalization` flag.

## 5. User settings that affect the text

Before the hand-off: `removeFillerWordsEnabled` + `fillerWords`; custom dictionary entries; `autoConvertPunctuationEnabled`, `punctuationDictionaryPrefix`, the punctuation and action rule tables;
`spokenSendEnabled`/phrase. After the hand-off (affect Intelligence *output*): `literalDictationFormattingEnabled`; `gaavLowercaseFirstLetterEnabled`, `gaavRemoveTrailingPeriodEnabled`;
`continuousDictationSpacingEnabled`, `contextAwareCapitalizationEnabled`. All live in UserDefaults, are mutable at any time, are read at the moment each stage runs, and are not recorded with the output.

## 6. Observable inventory

`observable → producer → transformation → version/stability → available at the Intelligence input? → provenance quality → policy relevance`

| # | Observable | Producer | Transformation | Version / stability | At hand-off? | Provenance quality | Policy relevance |
|---|---|---|---|---|---|---|---|
| O1 | Provider text | provider `transcribeFinal` | none by PratiLekh | model/provider-dependent, opaque; identity not stamped on the text | **No** (API seam only) | low–medium (origin of marks opaque) | origin of provider punctuation/caps (I4, PO-E) |
| O2 | Provider confidence | provider | none | mostly a constant 1.0 (Whisper, Apple, external); not carried | No | none | none (V-2: not evidence) |
| O3 | Hand-off text `legalNormalized` | pipeline above | fillers → dictionary → spoken punct ×2 → send parse → legal norm | **unversioned stages; settings-dependent; not reproducible from the text alone** | Yes (is the input) | medium: deterministic stages, but no per-stage record | the substrate for every predicate (EP-3) |
| O4 | Filler removals | `removeFillerWords` | word + attached-punctuation deletion | list/setting-dependent | No | none (nothing recorded) | I1 (word deletion happened upstream) |
| O5 | Dictionary substitutions | `applyCustomDictionary` | regex, case-insensitive trigger→replacement | user data, unversioned | No | none | I1/I2; precedent for a user-curated lexicon (A4/A5) |
| O6 | Spoken-command marks (dictated punctuation) | `SpokenPunctuationFormatter` | word→symbol with spacing rules; deletes adjacent provider commas/periods | rules/prefix user-mutable | **No** (origin erased on conversion) | none *as recorded*; derivable only by instrumenting this stage | I4, PO-E (see §9 A1) |
| O7 | Spoken-send result | `SpokenSendParser` | strips trailing send phrase + punctuation | setting-dependent | partly (ContentView holds `shouldSend`, not the text's history) | low | an explicit user act; weak finality evidence |
| O8 | Normalization outcome (applied/declined, typed pass/step, ranges) | `LegalDictationProcessor` | Phase-3 rules over provenance (V1.10 replayable) | pack/rule code; deterministic | In scope at the seam; not handed to the AI | **high** | I2; protected spans |
| O9 | Protected spans | `ProtectedSpanDerivation` + `NumericStructuralProtection` | derived from O8 and digit structure | deterministic | derivable (not wired) | high | I2 |
| O10 | `protectsLeadingCapitalization` | `NormalizationOutcome` | boolean from O8 | deterministic | in scope | high | interaction with downstream first-letter lowering |
| O11 | Active settings snapshot | SettingsStore | none | **mutable, unversioned, unrecorded** | No (readable, but not stamped) | none | V-3: would need recording to be evidence |
| O12 | Target-field preceding text | `TypingService.textBeforeCursorInFocusedField` | accessibility read | conditional (only if continuous settings on); sensitive; unversioned | **No** (consumed only after the hand-off) | medium (a recorded fact, not provenance of intent) | the only continuation signal (PO-I) |
| O13 | App context (name/bundle/title) | ContentView | none | live | No (used by spoken-punct/literal formatters) | medium | none directly |
| O14 | Segment-finality indicator | — | — | **does not exist** | No | — | PO-I |
| O15 | Sentence-boundary / abbreviation information | — | — | **does not exist** (only raw characters) | No | — | A1/A2 |
| O16 | Audio (optional with history) | `DictationAudioHistoryStore` | none | user-optional | No | high but off the path | future V2/V3 only |
| O17 | Transcription model identity | SettingsStore | none | mutable | No | — | would be recorded provenance (V-1) |

**Observables a future predicate could consume *today*, without changing the pipeline:** O3 (the text itself), O8–O10 (normalization provenance and protected spans), and — as a recorded fact
only — O12/O11 if they were captured at the seam. **Not consumable today:** O1/O4–O7 provenance (not recorded), O14/O15 (nonexistent), O2 (not evidence).

## 7. What the existing deterministic operations guarantee — and how they relate to V1.32

*Diagnostic only; nothing is promoted to T1 here (T1 membership is a separate normative decision).*

| Operation | (1) Deterministic current behavior | (2) Plausible T1 candidate under V1.32 §4.1 | (3) Cannot qualify as T1 as the spec stands (reason) |
|---|---|---|---|
| Legal normalization (Phase 3: statutory refs, witness refs) | yes, with replayable provenance | **yes** — a rule-derivable normalization with typed provenance (already named T1 in V1.31/V1.32 §5 within its grammar) | — |
| Spoken-punctuation command execution (`literal comma` → `,`) | yes (given setting/rules/prefix) | **yes** — executing an explicit dictated command is rule-derivable and consistent with I4 | the *side effect* of deleting adjacent provider marks and the double application (§8 X3) must be specified before any T1 statement |
| Spoken-send extraction | yes | arguably — a command, not a correction | strips trailing punctuation (changes existing marks, I4) |
| Filler removal | yes | no | **I1/I3**: deletes words (and attached punctuation) from a user-configurable list; information removed, unrecorded |
| Custom dictionary | yes | no | **I1/I2**: arbitrary user substitutions; may change words, names, numbers |
| Whitespace collapse | only as a side effect of filler removal (re-join on single spaces) | a standalone collapse/trim *would* be T1 | no standalone, specified implementation exists in this pipeline |
| Literal formatting (slash commands, @mentions) | yes, app-dependent, default off | no | rewrites words by application context; out of scope for legal text |
| GAAV (strip final "." / lowercase first letter) | yes, default off | no | **I2/I4**: lowers a letter and deletes a mark by preference; applied after the hand-off |
| Continuous smart caps / spacing | yes given field context, default off | spacing: perhaps; capitalization: no | capitalization **lowers** the first letter when the preceding context does not end a sentence, treats any `.`/`!`/`?` as a sentence end (no abbreviation exclusion), reads external state |
| Internal sentence-initial capitalization | **does not exist** | n/a | no component capitalizes interior sentence starts |

## 8. Implementation / documentation discrepancies (reported, not repaired)

- **X1 — V1.32 §13 (committed) overstates how user settings reach the Intelligence input.** It says the formatting stage "can optionally strip a trailing period or lowercase a leading capital … so the text Intelligence receives … may reflect user settings." In the implementation GAAV and continuous formatting run **after** the AI/Intelligence hand-off (ContentView.swift:2785–2796); the hand-off text reflects filler, dictionary, spoken-punctuation and spoken-send settings and legal normalization, **not** GAAV/continuous settings. Consequence: B-A1.2's "user setting" cause is not a cause at the hand-off, but those settings *do* post-process Intelligence output (§9). The V1.32 text stays as committed; a later specification version should amend it.
- **X2 — V1.31 §5 / V1.32 B-A2.5 imply the deterministic formatter already owns sentence-initial capitalization.** The implementation capitalizes only the *first letter of a segment* (continuous smart caps, default off, using the external field context), and **lowers** it otherwise; nothing capitalizes interior sentence starts, and its boundary test has no abbreviation exclusion. "T1 where the formatter already owns it" is not supported for interior sentences.
- **X3 — spoken punctuation runs twice** (ASRService.swift:3121, then ContentView.swift:2687 with app context). Documentation (CLAUDE.md pipeline description, "after spoken punctuation") describes one stage. Whether the second pass is idempotent on the first pass's output was **not verified** (no execution in this milestone).
- **X4 — naming:** `CLAUDE.md` calls the provider-boundary text `providerTranscript` (the Evaluation field); the production API returns it as `providerText` (ASRService.swift:3246). Cosmetic.
- **X5 — "raw" in history:** `rawText` in a history entry is the post-stop text (after fillers/dictionary/spoken punctuation), not the provider's raw output; consistent with CLAUDE.md's "history restores pre-legal text" but not with the word "raw".

## 9. Effect on the five prospective T2 areas — findings, then the decisions' effect (no state moves)

**Findings (evidence-only; before the decisions in §A).**

| Area | Resolves a blocker? | Introduces a blocker? | Points toward T1/T3/T4? | Net |
|---|---|---|---|---|
| **A1 Terminal period** | partly: B-A1.2's "user setting" cause is *not* operative at the hand-off (X1); segment finality is *established as absent* | **yes — downstream interaction:** `gaavRemoveTrailingPeriodEnabled` deletes a trailing "." after the hand-off, and continuous mode appends a space, so an Intelligence-added period can be undone or contradicted | **preference-owned presentation, not T2** | B-A1.1, B-A1.3, B-A1.4 stand; origin of marks needs recording (derivable only by changing the spoken-punctuation stage) |
| **A2 Sentence-initial capitalization** | no | **yes — downstream interaction** for the segment-initial letter (smart caps may re-lowercase it; GAAV lowercases it) and X2 (no interior owner) | segment-initial: formatter/preference-owned; interior: no owner, so T1 would require *new* work with the same boundary/abbreviation blockers | B-A2.1/.2/.4 unchanged; B-A2.3 refined (start-of-text depends on field context, absent at the hand-off) |
| **A3 Month/day names** | no | no | no component or date observable exists; the deferred date normalizer remains the alternative | unchanged |
| **A4 Per-matter vocabulary** | partly informs B-A4.2 (a user-level, user-curated store exists: custom dictionary, Parakeet boosting list) | yes: dictionary substitutions are upstream and unrecorded | none | B-A4.1/.3/.4/.5 unchanged |
| **A5 Split lexicon** | no (no general-word lexicon in the tree) | no | the custom dictionary shows user-curated tables can express splits (PO-F context) | unchanged; T3 scope |

**Effect of the adopted decisions (§A).**

| Area | Status after the decisions |
|---|---|
| **A1** | **Out of Intelligence ownership** (PO-K). No longer a prospective T2 area *for Intelligence*. The downstream formatters' handling of terminal marks is neither authorized nor classified by this decision. Because PO-I forbids inferring finality from hotkey release, no future Intelligence rule could have licensed a terminal-period insertion on that basis in any case. |
| **A2** | **Narrowed.** Segment-initial capitalization is out of Intelligence ownership (PO-K). **Interior sentence-initial capitalization remains unresolved / blocked** (needs boundary and abbreviation evidence that does not exist; ownership — Intelligence T2, new deterministic processing, or neither — is not decided). |
| **A3** | unchanged, **unauthorized** (L0, not authorized) |
| **A4** | unchanged, **unauthorized** (L0, not authorized) |
| **A5** | unchanged, **unauthorized** (L0, not authorized) |

## 10. Evidence for PO-I and PO-K, and the options considered (the decisions are in §A)

**PO-I — what unit does Intelligence receive, and can it be incomplete?** Evidence (§2): the unit is one hotkey session's text; the pipeline never establishes finality; continuation
context exists only in the target field (conditional, external, after the hand-off); an explicit spoken-send exists but means "send" and is off by default. Options the evidence supported:
- **I-1** treat the unit as never final — **adopted in substance by §A** (no finality semantics; none may be inferred from segment end or hotkey release);
- **I-2** introduce an explicit finality signal from an existing explicit event — **not adopted; not introduced in this milestone**;
- **I-3** supply target-field context as a recorded fact — **not adopted; not introduced in this milestone**.
*Not supported by the evidence (and now excluded by §A):* inferring finality from end of text or hotkey release.

**PO-K — which operations belong to deterministic processing rather than Intelligence?** Evidence (§1, §7–§9): the presentation formatters are user-preference-driven and run **after** the hand-off, so they
would override or contradict Intelligence output for the terminal period and the segment-initial letter; no component owns interior sentence-initial capitalization; no standalone whitespace normalizer exists
(collapse happens only as a filler-removal side effect). Options the evidence supported, and their disposition:
- **K-1** terminal punctuation and segment-initial capitalization are presentation preferences owned by the existing formatters — **adopted by §A**, without validating those formatters as T1;
- **K-2** extend deterministic processing to interior sentence-initial capitalization and whitespace normalization — **left open** (ownership of interior capitalization and general whitespace is unresolved);
- **K-3** keep them as T2 candidates — **not adopted** for terminal punctuation and segment-initial capitalization; interior capitalization stays blocked.
- Open under any outcome: a specified order of authority between Intelligence output and later formatters (the repository defines none, since Intelligence is not wired).

## 11. What this investigation does not establish

Model or provider behavior (how often a provider omits a mark; FE2–FE6); whether the second spoken-punctuation pass is idempotent (not executed); that any option above is desirable; the feasibility or cost of recording
provenance in the spoken-punctuation stage (it is *derivable in principle* — that stage creates the marks — but nothing records it today); anything about policy authorization.

## 12. Smallest justified next milestone

**V1.34 — specification v1.1 and provenance requirements (documentation only).** (1) Issue **policy specification v1.1** as a *new version* (the committed V1.32 text is not edited in place): correct X1 and X2, record the §A
ownership decisions in the register (A1 removed from Intelligence ownership; A2 narrowed to interior; A3–A5 unchanged; no lifecycle state moves without the V1.32 §8 process). (2) Specify, as requirements only, what provenance the
pipeline *would have* to record for any evidence predicate still wanted (origin of marks, settings snapshot, and — only if a later decision introduces them — finality and field context); nothing is implemented, and PO-I forbids
presuming finality. (3) Frame the remaining ownership questions (interior sentence-initial capitalization, general whitespace) as explicit decision items. No corpus, no model, no code. With A1 and the segment-initial half of A2
removed, the open T2 areas are interior A2, A3, A4 and A5, each blocked on boundary/abbreviation evidence, a date decision, a vocabulary or a lexicon.
