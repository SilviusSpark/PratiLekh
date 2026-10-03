#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Intelligence V1.34 -- non-model consistency check of policy specification v1.1: V1.32 (v1.0) is byte-unchanged; V1.31 invariants and
# PO-A..PO-H and V1.33's PO-I/PO-K are carried verbatim; clause-id integrity; the reconciled register (A1/A2a retired, A2b/A3/A4/A5
# L0 NOT AUTHORIZED, nothing authorized); ownership clauses; the evidence capability map's structure and non-requirement rule; Part III's
# four lists; the readiness gate still closed; and that no production, test, reference or earlier-version document changed.
python3 - <<'PY'
import hashlib, re, subprocess, sys
def fail(m): print("FAIL:", m); sys.exit(1)
rd = lambda p: open(p).read()
V32 = "Evaluation/Intelligence/V1_32_AUTONOMOUS_CORRECTION_POLICY_SPECIFICATION.md"
spec = rd("Evaluation/Intelligence/V1_34_AUTONOMOUS_CORRECTION_POLICY_SPECIFICATION_V1_1.md")
v31 = rd("Evaluation/Intelligence/V1_31_AUTONOMOUS_CORRECTION_POLICY_INVESTIGATION.md")
v33 = rd("Evaluation/Intelligence/V1_33_PIPELINE_EVIDENCE_AND_DETERMINISTIC_BOUNDARY_INVESTIGATION.md")

if hashlib.sha256(open(V32, "rb").read()).hexdigest() != "9b4709956ab742d26edc4f2c7ad243bb54dc3a55c7c5becc0db88f63be3479bd": fail("V1.32 (v1.0) bytes changed")
if subprocess.run(["git", "diff", "--quiet", "HEAD", "--", V32]).returncode != 0: fail("V1.32 differs from HEAD")

inv = v31[v31.index("## 4. Governing invariants"):v31.index("## 5. Taxonomy")].split("\n", 1)[1].strip()
if inv not in spec: fail("invariants differ from V1.31 section 4")
po = v31[v31.index("| # | Decision |"):v31.index("**Current authorization state")].strip()
if po not in spec: fail("PO-A..PO-H table differs from V1.31")
po33 = v33[v33.index("**PO-I — segment finality.**"):v33.index("**Register consequences")].strip()
if po33 not in spec: fail("PO-I/PO-K text differs from V1.33 section A")

part1 = spec[:spec.index("# Part II")]
defs = re.findall(r"`\[([A-Z]+-\d+)\]`\s*$", part1, flags=re.M)
if len(defs) != len(set(defs)): fail("duplicate clause definitions")
refs = set(re.findall(r"`\[([A-Z]+-\d+)\]`", spec))
if not refs <= set(defs): fail(f"undefined clause references: {sorted(refs - set(defs))}")
for prefix, count in [("C", 6), ("T", 6), ("O", 7), ("L", 6), ("EP", 12), ("F", 4), ("D", 5), ("V", 5), ("R", 4), ("VER", 4), ("MAP", 2)]:
    for i in range(1, count + 1):
        if f"{prefix}-{i}" not in defs and not (prefix == "T" and i < 6): fail(f"clause {prefix}-{i} not defined")

reg = spec[spec.index("7.2 **Register state"):spec.index("7.3 No other")]
rows = {m.group(1): m.group(0) for m in re.finditer(r"^\| \*\*(A\w+)\*\* .*$", reg, flags=re.M)}
if set(rows) != {"A1", "A2a", "A2b", "A3", "A4", "A5"}: fail(f"register rows: {sorted(rows)}")
for k in ("A1", "A2a"):
    if "OUTSIDE INTELLIGENCE OWNERSHIP" not in rows[k] or "RETIRED" not in rows[k] or "NOT AUTHORIZED" in rows[k]: fail(f"{k} must be retired and outside ownership")
if "UNRESOLVED" not in rows["A2b"]: fail("A2b ownership must be unresolved")
for k in ("A2b", "A3", "A4", "A5"):
    if "L0 / NOT AUTHORIZED" not in rows[k]: fail(f"{k} must be L0 / NOT AUTHORIZED")
if reg.count("NOT AUTHORIZED") != 4: fail("exactly A2b, A3, A4, A5 are NOT AUTHORIZED")
if re.search(r"(?<!NOT )AUTHORIZED", reg.replace("Authorization", "")): fail("register contains an authorized state")
for text in ["no operation is authorized", "The ownership reconciliation of §6A/§7 authorizes nothing", "**Present status against the gate: not ready, unchanged from v1.0.**",
             "**PO-I remains authoritative**", "MUST NOT be introduced on the strength of this map", "creates **no blanket pipeline requirement**",
             "no conformance corpus was created or frozen", "A5 determination"]:
    if text not in spec: fail(f"missing statement: {text}")
for e in ["E1", "E2", "E3", "E4", "E5"]:
    if f"**{e} —" not in spec: fail(f"evidence category {e} missing")
cap = spec[spec.index("## 13A."):spec.index("# Part II")]
labels = ["**Owner:**", "**Required policy facts:**", "**Required observables:**", "**Currently available:**", "**Missing capability:**", "**Provenance requirement:**", "**Unresolved PO / investigation:**", "**Status:**"]
blocks = re.split(r"^### ", cap, flags=re.M)[1:]
if [b.split(" ", 1)[0] for b in blocks] != ["M1", "M2", "M3", "M4", "M5"]: fail("capability map must have M1..M5")
for b in blocks:
    for l in labels:
        if l not in b: fail(f"capability block {b.split(chr(10))[0]} lacks {l}")
for q in ["## 24.", "## 25.", "## 26.", "## 26A."]:
    if q not in spec: fail(f"missing Part III list {q}")
if "## 6A." not in spec or "[O-4]" not in spec: fail("ownership section missing")

changed = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout.splitlines()
bad = [l for l in changed if re.match(r"^.. (Sources/|Tests/|Evaluation/References/|Evaluation/Intelligence/V1_(31|32|33|30)_|Evaluation/Intelligence/(Comparison|CapabilityEvaluation|Harness|CapabilitySupplementary))", l)]
if bad: fail(f"forbidden paths changed: {bad}")
print("PASS: spec v1.1 consistent -- V1.32 byte-unchanged, V1.31/V1.33 decisions and invariants verbatim, reconciled register (nothing authorized), ownership clauses, capability map, readiness gate closed; no production/reference/earlier-version change")
PY
