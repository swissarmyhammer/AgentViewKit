---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5n67c4ted4z8axjn8qpqcrc
  text: |-
    Testudo's lock snippet, verbatim from testudoapp-2c (2026-10-23). It's local in Testudo and not pushed yet; testudoapp-2c will say when it is. bash 3.2-safe. `$REPO_ROOT` is the repo root, INT_STATUS=130, TERM_STATUS=143. The holder is the script's `$$`. Match this so the three repos agree.

    ```bash
    readonly UI_TEST_LOCK="$HOME/Library/Caches/swissarmyhammer/ui-tests.lock"
    readonly UI_TEST_LOCK_POLL_SECONDS=5

    ui_test_lock_content() {
        printf '%s %s %s\n' "$$" "$(basename "$REPO_ROOT")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }

    # Atomic: write a draft, hard-link it to the lock path (fails if the lock exists).
    # 0 = holds the lock, 1 = lock exists, 2 = draft could not be written.
    create_ui_test_lock() {
        local lock="$1" draft="$1.$$" status=0
        if ! ui_test_lock_content > "$draft"; then
            echo "error: cannot write $draft" >&2
            return 2
        fi
        ln "$draft" "$lock" 2>/dev/null || status=1
        rm -f "$draft"
        return "$status"
    }

    # Remove the lock only if its content is still $2 (a racing waiter may have retaken it).
    remove_ui_test_lock_held_by() {
        local lock="$1" holder="$2"
        if [ "$(cat "$lock" 2>/dev/null || true)" = "$holder" ]; then
            rm -f "$lock"
        fi
    }

    release_ui_test_lock() {
        local lock="$1" holder
        holder="$(cat "$lock" 2>/dev/null || true)"
        if [ "${holder%% *}" = "$$" ]; then
            rm -f "$lock"
        fi
    }

    acquire_ui_test_lock() {
        local lock="$1" poll_seconds="$2" status holder last_holder=""
        mkdir -p "$(dirname "$lock")"
        while true; do
            status=0
            create_ui_test_lock "$lock" || status=$?
            if [ "$status" -ne 1 ]; then
                break
            fi
            holder="$(cat "$lock" 2>/dev/null || true)"
            if [ -n "$holder" ] && ! kill -0 "${holder%% *}" 2>/dev/null; then
                echo "==> Removing the stale UI test lock $lock, held by: $holder"
                remove_ui_test_lock_held_by "$lock" "$holder"
            elif [ -e "$lock" ]; then
                if [ "$holder" != "$last_holder" ]; then
                    echo "==> Waiting for the UI test lock $lock, held by: $holder"
                    last_holder="$holder"
                fi
                sleep "$poll_seconds"
            fi
        done
        if [ "$status" -ne 0 ]; then
            return 1
        fi
        local release
        release="release_ui_test_lock $(printf '%q' "$lock")"
        trap "$release" EXIT
        trap "$release; exit $INT_STATUS" INT
        trap "$release; exit $TERM_STATUS" TERM
    }

    # Usage, only for test runs:
    # acquire_ui_test_lock "$UI_TEST_LOCK" "$UI_TEST_LOCK_POLL_SECONDS" || exit 1
    ```
  timestamp: 2026-10-23T20:11:20.602340+00:00
- actor: claude-code
  id: 01m5nkw3hkzat0phhdj1t49vzm
  text: |-
    Research (implement):
    - EditorKit pin: per coordinator, ran `swift package update EditorKit` (it resolved main tip 706794f, a kanban-only commit on top of 3bc9d3e), then set Package.resolved and the demo's gitignored xcshareddata/swiftpm/Package.resolved to 3bc9d3e688bd384673b8e804e2851249558e5bb8 by hand; `swift package resolve` checks out 3bc9d3e. Both files are gitignored. No scratch-clone override is used.
    - test-examples.sh runs build and test as separate xcodebuild steps in run_example, so the lock wraps only the `test` step.
    - Trap interaction: run_with_limit sets its own `trap ... INT TERM HUP` and then `trap - INT TERM HUP`. That overwrites the lock's INT/TERM traps while the test step runs. Its INT/TERM/HUP handler calls `exit 130`, which still fires the lock's EXIT trap, so an interrupt releases the lock. The lock is released explicitly right after the step, so the reset does not leave the lock held.
    - Where script checks run: no CI step runs scripts directly. `swift test` (the shared swift-ci workflow) runs Tests/PackageStructureTests/ExampleGateTimeLimitTests, which runs `Scripts/test-examples.sh --self-test` through /bin/bash. The new lock check is wired the same way.
    - Plan: the snippet goes verbatim into a sourced `Scripts/ui-test-lock.sh`, so the real code is what gets tested. INT_STATUS maps to the script's INTERRUPTED_STATUS (130). TERM_STATUS maps to a new TERMINATED_STATUS (143). `Scripts/test-ui-test-lock.sh` uses a mktemp lock path.
  timestamp: 2026-10-24T00:09:51.411845+00:00
