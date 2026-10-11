---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4p2tnjy238spwgpz6az44pj
  text: |-
    Research (implement).
    - `SharedSymbol` (Items/SharedSymbol.swift) has only terminal and copy. About 80 other symbol names are in about 35 files below Sources/AgentViewKit.
    - `SymbolNameScanner` (PackageStructureTests) finds each symbol name in a symbol context. A new test can use it to make sure that each kit name is written only in SharedSymbol.swift, and only one time there.
    - More shared symbols that the card does not name: "arrow.up" is Send and Load Earlier. "clock" is the pending send state and the empty activity list. "circle" is the pending plan entry and the radio button with no selection. "stop.circle" is the unknown exit of a terminal. The connection failure uses the warning triangle. `hand.raised` and `hand.raised.fill` are the same concept. `xmark.circle` and `xmark.circle.fill` are both Remove.
    - The demo and the README snippet cannot read the internal table. The old test "each SharedSymbol name only in the SharedSymbol file" scans Examples too. With a full table, that test cannot hold for Examples.
    - Private items that the concept test must read: the plan status symbol (a private property of PlanEntryRow), SendStateLabel (private), SessionNoticeBanner.symbolName (private), the AgentConnectionBanner and SessionStreamBanner messages (private).
  timestamp: 2026-10-11T18:15:31.166315+00:00
- actor: claude-code
  id: 01m4p3rjdaavxa6eq7ma1v5ypm
  text: |-
    Implementation landed (not committed).

    Symbol table:
    - `SharedSymbol` (Items/SharedSymbol.swift) is now the full symbol table of the kit. Each constant is one concept. `ToolKindSymbol`, `ToolStatusSymbol` and all views read the names from it. No other file below Sources/AgentViewKit writes a symbol name.

    Concept choices:
    - error: `xmark.octagon.fill` (failed tool call, failed turn, `_error` stop reason, error notice, error card, failed send, failed command, failed connection, unreadable patch, demo failure label).
    - warning: `exclamationmark.triangle.fill` (warning notice, lost tool result, missing updates, attachment not accepted, URL warning).
    - cancelled: `stop.circle.fill`. pending: `hourglass` (tool call, plan entry, send state). in progress: `ellipsis.circle.fill`. completed: `checkmark.circle.fill` (the ready banner and the sent message also use it). unknown: `questionmark.circle.fill` (status, kind, state, stop reason, severity, file operation, exit).
    - diff: the modified file is now `dot.square`, beside `plus.square` and `minus.square`.
    - switch mode: the tool kind is now `switch.2`. The max-turn-requests banner keeps `arrow.trianglehead.2.clockwise.rotate.90`.
    - Other shared symbols that the card did not name: Load Earlier is now `arrow.up.to.line` (Send keeps `arrow.up`). The permission title is now `hand.raised.fill`, the same as the requires-action banner. Remove Date is now `xmark.circle.fill`, the same as Remove attachment. The unknown exit of a terminal is now the unknown symbol (it was `stop.circle`).

    Tests:
    - SymbolNameTests: each kit symbol name is written only in SharedSymbol.swift; each table name shows a symbol; the table writes each name one time. The old test "each SharedSymbol name only in the SharedSymbol file" scanned Examples too. The examples cannot read the internal table, so the new test scans only Sources/AgentViewKit.
    - The scan finds all literals in the body of a `*Symbol` type, also the wire value `_lost` and the label "Result lost" of ToolStatusSymbol. The new test compares only names in `name_availability.plist` of CoreGlyphs (new `SystemSymbolData.availableNames()`). That list holds current names and old names.
    - SymbolConceptTests: each concept has one symbol, and two concepts do not share a symbol. It covers the tool rows, the state banner, the stop reasons, the notice, connection and session stream banners, the plan, the diff, the command output, the terminal exit, the message actions, the send state, the error card and the permission card. ErrorViewContentTests reads `SharedSymbol.error`.
    - To let the tests read them, these items are now internal: `NoticeBanner` and its `symbolName(for:)`, `AgentConnectionBanner.makeMessage(for:)`, the four `SessionStreamBanner` messages, `UserMessageView.SendStateLabel`. `TaskListView.statusSymbol(_:)` is new (the row read a private property before).
  timestamp: 2026-10-11T18:31:50.954693+00:00
- actor: claude-code
  id: 01m4p3rqn97zgyb2d0qf2phzng
  text: |-
    ### implement — changed
    - evidence: `swift test` full run: 1061 tests in 115 suites passed (1 known issue that was there before), 104 tests in 10 suites passed, 1 test passed; 0 failures. The only build warning is the SwiftPM "missing creator for mutated node" of mlx-swift_Cmlx, which was there before. Load average 59.67 at start, 64.20 at end.
    - files: Sources/AgentViewKit/Items/SharedSymbol.swift, Items/ToolKindSymbol.swift, 35 view files below Sources/AgentViewKit that now read SharedSymbol, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift, Tests/AgentViewKitTests/Items/SymbolConceptTests.swift (new), Tests/AgentViewKitTests/Items/ErrorViewHostedTests.swift, Tests/PackageStructureTests/SymbolNameTests.swift, Tests/PackageStructureTests/SystemSymbolData.swift.
    - next: /review. Task stays in doing. Not committed.
  timestamp: 2026-10-11T18:31:56.329544+00:00
