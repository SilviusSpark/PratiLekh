# Intelligence V1.3B — Tool-Engagement Framing Findings

EXPERIMENTAL evidence only, from a behavioral investigation into why
`qwen2.5:1.5b` (via local Ollama, OpenAI-compatible endpoint) reliably calls a
factual/action tool but did not call any tool for tasks that read a supplied
text and derive/submit a value from it. Not production Intelligence behavior;
does not affect `Sources/Fluid/Intelligence/` (V1.0/V1.1/V1.2, unchanged).

Fixed throughout: `temperature: 0`, `seed: 42`, `num_ctx: 2048`, Ollama cloud
disabled, no other model downloaded. 5 attempts per condition unless noted.

## Controls (session-comparability check against V1.3A)

| Condition | Tool calls | Notes |
|---|---:|---|
| C0 — weather (factual/action) | 5/5 | matches V1.3A exactly |
| C1 — original A1 editing tool | 0/5 | matches V1.3A exactly |

Session confirmed comparable to V1.3A before proceeding.

## Experiment A — tool name only (schema/description/instructions held constant)

| Name | Tool calls |
|---|---:|
| `propose_edit` | 0/5 |
| `submit_correction` | 0/5 |
| `apply_text_correction` | 0/5 |
| `record_text_change` | 0/5 |
| `submit_result` (neutral) | 0/5 |

**No measurable effect from tool name alone**, including a deliberately
non-editing-flavored name.

## Experiment B — description only (name frozen at `submit_result`)

| Description class | Tool calls |
|---|---:|
| D1 descriptive | 0/5 |
| D2 imperative | 0/5 |
| D3 action-neutral | 0/5 |
| D4 minimal | 0/5 |

**No measurable effect from description alone.**

## Experiment C — user framing only (name + description frozen)

| Framing | Tool calls |
|---|---:|
| U1 declarative | 0/5 |
| U2 question | 0/5 |
| U3 explicit tool action | 0/5 |
| U4 workflow/action | 0/5 |
| U5 output-contract-only | 0/5 |

**No measurable effect from user-message framing alone.**

## Experiment D — matched semantic-task controls (identical `{input, output}` schema and identical neutral description across D1–D4)

| Task class | Tool calls |
|---|---:|
| D0 factual/action (weather, reference) | 5/5 |
| D1 extraction (day-of-week from a sentence) | 0/5 |
| D2 classification (statement vs. question) | 0/5 |
| D3 generic transformation (uppercase, non-editing) | 0/5 |
| D4 editing/correction (matched schema) | 0/5 |

**Extraction and classification failed identically to transformation and
editing.** This is a broader result than "editing is uniquely suppressed" —
every task that requires reading the supplied text and deriving/submitting a
value from it failed to engage tool-calling, while only the external
factual/action lookup succeeded.

## Forced-`tool_choice` diagnostics (reported separately, never counted as baseline)

- V1.3A: forced A1 (editing) — 0/3; forced weather (positive control) — 1/1.
- V1.3B: forced D2 classification — 0/3 (model answered in prose — `"Question"`
  / `"statement"` — despite `tool_choice` requiring the function by name).

Forcing does not change the outcome for any given-text-processing task
tested; it only ever succeeds for the external factual/action task.

## Experiment E

**Not run.** Its precondition ("Experiment D shows extraction/classification/
transformation engagement, but editing remains near zero") was not met —
extraction and classification failed identically to editing. Per the
milestone's own instructions, isolating "editing-specific lexical cues" is
not a meaningful next step when the same failure spans tasks with no
editing/correction vocabulary at all (e.g. uppercase transformation,
statement/question classification).

## Causal conclusions actually supported

- Tool name: **no measurable effect** (Experiment A).
- Tool description: **no measurable effect** (Experiment B).
- User-message framing: **no measurable effect** (Experiment C).
- Forced tool selection: **no measurable effect** for any given-text task
  (V1.3A + V1.3B forced diagnostics).
- The one dimension that correlates with engagement across every condition
  tested (16 conditions, ~83 requests) is: **whether the task is framed as an
  external factual/action lookup** (succeeds, 5/5 in two independent
  instances) **vs. any task operating on and returning a value derived from
  supplied input text** (fails, 0/5 across 15 independent conditions
  spanning editing, extraction, classification, and non-editing
  transformation).

## Supported conclusion

Under the tested Ollama/OpenAI-compatible tool-calling configuration, Qwen2.5
1.5B reliably engages tools for the external factual/action control but does
not reliably engage tools for any tested task requiring it to process
supplied text and submit a derived value. We have NOT established whether
this behavior comes from model training, Ollama's chat template, Qwen's
learned tool-use priors, some interaction among them, or another unisolated
mechanism -- only that framing changes (name, description, user message) and
forced tool selection do not alter it.

## Model-candidate decision

Qwen2.5 1.5B is not currently considered a viable candidate for PratiLekh's
**tool-mediated** Intelligence proposal architecture, as tested. This
conclusion is specific to that architecture and to the conditions measured
here. It must NOT be generalized into "Qwen2.5 1.5B cannot perform legal
text correction" -- that capability was never tested; only its willingness
to route a given-text-processing task through the tool-calling mechanism
was. The model remains installed but unloaded; no other model was
downloaded during this investigation.

V1.3A's deterministic-addressing findings remain valid and independent of
this result -- they describe a property of PratiLekh's own deterministic
resolver code, not of any particular model. The likely long-term boundary
remains conceptually `model-facing proposal -> deterministic PratiLekh
source resolver -> exact internal UTF-16 proposal -> V1.0 Safety Authority`,
with B3-style exact-context addressing remaining a promising but
not-yet-adopted candidate. No production contract change is authorized by
this milestone.

## Hypotheses still unresolved

- *Why* this model's tool-calling template/training associates tool-calling
  specifically with external-action semantics was not investigated — this is
  a behavioral/black-box finding, not a mechanistic one.
- Whether a different phrasing entirely outside the templates tried here
  (not attempted, to avoid an unbounded prompt-optimization loop) could
  restore engagement is unknown and was deliberately not pursued further,
  per the milestone's explicit instruction not to prompt-engineer
  indefinitely.
- Whether this pattern is specific to `qwen2.5:1.5b`'s size/training or
  generalizes to other small local models was not tested (no other model is
  authorized in this milestone).
