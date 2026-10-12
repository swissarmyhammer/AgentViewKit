#!/usr/bin/env bash
#
# test-examples.sh: the gate of the example apps.
#
# For each example, the script:
#
#   1. makes the Xcode project again with `Examples/<AppName>/Scripts/generate_xcodeproj.rb`
#      (the `.xcodeproj` is git-ignored, so a clean checkout has none),
#   2. builds the app with `xcodebuild -scheme <AppName> build`,
#   3. runs the UI tests of the scheme with `xcodebuild -scheme <AppName> test`.
#
# The UI tests drive the app through XCUIApplication. The process that runs this script must
# have the Accessibility and the Automation permissions, and a user session must be logged in.
#
# Each step has a time limit (EXAMPLE_BUILD_TIMEOUT and EXAMPLE_TEST_TIMEOUT, in seconds),
# because a UI test runner that waits forever uses no CPU and gives no output. At the limit
# the script stops the step, each process that the step started, and each process that runs
# from the DerivedData directory of the example: the app under test and the UI test runner.
# Thus no process of a failed run stays alive and changes the next run.
#
# The results go to `.build/examples/<AppName>/`: one `.xcresult` bundle for the build and
# one for the tests.
#
# Requires Xcode and the `xcodeproj` gem (`gem install xcodeproj`).
#
# Written for the bash 3.2 of macOS.
#
# Usage: Scripts/test-examples.sh [AppName ...]
#   With no argument, each example in EXAMPLES runs. With arguments, only those run.
#
# Usage: Scripts/test-examples.sh --self-test
#   Checks the time limit with `sleep` processes only. It runs no build and no UI test.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT

# Each example app.
EXAMPLES=(
    AgentViewKitDemo
)
readonly EXAMPLES

# The time limits of one build and of one test run, in seconds.
readonly BUILD_TIMEOUT="${EXAMPLE_BUILD_TIMEOUT:-1800}"
readonly TEST_TIMEOUT="${EXAMPLE_TEST_TIMEOUT:-900}"

# The time, in seconds, that a process has to end after SIGTERM. Then it gets SIGKILL.
readonly STOP_GRACE_SECONDS=10

# The exit status of a step that its time limit stopped. GNU `timeout` uses the same value.
readonly LIMIT_STATUS=124

# The exit status of the script when it gets SIGINT, SIGTERM or SIGHUP during a step.
readonly INTERRUPTED_STATUS=130

# The time limit of the command of the self-test, in seconds.
readonly SELF_TEST_LIMIT=1

# The time that each `sleep` process of the self-test sleeps, in seconds. It is much longer
# than SELF_TEST_LIMIT, so only a stop can end the process during the self-test.
readonly SELF_TEST_SLEEP=300

# Stops with a message when the `xcodeproj` gem is not installed.
require_xcodeproj_gem() {
    if ! ruby -e 'require "xcodeproj"' 2>/dev/null; then
        echo "error: the xcodeproj gem is not installed. Run: gem install xcodeproj" >&2
        return 1
    fi
}

# Writes the process id of each process in a process group, one on each line.
#
# Arguments: the process group id.
processes_in_group() {
    pgrep -g "$1" || true
}

