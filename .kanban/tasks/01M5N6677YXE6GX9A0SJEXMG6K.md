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
position_column: todo
position_ordinal: b180
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
- [ ] `Scripts/test-examples.sh` takes the lock around the xcodebuild UI-test step only, with the build outside the lock if the script separates the two. Print a line while it waits, naming the holder.
- [ ] Release on EXIT, INT and TERM, only when this process holds the lock.
- [ ] Match Testudo's implementation, so the three repos agree. Ask testudoapp-2c for the snippet, or read it from their script once it's pushed.
- [ ] A shell check of the lock logic: a held lock blocks, a stale lock (dead pid) is taken over, release removes only our own lock. A small script test under Scripts/ or Tests/ that CI can run.

Acceptance: a run while another holder has the lock waits, then runs; a run with a stale lock proceeds; Ctrl-C releases the lock; `Scripts/test-examples.sh` still passes. #avk-8 #testudo-request #cross-repo