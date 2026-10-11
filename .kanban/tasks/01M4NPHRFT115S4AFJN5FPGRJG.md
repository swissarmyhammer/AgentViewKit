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
- actor: claude-code
  id: 01m4peezahwxyj1dvkxytd35kq
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (c9cb4dc). 5 findings, 5 confirmed, 0 refuted. Sources/AgentViewKit/Activity/ActivityTimeline.swift:220, Sources/AgentViewKit/Items/ToolCallView.swift:442, Sources/AgentViewKit/Thread/ThreadMinimapView.swift:63, Sources/AgentViewKit/Thread/ThreadMinimapView.swift:85, Sources/AgentViewKit/Thread/ThreadMinimapView.swift:454
    - next: implement the 5 open items in the "Review Findings (2026-10-11 16:31)" section. The task stays in review.
  timestamp: 2026-10-11T21:38:50.833081+00:00
- actor: claude-code
  id: 01m4pefcsb7fzjw2dvqm71r82s
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — status symbols in the activity timeline, MCP chip, plan priority, failure banner color, minimap tick shapes
    - test: green — swift test, 1080 tests passed, 1 expected known issue, load average 150 to 180; the test step made ToolCallBody Equatable and added a mount settle wait in ToolCallViewHostedTests
    - commit: c9cb4dc
    - review: findings — Sources/AgentViewKit/Activity/ActivityTimeline.swift:220, Sources/AgentViewKit/Items/ToolCallView.swift:442, Sources/AgentViewKit/Thread/ThreadMinimapView.swift:63, Sources/AgentViewKit/Thread/ThreadMinimapView.swift:85, Sources/AgentViewKit/Thread/ThreadMinimapView.swift:454
  timestamp: 2026-10-11T21:39:04.619875+00:00
- actor: claude-code
  id: 01m4pgr734q8zgfb30hvzakmdm
  text: |-
    Review findings fixed (not committed).
    - Status image: new `Items/ToolStatusImage.swift` (`ToolStatusImage(status:)`: symbol, theme weight, status color). `ActivityEntryRow` and the `ToolCallView` row use it. The row keeps its symbol effects.
    - Renderer identity: `KeyedViewRegistry` keeps a `Registration` for each key: the renderer and an `ID` (key + a new UUID token for each `register` call). `registration(for:)` and `ToolCallRegistry.registration(named:)` are internal. `ToolCallBody` keeps `renderer` and `registrationID` as two values, and `==` compares `registrationID`. The old doc text "both use a registered view or both use the default body" is gone. New test `ToolCallViewHostedTests.aSwapOfTheRegisteredViewRefreshesTheExpandedBody` (RED before the fix: the old view stayed; GREEN after).
    - Status isolation: `ToolCallView.body` no longer reads the status. A new private `ToolCallHeader` view (the row, with the row counter) and a `ToolCallLabel` modifier (the label of the call) read the status. So a status change does not give `ToolCallBody` a new value.
    - Minimap: `TickMark.cancelledBandCount = 3`; the cancelled bar is `rect.insetBy(dx: 0, dy: rect.height / cancelledBandCount)`. swiftlint `no_magic_numbers` (allowed 0, 1, -1, 100) gives no finding in the whole file.
    - Accessibility chain: new internal `View.valueElement(label:value:identifier:)` in `Infrastructure/ValueElement.swift`. `ThreadMinimapView` and `ConnectionStatusChip` use it.

    What did not work, and discoveries:
    - First try: `ToolCallBody` kept one `Registration?` value (function inside a struct). Probes showed that SwiftUI then evaluated the body with no `==` call; `aStatusUpdateEvaluatesTheRowAndNotTheExpandedBody` failed 3 times of 4. With the function and the identity as two values, SwiftUI calls `==` again.
    - Even then, the status test failed one time in a full run at load 170. Cause: the row body read the status, so each status change gave `ToolCallBody` a new value, and SwiftUI sometimes skips `==`. The header/label split removes that path.
    - The late first-layout evaluation (the reason for the `settle` wait): probes show that after the mount the window changes the environment one or two times. `ToolCallView` reports `_theme, _editorTheme changed` (`editorTheme` is `any Theme`, which SwiftUI cannot compare), and on the first of these passes SwiftUI evaluated `ToolCallBody` with no `==` call. That is SwiftUI behavior for a new node; the kit cannot stop it. The `settle` wait stays, with no change to any wait limit.
    - A registered body evaluates again each time that the host view that holds `.toolCallView(named:)` evaluates, because each pass makes a new registration token. The Registries doc states this.
    - `ToolCallEntryViewHostedTests.theBodyShowsTheRawInputTheTextPartAndTheRawOutputOfTheEntry` failed one time in a filtered run at load 178 (the text part was not yet in the accessibility tree), and passed in the next runs. The test waits only for the output text.
  timestamp: 2026-10-11T22:18:50.852583+00:00
- actor: claude-code
  id: 01m4pgra0drhtfmv5nb4rwxva1
  text: |-
    ### implement — changed
    - evidence: `swift test` exit 0: 1081 tests in 118 suites passed (1 known issue that HostedLayoutExpectationsTests expects), PackageStructureTests 104 tests passed. Only warning: the SwiftPM "missing creator for mutated node" note for the mlx-swift bundle. Load average 146.72 at start, 156.94 at end. Files: Sources/AgentViewKit/Activity/ActivityTimeline.swift, Connections/ConnectionStatusChip.swift, Items/ToolCallView.swift, new Items/ToolStatusImage.swift, new Infrastructure/ValueElement.swift, Thread/Registries.swift, Thread/ThreadMinimapView.swift; Tests/AgentViewKitTests/Items/ToolCallViewHostedTests.swift.
    - next: /review
  timestamp: 2026-10-11T22:18:53.837869+00:00
