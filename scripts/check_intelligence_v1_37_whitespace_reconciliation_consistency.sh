#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Intelligence V1.37 -- non-model consistency check of the v1.3 whitespace-reconciliation addendum: V1.32/V1.34/V1.35/V1.36 are byte-unchanged;
# PO-S/PO-T/PO-U and the narrowed P-1 (verbatim from V1.36) are present; the final taxonomy WS-1..WS-13 has valid dispositions with exactly one
# candidate (WS-2/DP-2a); DP-2 is retired and DP-2a is blocked, not T1, not authorized, not implemented, without a conformance suite; PO-S is said
# not to satisfy the placement blocker; DB-1 is separate and not a blocker; the Intelligence register is empty; the readiness gate is closed;
# and no production, test, reference or earlier-version file changed. No model, no network.
python3 - <<'PY'
import hashlib, re, subprocess, sys
def fail(m): print("FAIL:", m); sys.exit(1)
pins = {
  "Evaluation/Intelligence/V1_32_AUTONOMOUS_CORRECTION_POLICY_SPECIFICATION.md": "9b4709956ab742d26edc4f2c7ad243bb54dc3a55c7c5becc0db88f63be3479bd",
  "Evaluation/Intelligence/V1_34_AUTONOMOUS_CORRECTION_POLICY_SPECIFICATION_V1_1.md": "3cf6a291f7181260c60f31b387e35bbd8aedbafe643c2b6e60bf4aa641cd4c56",
  "Evaluation/Intelligence/V1_35_OWNERSHIP_RECONCILIATION_AND_DETERMINISTIC_WORK_CLASSIFICATION.md": "4c7329944b5b64b11e6626f41929f77f3d0aa3e358be2709f8a6ee2c012b56c2",
  "Evaluation/Intelligence/V1_36_DETERMINISTIC_WHITESPACE_PRESERVATION_POLICY_INVESTIGATION.md": "3091eb0460c17c97b3844d219e1374b69cd2e261fd2f218c6bd4c60b140b4083",
}
for path, digest in pins.items():
    if hashlib.sha256(open(path, "rb").read()).hexdigest() != digest: fail(f"{path} bytes changed")
    if subprocess.run(["git", "diff", "--quiet", "HEAD", "--", path]).returncode != 0: fail(f"{path} differs from HEAD")
doc = open("Evaluation/Intelligence/V1_37_DETERMINISTIC_WHITESPACE_POLICY_RECONCILIATION.md").read()
v36 = open("Evaluation/Intelligence/V1_36_DETERMINISTIC_WHITESPACE_PRESERVATION_POLICY_INVESTIGATION.md").read()

p1 = v36[v36.index("- **P-1 What the traced pipeline"):v36.index("- **P-2 Origin is lost.**")].strip()
quoted = "\n".join("> " + l if i else "> " + l for i, l in enumerate(p1.split("\n")))
if quoted not in doc: fail("P-1 is not carried verbatim from V1.36")
for bad in ["no command can produce a run of two or more ordinary spaces", "No spoken mechanism expresses", "the judge cannot dictate it"]:
    if bad in doc: fail(f"over-broad claim present: {bad}")

dec = doc[doc.index("## 1. Adopted decisions"):doc.index("## 2. Final whitespace")]
for key, phrases in {"PO-S": ["Adopt the V1.36 whitespace preservation policy", "narrowed P-1", "currently traced pipeline only", "does not establish that intentional multiple-`U+0020` input can never reach a future operation"],
                     "PO-T": ["Segment-edge whitespace is outside DP-2 ownership"],
                     "PO-U": ["Non-`U+0020` whitespace is preserve-only", "separately specified operation and justification"]}.items():
    row = next((l for l in dec.splitlines() if l.startswith(f"| **{key}**")), None)
    if row is None: fail(f"decision {key} missing")
    for p in phrases:
        if p not in row: fail(f"{key} lacks: {p}")
for text in ["**PO-S does not satisfy the DP-2a placement blocker**", "Policy adoption is not candidate readiness", "it does **not** assign an owner"]:
    if text not in dec: fail(f"missing: {text}")