# Writes the process id of each process of this user whose command line starts with a path
# in a directory, one on each line. The command line of an app starts with the path of its
# executable, so the list holds each process that runs an executable from the directory.
#
# Arguments: the directory.
processes_under() {
    local directory="$1"
    local pid command_line
    ps -ww -x -U "$(id -u)" -o pid= -o command= | while read -r pid command_line; do
        case "$command_line" in
            "$directory"/*) echo "$pid" ;;
        esac
    done
}

# Stops a set of processes. Each process gets SIGTERM. Each process that is alive after
# STOP_GRACE_SECONDS gets SIGKILL.
#
# Arguments: a command that writes the process ids, and its arguments. The function runs the
# command again each second to find the processes that are still alive.
stop_processes() {
    local pids waited=0
    pids="$("$@")"
    [ -n "$pids" ] || return 0
    echo "Stopping:" >&2
    # The ids are numbers, one on each line, so the word splitting gives one argument each.
    # shellcheck disable=SC2086
    ps -o pid= -o command= -p "$(echo $pids | tr ' ' ',')" >&2 || true
    # shellcheck disable=SC2086
    kill -TERM $pids 2>/dev/null || true
    while [ "$waited" -lt "$STOP_GRACE_SECONDS" ]; do
        sleep 1
        waited=$((waited + 1))
        pids="$("$@")"
        [ -n "$pids" ] || return 0
    done
    # shellcheck disable=SC2086
    kill -KILL $pids 2>/dev/null || true
}

# Waits for a time limit, then stops a process group. It runs in the background, beside the
# command that it watches.
#
# SIGTERM before the limit cancels the wait, and the function ends with status 0. When the
# limit occurs, the function ignores SIGTERM until the group is stopped, and it ends with
# LIMIT_STATUS.
#
# Arguments: the time limit in seconds, then the process group id.
watch_limit() {
    local limit="$1"
    local group="$2"
    local sleep_pid=""
    trap 'kill "$sleep_pid" 2>/dev/null; exit 0' TERM
    sleep "$limit" &
    sleep_pid=$!
    wait "$sleep_pid"
    trap '' TERM
    echo "error: the time limit of $limit seconds occurred. Stopping the process group $group." >&2
    stop_processes processes_in_group "$group"
    exit "$LIMIT_STATUS"
}

# Runs a command with a time limit, in seconds.
#
# The command runs in its own process group, so that the limit stops each process that the
# command started, and no other process. bash 3.2 cannot make a process group, and macOS
# ships no `setsid` and no `timeout` command, so `perl` (which ships with macOS) makes the
# group and then runs the command. A process group that is not in the foreground does not
# get the SIGINT of the terminal, so the function sends SIGINT, SIGTERM and SIGHUP of the
# script on to the group.
#
# Arguments: the time limit in seconds, then the command and its arguments.
# Returns: LIMIT_STATUS when the limit stopped the command, else the status of the command.
run_with_limit() {
    local limit="$1"
    shift
    local command_pid watchdog_pid status=0 watchdog_status=0
    perl -e 'setpgrp(0, 0) or die "setpgrp failed: $!\n"; exec @ARGV or die "exec failed: $!\n"' -- "$@" &
    command_pid=$!
    watch_limit "$limit" "$command_pid" &
    watchdog_pid=$!
    trap 'kill -TERM -- "-$command_pid" "$watchdog_pid" 2>/dev/null; exit "$INTERRUPTED_STATUS"' INT TERM HUP

    wait "$command_pid" || status=$?
    kill -TERM "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" || watchdog_status=$?
    trap - INT TERM HUP

    if [ "$watchdog_status" -eq "$LIMIT_STATUS" ]; then
        return "$LIMIT_STATUS"
    fi
    return "$status"
}

# Runs one step of an example with a time limit.
#
# XCUITest starts the app under test and the UI test runner through launchd, so they are not
# in the process group of the step, and the limit does not stop them. Their executables are
# in the DerivedData directory of the example. Thus, when the limit occurs, the function also
# stops each process that runs an executable from that directory.
#
# Arguments: the time limit in seconds, the DerivedData directory, then the command and its
# arguments.
# Returns: LIMIT_STATUS when the limit stopped the command, else the status of the command.
run_example_step() {
    local limit="$1"
    local derived_data="$2"
    shift 2
    local status=0
    run_with_limit "$limit" "$@" || status=$?
    if [ "$status" -eq "$LIMIT_STATUS" ]; then
        stop_processes processes_under "$derived_data"
    fi
    return "$status"
}

# Runs `xcodebuild` for one example, with a time limit.
#
# EditorKit and Textual use Swift macros. A build with no person to approve them must skip
# the macro and the plugin validation.
#
# Arguments: the time limit in seconds, the DerivedData directory, then the other arguments
# of xcodebuild.
run_xcodebuild() {
    local limit="$1"
    local derived_data="$2"
    shift 2
    run_example_step "$limit" "$derived_data" xcodebuild -skipMacroValidation \
        -skipPackagePluginValidation -derivedDataPath "$derived_data" "$@"
}

# Makes the project of one example again, builds it, and runs its UI tests.
# Returns non-zero when the example has no generator, or when a step fails.
run_example() {
    local app_name="$1"
    local example_dir="$REPO_ROOT/Examples/$app_name"
    local generator="$example_dir/Scripts/generate_xcodeproj.rb"
    local project="$example_dir/$app_name.xcodeproj"
    local results="$REPO_ROOT/.build/examples/$app_name"
    local derived_data="$results/DerivedData"

    if [ ! -f "$generator" ]; then
        echo "error: no example named $app_name. Expected $generator" >&2
        return 1
    fi

    # `set -e` has no effect in a function that runs in an `if` condition, so each step
    # returns on its own failure.
    echo "==> $app_name: generate $app_name.xcodeproj"
    ruby "$generator" || return 1

    mkdir -p "$results" || return 1
    # xcodebuild does not write over a result bundle that exists.
    rm -rf "$results/$app_name-build.xcresult" "$results/$app_name-test.xcresult" || return 1

    echo "==> $app_name: build"
    run_xcodebuild "$BUILD_TIMEOUT" "$derived_data" -project "$project" -scheme "$app_name" \
        -destination 'platform=macOS' \
        -resultBundlePath "$results/$app_name-build.xcresult" build || return 1

    echo "==> $app_name: UI tests"
    run_xcodebuild "$TEST_TIMEOUT" "$derived_data" -project "$project" -scheme "$app_name" \
        -destination 'platform=macOS' \
        -resultBundlePath "$results/$app_name-test.xcresult" test || return 1
}

# Starts a `sleep` process outside the process group of the script, as launchd starts an app.
# The command line of the process starts with a path, as the command line of an app starts
# with the path of its executable. The path needs no file.
#
# Arguments: the path. Writes the process id.
start_detached_sleep() {
    local path="$1"
    perl -e 'setpgrp(0, 0) or die "setpgrp failed: $!\n"; exec { "sleep" } @ARGV or die "exec failed: $!\n"' \
        -- "$path" "$SELF_TEST_SLEEP" </dev/null >/dev/null 2>&1 &
    echo "$!"
}

# Tells whether a process runs. A process that ended and waits for its parent does not run.
#
# Arguments: the process id.
is_running() {
    local state
    state="$(ps -o stat= -p "$1" 2>/dev/null || true)"
    case "$state" in
        "" | Z*) return 1 ;;
        *) return 0 ;;
    esac
}

# Writes one result line of the self-test. Returns non-zero when the check failed.
#
# Arguments: "running" or "stopped" (the state that the check expects), the process id, then
# the name of the process.
check_process_state() {
    local expected="$1"
    local pid="$2"
    local name="$3"
    local actual="stopped"
    if is_running "$pid"; then
        actual="running"
    fi
    if [ "$actual" = "$expected" ]; then
        echo "ok: $name is $actual"
        return 0
    fi
    echo "not ok: $name is $actual, expected $expected"
    return 1
}

# The temporary directory of the self-test, and the ids of the processes that it started. The
# EXIT trap of the self-test reads them after `self_test` returns, so they are not local.
self_test_work=""
self_test_pids=""

# Stops each process that the self-test started, and removes its temporary directory. The
# self-test runs it at exit, also when a check fails or the script gets a signal.
stop_self_test_processes() {
    # The ids are numbers, so the word splitting gives one argument each.
    # shellcheck disable=SC2086
    [ -z "$self_test_pids" ] || kill -KILL $self_test_pids 2>/dev/null || true
    [ -z "$self_test_work" ] || rm -rf "$self_test_work"
}

# Checks the time limit of an example step with `sleep` processes only. It starts:
#
#   - a command whose child sleeps, in the process group of the step,
#   - a fake app under test and a fake UI test runner, outside the process group, with paths
#     in a temporary DerivedData directory,
#   - one sleeping process outside the process group and outside that directory.
#
# Then it runs the command with the time limit SELF_TEST_LIMIT. The limit must stop the
# command, its child, the fake app and the fake runner. The process outside the directory
# must stay alive, because the script stops only the processes that it started or that run
# from the DerivedData directory of the example.
self_test() {
    local products child_pid_file status=0 failed=0
    local app_pid runner_pid outside_pid child_pid
    trap stop_self_test_processes EXIT
    self_test_work="$(mktemp -d)"
    products="$self_test_work/DerivedData/Build/Products/Debug"
    child_pid_file="$self_test_work/child.pid"
    app_pid="$(start_detached_sleep "$products/AgentViewKitDemo.app/Contents/MacOS/AgentViewKitDemo")"
    runner_pid="$(start_detached_sleep \
        "$products/AgentViewKitDemoUITests-Runner.app/Contents/MacOS/AgentViewKitDemoUITests-Runner")"
    outside_pid="$(start_detached_sleep "$self_test_work/Outside/sleep")"
    self_test_pids="$app_pid $runner_pid $outside_pid"

    # The inner `bash` expands "$1" and "$2" (its own arguments), so the quotes are single.
    # shellcheck disable=SC2016
    run_example_step "$SELF_TEST_LIMIT" "$self_test_work/DerivedData" bash -c \
        'sleep "$1" </dev/null >/dev/null 2>&1 & echo "$!" >"$2"; wait' \
        self-test-command "$SELF_TEST_SLEEP" "$child_pid_file" || status=$?
    child_pid="$(cat "$child_pid_file")"
    self_test_pids="$self_test_pids $child_pid"

    if [ "$status" -eq "$LIMIT_STATUS" ]; then
        echo "ok: the step ended with the limit status $LIMIT_STATUS"
    else
        echo "not ok: the step ended with status $status, expected $LIMIT_STATUS"
        failed=1
    fi
    check_process_state stopped "$child_pid" "the child of the command" || failed=1
    check_process_state stopped "$app_pid" "the app under test" || failed=1
    check_process_state stopped "$runner_pid" "the UI test runner" || failed=1
    check_process_state running "$outside_pid" "the process outside DerivedData" || failed=1

    if [ "$failed" -ne 0 ]; then
        echo "FAIL self-test"
        return 1
    fi
    echo "PASS self-test"
}

main() {
    if [ "${1:-}" = "--self-test" ]; then
        self_test
        return
    fi

    require_xcodeproj_gem

    local selected=("$@")
    if [ $# -eq 0 ]; then
        selected=("${EXAMPLES[@]}")
    fi

    local failed=""
    local app_name
    for app_name in "${selected[@]}"; do
        if run_example "$app_name"; then
            echo "PASS $app_name"
        else
            echo "FAIL $app_name"
            failed="$failed $app_name"
        fi
    done

    if [ -n "$failed" ]; then
        echo
        echo "The example gate failed for:$failed"
        echo "See .build/examples/<AppName>/ for the .xcresult bundles."
        return 1
    fi

    echo
    echo "The example gate passed."
}

main "$@"
