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
- actor: claude-code
  id: 01m5nmtbrd0jfrg4jc3nfnbz30
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (355df3e) — 1 finding (1 confirmed, 1 refuted): Scripts/test-ui-test-lock.sh:141 `test-integrity/no-test-cheating`. Not in Scripts/ui-test-lock.sh, so not a cross-repo contract issue.
    - next: implement the fix in Scripts/test-ui-test-lock.sh (`expect_silence` must tell a read timeout apart from EOF), then re-review.
  timestamp: 2026-10-24T00:26:22.861970+00:00
- actor: claude-code
  id: 01m5nmtwc7dreebkm6vz5k18vz
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — Scripts/ui-test-lock.sh (Testudo's snippet), Scripts/test-ui-test-lock.sh (23 checks), UITestLockTests, ScriptRun.swift; 7 files
    - test: green — swift test, 1766 tests in 216 suites passed, 0 failed, 0 skipped, at EditorKit 3bc9d3e; test-ui-test-lock.sh 23 ok
    - commit: 355df3e (+ 4e6a4d2, a kanban chore)
    - review: findings — Scripts/test-ui-test-lock.sh:141 (test-integrity/no-test-cheating)
  timestamp: 2026-10-24T00:26:39.879475+00:00
- actor: claude-code
  id: 01m5nnb07fn124dk8p47t82d1c
  text: |-
    Fix for the review finding Scripts/test-ui-test-lock.sh:141 (test-integrity/no-test-cheating). Only Scripts/test-ui-test-lock.sh changed; Scripts/ui-test-lock.sh (Testudo's snippet) is unchanged.

    Discovery that changes the suggested fix: on the bash 3.2.57 of macOS (/bin/bash, which `bash` and the Swift test both run), `read -t` returns 1 for a time limit AND for EOF. Measured on a FIFO: timeout=1, eof=1. The "> 128" status only exists in bash 4+. So "only status > 128 is silence" would fail every run here. What the fix does instead:
    - `read_timed_out`: status > 128 counts as a timeout (bash 4+). Status 1 counts as a timeout only when the read took the whole window, measured in ms with perl Time::HiRes (bash 3.2 has no sub-second clock). A status-1 read that returns early is EOF and fails the check ("the output of the holder ended after N ms").
    - After a timeout, `kill -0` (is_running) checks that the waiter process still runs at the end of the window. Measured: bash reaps an ended background holder, so kill -0 fails for a dead one.

    Whole-script audit for the same cause (a read or wait whose failure counts as success):
    - `expect_lock_content` read the lock with `cat ... || true`. When the lock was missing and the expected content was empty, the check passed. It now fails when it can't read the lock ("no lock to read").
    - `first_content` in check_held_lock_blocks came from `cat ... || true`, so it was empty when the lock was missing, and that made "the lock keeps the content of its holder" vacuous. Added the check "the lock names the holder that took it", which matches `<first_pid> *`.
    - Others reviewed and left as they are: expect_line already fails on read failure; stop_holder's `wait || status=$?` compares the status to 143/130, so 127 cannot pass; `wait "$dead_pid"`, `content="$(cat ...)"` and the `kill` in stop_holder abort under set -e.

    Mutation proof (scratch copies under the session scratchpad; real files untouched):
    - A: the waiter is SIGKILLed after 0.5 s and its FIFO closes. Before the fix: "ok: a waiter stays blocked...". After: "not ok: ... (the output of the holder ended after 665 ms)".
    - B: the waiter is SIGKILLed after 0.5 s, but an orphan `sleep 5` keeps the FIFO open, so the read times out. Before: ok. After: "not ok: ... (the holder 23913 runs at the end of 2 seconds)". This proves the kill -0 branch.
    - C: create_ui_test_lock reports success but leaves no lock file. Before: "ok: the lock keeps the content of its holder". After: "not ok: the lock names the holder that took it (the lock: )" and "not ok: the lock keeps the content of its holder (no lock to read)".
  timestamp: 2026-10-24T00:35:28.111255+00:00
- actor: claude-code
  id: 01m5nnb3ke6m2ysck5n2p41smw
  text: |-
    ### implement — changed
    - evidence: 1 file: Scripts/test-ui-test-lock.sh (+68/-9). `bash Scripts/test-ui-test-lock.sh`: 24 ok, PASS, exit 0. `swift test`: 1766 tests in 216 suites passed with 7 known issues (the existing withKnownIssue ones), UITestLockTests passed. EditorKit resolved at 3bc9d3e688bd384673b8e804e2851249558e5bb8. The build prints a SwiftPM warning, "missing creator for mutated node" (mlx-swift_Cmlx.bundle); it was already in earlier logs and is not from this change. Mutations A, B and C now fail the checks they target. Not committed. The finding is checked off and the card stays in doing.
    - next: /review
  timestamp: 2026-10-24T00:35:31.566337+00:00
- actor: claude-code
  id: 01m5nnjqgzx8ftjqje5ck9x4fa
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (bb6c659) — 0 findings (findings 0, confirmed 0, refuted 0; 6 validator attempts, 0 failed); 1 file reviewed, 2 .kanban/ files excluded by .reviewignore; the one prior item in `## Review Findings (2026-10-23 19:24)` is checked
    - next: none — task moved to done
  timestamp: 2026-10-24T00:39:41.343880+00:00
- actor: claude-code
  id: 01m5nnk75h4baftnsk76zawerw
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — expect_silence tells a timeout from EOF (bash 3.2 elapsed-window rule) and checks the waiter with kill -0; lock-content checks fail on a missing lock; 1 file
    - test: green — swift test, 1766 tests in 216 suites passed, 0 failed, 0 skipped; test-ui-test-lock.sh 24 ok
    - commit: bb6c659
    - review: clean — 0 findings; task in done
    - Not pushed. Code commits: 355df3e, bb6c659.
  timestamp: 2026-10-24T00:39:57.361903+00:00
position_column: done
position_ordinal: ffffd080
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

## Review Findings (2026-10-23 19:24)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 6 file(s) reviewed, 3 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `README.md` — no validator matches this file

- [x] `Scripts/test-ui-test-lock.sh:141` `test-integrity/no-test-cheating` — `expect_silence` reports the check as passing whenever `read` fails, but `read` also fails on EOF. If the waiter exits early (for example, it crashes or its pipe closes), the check `a waiter stays blocked while a live process holds the lock` still passes, so it cannot tell a blocked waiter from a dead one. The check is vacuous in that case. Distinguish a timeout from EOF. Read with `-t` and treat only the timeout case (status > 128 in bash) as silence. Treat EOF as a failure, for example by checking that the holder process is still running with `kill -0` before the read, or by failing when `read` returns 1.
  - Cross-repo note: this finding is in AVK's own test script `Scripts/test-ui-test-lock.sh`, not in the verbatim Testudo snippet `Scripts/ui-test-lock.sh`. Fixing it does not change the shared lock logic, so it is not a cross-repo contract issue.
