#!/usr/bin/env bash
#
# test-ui-test-lock.sh: the check of the shared swissarmyhammer UI test lock in
# `Scripts/ui-test-lock.sh`.
#
# The check takes a lock in a temporary directory, never the real lock
# `$UI_TEST_LOCK`, so it cannot change a UI test run of another repository. It checks:
#
#   - a lock that a live process holds blocks a waiter, and the waiter names the holder,
#   - the waiter takes the lock when the holder ends,
#   - SIGTERM and SIGINT release the lock that the process holds,
#   - a stale lock (its process is dead) is removed and taken over,
#   - a release removes only the lock of this process,
#   - no draft file stays beside the lock.
#
# A holder is this script in its `--hold` mode, in a process of its own. Each holder
# writes its lines to a FIFO, and the check reads each line as an event, with a time
# limit, so a broken lock fails the check and does not hang it.
#
# Written for the bash 3.2 of macOS.
#
# Usage: Scripts/test-ui-test-lock.sh
#
# Usage: Scripts/test-ui-test-lock.sh --hold <lock>
#   Takes the lock, writes "held: <content of the lock>", and runs until a signal
#   stops it. Only the check starts this mode.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT

# This script, which the check runs again in its `--hold` mode.
readonly SELF="$REPO_ROOT/Scripts/test-ui-test-lock.sh"

# The exit status of a holder that SIGINT stopped, and of one that SIGTERM stopped.
# The lock code reads both names.
readonly INTERRUPTED_STATUS=130
readonly TERMINATED_STATUS=143

# shellcheck source=Scripts/ui-test-lock.sh
. "$REPO_ROOT/Scripts/ui-test-lock.sh"

# The time between two tries of a waiter, in seconds. It is short, so the check is fast.
readonly TEST_POLL_SECONDS=0.2

# The time limit of one event that must come, in seconds.
readonly EVENT_TIMEOUT_SECONDS=30

# The time that a blocked waiter must stay silent, in seconds: many tries of the waiter.
readonly BLOCKED_SECONDS=2

# A `read` whose `-t` time limit ends exits with 128 plus the number of the signal in
# bash 4 and later, so a status above this floor is a time limit.
readonly READ_TIMEOUT_STATUS_FLOOR=128

# The exit status of a `read` that reached the end of its input. The bash 3.2 of macOS
# gives this status also when the `-t` time limit ends, so only the time that the `read`
# took tells the two apart there.
readonly READ_END_OF_INPUT_STATUS=1

# The number of milliseconds in one second.
readonly MILLISECONDS_PER_SECOND=1000

# The temporary directory of the check, and the ids of the holders that it started.
# The EXIT trap reads them, so they are not local.
work=""
holder_pids=""

# The number of the checks that failed.
failures=0

# Writes the result line of one check, and counts a failure.
#
# Arguments: the name of the check, then the command that decides it (for example a
# `[` test). The check passes when the command succeeds.
check() {
    local name="$1"
    shift
    if "$@"; then
        echo "ok: $name"
        return 0
    fi
    echo "not ok: $name"
    failures=$((failures + 1))
}

# Takes the lock, writes its content, then runs until a signal stops the process. The
# EXIT, INT and TERM traps of the lock code release the lock.
#
# Arguments: the lock path.
hold_lock() {
    acquire_ui_test_lock "$1" "$TEST_POLL_SECONDS" || exit 1
    echo "held: $(cat "$1")"
    while true; do
        sleep "$TEST_POLL_SECONDS"
    done
}

# Starts a holder in the background. A background job of bash ignores SIGINT, and a
# shell cannot trap a signal that it ignored at its start, so `perl` (which ships with
# macOS) gives SIGINT its default action again before it runs the holder. The caller
# reads the process id from `$!`.
#
# Arguments: the lock path, then the FIFO that the holder writes its lines to.
start_holder() {
    perl -e '$SIG{INT} = "DEFAULT"; exec @ARGV or die "exec failed: $!\n"' \
        /bin/bash "$SELF" --hold "$1" >"$2" 2>&1 &
}

# Makes a FIFO in the work directory and writes its path.
#
# Arguments: the name of the FIFO.
make_fifo() {
    local fifo="$work/$1.fifo"
    mkfifo "$fifo"
    echo "$fifo"
}

# Reads the next line of a holder, and checks it against a pattern.
#
# Arguments: the file descriptor of the FIFO of the holder, the pattern (a `case`
# pattern), then the name of the check.
expect_line() {
    local fd="$1" pattern="$2" name="$3" line=""
    if ! IFS= read -r -t "$EVENT_TIMEOUT_SECONDS" -u "$fd" line; then
        check "$name (no line in $EVENT_TIMEOUT_SECONDS seconds)" false
        return 0
    fi
    check "$name (the line: $line)" line_matches "$line" "$pattern"
}

