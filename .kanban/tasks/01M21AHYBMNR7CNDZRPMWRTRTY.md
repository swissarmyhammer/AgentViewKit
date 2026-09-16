---
comments:
- actor: claude-code
  id: 01m2nzc425nq0fnm9nqefg07kb
  text: 'Dependency added: ^eh8gn3p (ContentBlockView family). This task shows each `ToolContent.block` through `ContentBlockView`. `ContentBlockView` is not in the tree, and ^eh8gn3p is not done. The task permits placeholders only for `DiffView` and `TerminalView`. Thus this task waits for ^eh8gn3p.'
  timestamp: 2026-09-16T20:43:45.093957+00:00
- actor: claude-code
  id: 01m2nzyntzej8jbs1qbdkmqbsj
  text: 'Requirement from ^03aha3m (done): `CommandOutputView(command:output:exitCode:rowLimit:model:)` is in Sources/AgentViewKit/Content/CommandOutputView.swift. Show the text output of an `execute` kind tool call that has no `terminalId` through `CommandOutputView`. Do not use `TerminalView` for that output.'
  timestamp: 2026-09-16T20:53:53.119023+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21AFDM0RPN9SPB5D35Y2FDR
- 01M21ACHJYSF8G8R7HY3M70Z7F
- 01M21BCRF2JZ6W49NKXHE8KKT1
- 01M21BDXGQ5HYN8GCKAEH8GN3P
position_column: todo
position_ordinal: '9680'
title: 'ToolCallView: kind icons, status effects, locations, raw input and output, collapsible content (plan §5, §9 C)'
---
## What
Create `Sources/AgentViewKit/Items/ToolCallView.swift` and `ToolKindSymbol.swift`, per plan.md §5 and §9 C.

- A compact row: an SF Symbol per `ToolKind` (read, edit, delete, move, search, execute, think, fetch, switchMode, other, unknown), the title, a status glyph, and the duration from `startedAt` and `endedAt` when both exist.
- Status: `pending` and `inProgress` use `ProgressView` plus `.symbolEffect(.variableColor)`; the transition to `completed` uses `.contentTransition(.symbolEffect(.replace))` and `.bounce`; `failed`, `cancelled`, `lost`, and `unknown` each get a distinct symbol and label.
- Expanded body (state in `ExpandedBlocksStore`): `locations` as path chips, `rawInput` and `rawOutput` as pretty JSON in `CodeBlockView`, and each `ToolContent`: `block` through `ContentBlockView`, `diff` through `DiffView`, `terminal` through `TerminalView` by id. Placeholders for the last two until those tasks land.
- A `ConnectionStatusChip` slot for a call blocked on auth (set by the host through `.toolCallConnectionState(_:)`).
- The row calls `BodyEvaluationCounter.note("tool-row-<id>")` and the expanded body `note("tool-body-<id>")` under `#if DEBUG`.
- Accessibility identifier `tool-call-<id>`, label "<title>, <status>", updated on status change.

## Acceptance Criteria
- [ ] Each kind maps to a distinct symbol name.
- [ ] Each status maps to a distinct label.
- [ ] With the body expanded, a status patch from `inProgress` to `completed` adds one evaluation to `tool-row-<id>` and zero to `tool-body-<id>`.
- [ ] A press on the row toggles `ExpandedBlocksStore.isExpanded(id)`.

## Tests
- [ ] `Tests/AgentViewKitTests/Items/ToolKindSymbolTests.swift`: symbol and label tables.
- [ ] `Tests/AgentViewKitTests/Items/ToolCallViewHostedTests.swift`: mount, patch counts, expand.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.