#!/bin/sh
# Evaluation framework tests. Scoring tests are standalone; the fixture replay
# test and the runner checks also compile the real LegalLanguage sources.
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_test_dir=$(mktemp -d /tmp/pratilekh-evaluation-tests.XXXXXX)

task_eval_sources=$(ls Evaluation/Sources/*.swift)
task_legal_sources=$(find Sources/Fluid/LegalLanguage -name '*.swift' | sort)

for task_test_file in Tests/EvaluationMetricsTests.swift Tests/EvaluationScoringTests.swift; do
    task_binary_name=$(basename "$task_test_file" .swift)
    # shellcheck disable=SC2086
    xcrun swiftc -parse-as-library $task_eval_sources "$task_test_file" -o "$task_test_dir/$task_binary_name"
    "$task_test_dir/$task_binary_name"
done

# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_legal_sources $task_eval_sources Tests/EvaluationFixtureReplayTests.swift -o "$task_test_dir/EvaluationFixtureReplayTests"
"$task_test_dir/EvaluationFixtureReplayTests"

# Phase 3E.2A diagnostic references (D01-D10): load/validate, and replay
# against the real LegalDictationProcessor under a perfect-ASR assumption to
# anchor the current known behavior this milestone measured.
# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_legal_sources $task_eval_sources Tests/Diagnostics3E2ATests.swift -o "$task_test_dir/Diagnostics3E2ATests"
"$task_test_dir/Diagnostics3E2ATests"

# Phase 3E.2B diagnostic references (N01-N12, Y01-Y10, P01-P06): load/validate,
# pairing structure, and recognition-soundness replay -- deliberately no
# assertion on N01-N12's current normalization outcome kind (see file doc).
# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_legal_sources $task_eval_sources Tests/Diagnostics3E2BTests.swift -o "$task_test_dir/Diagnostics3E2BTests"
"$task_test_dir/Diagnostics3E2BTests"

# Runner: build once, then exercise the privacy guard and the offline path.
# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_legal_sources $task_eval_sources Evaluation/Runner/EvalRunner.swift -o "$task_test_dir/eval_runner"

if "$task_test_dir/eval_runner" --text-dir "$task_test_dir" --out "$(pwd)/evaluation-results-should-be-rejected" >/dev/null 2>&1; then
    echo "FAIL: runner accepted an --out directory inside the repository"; exit 1
fi
test ! -e "$(pwd)/evaluation-results-should-be-rejected" || { echo "FAIL: runner wrote inside the repository"; exit 1; }

task_text_dir="$task_test_dir/text"
mkdir -p "$task_text_dir"
for task_ref in Evaluation/References/synthetic/*.json; do
    task_id=$(basename "$task_ref" .json)
    python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['reference'])" "$task_ref" > "$task_text_dir/$task_id.txt"
done
"$task_test_dir/eval_runner" --text-dir "$task_text_dir" --out "$task_test_dir/results" > "$task_test_dir/offline.out"
grep -q "corrupted tokens: none" "$task_test_dir/offline.out" || { echo "FAIL: offline run reported corrupted tokens"; exit 1; }
grep -q "severe failures: none" "$task_test_dir/offline.out" || { echo "FAIL: offline run reported severe failures"; exit 1; }
grep -q "settings captured: NO" "$task_test_dir/offline.out" || { echo "FAIL: summary must state settings were not captured"; exit 1; }
test -f "$task_test_dir"/results/*/run.json || { echo "FAIL: run.json missing"; exit 1; }
test -f "$task_test_dir"/results/*/syn-stat-001.result.json || { echo "FAIL: per-sample result missing"; exit 1; }
echo "PASS: eval runner offline path and repository privacy guard"

# Local API path against a stub server (the real app is not required).
task_audio_dir="$task_test_dir/audio"
mkdir -p "$task_audio_dir"
for task_ref in Evaluation/References/synthetic/*.json; do
    : > "$task_audio_dir/$(basename "$task_ref" .json).wav"
done
python3 - "$task_test_dir" <<'PY' &
import http.server, json, os, sys
root = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        stem = os.path.splitext(os.path.basename(body["path"]))[0]
        text = open(os.path.join(root, "text", stem + ".txt")).read().strip()
        out = json.dumps({"text": text, "confidence": 0.9, "sampleCount": 16000, "provider": "stub-model"}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers(); self.wfile.write(out)
    def log_message(self, *a): pass
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
open(os.path.join(root, "port"), "w").write(str(srv.server_port))
srv.serve_forever()
PY
task_server_pid=$!
trap 'kill $task_server_pid 2>/dev/null || true' EXIT
task_wait=0
while [ ! -s "$task_test_dir/port" ] && [ "$task_wait" -lt 50 ]; do sleep 0.1; task_wait=$((task_wait + 1)); done
task_port=$(cat "$task_test_dir/port")
"$task_test_dir/eval_runner" --audio "$task_audio_dir" --out "$task_test_dir/results-api" --api-base "http://127.0.0.1:$task_port" > "$task_test_dir/api.out"
grep -q "stub-model" "$task_test_dir/api.out" || { echo "FAIL: provider identity not recorded from the API"; exit 1; }
grep -q "source: localAPI" "$task_test_dir/api.out" || { echo "FAIL: API run source not recorded"; exit 1; }
echo "PASS: eval runner Local API path (stub server)"

# Phase 3E.2A diagnostic corpus (D01-D10) end-to-end through the offline
# runner, under a perfect-ASR assumption. Checks structural/invariant
# properties only -- NOT the exact current D02/D03 normalization outcome,
# which is an open finding (see Evaluation/DIAGNOSTICS_3E2A.md), not a
# regression requirement: a future fix to that normalization gap must not
# require editing this script.
task_diag_text_dir="$task_test_dir/diag-text"
mkdir -p "$task_diag_text_dir"
for task_ref in Evaluation/References/diagnostics-3e2a/*.json; do
    task_id=$(basename "$task_ref" .json)
    python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['reference'])" "$task_ref" > "$task_diag_text_dir/$task_id.txt"
done
"$task_test_dir/eval_runner" --references Evaluation/References/diagnostics-3e2a --text-dir "$task_diag_text_dir" --out "$task_test_dir/diag-results" > "$task_test_dir/diag.out"
grep -q "samples: 10 (scored: 10)" "$task_test_dir/diag.out" || { echo "FAIL: expected all 10 diagnostic samples to score"; exit 1; }
task_diag_result_dir=$(ls -d "$task_test_dir"/diag-results/*/)
for task_id in D01 D02 D03 D04 D05 D06 D07 D08 D09 D10; do
    test -f "${task_diag_result_dir}${task_id}.result.json" || { echo "FAIL: $task_id produced no result (must remain processable)"; exit 1; }