# Tells whether a line matches a `case` pattern.
#
# Arguments: the line, then the pattern.
line_matches() {
    # The pattern is a `case` pattern, so it stays unquoted.
    # shellcheck disable=SC2254
    case "$1" in
        $2) return 0 ;;
        *) return 1 ;;
    esac
}

# Writes the time of the clock in milliseconds. The bash 3.2 of macOS has no clock finer
# than a second, so `perl` (which ships with macOS) reads it.
now_milliseconds() {
    perl -MTime::HiRes=time -e "printf \"%d\\n\", time() * $MILLISECONDS_PER_SECOND"
}

# Tells whether a `read` with a `-t` time limit ended at its time limit, and not at the
# end of its input. The end of the input means that every writer of the FIFO closed it,
# for example because the holder ended.
#
# Arguments: the exit status of the `read`, the milliseconds that it took, then its time
# limit in seconds.
read_timed_out() {
    if [ "$1" -gt "$READ_TIMEOUT_STATUS_FLOOR" ]; then
        return 0
    fi
    # The bash 3.2 of macOS: a time limit and the end of the input give the same status,
    # and only a time limit makes the `read` take the whole limit.
    [ "$1" -eq "$READ_END_OF_INPUT_STATUS" ] &&
        [ "$2" -ge $(($3 * MILLISECONDS_PER_SECOND)) ]
}

# Tells whether a process runs. The check shell reaps each holder that ends, so an ended
# holder has no process id.
#
# Arguments: the process id.
is_running() {
    kill -0 "$1" 2>/dev/null
}

# Checks that a holder writes no line for BLOCKED_SECONDS, and still runs at the end of
# that time. The `read` must end at its time limit: when it ends at the end of the input,
# the holder closed its FIFO, so it ended and was not blocked.
#
# Arguments: the file descriptor of the FIFO of the holder, the process id of the holder,
# then the name of the check.
expect_silence() {
    local fd="$1" pid="$2" name="$3" line="" status=0 started elapsed
    started="$(now_milliseconds)"
    IFS= read -r -t "$BLOCKED_SECONDS" -u "$fd" line || status=$?
    elapsed=$(($(now_milliseconds) - started))
    if [ "$status" -eq 0 ]; then
        check "$name (the line: $line)" false
    elif ! read_timed_out "$status" "$elapsed" "$BLOCKED_SECONDS"; then
        check "$name (the output of the holder ended after $elapsed ms)" false
    else
        check "$name (the holder $pid runs at the end of $BLOCKED_SECONDS seconds)" \
            is_running "$pid"
    fi
}

# Sends a signal to a holder, waits for its end, and checks its exit status.
#
# Arguments: the signal, the process id, the exit status that the check expects, then
# the name of the check.
stop_holder() {
    local status=0
    kill "-$1" "$2"
    wait "$2" || status=$?
    check "$4 (exit status $status)" [ "$status" -eq "$3" ]
}

# Checks that the lock file is absent.
#
# Arguments: the lock path, then the name of the check.
expect_no_lock() {
    check "$2" [ ! -e "$1" ]
}

# Checks that the lock holds a content. A lock that the check cannot read fails the check,
# also when the content that the check expects is empty.
#
# Arguments: the lock path, the content, then the name of the check.
expect_lock_content() {
    local content
    if ! content="$(cat "$1" 2>/dev/null)"; then
        check "$3 (no lock to read)" false
        return 0
    fi
    check "$3" [ "$content" = "$2" ]
}

