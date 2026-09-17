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
- actor: claude-code
  id: 01m2pwwhdek5bjf8pks8gn8m8a
  text: |-
    ### finish iteration 1 — findings
    - implement: added ToolCallView, ToolKindSymbol (ToolKindSymbol and ToolStatusSymbol), the `.toolCallConnectionState(_:)` modifier, and ItemRow now shows ToolCallView.
    - test: `swift test` passed. AgentViewKitTests 1081, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 44.
    - commit: 7e21392
    - review: 3 findings (identifier suffix duplication, status label reuse with TaskListView.statusLabel, test factory names without `make`).
  timestamp: 2026-09-17T05:19:31.758021+00:00
- actor: claude-code
  id: 01m2px8yvw2p6qws8xed37rk17
  text: |-
    ### finish iteration 2 — findings
    - implement: fixed the 3 round 1 findings. Added WorkStatusLabel (shared by TaskListView and ToolStatusSymbol), the `suffixedIdentifier(for:suffix:)` helper, and `make` test factories. The in-progress tool label is now "In progress", and an unknown status label has its wire string.
    - test: `swift test` passed. AgentViewKitTests 1082, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 44.
    - commit: 76ce683
    - review: 3 new findings (WorkStatusLabel access level, `unknown(_:)` label, `makeExpandedStore(_:)` label).
  timestamp: 2026-09-17T05:26:18.748596+00:00
- actor: claude-code
  id: 01m2pxfmw0wmjghqjj3tdepa7j
  text: |-
    ### finish iteration 3 — done
    - implement: fixed the 3 round 2 findings. WorkStatusLabel is internal, `unknown(for:)` and `makeExpandedStore(for:)` label their parameters.
    - test: `swift test` passed. AgentViewKitTests 1082, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 44.
    - commit: b5066b6
    - review: clean (zero findings, all prior items checked).
  timestamp: 2026-09-17T05:29:57.888788+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21AFDM0RPN9SPB5D35Y2FDR
- 01M21ACHJYSF8G8R7HY3M70Z7F
- 01M21BCRF2JZ6W49NKXHE8KKT1
- 01M21BDXGQ5HYN8GCKAEH8GN3P
position_column: done
position_ordinal: bd80
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
- [x] Each kind maps to a distinct symbol name.
- [x] Each status maps to a distinct label.
- [x] With the body expanded, a status patch from `inProgress` to `completed` adds one evaluation to `tool-row-<id>` and zero to `tool-body-<id>`.
- [x] A press on the row toggles `ExpandedBlocksStore.isExpanded(id)`.

## Tests
- [x] `Tests/AgentViewKitTests/Items/ToolKindSymbolTests.swift`: symbol and label tables.
- [x] `Tests/AgentViewKitTests/Items/ToolCallViewHostedTests.swift`: mount, patch counts, expand.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-17 00:12)

> Scope: `review sha HEAD~1..HEAD` (commit 7e21392). 5 files reviewed.

- [x] `Sources/AgentViewKit/Items/ToolCallView.swift:144` `duplication/duplication` — Multiple identifier helper functions (toggleIdentifier, bodyIdentifier, locationsIdentifier, inputIdentifier, outputIdentifier) differ only by which static suffix they append to the base identifier. These are one function with a suffix parameter. Extract a single helper function like `static func suffixedIdentifier(for id: String, suffix: String) -> String { identifier(for: id) + suffix }` and call it from each of these five functions, passing the appropriate suffix constant. This prevents the suffix-appending logic from drifting across five copies.
- [x] `Sources/AgentViewKit/Items/ToolKindSymbol.swift:55` `reuse/reuse` — ToolStatusSymbol.label() maps tool call statuses to localized label strings, but very similar functionality already exists. TaskListView.statusLabel() has 0.96 similarity, indicating this code likely duplicates an existing implementation. Investigate whether ToolStatusSymbol.label() should reuse TaskListView.statusLabel() or if both should call a shared status-to-label mapping function. If they handle different status types (PlanEntry.Status vs ToolCallStatus), consider extracting a parameterized shared utility.
- [x] `Tests/AgentViewKitTests/Items/ToolCallViewHostedTests.swift:33` `swift/fluent-usage` — Factory method should begin with `make` to follow Apple's naming convention for methods that create instances. Rename `callThread` to `makeCallThread` to follow the factory method convention.

## Review Findings (2026-09-17 00:21)

> Scope: `review sha HEAD~1..HEAD` (commit 76ce683). 6 files reviewed.

- [x] `Sources/AgentViewKit/Status/WorkStatusLabel.swift:8` `swift/access-control` — WorkStatusLabel is marked public but is only used internally within the AgentViewKit module. Library code should default to internal and use public only for intended cross-module API. Change `public nonisolated enum WorkStatusLabel` to `nonisolated enum WorkStatusLabel` (internal by default), or explicitly mark it `internal nonisolated enum WorkStatusLabel` if API-shaping intent needs to be stated.
- [x] `Sources/AgentViewKit/Status/WorkStatusLabel.swift:28` `swift/fluent-usage` — The unknown(_:) function omits the parameter label, but this is not a value-preserving conversion. The function constructs and returns a localized string with formatting applied to the input, so the parameter should be labeled to form a grammatical phrase. Change `public static func unknown(_ wireValue: String)` to `public static func unknown(for wireValue: String)` so calls read as `WorkStatusLabel.unknown(for: wireValue)`, making the intent clear and consistent with other helper methods.
- [x] `Tests/AgentViewKitTests/Items/ToolCallViewHostedTests.swift:44` `swift/fluent-usage` — The makeExpandedStore(_:) function omits the parameter label, but this is not a value-preserving conversion. The function creates and configures a new store, so the parameter should be labeled to form a grammatical phrase. Change `static func makeExpandedStore(_ id: String)` to `static func makeExpandedStore(for id: String)` so calls read as `Self.makeExpandedStore(for: id)`, consistent with the labeled-parameter style of the nearby `makeCallThread(id:status:)` function.

## Review Findings (2026-09-17 00:28)

> Scope: `review sha HEAD~1..HEAD` (commit b5066b6). 4 files reviewed. Zero findings.
