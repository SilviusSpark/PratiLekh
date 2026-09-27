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
