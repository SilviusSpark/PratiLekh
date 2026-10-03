#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Intelligence V1.35 -- non-model consistency check of the v1.2 ownership-reconciliation addendum: V1.32 (v1.0) and V1.34 (v1.1) are
# byte-unchanged; adopted decisions and the PO-Q retirement are present; the five kinds, the ledgers (empty Intelligence register,
# DP/EI/UO items), the historical id mapping, A3 routes, the revised capability map and the closed readiness gate are consistent; nothing is
# authorized; and no production, test, reference or earlier-version file changed. No model, no network.
python3 - <<'PY'
import hashlib, re, subprocess, sys
def fail(m): print("FAIL:", m); sys.exit(1)
rd = lambda p: open(p).read()
pins = {
  "Evaluation/Intelligence/V1_32_AUTONOMOUS_CORRECTION_POLICY_SPECIFICATION.md": "9b4709956ab742d26edc4f2c7ad243bb54dc3a55c7c5becc0db88f63be3479bd",
  "Evaluation/Intelligence/V1_34_AUTONOMOUS_CORRECTION_POLICY_SPECIFICATION_V1_1.md": "3cf6a291f7181260c60f31b387e35bbd8aedbafe643c2b6e60bf4aa641cd4c56",
}
for path, digest in pins.items():
    if hashlib.sha256(open(path, "rb").read()).hexdigest() != digest: fail(f"{path} bytes changed")
    if subprocess.run(["git", "diff", "--quiet", "HEAD", "--", path]).returncode != 0: fail(f"{path} differs from HEAD")
spec = rd("Evaluation/Intelligence/V1_35_OWNERSHIP_RECONCILIATION_AND_DETERMINISTIC_WORK_CLASSIFICATION.md")
v11 = rd("Evaluation/Intelligence/V1_34_AUTONOMOUS_CORRECTION_POLICY_SPECIFICATION_V1_1.md")

# Adopted decisions.
dec = spec[spec.index("## 1. Adopted decisions"):spec.index("## 2. Five kinds")]
for key, phrases in {
  "PO-O": ["belongs to future deterministic processing, not Intelligence", "blocked", "Ownership is not authorization or implementation"],
  "PO-P": ["belongs to deterministic processing", "separately specified preservation policy", "Ownership is not authorization or implementation"],
  "PO-J": ["record-sensitive unless deterministic evidence establishes participation in a date structure", "lexical plausibility alone cannot authorize normalization"],
  "A4 disposition": ["retired as an autonomous correction area", "evidence infrastructure", "its own ownership, classification and authorization"],
  "A5 disposition": ["distinguished from the word-split operation", "evidence infrastructure", "unresolved pending PO-N"],
  "PO-M": ["Remains unresolved"],
  "PO-Q": ["Retired", "superseded by the individual dispositions"],
}.items():
    row = next((l for l in dec.splitlines() if l.startswith(f"| **{key}**")), None)
    if row is None: fail(f"decision row {key} missing")
    for p in phrases:
        if p not in row: fail(f"{key} row lacks: {p}")

# Clause ids (own definitions; references may also use v1.1 ids).
defs = re.findall(r"`\[([A-Z]+-\d+)\]`\s*$", spec, flags=re.M)
if len(defs) != len(set(defs)): fail("duplicate clause definitions")
v11defs = set(re.findall(r"`\[([A-Z]+-\d+)\]`\s*$", v11[:v11.index("# Part II")], flags=re.M))
refs = set(re.findall(r"`\[([A-Z]+-\d+)\]`", spec))
if not refs <= set(defs) | v11defs: fail(f"undefined clause references: {sorted(refs - set(defs) - v11defs)}")
for prefix, count in [("RC", 11), ("REG", 4)]:
    for i in range(1, count + 1):
        if f"{prefix}-{i}" not in defs: fail(f"clause {prefix}-{i} not defined")

# Kinds, ledgers, statements.
for n in range(1, 6):
    if f"\n{n}. **" not in spec[spec.index("## 2. Five kinds"):spec.index("## 3. Ownership map")]: fail(f"kind {n} missing")
for text in ["**no operation is authorized**", "**4.1 Intelligence register (prospective T2/T3 operations with confirmed Intelligence ownership): EMPTY.**",
             "No confirmed Intelligence-owned prospective T2 correction operation remains", "**No.** After reconciliation the Intelligence register (§4.1) is empty",
             "Every ledger above carries **no authorization**", "**Closed — not ready.**", "creates **no blanket pipeline or data-collection requirement**",
             "neither a finality signal nor target-field context", "PO-I remains authoritative", "v1.2 = v1.1 (V1.34) plus this addendum", "Nothing has been kept or invented"]:
    if text not in spec: fail(f"missing statement: {text}")
led = spec[spec.index("## 4. Reconciled ledgers"):spec.index("## 5. A3")]
for item in ["DP-1", "DP-2", "EI-1", "EI-2", "EI-3", "EI-4", "UO-1", "UO-2"]:
    if not re.search(rf"^\| {item} \|", led, flags=re.M): fail(f"ledger item {item} missing")
if re.search(r"(?<!no )(?<!NOT )(?<!not )authorized\*?\*? \|", led.replace("not authorized", "").replace("Not authorized", "")): fail("a ledger row reads as authorized")
a3 = spec[spec.index("## 5. A3"):spec.index("## 6. Historical")]
for r in ["R-a", "R-b", "R-c", "R-d", "Excluded by adopted decisions"]:
    if r not in a3: fail(f"A3 route {r} missing")
mp = spec[spec.index("## 6. Historical"):spec.index("## 7. Evidence capability map")]
for row in ["A1 terminal period", "A2a segment-initial", "A2b interior", "A3 month/day", "A4 per-matter", "A5 split lexicon", "whitespace"]:
    if row not in mp: fail(f"historical mapping lacks {row}")
cap = spec[spec.index("## 7. Evidence capability map"):spec.index("## 8. Is any")]
labels = ["**Owner:**", "**Required policy facts:**", "**Required observables:**", "**Currently available:**", "**Missing capability:**", "**Provenance requirement:**", "**Unresolved PO / investigation:**", "**Status:**"]
blocks = re.split(r"^### ", cap, flags=re.M)[1:]
if [b.split(" ", 1)[0] for b in blocks] != ["M1", "M2", "M3", "M4", "M5"]: fail("capability map must have M1..M5")
for b in blocks:
    for l in labels:
        if l not in b: fail(f"capability block {b.split(chr(10))[0]} lacks {l}")
if "## 11. Smallest justified next milestone" not in spec or "V1.36" not in spec: fail("next-milestone section missing")

changed = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout.splitlines()
bad = [l for l in changed if re.match(r"^.. (Sources/|Tests/|Evaluation/References/|Evaluation/Intelligence/V1_(30|31|32|33|34)_|Evaluation/Intelligence/(Comparison|CapabilityEvaluation|Harness|CapabilitySupplementary))", l)]
if bad: fail(f"forbidden paths changed: {bad}")
print("PASS: v1.2 addendum consistent -- V1.32 and V1.34 byte-unchanged, adopted decisions and PO-Q retirement, five kinds, empty Intelligence register, ledgers, A3 routes, id mapping, capability map, gate closed; no production/reference/earlier-version change")
PY
