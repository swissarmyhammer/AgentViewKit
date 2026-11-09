---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m711af3fk1399t82jbpse732
  text: |-
    Research done. EK pin updated to main 8639885 in the root, ScreenshotTests and IntegrationTests (`swift package --package-path <p> update EditorKit`; the flag goes before the subcommand). `.symbolColumn()` is `.frame(width: editorStyle.symbolColumnWidth)` (EditorStyle/SymbolColumn.swift).

    Rows with a leading SF Symbol: PlanEntryRow (TaskListView, private width 16), ToolCallView row, TerminalView header, ActivityEntryRow, StatusTitleLayout (StatusBar banners, ErrorView, CompactionEntryView), EntryTimingView line, SourcesView label and SourceLink, ElicitationTabChip, AgentInfoHeader agent segment, ConversationEmptyHeader, and the Labels with `systemImage:` in content (PermissionView, ElicitationView, ElicitationURLConsentView, radio group, ToolCallTerminalLabel, ToolCallWaitingStatus, ImageView, AudioPlayerView, ArtifactView, AgentAuthView).

    Not changed, with the reason: AttachmentChip shows the file type icon of NSWorkspace (an NSImage, not an SF Symbol) at 28 pt x font scale, wider than the 22 pt column; the not-accepted mark of AttachmentChips is an icon-only label after the chip, not before text; SessionBreadcrumb choices are menu items, which the system menu draws; buttons are EK components; StatusCaption is EK `EditorStatusLabel`; trailing status and disclosure symbols stand after the text.

    Test plan: a headless unit test hosts each row in an NSHostingView with no window (as EK SymbolColumnTests does) and reads `fittingSize.width` at two values of `symbolColumnWidth`. The width must grow by the growth of the token.
  timestamp: 2026-11-09T20:52:14.063941+00:00
- actor: claude-code
  id: 01m711pjfaevvp5hp91jbdnkx2
  text: |-
    ### implement — changed
    - Each leading SF Symbol before text now uses `.symbolColumn()`: PlanEntryRow (private `statusSymbolWidth = 16` removed), ToolCallView row, TerminalView header, ActivityEntryRow, StatusTitleLayout (StatusBar, ErrorView, CompactionEntryView), EntryTimingView, SourcesView label and SourceLink, ElicitationTabChip, DecorativeSymbolImage (AgentInfoHeader, ConversationEmptyHeader).
    - New `SymbolColumnImage` and `Label(_:columnSymbol:)` (Sources/AgentViewKit/Items/SymbolColumnImage.swift). The content Labels use it: PermissionView (5), ElicitationView, ElicitationURLConsentView (2), radio group, ToolCallTerminalLabel, ToolCallWaitingStatus, ImageView, AudioPlayerView, ArtifactView, AgentAuthView.
    - Not changed (see the research comment for the reasons): AttachmentChip file icon (NSImage, 28 pt), icon-only not-accepted mark, SessionBreadcrumb menu items, UsageRingView (a drawn ring, not an SF Symbol), EK buttons and EK `EditorStatusLabel`, ThemedEmptyState.
    - Test: Tests/AgentViewKitTests/Theme/SymbolColumnRowTests.swift. It hosts 7 rows in an NSHostingView with no window and checks that the fitting width grows by the growth of `symbolColumnWidth`. RED 7/7 before the change, GREEN 7/7 after.
    - ViewValueLayoutTests lists the new EK field `symbolColumnWidth` (the EK bump made `theStyleHasNoPaddingByte` fail with 8 bytes not covered).
    - evidence: root `swift test` 1109 tests / 126 suites + 50 tests / 10 suites pass. `swift build --package-path IntegrationTests --build-tests` and `--package-path ScreenshotTests --build-tests` complete. No nested suite, gallery or UI test was run. The one warning is the SwiftPM notice "missing creator for mutated node" for the mlx-swift_Cmlx bundle of a dependency; it also shows before this change.
    - next: /review
  timestamp: 2026-11-09T20:58:50.730164+00:00
- actor: claude-code
  id: 01m711ty7bvd2at1ffhz63zcxe
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (commit fc341dcd). 1 finding confirmed, 1 refuted. Open: Tests/AgentViewKitTests/Theme/SymbolColumnRowTests.swift:85 `reuse/reuse` (the `fittingWidth(of:columnWidth:)` helper repeats the NSHostingView fitting-size helper of the integration tests).
    - AttachmentChip: the 28 pt icon is the file-type NSImage of NSWorkspace, not an SF Symbol glyph. The Problem and the Work limit the change to the leading SF Symbol. Thus `AttachmentChip.iconSide` is not a private width of a leading symbol, and the first acceptance item is satisfied. The acceptance items stay open because a finding is open.
    - next: /implement the finding, then /review again.
  timestamp: 2026-11-09T21:01:13.835518+00:00