- actor: claude-code
  id: 01m4phg9cgx8sqfnq247vbwda9
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (7da4a29). 2 findings (2 confirmed, 1 refuted): Sources/AgentViewKit/Thread/Registries.swift:31, Sources/AgentViewKit/Thread/Registries.swift:35
    - next: Remove the assign-only properties `key` and `token` in Registries.swift, or read them. Then run the review again.
  timestamp: 2026-10-11T22:31:59.632905+00:00
- actor: claude-code
  id: 01m4phgjsgazpfzt3kv0jnbask
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — ToolStatusImage, renderer identity in KeyedViewRegistry, ToolCallHeader / ToolCallLabel, cancelledBandCount, valueElement helper; 5 findings checked
    - test: green — swift test, 1081 tests passed, 1 expected known issue, load average 139 to 155
    - commit: 7da4a29
    - review: findings — Sources/AgentViewKit/Thread/Registries.swift:31, Sources/AgentViewKit/Thread/Registries.swift:35
  timestamp: 2026-10-11T22:32:09.264475+00:00
- actor: claude-code
  id: 01m4phx5kef5nmyyczz8x8hnk2
  text: 'Dead-code findings fixed (not committed). Cause: `Registration.ID` stored `key` and `token`, and only the synthesized Hashable read them. Fix: the nested `ID` struct is gone. `Registration.id` is now one `UUID` token (a new token for each `register` call). `ToolCallBody` reads `registration?.id` and its written `==` compares it, so the token has an explicit reader. The key was not necessary in the identity: no two registrations have the same token. `ToolCallRegistry.Registration.ID` in ToolCallView.swift now resolves to `UUID` through `Identifiable`; no change in that file. The rest of Registries.swift has no other stored property that only gets an assignment (`registrations` and `renderer` have readers).'
  timestamp: 2026-10-11T22:39:01.742991+00:00
- actor: claude-code
  id: 01m4phx81w5639ae7kq46p4dzh
  text: |-
    ### implement — changed
    - evidence: `swift test` exit 0: 1081 tests in 118 suites passed (1 known issue that HostedLayoutExpectationsTests expects). `aSwapOfTheRegisteredViewRefreshesTheExpandedBody` and `aStatusUpdateEvaluatesTheRowAndNotTheExpandedBody` passed. Only warning: the SwiftPM "missing creator for mutated node" note for the mlx-swift bundle. Load average 96.82 at start, 120.05 at end. File: Sources/AgentViewKit/Thread/Registries.swift.
    - next: /review
  timestamp: 2026-10-11T22:39:04.252994+00:00
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

## Review Findings (2026-10-11 16:31)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 14 file(s) reviewed, 6 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

- [x] `Sources/AgentViewKit/Activity/ActivityTimeline.swift:220` `reuse/reuse` — The timeline row builds its status image by hand: the status symbol name, the theme weight, and the status color. `ToolCallView` already builds the same status image in its header. The copy can drift when the status image changes, for example its weight or its color source. Add one small view, such as `ToolStatusImage(status:)`, that takes the status and reads the theme. Use it in `ActivityEntryRow` and in `ToolCallView.header`. Keep the header's extra symbol effects on the header only.
- [x] `Sources/AgentViewKit/Items/ToolCallView.swift:442` `completeness/invariant-propagation` — The Equatable check on ToolCallBody compares only whether each renderer is nil. Two different non-nil registered renderers compare equal. If the registry gives a different renderer for the same tool name while the entry object is unchanged, SwiftUI skips the body and the row keeps the old renderer output. The fix covers the nil/non-nil case only. Pass a value that identifies the renderer, such as the registry generation or a registration token, and compare it in `==`. Alternatively, document that a renderer change for an existing tool name needs a new entry object, and add a test that a renderer swap updates a mounted expanded body.
- [x] `Sources/AgentViewKit/Thread/ThreadMinimapView.swift:63` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/ThreadMinimapView.swift:85` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/ThreadMinimapView.swift:454` `reuse/reuse` — The new `valueElement` helper repeats the accessibility chain of `ConnectionStatusChip.body`: `accessibilityElement(children: .ignore)`, label, value, `.isStaticText` trait, and identifier. It also copies the same comment about the static text role. Two copies of this chain can diverge, so a fix to one (for example, the role rule) does not reach the other. Move `valueElement` to a shared place in the kit, such as Sources/AgentViewKit/Infrastructure, next to `AccessibilityIdentifier`. Make it internal, not fileprivate. Use it from `ThreadMinimapView` and from `ConnectionStatusChip`, so the accessibility rule is written once.

## Review Findings (2026-10-11 17:26)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 8 file(s) reviewed, 6 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

- [x] `Sources/AgentViewKit/Thread/Registries.swift:31` `code-hygiene/dead-code-swift` — var.instance `key` is assignOnlyProperty.
- [x] `Sources/AgentViewKit/Thread/Registries.swift:35` `code-hygiene/dead-code-swift` — var.instance `token` is assignOnlyProperty.
