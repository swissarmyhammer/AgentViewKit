---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4pavten3e419cgy61c4wrmy
  text: |-
    Research (2026-10-11). The line numbers on the card moved. Current places:
    - ActivityTimeline.swift: `ActivityEntryRow.toolCallAppearance` tints the KIND symbol with `editorTheme.statusColor(for:)`; the row label is the title only (`.accessibilityLabel(appearance.title)`). `ToolCallView.accessibilityLabel(title:status:)` and `ToolStatusSymbol.name(for:)` already exist; reuse them.
    - ConnectionStatusChip.swift: `Circle().fill(color(for:))` dot; `label(for:)` returns plain literals (not localized).
    - TaskListView.swift: `PlanEntryRow` shows `SharedSymbol.priority` ("flag.fill") for each priority, tinted by `editorTheme.tint(for:)`.
    - StatusBar.swift: the symbol uses `editorTheme.accent` for each message. The failure messages are the three messages whose symbol is `SharedSymbol.error` (turn failed, stop reason `_error`, connection failed).
    - ThreadMinimapView.swift: `tint(of:)` and `draw(tints:...)` fill each tick with color only. The tick elements are `#if DEBUG` only.
    Plan: status symbol after the title in the timeline row and the call label in the row label; a status symbol in the chip (SharedSymbol concepts reused); new SharedSymbol concepts highPriority/mediumPriority/lowPriority (exclamationmark.3/.2/exclamationmark, checked in CoreGlyphs name_availability.plist); `StateBanner.Message.isFailure` from the error symbol, StatusBar uses `severityError` for it; minimap ticks get a shape for each status class, and a release accessibility element with a status summary.
    Test tools: RenderedPixels + DistinctRolesTheme for color, HostedViewHarness for labels.
  timestamp: 2026-10-11T20:35:57.525572+00:00
- actor: claude-code
  id: 01m4pc17bq9mpah9pknbhgvd4q
  text: |-
    Implementation landed (not committed).
    - Activity timeline: a tool call row shows the kind symbol (secondary), the title, and the status symbol from `ToolStatusSymbol.name(for:)` with `editorTheme.statusColor(for:)`. The row label is `ToolCallView.accessibilityLabel(title:status:)`, such as "Read README.md, In progress".
    - MCP chip: `ConnectionStatusChip.symbolName(for:)` replaces the dot. It reuses concepts: not reported = unknown, connecting = inProgress, connected = completed, failed = error, closed = disconnected (SharedSymbol docs extended). Labels use `String(localized:)`; failed reuses `WorkStatusLabel.failed`.
    - Priority: new SharedSymbol concepts highPriority/mediumPriority/lowPriority (exclamationmark.3/.2/exclamationmark). `SharedSymbol.priority` (flag.fill) is removed. `TaskListView.prioritySymbol(_:)`.
    - Status bar: `StateBanner.Message.isFailure` (symbol is the error symbol; one symbol per concept makes this exact). `StatusBar.symbolColor(for:in:)` gives `severityError` for a failure, `accent` for others.
    - Minimap: `ThreadMinimapView.TickMark` (plain, live = trailing half, failure = wedge, cancelled = thin bar) drawn by the Canvas. A release accessibility element `summaryIdentifier` ("Thread status") gives counts such as "In progress: 1, Completed: 1, and Error: 1", or "No status".
    What did not work: a RenderedPixels test of StatusBar found neither the accent nor the error color. The glass effect of the bar does not render the symbol in the image renderer. The test now checks `StatusBar.symbolColor(for:in:)` with DistinctRolesTheme, as StatusColorsTests does.
    Note: importing FoundationModelsACP in ThreadMinimapView.swift hides SwiftUI `Content` in `ThreadMinimapModifier`; the body now uses `Self.Content`.
  timestamp: 2026-10-11T20:56:23.159579+00:00
- actor: claude-code
  id: 01m4pc1ajmts6nbs4tf5q8vznn
  text: |-
    ### implement — changed
    - evidence: `swift test` 1080 tests in 118 suites passed (1 known issue that HostedLayoutExpectationsTests expects), PackageStructureTests 104 tests passed, exit 0. Load average 157.78 at start, 136.89 at end. Files: Sources/AgentViewKit/Activity/ActivityTimeline.swift, Connections/ConnectionStatusChip.swift, Items/SharedSymbol.swift, Status/StateBanner.swift, Status/StatusBar.swift, Status/TaskListView.swift, Thread/ThreadMinimapView.swift; Tests/AgentViewKitTests/Activity/ActivityTimelineHostedTests.swift, Items/SymbolConceptTests.swift, Thread/ThreadMinimapViewHostedTests.swift, new Status/StatusBarColorTests.swift, new Thread/ThreadMinimapTickMarkTests.swift.
    - next: /review
  timestamp: 2026-10-11T20:56:26.452377+00:00
depends_on:
- 01M4NPHNFGP5JDZS02XHHE6BE3
position_column: doing
position_ordinal: '80'
title: 'SF Symbols: show each status with a symbol, not with color only'
---
## What
An audit on 2026-10-11 found indicators that show their meaning only with color. Paths are below `Sources/AgentViewKit/`.

## Work
- [x] Activity timeline: show the tool status with its status symbol, and add the status to the accessibility label (`Activity/ActivityTimeline.swift:209`, `:247-248`).
- [x] MCP connection chip: replace the colored dot with a status symbol (`Connections/ConnectionStatusChip.swift:42`). Localize its labels (`:80-84`).
- [x] Plan priority: use a different symbol for each priority level, not the same `flag.fill` in different colors (`Status/TaskListView.swift:171-174`).
- [x] Status bar: a failure banner uses the error color, not `theme.accent` for each banner (`Status/StatusBar.swift:37`).
- [x] Thread minimap: the ticks show the status with color only (`Thread/ThreadMinimapView.swift:305-316` `tint(of:)`, the `Canvas` at `:152`). The accessibility elements of each tick exist only in DEBUG builds (`:156`). Give the status a signal that is not color (shape or symbol), and give release builds an accessible summary.
- [x] Tests for each change.