# Writes a lock content for a process id, in the format of the lock code.
#
# Arguments: the process id.
lock_content_of() {
    printf '%s %s %s\n' "$1" "other-repository" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

# A holder takes a free lock. A second holder waits, names the first, and stays blocked
# while the first holds the lock. SIGTERM releases the lock of the first, and the second
# takes it. SIGINT then releases the lock of the second.
#
# Arguments: the lock path.
check_held_lock_blocks() {
    local first_fifo second_fifo first_pid second_pid first_content
    first_fifo="$(make_fifo first)"
    second_fifo="$(make_fifo second)"

    start_holder "$1" "$first_fifo"
    first_pid=$!
    holder_pids="$holder_pids $first_pid"
    exec 3<"$first_fifo"
    expect_line 3 "held: $first_pid *" "a holder takes a free lock"
    first_content="$(cat "$1" 2>/dev/null || true)"
    check "the lock names the holder that took it (the lock: $first_content)" \
        line_matches "$first_content" "$first_pid *"

    start_holder "$1" "$second_fifo"
    second_pid=$!
    holder_pids="$holder_pids $second_pid"
    exec 4<"$second_fifo"
    expect_line 4 "==> Waiting for the UI test lock $1, held by: $first_content" \
        "a waiter names the holder of the lock"
    expect_silence 4 "$second_pid" "a waiter stays blocked while a live process holds the lock"
    expect_lock_content "$1" "$first_content" "the lock keeps the content of its holder"

    stop_holder TERM "$first_pid" "$TERMINATED_STATUS" "SIGTERM stops the holder"
    expect_line 4 "held: $second_pid *" "the waiter takes the lock when the holder ends"

    stop_holder INT "$second_pid" "$INTERRUPTED_STATUS" "SIGINT stops the holder"
    expect_no_lock "$1" "SIGINT releases the lock"
    exec 3<&- 4<&-
}

# A lock whose process is dead is stale. A holder removes it, names it, and takes the
# lock. SIGTERM then releases the lock.
#
# Arguments: the lock path.
check_stale_lock_is_taken_over() {
    local fifo dead_pid stale_content holder_pid
    fifo="$(make_fifo stale)"
    sleep 0 &
    dead_pid=$!
    wait "$dead_pid"
    stale_content="$(lock_content_of "$dead_pid")"
    echo "$stale_content" >"$1"

    start_holder "$1" "$fifo"
    holder_pid=$!
    holder_pids="$holder_pids $holder_pid"
    exec 5<"$fifo"
    expect_line 5 "==> Removing the stale UI test lock $1, held by: $stale_content" \
        "a holder names the stale lock that it removes"
    expect_line 5 "held: $holder_pid *" "a holder takes a stale lock over"

    stop_holder TERM "$holder_pid" "$TERMINATED_STATUS" "SIGTERM stops the holder"
    expect_no_lock "$1" "SIGTERM releases the lock"
    exec 5<&-
}

# A release removes the lock of this process, and never the lock of another process.
#
# Arguments: the lock path.
check_release_removes_only_our_own_lock() {
    local other_content our_content
    other_content="$(lock_content_of "$PPID")"
    echo "$other_content" >"$1"
    release_ui_test_lock "$1"
    expect_lock_content "$1" "$other_content" "a release keeps the lock of another process"

    remove_ui_test_lock_held_by "$1" "$(lock_content_of "$$")"
    expect_lock_content "$1" "$other_content" \
        "a stale removal keeps a lock whose content changed"

    our_content="$(lock_content_of "$$")"
    echo "$our_content" >"$1"
    release_ui_test_lock "$1"
    expect_no_lock "$1" "a release removes the lock of this process"
}

# Tells whether no draft file stands beside a lock path. A draft is `<lock>.<pid>`.
#
# Arguments: the lock path.
has_no_draft() {
    local draft
    for draft in "$1".*; do
        # With no match, the pattern stays as it is, and names no file.
        [ ! -e "$draft" ] || return 1
    done
}

# Checks that no draft file stands beside a lock path.
#
# Arguments: the lock path, then the name of the check.
expect_no_draft() {
    check "$2" has_no_draft "$1"
}

# The atomic create: each result of `create_ui_test_lock` leaves no draft file.
#
# Arguments: the lock path.
check_no_draft_is_left() {
    local status=0 content
    create_ui_test_lock "$1" || status=$?
    check "a create takes a free lock (status $status)" [ "$status" -eq 0 ]
    expect_no_draft "$1" "a create that takes the lock leaves no draft"
    content="$(cat "$1")"

    status=0
    create_ui_test_lock "$1" || status=$?
    check "a create finds a lock that exists (status $status)" [ "$status" -eq 1 ]
    expect_lock_content "$1" "$content" "a create keeps a lock that exists"
    expect_no_draft "$1" "a create that finds a lock leaves no draft"
    rm -f "$1"

    status=0
    create_ui_test_lock "$work/missing/ui-tests.lock" 2>/dev/null || status=$?
    check "a create with no writable draft fails (status $status)" [ "$status" -eq 2 ]
    expect_no_draft "$work/missing/ui-tests.lock" "a create with no draft leaves no draft"
}

# Stops each holder that the check started, and removes the work directory. The check
# runs it at exit, also when a check fails or the script gets a signal.
clean_up() {
    # The ids are numbers, so the word splitting gives one argument each.
    # shellcheck disable=SC2086
    [ -z "$holder_pids" ] || kill -KILL $holder_pids 2>/dev/null || true
    [ -z "$work" ] || rm -rf "$work"
}

main() {
    if [ "${1:-}" = "--hold" ]; then
        hold_lock "$2"
        return
    fi

    trap clean_up EXIT
    work="$(mktemp -d)"
    local lock="$work/swissarmyhammer/ui-tests.lock"
    if [ "$lock" = "$UI_TEST_LOCK" ]; then
        echo "error: the check must not take the real lock $UI_TEST_LOCK" >&2
        return 1
    fi

    check_held_lock_blocks "$lock"
    check_stale_lock_is_taken_over "$lock"
    check_release_removes_only_our_own_lock "$lock"
    check_no_draft_is_left "$lock"
    expect_no_draft "$lock" "no draft stays beside the lock"

    if [ "$failures" -ne 0 ]; then
        echo "FAIL ui-test-lock ($failures failed)"
        return 1
    fi
    echo "PASS ui-test-lock"
}

main "$@"