- actor: claude-code
  id: 01m4p4ser6tp792j6dg8xana1h
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (commit 790d407). 1 finding, 1 confirmed, 0 refuted. Tests/PackageStructureTests/SystemSymbolData.swift:47 (reuse/reuse).
    - next: Make availableNames() and table(named:) use one shared property-list reader. Then do the review again.
  timestamp: 2026-10-11T18:49:48.550147+00:00
- actor: claude-code
  id: 01m4p4sr1xd5jrdn5myk045pn5
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — SharedSymbol is the full symbol table; one symbol for each concept; about 35 view files
    - test: green — swift test, 1061 tests passed, 1 expected known issue, load average 59 to 68
    - commit: 790d407
    - review: findings — Tests/PackageStructureTests/SystemSymbolData.swift:47
  timestamp: 2026-10-11T18:49:58.077664+00:00
- actor: claude-code
  id: 01m4p59j996pn584wncsyhkxbc
  text: |-
    Fix for the reuse finding (SystemSymbolData.swift).
    - New private `propertyList(named:)` reads one data file from `resources` and decodes it with `PropertyListSerialization`. It is the only read path in the file now.
    - `table(named:)` and `availableNames()` both call it. The `NotAStringTable` check stays in `table(named:)`. The `NoNameTable` check stays in `availableNames()`.
    - No behavior change. The existing tests of `aliases()`, `restrictions()` and `availableNames()` in SymbolNameTests are the guard. No new test, because the change is a refactor of a test helper.
  timestamp: 2026-10-11T18:58:36.457663+00:00
- actor: claude-code
  id: 01m4p59mmrqz2zsbm53dm5y184
  text: |-
    ### implement — changed
    - evidence: 1 file — Tests/PackageStructureTests/SystemSymbolData.swift. `swift test` full run: 1 test in 1 suite passed, 104 tests in 10 suites passed, 1061 tests in 115 suites passed (1 known issue that was there before); 0 failures. The only build warning is the SwiftPM "missing creator for mutated node" of mlx-swift_Cmlx, which was there before. Load average 129.09 at start, 145.40 at end.
    - next: /review. Task stays in doing. Not committed.
  timestamp: 2026-10-11T18:58:38.872218+00:00
depends_on:
- 01M4NPZHCT8SVBD2JAM8PH2F7D
position_column: doing
position_ordinal: '80'
title: 'SF Symbols: one symbol table, one symbol for each concept'
---
## What
An audit on 2026-10-11 found that the symbol names are spread over many views, and that one concept has different symbols in different views. The renames of the old names are on a separate card, which comes first. Paths are below `Sources/AgentViewKit/`.

## Work
- [x] Put each SF Symbol name of the kit in one place (extend `ToolKindSymbol` / `ToolStatusSymbol` in `Items/ToolKindSymbol.swift`, or add one symbol table). The views read the names from it.
- [x] Use one symbol for each concept:
  - error: `xmark.octagon.fill` (`Items/ToolKindSymbol.swift:52`, `Status/SessionNoticeBanner.swift:104`, `Status/StateBanner+StopReasons.swift:45`) against `exclamationmark.triangle.fill` (`Items/ErrorView.swift:54`, `Status/StateBanner.swift:233`) and the outline triangle (`Items/UserMessageView.swift:89`, `Diff/DiffRendererSlot+EditorKit.swift:77`, demo `ACPTabView.swift:351`)
  - cancelled: `slash.circle` (`Items/ToolKindSymbol.swift:53`), `xmark.circle` (`Status/TaskListView.swift:201`), `stop.circle.fill` (`Status/StateBanner.swift:185`)
  - pending: `hourglass` against `circle`
  - completed: `checkmark.circle` (`Status/StateBanner.swift:171`) against `checkmark.circle.fill`
  - unknown: `questionmark.circle` (`Status/TaskListView.swift:202`, `Items/ToolKindSymbol.swift:55`), `questionmark.circle.fill` (`Status/StateBanner.swift:86`, `Status/StateBanner+StopReasons.swift:73`), `questionmark.square.dashed` (`Items/ToolKindSymbol.swift:25`)
  - diff edit row: `pencil` against the `.square` symbols (`Diff/DiffView.swift:174-181`)
- [x] The switch-mode tool kind (`Items/ToolKindSymbol.swift:23`) and the max-turn-requests banner (`Status/StateBanner.swift:208`) must not show the same symbol.
- [x] Tests: two different concepts do not share a symbol. Cover the banners, the stop reasons, the plan, the diff, the command output, the message actions and the send state. `Tests/AgentViewKitTests/Items/ErrorViewHostedTests.swift:15` pins `exclamationmark.triangle.fill`; change it to read the table.

## Review Findings (2026-10-11 13:37)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 45 file(s) reviewed, 8 not reviewed.

> 8 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 8 file(s)

- [x] `Tests/PackageStructureTests/SystemSymbolData.swift:47` `reuse/reuse` — availableNames() repeats the read-and-parse steps of the existing file helper that reads a data file (line 75). It reads the file with Data(contentsOf:), decodes it with PropertyListSerialization, and casts the result, but it does not call that helper. The existing helper and this function are a near-match that was not extended. Two parallel read paths can drift apart, for example in error handling or in the file location. Generalize the existing helper so that it returns the property list as [String: Any], or add a small shared reader that returns the decoded property list. Then have table(named:) and availableNames() both use it, and keep the NotAStringTable and NoNameTable checks at their call sites. If the helper's contract does not fit, document why the read is kept separate.
