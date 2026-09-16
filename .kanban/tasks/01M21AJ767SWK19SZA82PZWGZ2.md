---
comments:
- actor: claude-code
  id: 01m2p4sena7p2qk7ggj9mxs0ez
  text: |-
    ### finish iteration 1 — findings
    - decision: EditorKit paints a host mark only as a background, and only for an editor with a grammar. Thus the EditorView in TerminalView shows the ANSI text with no colors in v1. ANSIText keeps the SGR colors in the AttributedString (the acceptance criterion "red in red" is on ANSIText). A later EditorKit release with foreground marks can show them.
    - decision: R7 is recorded in the header of ANSIText.swift: own small parser, no new dependency, no VT emulation. A lone carriage return writes over the current line.
    - implement: changed — ANSIText.swift, TerminalView.swift, OwnModelSlot.swift, 2 test files
    - test: green — swift test, AgentViewKitTests 835 passed (was 797), other targets 20/71/1/91 passed
    - commit: 86dbdc4
    - review: findings — 20: ANSIText.swift:63-77,144,464,476 (magic numbers); TerminalView.swift:230 (duplication, reuse of capRow)
  timestamp: 2026-09-16T22:18:24.810279+00:00
- actor: claude-code
  id: 01m2p54fhnwgbejvbenx365q1g
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — shared OutputCapRow and OutputExitLabel (Content/OutputChrome.swift) used by CommandOutputView and TerminalView; ANSIText palette as named hex text, cube levels by formula, named value counts
    - test: green — swift test, AgentViewKitTests 835 passed, other targets 20/71/1/91 passed
    - commit: dd58862
    - review: findings — 1: ANSIText.swift:491 (code-hygiene/data-driven)
    - next: switch replaced by the table SGR.valueCounts; tests green (835); commit and review again
  timestamp: 2026-09-16T22:24:26.165793+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: review
position_ordinal: '80'
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

## Review Findings (2026-09-16 17:10)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:63` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:64` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:65` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:66` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:67` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:68` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:69` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:70` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:71` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:72` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:73` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:74` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:75` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:76` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:77` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:144` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:464` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:476` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/TerminalView.swift:230` `duplication/duplication` — capRow function duplicates CommandOutputView.capRow at 99% similarity. Both display "Showing the last N of M lines" with a "Show all" button using nearly identical HStack, Text, Spacer, and Button layout with identical spacing and styling. This near-verbatim duplication risks the two diverging during maintenance. Extract the cap-display UI pattern into a shared helper function, or have TerminalView reuse CommandOutputView's capRow directly instead of duplicating it.
- [x] `Sources/AgentViewKit/Terminal/TerminalView.swift:230` `reuse/reuse` — The `capRow` method reimplements row-limit display logic that exists nearly identically in `CommandOutputView`. Both show the same UI pattern ("Showing the last N of M lines" with a "Show All" button) and both operate on `CommandOutputView.VisibleRows`. The code should be shared rather than duplicated. Extract a shared helper function (or add parameters to CommandOutputView.capRow for identifiers) so both views reuse the same row-limit display logic instead of maintaining parallel copies.

## Review Findings (2026-09-16 17:20)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKit/Terminal/ANSIText.swift:491` `code-hygiene/data-driven` — A switch over SGR mode values with arms differing only in constant assignments should be expressed as a table lookup instead of control flow. Replace the switch with a data-driven table lookup: `let modeToCount: [Int: Int] = [SGR.paletteMode: SGR.paletteValueCount, SGR.directMode: SGR.directValueCount]; let count = modeToCount[mode] ?? 0`.