tax = doc[doc.index("## 2. Final whitespace"):doc.index("## 3. DP-2 reconciled")]
rows = {m.group(1): m.group(0) for m in re.finditer(r"^\| (WS-\d+) \|.*$", tax, flags=re.M)}
if set(rows) != {f"WS-{i}" for i in range(1, 14)}: fail(f"taxonomy rows: {sorted(rows)}")
for k, r in rows.items():
    if not re.search(r"PRESERVE-ONLY|AMBIGUOUS → PRESERVE|OUTSIDE DP-2 OWNERSHIP|CANDIDATE \(conditional\)|governed by WP-6/WP-7", r): fail(f"{k} lacks a final disposition")
if sum("CANDIDATE (conditional)" in r for r in rows.values()) != 1 or "CANDIDATE (conditional)" not in rows["WS-2"]: fail("WS-2/DP-2a must be the only candidate")
for k in ("WS-4", "WS-5", "WS-11"):
    if "PRESERVE-ONLY" not in rows[k]: fail(f"{k} must be preserve-only (PO-U)")
if "OUTSIDE DP-2 OWNERSHIP" not in rows["WS-3"]: fail("WS-3 must be outside DP-2 ownership (PO-T)")

for text in ["**The broad DP-2 concept (\"general whitespace/typographic normalization\", V1.35 DP-2 and V1.34 M5) is retired.**", "**DP-2a is the sole remaining deterministic whitespace candidate**",
             "DP-2a is, at v1.3: not T1; not authorized; not implemented; without a frozen conformance suite; BLOCKED**", "**RETIRED at v1.3**", "**BLOCKED**: B-1…B-5",
             "**No Intelligence T2 candidate exists after v1.3.**", "**EMPTY**", "is **not reopened**", "**The conformance-readiness gate remains closed — not ready.**",
             "It is **not a blocker for adopting the DP-2a preservation policy**", "**not a DP-2/DP-2a defect**", "**V1.38 — DP-2a exact deterministic function and pipeline-placement specification",
             "**PO-S does not satisfy this blocker**", "v1.3 = v1.2 (V1.35 addendum) + this addendum", "**nothing is promoted to T1**", "**no operation is authorized**"]:
    if text not in doc: fail(f"missing statement: {text}")
for b in ["B-1", "B-2", "B-3", "B-4", "B-5"]:
    if f"**{b} " not in doc: fail(f"blocker {b} missing")
defs = re.findall(r"`\[([A-Z]+-\d+)\]`\s*$", doc, flags=re.M)
if len(defs) != len(set(defs)): fail("duplicate clause ids")
for i in range(1, 17):
    if f"WA-{i}" not in defs: fail(f"clause WA-{i} missing")
ledger = doc[doc.index("## 5. Deterministic-work ledger"):doc.index("## 6. Evidence capability map")]
for item in ["DP-1", "DP-2a"]:
    if not re.search(rf"\| \**{item}\** \|", ledger): fail(f"ledger lacks {item}")
if "~~DP-2~~" not in ledger: fail("retired DP-2 must remain traceable")
cap = doc[doc.index("### M2 "):doc.index("## 7. DB-1")]
for l in ["**Owner:**", "**Required policy facts:**", "**Required observables:**", "**Currently available:**", "**Missing capability:**", "**Provenance requirement:**", "**Unresolved PO / investigation:**", "**Status:**"]:
    if l not in cap: fail(f"M2 lacks {l}")

changed = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout.splitlines()
bad = [l for l in changed if re.match(r"^.. (Sources/|Tests/|Evaluation/References/|Evaluation/Intelligence/V1_(30|31|32|33|34|35|36)_|Evaluation/Intelligence/(Comparison|CapabilityEvaluation|Harness|CapabilitySupplementary|PolicyInvestigation))", l)]
if bad: fail(f"forbidden paths changed: {bad}")
print("PASS: v1.3 whitespace reconciliation consistent -- V1.32/34/35/36 byte-unchanged, PO-S/T/U and verbatim narrowed P-1, final taxonomy, DP-2 retired / DP-2a blocked and not T1/authorized/implemented, DB-1 separate, empty Intelligence register, gate closed; no production/reference change")
PY
