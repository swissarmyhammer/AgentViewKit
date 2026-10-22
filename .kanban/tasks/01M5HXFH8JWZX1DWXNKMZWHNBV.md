---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5jzrqxxt05tf41hz3gjj9g4
  text: 'Research: none of the state enums have `allCases` — FoundationModelsACP `ToolCallStatus`, `PlanEntryStatus`, `PlanEntryPriority` and `NoticeSeverity` each carry an `.unknown(String)` case. So each preview reads a PreviewFixtures list, and a test checks that the list covers every symbol of the kit''s map, including the unknown case and the lost tool status (`ToolStatusSymbol.lostWireValue`). StatusSymbolImage is generic (name + color). Its states are the model enums that its callers map: plan entry status and priority (TaskListView) and notice severity (NoticeBanner). DecorativeSymbolImage draws two symbols: `AgentInfoHeader.symbol` and the symbol of `ConversationEmptyContent.standard`. Size: no caller sets a font, image scale or control size on these icons, so the kit draws them at the body font of the row, which is `editorTheme.proseFont`. The sheet takes its size from that theme font. Preview strings must not write SF Symbol names (SymbolNameTests), so they use SharedSymbol and the kit''s maps.'
  timestamp: 2026-10-22T23:40:00.829316+00:00
- actor: claude-code
  id: 01m5k0155b4tjbrngq2kpys2fw
  text: 'Implementation landed. Each of the three files now has one `#Preview`, and each draws its grid with a new shared view, `PreviewSymbolSheet` (Sources/AgentViewKit/Infrastructure/PreviewSymbolSheet.swift). The sheet takes a title, the states and a label function. Each row is an icon and the name of its state, laid out in a SwiftUI `Grid` with theme spacing and set in `editorTheme.proseFont`. The icon size comes from the theme: no caller of these views sets a font, image scale or control size, so the kit draws them at the row''s body font, which is `proseFont`. That means the kit uses one icon size today. The card asks for "sizes" (plural), but the sheet draws only that one size and invents no others. New PreviewFixtures: `unknownWireValue`, `toolCallStatuses` (with the lost status and an unknown status), `planEntryStatuses`, `planEntryPriorities`, `noticeSeverities`, and `HeaderSymbol`/`headerSymbols`. I wrote 5 PreviewFixturesTests first and watched them fail to compile on the missing members. Each test checks that its list covers every symbol of the kit''s map and that every label is unique. The header test checks the list against `AgentInfoHeader.symbol` and `ConversationEmptyContent.standard.systemImage`. StatusSymbolImage.swift has one private helper, `StatusSymbolSheets`, which reads `editorTheme` for the colors. It also needed `import EditorSwiftUI`/`EditorTheme`.'
  timestamp: 2026-10-22T23:44:36.523984+00:00
- actor: claude-code
  id: 01m5k018w1kdcyv8nbkyzm4edd
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Infrastructure/PreviewSymbolSheet.swift (new), Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift, Sources/AgentViewKit/Items/ToolStatusImage.swift, Sources/AgentViewKit/Items/StatusSymbolImage.swift, Sources/AgentViewKit/Items/DecorativeSymbolImage.swift, Tests/AgentViewKitTests/Infrastructure/PreviewFixturesTests.swift. The full `swift test` exits 0 with 0 failures: 1664 tests in 203 suites (3 known issues, already declared with withKnownIssue), plus 219 PackageStructure tests and 1 ReadmeSnippets test. The 5 new fixture tests failed first (RED) and then passed. No compiler warnings. The one build-system line "missing creator for mutated node … mlx-swift_Cmlx.bundle" comes from a dependency's bundle and was already there.
    - next: /review
  timestamp: 2026-10-22T23:44:40.321783+00:00
- actor: claude-code
  id: 01m5k06qdygg914k12r4atmpa5
  text: |-
    ### test — green
    - evidence: touched the 5 changed Sources files and PreviewFixturesTests.swift, then `swift test` (exit 0): 1664 tests in 203 suites passed, 0 failed, 0 skipped. PreviewFixturesTests passed. The 3 known issues are intentional withKnownIssue negative tests (SnapshotStoreTests, HostedLayoutExpectationsTests, ThemeHeightExpectationsTests). Compiler warnings: only the known SwiftPM mlx-swift "missing creator" notice; none from project code.
    - next: review/commit
  timestamp: 2026-10-22T23:47:39.070125+00:00
position_column: doing
position_ordinal: '8380'
title: 'AVK-14f Add one #Preview sheet for the status icons'
---
## Goal

The user examines the look of each component in the Xcode canvas. These small icon views have no `#Preview`:

- `Sources/AgentViewKit/Items/ToolStatusImage.swift` — `ToolStatusImage`
- `Sources/AgentViewKit/Items/StatusSymbolImage.swift` — `StatusSymbolImage`
- `Sources/AgentViewKit/Items/DecorativeSymbolImage.swift` — `DecorativeSymbolImage`

## Change

- [x] Add one `#Preview` in each file. Each preview shows a grid of all the states of its view, with the name of each state next to the icon. Use the enums of the model, with `allCases` where the type has it, so that a new state shows without a change to the preview.
- [x] Show the icons at the sizes that the kit uses.

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14