# Judicial dictation evaluation (Phase 3E.1 foundation)

Measures where the current PratiLekh dictation stack actually fails, stage by stage.

**Governing principle:** the reference is what the judge *dictated*, not what an evaluator or model
thinks the judge intended. Nothing here rewards a "legally better" provision, statute, fact, date,
amount or identifier: `302` scored against `304`, or IPC against BNS, is simply wrong.
(Complements the normalization principle: format what was dictated; never complete what was not dictated.)

## Layout
- `References/synthetic/<id>.json` - invented reference definitions (may live in Git).
- `Sources/` - schema, metrics, scoring, report (standalone Swift, no app dependency).
- `Runner/EvalRunner.swift` - the runner (`scripts/eval_run.sh`).
- Tests: `scripts/test_evaluation.sh`.

**Audio, private references, and all run results stay outside Git.** The runner refuses `--out`,
`--audio` and `--text-dir` paths inside the repository, and refuses non-synthetic references located
inside it. Never commit recordings (including recordings of synthetic scripts) or result files.

## Reference JSON (schemaVersion 1)
`id`, `tier` (`synthetic`|`private`), `category`, `tags[]`, `reference` (words as dictated),
`intendedFinal?` (text after approved deterministic formatting), `criticalTokens[]`
(`type`, `expected` canonical form, `spokenForms[]` = right words in non-canonical form),
`legalExpectations[]` (`apply` source+replacement, `decline` source, or a single `noCandidate`), `notes?`.
Generated stage outputs are never stored in references.

## Stages
- `providerTranscript` (Phase 3G.A, observability only): the `TranscriptionProvider`'s own returned
  text, captured immediately after `transcribeFinal`/`transcribeFile` return and before filler
  removal, custom dictionary or spoken-punctuation formatting. Reported as its own field on
  `SampleRunRecord` (`providerTranscript`), not as an entry in the scored `stages` list -- inserting
  it there would shift what `postASRDeterministic` is scored against (see `SampleScoring.score`'s
  positional reference/intendedFinal comparison). **Still not raw ASR**: `TranscriptionProvider`
  implementations may already perform their own internal formatting before returning this string;
  it means "before PratiLekh's own deterministic preprocessing," nothing more. Only present when
  audio was transcribed via the Local API; absent (never synthesized or copied from another stage)
  for `--text-dir` runs, since no provider is invoked in that mode.
- `postASRDeterministic`: `/v1/transcribe` output - provider text after filler removal, custom
  dictionary and spoken punctuation. **Not raw ASR**; still the same value it always was.
- `legalNormalized`: that text replayed through the real `LegalDictationProcessor`.
Post-legal formatting, AI and final output are not evaluated yet.

## Metrics (never blended)
WER and CER (vs `reference` for the first stage, `intendedFinal` after); exact critical-token
state per stage (`canonical` / `spoken` / `wrong`) with transitions `preserved`, `recovered`,
`unrecovered`, `corrupted` (each corrupted token is listed individually); normalization outcomes
`correctApplication`, `correctDecline`, `correctNoCandidate`, `missedOpportunity`, `falsePositive` and
`incorrectTransformation` (both severe, each listed), plus `notEvaluable` when the dictated span is not
in the ASR text (upstream recognition error, not blamed on normalization); formatting (case and
punctuation differences when the words match).

## Running
Offline, from post-ASR text files: `scripts/eval_run.sh --text-dir DIR --out DIR`.
With audio via the Local API: `scripts/eval_run.sh --audio DIR --out DIR`, with audio named
`<sampleID>.<wav|m4a|mp3|flac|caf|aiff>`. The app must be running with its Local API enabled
(off by default; this tool never changes it), on port 47733 unless `--api-base` is given.
The API exposes only the model display name; app settings (dictionary, boosting, etc.) are not
captured and results say so.

## Known limitations
- `postASRDeterministic` blends filler removal, custom dictionary and spoken punctuation into one
  value; as of Phase 3G.A, `providerTranscript` (audio runs only) makes the boundary immediately
  before those three transforms observable, but it is still not raw acoustic/model output -- see
  "Stages" above. Provider-internal processing before that point remains unobservable.
- Spoken-number vs digit forms (e.g. a provider writing `302` where the reference says "three zero two") count as WER errors.
  Not addressed in 3E.1; the real corpus will show whether metric normalization is warranted.
- Critical tokens are presence-based per sample; keep samples short with distinct tokens.
- `notEvaluable` marks outcomes attributable to an upstream recognition error and is reported in every summary.
- Post-legal formatting, AI and final-output stages are not yet evaluated.
