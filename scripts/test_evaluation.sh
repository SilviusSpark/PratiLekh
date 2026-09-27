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

# Phase 3G.A: --text-dir never invokes a provider, so providerTranscript must
# be absent rather than synthesized from the supplied text.
task_offline_result_dir=$(ls -d "$task_test_dir"/results/*/)
python3 -c "
import json
d = json.load(open('${task_offline_result_dir}syn-stat-001.result.json'))
assert d.get('providerTranscript') is None, d
assert not any(s['stage'] == 'providerTranscript' for s in d['stages']), d['stages']
" || { echo "FAIL: --text-dir must not synthesize a providerTranscript (no provider was invoked)"; exit 1; }
echo "PASS: --text-dir evaluation reports no providerTranscript (no provider invocation)"

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

# Phase 3G.A: a second stub server that also returns providerText, proving
# the API-to-result plumbing preserves it correctly. This does not exercise
# the real ASR pipeline (see ASRService.swift's transcribeSamplesForAPI /
# transcribeFileForAPI for where providerText is actually captured,
# immediately after provider.transcribeFinal/transcribeFile return and
# before filler removal, custom dictionary and spoken-punctuation
# formatting) -- it proves the transport does not lose, corrupt, invent or
# leak that value between samples.
task_audio_dir2="$task_test_dir/audio2"
mkdir -p "$task_audio_dir2"
for task_ref in Evaluation/References/synthetic/*.json; do
    : > "$task_audio_dir2/$(basename "$task_ref" .json).wav"
done
python3 - "$task_test_dir" <<'PY' &
import http.server, json, os, sys
root = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        stem = os.path.splitext(os.path.basename(body["path"]))[0]
        text = open(os.path.join(root, "text", stem + ".txt")).read().strip()
        if stem == "syn-dw-001":
            # Simulates a transcription failure for this one sample only.
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "simulated transcription failure"}).encode())
            return
        payload = {"text": text, "confidence": 0.9, "sampleCount": 16000, "provider": "stub-model-3ga"}
        if stem == "syn-stat-001":
            # Simulates the provider having said a filler word that
            # PratiLekh's deterministic preprocessing later removed --
            # providerText and the post-processed text legitimately differ.
            payload["providerText"] = text.replace("charged under section", "charged under, um, section")
        elif stem == "syn-prose-001":
            # Simulates no deterministic transform having changed anything --
            # providerText and the post-processed text legitimately match.
            payload["providerText"] = text
        # Every other sample (including syn-mixed-001) omits providerText
        # entirely, simulating an API response shape that predates this field.
        out = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(out)
    def log_message(self, *a): pass
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
open(os.path.join(root, "port2"), "w").write(str(srv.server_port))
srv.serve_forever()
PY
task_server2_pid=$!
trap 'kill $task_server_pid 2>/dev/null || true; kill $task_server2_pid 2>/dev/null || true' EXIT
task_wait=0
while [ ! -s "$task_test_dir/port2" ] && [ "$task_wait" -lt 50 ]; do sleep 0.1; task_wait=$((task_wait + 1)); done
task_port2=$(cat "$task_test_dir/port2")
# One sample (syn-dw-001) deliberately fails; the run as a whole therefore
# exits non-zero (see EvalRunner's exit(3) on any per-sample error) -- that
# is expected here, not a test failure.
"$task_test_dir/eval_runner" --audio "$task_audio_dir2" --out "$task_test_dir/results-api-3ga" --api-base "http://127.0.0.1:$task_port2" > "$task_test_dir/api-3ga.out" || true
task_api3ga_result_dir=$(ls -d "$task_test_dir"/results-api-3ga/*/)

python3 -c "
import json
d = json.load(open('${task_api3ga_result_dir}syn-stat-001.result.json'))
post_asr = next(s['text'] for s in d['stages'] if s['stage'] == 'postASRDeterministic')
assert d.get('providerTranscript') is not None, d
assert d['providerTranscript'] != post_asr, 'providerTranscript must differ from postASRDeterministic when the API reports a difference'
assert 'um' in d['providerTranscript'] and 'um' not in post_asr
" || { echo "FAIL: providerTranscript did not carry a distinct pre-transform value (syn-stat-001)"; exit 1; }
echo "PASS: providerTranscript differs from postASRDeterministic when the provider and post-processed text differ"

python3 -c "
import json
d = json.load(open('${task_api3ga_result_dir}syn-prose-001.result.json'))
post_asr = next(s['text'] for s in d['stages'] if s['stage'] == 'postASRDeterministic')
assert d.get('providerTranscript') is not None, d
assert d['providerTranscript'] == post_asr, 'providerTranscript may legitimately equal postASRDeterministic when nothing changed it'
" || { echo "FAIL: providerTranscript equality case failed (syn-prose-001)"; exit 1; }
echo "PASS: providerTranscript legitimately equals postASRDeterministic when no transform applied"

python3 -c "
import json
d = json.load(open('${task_api3ga_result_dir}syn-mixed-001.result.json'))
assert d.get('providerTranscript') is None, d
assert d.get('error') is None, d
" || { echo "FAIL: an API response omitting providerText must decode as an absent value, not an error (syn-mixed-001)"; exit 1; }
echo "PASS: an API response shape that predates providerText still decodes (additive/backward-compatible)"

python3 -c "
import json
d = json.load(open('${task_api3ga_result_dir}syn-dw-001.result.json'))
assert d.get('providerTranscript') is None, d
assert d.get('error') is not None, 'a failed transcription request must be reported as an error, not a stale result'
" || { echo "FAIL: a failed transcription request leaked or fabricated a providerTranscript (syn-dw-001)"; exit 1; }
echo "PASS: a failed transcription request reports no providerTranscript (no stale/leaked value)"

# syn-stat-001 is evaluated after syn-dw-001's simulated failure (sorted
# reference order); its correct, distinct providerText above already proves
# the failure did not leak into or overwrite a later sample's value.
echo "PASS: a sample evaluated after a failed request is unaffected (no cross-sample leakage)"

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
