#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Intelligence V1.32 -- non-model consistency check of the autonomous-correction policy specification:
#   fidelity to V1.31 (invariants and PO decisions verbatim), clause-id integrity, register/area completeness, the explicit
#   "no T2 class is authorized" and "corpus gate not ready" statements, and that this milestone created no corpus and changed no
#   production, test or reference file. No model, no network.
python3 - <<'PY'
import re, subprocess, sys
spec = open("Evaluation/Intelligence/V1_32_AUTONOMOUS_CORRECTION_POLICY_SPECIFICATION.md").read()
v31 = open("Evaluation/Intelligence/V1_31_AUTONOMOUS_CORRECTION_POLICY_INVESTIGATION.md").read()
def fail(msg):
    print("FAIL:", msg); sys.exit(1)

inv = v31[v31.index("## 4. Governing invariants"):v31.index("## 5. Taxonomy")].split("\n", 1)[1].strip()
if inv not in spec: fail("invariants differ from V1.31 section 4")
po = v31[v31.index("| # | Decision |"):v31.index("**Current authorization state")].strip()
if po not in spec: fail("PO-A..PO-H table differs from V1.31 section A")
for label in ["PO-A", "PO-B", "PO-C", "PO-D", "PO-E", "PO-F", "PO-G", "PO-H", "PO-2 / PO-3"]:
    if f"| **{label}**" not in spec: fail(f"missing decision row {label}")
for n in range(1, 11):
    if f"**I{n} " not in spec: fail(f"missing invariant I{n}")

part1 = spec[:spec.index("# Part II")]
defs = re.findall(r"`\[([A-Z]+-\d+)\]`\s*$", part1, flags=re.M)
if len(defs) != len(set(defs)): fail("duplicate clause definitions")
refs = set(re.findall(r"`\[([A-Z]+-\d+)\]`", spec))
if not refs <= set(defs): fail(f"references to undefined clauses: {sorted(refs - set(defs))}")
for prefix, count in [("C", 5), ("L", 5), ("EP", 12), ("F", 4), ("D", 5), ("V", 5), ("R", 1)]:
    for i in range(1, count + 1):
        if f"{prefix}-{i}" not in defs: fail(f"clause {prefix}-{i} not defined")
for state in ["L0", "L1", "L2", "L3", "L4", "L5"]:
    if f"| **{state}** |" not in spec: fail(f"lifecycle state {state} missing")

areas = ["terminal period", "sentence-initial capitalization", "month/day-name capitalization", "per-matter vocabulary", "word split"]
register = spec[spec.index("7.2 **Register state"):spec.index("7.3 No other")]
if register.count("NOT AUTHORIZED") != len(areas): fail("register must list every T2 area as NOT AUTHORIZED")
for a in areas:
    if a not in register: fail(f"register lacks area: {a}")
for a in ["A1", "A2", "A3", "A4", "A5"]:
    if f"**{a} " not in spec: fail(f"section 13 lacks area {a}")
for text in ["no T2 class is currently authorized", "Present status against the gate: not ready"]:
    if text not in spec: fail(f"missing statement: {text}")
if "**no conformance corpus was created or frozen**" not in spec: fail("corpus statement missing")
for q in ["## 24.", "## 25.", "## 26."]:
    if q not in spec: fail(f"missing question section {q}")

# This milestone must not touch production, tests, frozen references, or create a corpus.
changed = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout.splitlines()
bad = [l for l in changed if re.match(r"^.. (Sources/|Tests/|Evaluation/References/)", l)]
if bad: fail(f"forbidden paths changed: {bad}")
print("PASS: V1.32 specification is internally consistent and faithful to V1.31 (decisions, invariants, clause ids, register, gate); no production/test/reference change")
PY
