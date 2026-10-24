# ui-test-lock.sh: the shared swissarmyhammer UI test lock. A script sources this file.
#
# The swissarmyhammer repositories (Testudo, EditorKit and AgentViewKit) each run UI
# tests that bring an app to the front. Two such runs at one time disturb each other, so
# each run takes one lock that the three repositories share:
#
#   - Path: `$HOME/Library/Caches/swissarmyhammer/ui-tests.lock`.
#   - Content: `<pid> <repo> <UTC ISO8601>`. The pid is the `$$` of the script.
#   - Atomic create: the script writes a draft file, then hard-links it to the lock path
#     with `ln draft lock`, which fails when the lock exists.
#   - Waiting: a waiter tries again each UI_TEST_LOCK_POLL_SECONDS. A lock is stale when
#     `kill -0 <pid>` fails, and a waiter removes a stale lock.
#   - Release: a trap on EXIT, INT and TERM removes the lock, only when this process
#     holds it.
#   - Scope: only a test run takes the lock, never a build.
#
# The code below is the code of Testudo, as testudoapp-2c gave it, so that the three
# repositories agree. Only the names of the two exit statuses are the names of this
# repository. Keep it the same as the code of the other two repositories.
#
# The script that sources this file defines:
#
#   - REPO_ROOT: the root of the repository. Its name goes into the lock.
#   - INTERRUPTED_STATUS: the exit status of the script after SIGINT (130).
#   - TERMINATED_STATUS: the exit status of the script after SIGTERM (143).
#
# `Scripts/test-ui-test-lock.sh` checks this code with a lock in a temporary directory.
#
# Written for the bash 3.2 of macOS.

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
    trap "$release; exit $INTERRUPTED_STATUS" INT
    trap "$release; exit $TERMINATED_STATUS" TERM
}

# Usage, only for test runs:
# acquire_ui_test_lock "$UI_TEST_LOCK" "$UI_TEST_LOCK_POLL_SECONDS" || exit 1
