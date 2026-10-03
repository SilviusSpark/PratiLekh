#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Intelligence V1.36 -- non-model consistency check of the whitespace preservation-policy investigation: V1.32/V1.34/V1.35 are byte-unchanged;
# the taxonomy covers WS-1..WS-13 with a valid disposition; WP-1..WP-10 and the DP-2a candidate are present; DP-2a is explicitly not promoted,
# authorized or implemented; the executed probe tables (L1-L10, E1-E10) are present; the policy is labelled a proposal; the open decisions and
# the conformance-readiness conditions are recorded; and no production, test, reference or earlier-version file changed. No model, no network.
python3 - <<'PY'
import hashlib, re, subprocess, sys
def fail(m): print("FAIL:", m); sys.exit(1)
pins = {
  "Evaluation/Intelligence/V1_32_AUTONOMOUS_CORRECTION_POLICY_SPECIFICATION.md": "9b4709956ab742d26edc4f2c7ad243bb54dc3a55c7c5becc0db88f63be3479bd",
  "Evaluation/Intelligence/V1_34_AUTONOMOUS_CORRECTION_POLICY_SPECIFICATION_V1_1.md": "3cf6a291f7181260c60f31b387e35bbd8aedbafe643c2b6e60bf4aa641cd4c56",
  "Evaluation/Intelligence/V1_35_OWNERSHIP_RECONCILIATION_AND_DETERMINISTIC_WORK_CLASSIFICATION.md": "4c7329944b5b64b11e6626f41929f77f3d0aa3e358be2709f8a6ee2c012b56c2",
}
for path, digest in pins.items():
    if hashlib.sha256(open(path, "rb").read()).hexdigest() != digest: fail(f"{path} bytes changed")
    if subprocess.run(["git", "diff", "--quiet", "HEAD", "--", path]).returncode != 0: fail(f"{path} differs from HEAD")
doc = open("Evaluation/Intelligence/V1_36_DETERMINISTIC_WHITESPACE_PRESERVATION_POLICY_INVESTIGATION.md").read()

tax = doc[doc.index("## 3. Proposed normative whitespace taxonomy"):doc.index("## 4. Proposed preservation invariants")]
rows = {m.group(1): m.group(0) for m in re.finditer(r"^\| \*\*(WS-\d+)\*\* .*$", tax, flags=re.M)}
if set(rows) != {f"WS-{i}" for i in range(1, 14)}: fail(f"taxonomy rows: {sorted(rows)}")
for k, r in rows.items():
    if not re.search(r"\(1\) must preserve|\(2\) potentially canonicalizable|\(3\) ambiguous|\(4\) outside scope|governed by WP-6/WP-7", r): fail(f"{k} lacks a valid disposition")
if "(2) potentially canonicalizable" not in rows["WS-2"]: fail("WS-2 must be the canonicalizable class")
if sum("(2) potentially canonicalizable" in r for r in rows.values()) != 1: fail("exactly one class may be potentially canonicalizable")
for k in ("WS-4", "WS-5", "WS-6", "WS-10", "WS-11", "WS-1"):
    if "(1) must preserve" not in rows[k]: fail(f"{k} must be must-preserve")
inv = doc[doc.index("## 4. Proposed preservation invariants"):doc.index("## 5. Candidate")]
for i in range(1, 11):
    if f"**WP-{i} " not in inv: fail(f"WP-{i} missing")
for text in ["**DP-2a — ordinary-space run collapse.**", "**not promoted**", "not authorized, not implemented", "**nothing is authorized.**", "**DP-2 is not promoted to T1**",
             "becomes normative only if the Product Owner adopts it", "**PO-S**", "**PO-T**", "**PO-U**", "**Yes — DP-2a is sufficiently specified to be a *future T1 candidate*.**",
             "no whitespace canonicalizer was implemented", "**P-1 What the traced pipeline does and does not produce (narrowed).**",
             "not a claim that no dictation mechanism could ever express multiple spaces", "**V1.36 itself does not establish that implementation precondition**",
             "intentional multi-space input cannot reach it", "equivalent deterministic evidence", "DB-1", "can consume embedded tab or newline whitespace",
             "not a DP-2 defect", "## 13. Product Owner decisions received after this investigation", "**PO-T:** **segment-edge whitespace remains outside DP-2 ownership.**",
             "**PO-U:** **non-U+0020 whitespace is preserve-only under the current policy**", "deliberately not folded into the proposed policy", "## 11. What would have to be true before a whitespace conformance suite could be frozen", "**V1.37"]:
    if text not in doc: fail(f"missing statement: {text}")
for forbidden in ["no command can produce a run of two or more ordinary spaces", "No spoken mechanism expresses", "the judge cannot dictate it", "P-1 shows no authored whitespace can form such a run"]:
    if forbidden in doc: fail(f"over-broad claim still present: {forbidden}")
for i in range(1, 11):
    if not re.search(rf"^\| L{i} \|", doc, flags=re.M) or not re.search(rf"^\| E{i} \|", doc, flags=re.M): fail(f"probe row L{i}/E{i} missing")
changed = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout.splitlines()
bad = [l for l in changed if re.match(r"^.. (Sources/|Tests/|Evaluation/References/|Evaluation/Intelligence/V1_(30|31|32|33|34|35)_|Evaluation/Intelligence/(Comparison|CapabilityEvaluation|Harness|CapabilitySupplementary))", l)]
if bad: fail(f"forbidden paths changed: {bad}")
print("PASS: V1.36 whitespace investigation consistent -- earlier versions byte-unchanged, taxonomy WS-1..13, invariants WP-1..10, DP-2a not promoted/authorized/implemented, probe tables present; no production/reference change")
PY
