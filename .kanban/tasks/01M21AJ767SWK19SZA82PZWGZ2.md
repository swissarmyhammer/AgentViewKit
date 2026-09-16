---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: doing
position_ordinal: '8180'
title: TerminalView for agent-owned terminals with ANSI handling (plan §9 C, research R7)
---
## What
Create `Sources/AgentViewKit/Terminal/TerminalView.swift` and `ANSIText.swift`, per plan.md §9 C. This task also settles research R7 with a decision recorded in the file header.

- `ANSIText.attributed(from data: Data) -> AttributedString`: decodes UTF-8 with lossy replacement, applies SGR colors and bold, and strips every other escape sequence (cursor movement, OSC, clear). No third-party parser in v1. If a later task needs full VT emulation, it replaces this file.
- `TerminalView(record: TerminalRecord)`: a header with the command and cwd, the output in a read-only EditorKit `EditorView` with SF Mono and `.editorSizingMode(.intrinsic)`, capped at a configurable row count with a "show all" toggle, and a footer with the exit status. While `exitStatus` is nil, a `ProgressView` shows.
- An optional `input` mode: when the host passes `stdin: (String) -> Void`, a single-line field appears under the output. The terminal auth flow uses it.

## Acceptance Criteria
- [x] `\u{1B}[31mred\u{1B}[0m` renders "red" in red; a cursor-move sequence produces no text.
- [x] Invalid UTF-8 renders with replacement characters and no crash.
- [x] The exit status footer shows the code or the signal.
- [x] With `stdin` set, typing and Return calls the closure with the line.

## Tests
- [x] `Tests/AgentViewKitTests/Terminal/ANSITextTests.swift`: SGR colors, strip cases, invalid UTF-8.
- [x] `Tests/AgentViewKitTests/Terminal/TerminalViewHostedTests.swift`: header, footer, progress, and the stdin field.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.