- actor: claude-code
  id: 01m5nmgb49bq6j6jtth0r01pqq
  text: |-
    Implementation landed (not committed; the card stays in doing).
    - `Scripts/ui-test-lock.sh` (new, sourced): Testudo's snippet verbatim. Only `$INT_STATUS` became `$INTERRUPTED_STATUS` (130, already in test-examples.sh) and `$TERM_STATUS` became `$TERMINATED_STATUS` (143, new). A header records the contract and what the sourcing script defines (REPO_ROOT, the two statuses).
    - `Scripts/test-examples.sh`: sources the lib. A new `run_ui_tests` takes the lock around the `xcodebuild ... test` step only; generate and build stay outside it. It releases the lock right after the step. Why the explicit release: `run_with_limit` overwrites the lock's INT/TERM traps with its own (which `exit 130`, so the EXIT trap still releases) and then runs `trap - INT TERM HUP`.
    - `Scripts/test-ui-test-lock.sh` (new): uses a mktemp lock path and refuses the real `$UI_TEST_LOCK`. Holders are the script itself in `--hold` mode. Each writes to a FIFO that the check reads with `read -t` (30 s limit per event, waiter poll 0.2 s). 23 checks: a live holder blocks a waiter (the waiter names the holder and stays silent for 2 s); the waiter takes the lock when the holder gets SIGTERM; SIGINT releases the lock (exit 130); SIGTERM gives exit 143; a stale lock (dead pid) is named, removed and taken over; release / remove_held_by keep a foreign lock; create returns 0, 1 or 2 and never leaves a `<lock>.<pid>` draft.
    - Gotcha: a bash background job starts with SIGINT ignored, and a non-interactive shell cannot trap a signal ignored at entry. So the check starts each holder through `perl -e '$SIG{INT}="DEFAULT"; exec @ARGV'` (verified on bash 3.2.57).
    - Mutation check: making release_ui_test_lock remove the lock unconditionally fails 2 checks, so the check can fail.
    - Wiring: `Tests/PackageStructureTests/UITestLockTests.swift` runs the check (via `swift test`, the shared swift-ci job). The bash runner moved out of ExampleGateTimeLimitTests into a shared `Tests/PackageStructureTests/ScriptRun.swift` so the two suites don't copy it.
    - README: one paragraph on the lock in the demo UI test section.
  timestamp: 2026-10-24T00:20:54.537321+00:00
- actor: claude-code
  id: 01m5nmgexaewbq4trre1e8zcfs
  text: |-
    ### implement — changed
    - evidence: 7 files: Scripts/ui-test-lock.sh (new), Scripts/test-ui-test-lock.sh (new), Scripts/test-examples.sh, Tests/PackageStructureTests/ScriptRun.swift (new), Tests/PackageStructureTests/UITestLockTests.swift (new), Tests/PackageStructureTests/ExampleGateTimeLimitTests.swift, README.md. `bash Scripts/test-ui-test-lock.sh`: 23 ok, PASS. `Scripts/test-examples.sh --self-test`: PASS. `swift test`: 1766 tests in 216 suites passed (7 known issues, all pre-existing withKnownIssue). `Scripts/test-examples.sh AgentViewKitDemo` on the real lock: BUILD SUCCEEDED, 5 UI tests with 0 failures, gate passed, lock released. EditorKit resolved at 3bc9d3e688bd384673b8e804e2851249558e5bb8 (Package.resolved and the demo's resolved file); no scratch-clone override.
    - next: /review
  timestamp: 2026-10-24T00:20:58.410999+00:00
position_column: doing
position_ordinal: '8380'
title: Scripts/test-examples.sh takes the shared swissarmyhammer UI-test lock
---
Requested by testudoapp-2c (2026-10-23). During Testudo's UI run, an AgentViewKitDemo window came up over Testudo mid-suite and caused 3 XCTest warnings there. Testudo's `Scripts/xcodebuild-app.sh` and EditorKit already take the shared lock. AVK's UI-test runner has to take it too.

## The contract (testudoapp-2c)
- Path: `$HOME/Library/Caches/swissarmyhammer/ui-tests.lock`.
- Content: `<pid> <repo> <UTC ISO8601>`.
- Atomic create: write a draft file, then hard-link it into place with `ln draft lock`, which fails if the lock exists.
- Waiting: a waiter polls every 5 s. A lock is stale if `kill -0 <pid>` fails, and a stale lock can be removed.
- Release: a trap on EXIT, INT and TERM removes the lock, only if this process holds it.
- Scope: only test runs take it, not builds.

## What to do
- [x] `Scripts/test-examples.sh` takes the lock around the xcodebuild UI-test step only, with the build outside the lock if the script separates the two. Print a line while it waits, naming the holder.
- [x] Release on EXIT, INT and TERM, only when this process holds the lock.
- [x] Match Testudo's implementation, so the three repos agree. Ask testudoapp-2c for the snippet, or read it from their script once it's pushed.
- [x] A shell check of the lock logic: a held lock blocks, a stale lock (dead pid) is taken over, release removes only our own lock. A small script test under Scripts/ or Tests/ that CI can run.

Acceptance: a run while another holder has the lock waits, then runs; a run with a stale lock proceeds; Ctrl-C releases the lock; `Scripts/test-examples.sh` still passes. #avk-8 #testudo-request #cross-repo