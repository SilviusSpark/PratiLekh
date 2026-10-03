#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Intelligence V1.30 -- independent verification of the committed S3 evidence (no model, no network, no benchmark):
#   1. every evidence file matches SHA256SUMS;  2. plan.json is byte-identical to the committed S3_PROPOSED_RUN_PLAN.json and
#   run_info.json names the approved plan hash;  3. 390 proposer records == the plan's steps, one run, baseline contract hashes;
#   4. the committed analyzer, run on the stored records + lifecycle, reproduces report.md (lifecycle verification included);
#   5. the filtered server log shows exactly 390 chat completions and 5 keep_alive unloads (/api/generate).
R=Evaluation/Intelligence/V1_30_S3_RESULTS
APPROVED=472f3807e47d904cbbf0d83c70cd679f45c0efde17c4e611579241bb58651e58
(cd "$R" && shasum -a 256 -c SHA256SUMS >/dev/null) || { echo "FAIL: SHA256SUMS mismatch" >&2; exit 1; }
cmp "$R/plan.json" Evaluation/References/intelligence-v1-comparison-s2/S3_PROPOSED_RUN_PLAN.json || { echo "FAIL: plan.json differs from the committed plan" >&2; exit 1; }
grep -q "\"planSHA256\" : \"$APPROVED\"" "$R/run_info.json" || { echo "FAIL: run_info does not name the approved plan hash" >&2; exit 1; }
python3 - "$R" <<'PY'
import json, sys
r = [json.loads(l) for l in open(sys.argv[1] + "/records.jsonl")]
assert len(r) == 390 and [x["sequence"] for x in r] == list(range(1, 391)), "records are not the 390 plan steps"
assert len({x["runID"] for x in r}) == 1 and {x["evidenceKind"] for x in r} == {"developmentCorpus"}
assert {x["contractArm"] for x in r} == {"V1.21-production"}
assert {x["contractInstructionsSHA256"] for x in r} == {"249ebb6ae1d7d6df9387d5d82ce818a0ccf5bef0b5104a05211f592caf54ad88"}
assert {x["toolDefinitionSHA256"] for x in r} == {"d7a7cc2347d9f9f2b21561e0073f5fef183125edca916f658f9e62130265cc98"}
assert {x["corpusSHA256"] for x in r} == {"e164297ec472e7f750d8e3e18f52f939e22a89bd7578ecc42df18d5b7941e364"}
log = open(sys.argv[1] + "/server_requests.log").read()
assert log.count('POST     "/v1/chat/completions"') == 390 and log.count('POST     "/api/generate"') == 5, "server request counts"
PY
out=$(mktemp)
trap 'rm -f "$out"' EXIT
scripts/intelligence_v1_comparison_s3_analyze.sh --records "$R/records.jsonl" --lifecycle "$R/lifecycle.jsonl" --write "$out" >/dev/null 2>&1
# Known cosmetic nondeterminism: the 'addressing rejections' dictionary prints in arbitrary key order. Compare that line's
# bracketed items as a sorted set, every other line verbatim.
python3 - "$out" "$R/report.md" <<'PY'
import re, sys
a, b = (open(p).read().split("\n") for p in sys.argv[1:3])
assert len(a) == len(b), "report length differs"
for x, y in zip(a, b):
    if "addressing rejections" in x and "addressing rejections" in y:
        norm = lambda s: (s.split("addressing rejections")[0], sorted(re.findall(r'"[^"]+": \d+', s)))
        assert norm(x) == norm(y), "addressing-rejection counts differ"
    else:
        assert x == y, "report differs: " + x[:80]
PY
echo "PASS: V1.30 S3 evidence verified -- hashes, plan identity, 390 records, lifecycle, analyzer reproduction, server request counts"