done
# D01 is the reliable baseline: this IS a regression invariant.
python3 -c "
import json
d = json.load(open('${task_diag_result_dir}D01.result.json'))
n = d['score']['normalization']
assert len(n) == 1 and n[0]['kind'] == 'correctApplication', n
assert n[0]['observedReplacement'] == 'Section 323 IPC', n
" || { echo "FAIL: D01 (reliable digit-by-digit baseline) regressed"; exit 1; }
# D06's formatting score is a harness invariant (text input carries no
# punctuation by construction), independent of any production behavior.
python3 -c "
import json
d = json.load(open('${task_diag_result_dir}D06.result.json'))
f = d['score']['formatting']
assert f['comparable'] and f['punctuationDifferences'] == 3, f
" || { echo "FAIL: D06 offline formatting-harness invariant broke"; exit 1; }
echo "PASS: Phase 3E.2A diagnostic corpus (D01-D10) runs offline and reports individually"

# Phase 3E.2B diagnostic corpus (N01-N12, Y01-Y10, P01-P06) end-to-end through
# the offline runner, under a perfect-ASR assumption. Structural/invariant
# checks only -- NOT N01-N12's exact current normalization outcome, which
# (per case) is an open finding (see Evaluation/DIAGNOSTICS_3E2B.md), not a
# regression requirement in either direction.
task_diag2_text_dir="$task_test_dir/diag2-text"
mkdir -p "$task_diag2_text_dir"
for task_ref in Evaluation/References/diagnostics-3e2b/*.json; do
    task_id=$(basename "$task_ref" .json)
    python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['reference'])" "$task_ref" > "$task_diag2_text_dir/$task_id.txt"
done
"$task_test_dir/eval_runner" --references Evaluation/References/diagnostics-3e2b --text-dir "$task_diag2_text_dir" --out "$task_test_dir/diag2-results" > "$task_test_dir/diag2.out"
grep -q "samples: 28 (scored: 28)" "$task_test_dir/diag2.out" || { echo "FAIL: expected all 28 Phase 3E.2B samples to score"; exit 1; }
task_diag2_result_dir=$(ls -d "$task_test_dir"/diag2-results/*/)
for task_id in N01 N02 N03 N04 N05 N06 N07 N08 N09 N10 N11 N12 Y01 Y02 Y03 Y04 Y05 Y06 Y07 Y08 Y09 Y10 P01 P02 P03 P04 P05 P06; do
    test -f "${task_diag2_result_dir}${task_id}.result.json" || { echo "FAIL: $task_id produced no result (must remain processable)"; exit 1; }
done
# P01's formatting score is a harness invariant (text input carries no
# punctuation by construction; three sentences -> three boundaries differ),
# independent of any production behavior.
python3 -c "
import json
d = json.load(open('${task_diag2_result_dir}P01.result.json'))
f = d['score']['formatting']
assert f['comparable'] and f['punctuationDifferences'] == 3, f
" || { echo "FAIL: P01 offline formatting-harness invariant broke"; exit 1; }
echo "PASS: Phase 3E.2B diagnostic corpus (N/Y/P) runs offline and reports individually"
