#!/usr/bin/env bash
#
# extract-readme-snippets.sh: writes each compiled snippet of README.md to a file.
#
# A snippet is a ```swift block of README.md whose first line is
# `// readme:compile <Name>`. The script writes the lines of the block, with
# the marker line, to `<output-dir>/<Name>.swift`. Before it writes, it
# removes each `.swift` file of the output directory, so that a snippet that
# the README does not have any more does not stay.
#
# A block opens on a line that is exactly ```swift and closes on a line that
# is exactly ```. `Tests/PackageStructureTests/ReadmeSnippets.swift` reads the
# README with the same rule.
#
# The `ReadmeSnippetsTests` target compiles the default output directory.
# `Scripts/check-readme.sh` writes to a temporary directory and compares it
# with the default output directory.
#
# The script fails when a marker has no name, when a name is not a Swift
# identifier, when two blocks have the same name, or when a marker line is
# not the first line of a ```swift block.
#
# Written for the bash 3.2 of macOS.
#
# Usage: Scripts/extract-readme-snippets.sh [output-dir]
#   The default output directory is Examples/ReadmeSnippets/Snippets.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly README="$REPO_ROOT/README.md"
readonly MARKER="// readme:compile"
readonly OPEN_FENCE='```swift'
readonly CLOSE_FENCE='```'
readonly DEFAULT_OUTPUT_DIR="$REPO_ROOT/Examples/ReadmeSnippets/Snippets"

# Stops with a message.
fail() {
    echo "error: $*" >&2
    exit 1
}

# The number of lines of the README that start with the marker.
marker_line_count() {
    grep -c "^$MARKER" "$README" || true
}

main() {
    local output_dir="${1:-$DEFAULT_OUTPUT_DIR}"
    mkdir -p "$output_dir"
    rm -f "$output_dir"/*.swift

    local in_block=0    # 1 between the fences of a ```swift block
    local first_line=0  # 1 on the first line of a block
    local file=""       # the file of the block, or "" for a block with no marker
    local count=0
    local line name
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$in_block" -eq 0 ]; then
            if [ "$line" = "$OPEN_FENCE" ]; then
                in_block=1
                first_line=1
                file=""
            fi
            continue
        fi
        if [ "$line" = "$CLOSE_FENCE" ]; then
            in_block=0
            continue
        fi
        if [ "$first_line" -eq 1 ]; then
            first_line=0
            case "$line" in
                "$MARKER"*)
                    name="${line#"$MARKER"}"
                    # Removes the spaces around the name.
                    name="$(echo "$name" | tr -d '[:space:]')"
                    [ -n "$name" ] || fail "a marker has no name: '$line'"
                    [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || fail "the snippet name '$name' is not an identifier"
                    file="$output_dir/$name.swift"
                    [ ! -e "$file" ] || fail "two snippets have the name '$name'"
                    count=$((count + 1))
                    ;;
            esac
        fi
        if [ -n "$file" ]; then
            printf '%s\n' "$line" >> "$file"
        fi
    done < "$README"

    local markers
    markers="$(marker_line_count)"
    [ "$markers" -eq "$count" ] || fail "README.md has $markers marker lines, but $count open a \`\`\`swift block"

    echo "Wrote $count snippet(s) to $output_dir"
}

main "$@"
