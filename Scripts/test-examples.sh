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
# because a UI test runner that waits forever uses no CPU and gives no output.
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

# Stops with a message when the `xcodeproj` gem is not installed.
require_xcodeproj_gem() {
    if ! ruby -e 'require "xcodeproj"' 2>/dev/null; then
        echo "error: the xcodeproj gem is not installed. Run: gem install xcodeproj" >&2
        return 1
    fi
}

# Runs `xcodebuild` with a time limit.
#
# EditorKit and Textual use Swift macros. A build with no person to approve them must skip
# the macro and the plugin validation.
#
# Arguments: the time limit in seconds, then the arguments of xcodebuild.
run_xcodebuild() {
    local limit="$1"
    shift
    timeout "$limit" xcodebuild -skipMacroValidation -skipPackagePluginValidation "$@"
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
    run_xcodebuild "$BUILD_TIMEOUT" -project "$project" -scheme "$app_name" \
        -destination 'platform=macOS' -derivedDataPath "$derived_data" \
        -resultBundlePath "$results/$app_name-build.xcresult" build || return 1

    echo "==> $app_name: UI tests"
    run_xcodebuild "$TEST_TIMEOUT" -project "$project" -scheme "$app_name" \
        -destination 'platform=macOS' -derivedDataPath "$derived_data" \
        -resultBundlePath "$results/$app_name-test.xcresult" test || return 1
}

main() {
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
