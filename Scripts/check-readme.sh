#!/usr/bin/env bash
#
# check-readme.sh: the gate of README.md (plan.md §1).
#
# The script:
#
#   1. writes the snippets of README.md to a temporary directory with
#      Scripts/extract-readme-snippets.sh,
#   2. compares that directory with Examples/ReadmeSnippets/Snippets, the
#      directory that the ReadmeSnippetsTests target compiles, and
#   3. builds the ReadmeSnippetsTests target, so that a snippet that does not
#      compile fails.
#
# The script fails when the two directories differ, or when the build fails.
# When the directories differ, run Scripts/extract-readme-snippets.sh and
# commit the result.
#
# Written for the bash 3.2 of macOS.
#
# Usage: Scripts/check-readme.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SNIPPETS_DIR="$REPO_ROOT/Examples/ReadmeSnippets/Snippets"
readonly EXTRACT="$REPO_ROOT/Scripts/extract-readme-snippets.sh"
readonly TARGET="ReadmeSnippetsTests"

# The temporary directory of the fresh extraction. `cleanup` removes it.
FRESH_DIR=""

# Removes the temporary directory, when there is one.
cleanup() {
    if [ -n "$FRESH_DIR" ]; then
        rm -rf "$FRESH_DIR"
    fi
}

main() {
    trap cleanup EXIT
    FRESH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readme-snippets.XXXXXX")"

    echo "==> extract the snippets of README.md"
    "$EXTRACT" "$FRESH_DIR"

    echo "==> compare with $SNIPPETS_DIR"
    if ! diff -r "$FRESH_DIR" "$SNIPPETS_DIR"; then
        echo
        echo "README gate FAILED: README.md and Examples/ReadmeSnippets/Snippets differ."
        echo "Run Scripts/extract-readme-snippets.sh and commit the result."
        return 1
    fi

    echo "==> build $TARGET"
    if ! swift build --package-path "$REPO_ROOT" --target "$TARGET"; then
        echo
        echo "README gate FAILED: a snippet does not compile."
        return 1
    fi

    echo
    echo "README gate passed: each snippet is in its file, and each snippet compiles."
}

main "$@"
