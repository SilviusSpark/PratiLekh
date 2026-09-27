#!/bin/sh
# Builds and runs the judicial dictation evaluation runner. See Evaluation/README.md.
#   scripts/eval_run.sh --out DIR (--audio DIR | --text-dir DIR) [--references DIR] [--api-base URL]
# Private audio, text and results must live outside the repository (enforced by the runner).
set -eu
cd "$(dirname "$0")/.."
task_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
test -d "$task_developer_dir/Platforms/MacOSX.platform"
export DEVELOPER_DIR="$task_developer_dir"
task_build_dir=$(mktemp -d /tmp/pratilekh-eval-run.XXXXXX)
trap 'rm -rf "$task_build_dir"' EXIT
task_eval_sources=$(ls Evaluation/Sources/*.swift)
task_legal_sources=$(find Sources/Fluid/LegalLanguage -name '*.swift' | sort)
# shellcheck disable=SC2086
xcrun swiftc -parse-as-library $task_legal_sources $task_eval_sources Evaluation/Runner/EvalRunner.swift -o "$task_build_dir/eval_runner"
"$task_build_dir/eval_runner" "$@"
