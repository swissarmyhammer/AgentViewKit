---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4q85mwg4120rj9ehvtdcx37
  text: 'Research: these symbol images write the same chain (hierarchical mode, symbol weight, a Color from the theme): CompactionEntryView header, ErrorView card, SessionNoticeBanner, ActivityTimeline row (appearance.tint is a Color: Color.secondary or editorTheme.severityError). Each of these files has one Image(systemName:) only. ToolCallView (kind symbol, disclosure) and DiffView use foregroundStyle(.secondary), a hierarchical shape style, not a theme Color, so they are not the same chain; they stay as they are. SpeechInputButton, ElicitationLayout, TerminalView, ConnectionStatusChip, AgentInfoHeader, EntryTimingView, ReasoningView, ConversationEmptyState, SourcesView have no hierarchical mode, so they are not the same chain.'
  timestamp: 2026-10-12T05:08:08.208209+00:00
- actor: claude-code
  id: 01m4q8etjtazc1acygnwh2pfqt
  text: 'Implementation done. RED: SharedSymbolTreatmentTests.eachStatusSymbolDrawsWithTheSharedStatusSymbolImage failed at CompactionEntryView.swift:106, ErrorView.swift:64, SessionNoticeBanner.swift:125 and ActivityTimeline.swift:214. GREEN: each of these four symbol images is now a StatusSymbolImage. The four files are in statusSymbolFiles. ActivityTimeline is in the list also, because its row symbol wrote the same chain with a Color (Color.secondary or editorTheme.severityError). For that reason, the doc of StatusSymbolImage.color now says "a color of the EditorKit theme, or Color.secondary for a row with no state color". ToolCallView and DiffView stay as they are: they use foregroundStyle(.secondary), which is a hierarchical shape style and not a Color. The build shows one warning that is not from the source: "missing creator for mutated node: .build/out/Products/Debug/mlx-swift_Cmlx.bundle/Contents/MacOS". This warning comes from the build system for the mlx-swift bundle, and was there before this change.'
  timestamp: 2026-10-12T05:13:08.954177+00:00
- actor: claude-code
  id: 01m4q8ez78wjt00dbt13mtvn4v
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Items/CompactionEntryView.swift, Sources/AgentViewKit/Items/ErrorView.swift, Sources/AgentViewKit/Status/SessionNoticeBanner.swift, Sources/AgentViewKit/Activity/ActivityTimeline.swift, Sources/AgentViewKit/Items/StatusSymbolImage.swift (doc), Tests/PackageStructureTests/SharedSymbolTreatmentTests.swift. `swift test`: 1153 tests in 128 suites pass, 2 known issues (the expected-failure tests that were there before), exit 0. Load average at start 20.55 22.46 21.86, at end 25.23 22.71 21.98. No UI tests run.
    - next: /review
  timestamp: 2026-10-12T05:13:13.704828+00:00
position_column: doing
position_ordinal: '80'
title: Use StatusSymbolImage for the other status symbols
---
## What
`Sources/AgentViewKit/Items/StatusSymbolImage.swift` (from ^r9sqgxj) holds the treatment of a status symbol: the hierarchical rendering mode, the symbol weight of the kit theme and a theme color. Other views still write the same modifier chain on their own symbol image.

## Work
- [x] `Items/CompactionEntryView.swift` (header symbol): hierarchical, status color, symbol weight. Use `StatusSymbolImage`.
- [x] `Items/ErrorView.swift` and `Status/SessionNoticeBanner.swift`: examine each symbol image with the hierarchical mode, a theme color and the symbol weight. Use `StatusSymbolImage` where the chain is the same.
- [x] Add each changed file to `SharedSymbolTreatmentTests.statusSymbolFiles` (Tests/PackageStructureTests).
- [x] Keep `SymbolRenderingModeTests` green.