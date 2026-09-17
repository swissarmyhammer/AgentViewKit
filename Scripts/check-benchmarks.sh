#!/usr/bin/env bash
#
# The benchmark gate of plan.md §8 (research R1 and R4).
#
# The script runs each scenario of the `Benchmarks/` package, and compares
# the run with the committed baseline `main`. Each benchmark declares its
# relative thresholds in `Benchmarks/.../BenchmarkPolicy.swift`.
#
# The script fails when:
#
#   * a metric is WORSE than the baseline by more than its threshold, or
#   * a scenario stops with an error. The scenarios check their own gates
#     (the p90 chunk cost, the settled paragraphs, the items observer) and
#     stop with an error when a gate fails. The benchmark tool can then
#     exit with status 0, so the script also reads the report.
#
# A metric that is BETTER than the baseline passes with a warning: record
# the baseline again (Benchmarks/README.md).
#
# The scenarios mount SwiftUI views in an off-screen window. The window
# server is not available in the plugin sandbox, so the script runs the
# plugin with `--disable-sandbox`.
#
# Written for the bash 3.2 of macOS.
#
# Usage: Scripts/check-benchmarks.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly BENCHMARK_PACKAGE="$REPO_ROOT/Benchmarks"
# The committed baseline that each check compares with.
readonly BASELINE="main"
readonly REPORT="$REPO_ROOT/.build/benchmark-check.log"
# The report lines of a scenario that stopped with an error.
readonly RUNTIME_FAILURE_PATTERN="failed during runtime|failed with|teardown failed|benchmarkCrashed"

main() {
    mkdir -p "$(dirname "$REPORT")"

    local status=0
    swift package --package-path "$BENCHMARK_PACKAGE" --disable-sandbox \
        benchmark baseline check "$BASELINE" \
        --no-progress \
        > "$REPORT" 2>&1 || status=$?

    if grep -Eq "$RUNTIME_FAILURE_PATTERN" "$REPORT"; then
        cat "$REPORT"
        echo
        echo "Benchmark gate FAILED: a scenario stopped with an error."
        echo "The report above names the scenario and the gate."
        return 1
    fi

    if [ "$status" -eq 0 ]; then
        echo "Benchmark gate passed: each scenario is in the '$BASELINE' baseline thresholds."
        return 0
    fi

    cat "$REPORT"
    echo

    if grep -q "is BETTER than" "$REPORT" && ! grep -q "is WORSE than" "$REPORT"; then
        echo "Benchmark gate passed with a WARNING: a metric is better than its threshold."
        echo "Record the baseline again (Benchmarks/README.md has the two commands)."
        return 0
    fi

    echo "Benchmark gate FAILED: a metric is worse than its threshold."
    echo "The table above names the benchmark, the metric, and the percentile."
    echo "If the change is intentional, record the baseline again in the same"
    echo "change and tell why (Benchmarks/README.md)."
    return 1
}

main "$@"