- actor: claude-code
  id: 01m7123haf2reqmajnydjvwf0j
  text: |-
    Finding `reuse/reuse` (SymbolColumnRowTests fittingWidth) is closed. The existing helper was `StyleViewHost` in IntegrationTests/Tests/IntegrationTests/Style/StyleViewHost.swift. A second copy was `UsageRingViewHostedTests.fittingWidth(of:)`. EditorTestSupport has no windowless fitting-size helper. Both test targets link `AgentViewKitTestSupport`, so `StyleViewHost` moved there as a public type (Sources/AgentViewKitTestSupport/StyleViewHost.swift). `StyleRecord` stays in IntegrationTests (file renamed to Style/StyleRecord.swift). SymbolColumnRowTests and UsageRingViewHostedTests now call `StyleViewHost.fittingSize(of:)`. Four IntegrationTests files got `import AgentViewKitTestSupport`.

    ### implement — changed
    - evidence: root `swift test` 1109 tests in 126 suites passed, and 50 tests in 10 suites passed; `swift build --package-path IntegrationTests --build-tests` and `swift build --package-path ScreenshotTests --build-tests` complete. The only warning is the SwiftPM "missing creator for mutated node" note on the mlx-swift_Cmlx bundle of a dependency, no source warning.
    - files: Sources/AgentViewKitTestSupport/StyleViewHost.swift (new), Tests/AgentViewKitTests/Theme/SymbolColumnRowTests.swift, IntegrationTests/Tests/IntegrationTests/Style/StyleRecord.swift (was StyleViewHost.swift), Status/UsageRingViewHostedTests.swift, Status/StatusTitleLineHostedTests.swift, Style/StatusBarTests.swift, Style/SurfaceAndTileTests.swift, Style/ChangeHighlightEdgeHostTests.swift
    - next: review
  timestamp: 2026-11-09T21:05:55.535597+00:00
- actor: claude-code
  id: 01m712730c1gwsysfacks6w6z1
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit b109b4c6). 0 findings, 0 confirmed, 0 refuted (7 validators run). The prior finding `reuse/reuse` at Tests/AgentViewKitTests/Theme/SymbolColumnRowTests.swift:85 is checked. The engine noted that 5 code-hygiene tool rules found no file at the old path IntegrationTests/Tests/IntegrationTests/Style/StyleViewHost.swift. The commit moved that file to Sources/AgentViewKitTestSupport/StyleViewHost.swift, so this note is not a finding.
    - acceptance: item 1, `statusSymbolWidth` is not in Sources, Tests, IntegrationTests or ScreenshotTests. The AttachmentChip icon is a file-type NSImage, not an SF Symbol (the prior review agrees). Item 2, `swift test --filter SymbolColumnRowTests` passes 7/7 with no window. Item 3, the implement record gives root `swift test` 1109 tests in 126 suites and 50 tests in 10 suites passed, and both `--build-tests` builds complete. Item 4, no windowed test or gallery was run.
    - next: none. The card moves to done.
  timestamp: 2026-11-09T21:07:51.948132+00:00
position_column: done
position_ordinal: ffffffd080
title: The leading symbol of each row uses the symbol column of the style
---
## Problem
EditorKit main has `EditorStyle.symbolColumnWidth` (22 pt default) and `.symbolColumn()` (module EditorStyle) for the leading SF Symbol of a row (peer editorkit-9f, 2026-11-09). Some AVK rows put a symbol before their text with a private width (for example `TaskListView.statusSymbolWidth = 16`) or with no fixed width. Then the text of different rows does not line up.

## Work
- Update the EditorKit pin (gitignored Package.resolved files) to EK main.
- Find each AVK row that puts an SF Symbol before its text: TaskListView, the tool call row, the terminal row, the banners, the attachment chips, the plan rows and the others.
- Replace the private width or the missing width with `.symbolColumn()`. Remove the private width constants.
- Update the tests that read the old widths.

## Acceptance
- [x] No AVK row gives its leading symbol a private width.
- [x] A headless unit test or a layout test proves that the rows use the width of the style.
- [x] The root `swift test` passes. `swift build --package-path IntegrationTests --build-tests` and `swift build --package-path ScreenshotTests --build-tests` pass.
- [x] Do NOT run windowed tests or the gallery.

## Review Findings (2026-11-09 14:59)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 20 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Tests/AgentViewKitTests/Theme/SymbolColumnRowTests.swift:85` `reuse/reuse` — The new `fittingWidth(of:columnWidth:)` helper repeats a fitting-size helper that already exists in the integration tests. It wraps a view in an NSHostingView and reads its fitting width, which is the same capability the existing helper provides. Two copies can drift apart. Move the shared sizing code (NSHostingView fitting size) into the existing test support module, or into a helper both test targets can import, and call it from SymbolColumnRowTests and the integration tests. If the test targets cannot share code, state that reason in a comment on the new helper.
