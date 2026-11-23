---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m84srb6x73rdd4pz4hebwpbx
  text: |-
    Implementation notes (implement step).

    - New public view: Sources/AgentViewKit/Lists/AgentRowSourceIcon.swift. `Source` is `Hashable, Sendable` (EditorSymbol and Bundle are both Sendable, so the doc comment needs no note).
    - Size of an image source: the view puts a hidden SF Symbol in the font of the row, and fits the image in an overlay on it. Thus the image has the size of a symbol of the font of the row. The font of a row of the kit and of the TestudoApp `SessionRowLabel` is the `ui` font of the theme, so the image has the symbol size of the `ui` font. The view does not set a font itself: a `.font` on the icon would override the font of the host label, and then the symbol source and the title could have different sizes. EditorKit `EditorToolbarItemHeightTemplate` uses the same hidden-template pattern.
    - The rule of AgentSymbol.swift says that no other source file writes a symbol name and that the table writes each name one time. Thus the hidden symbol is `AgentSymbol.sizeTemplate = notChosen` ("circle"). It writes no new name.
    - The kit symbol case draws with `EditorSymbolImage(_:)`. Both cases go through `.symbolColumn()`, and the icon is one accessibility element with the label `name`.
    - Unit tests: Tests/AgentViewKitTests/Lists/AgentRowSourceIconTests.swift (6 tests). RED: first a missing type (compile error), then a skeleton with `EmptyView()`, where the 2 label tests and the 2 width cases failed. The width test sets `symbolColumnWidth` to 40 (not the default 22), so an icon with a width of its own fails. The `Source` arguments of a parameterized test must be `nonisolated static`, else the @Test macro reads a MainActor static and does not compile.
    - Gallery: ScreenshotTests now has a resource, Resources/GalleryAssets.xcassets with `SampleSourceIcon` (a generic SVG, not a real brand mark). ScreenshotTests/Package.swift processes it. SwiftPM compiles the catalog with actool, and `Image(name, bundle: .module)` finds the image. The fixture file imports AgentViewKit with no `@testable`, so the public API compiles from a host module.
    - `AgentRowList` takes `id: KeyPath<Item, String>`, so the gallery row uses `\.title` as its id.
  timestamp: 2026-11-23T18:12:39.773300+00:00
- actor: claude-code
  id: 01m84ssbnpt0d0bpvmv2xw0sjf
  text: |-
    ### implement — changed
    - evidence: 7 files and 1 asset catalog. New: Sources/AgentViewKit/Lists/AgentRowSourceIcon.swift, Tests/AgentViewKitTests/Lists/AgentRowSourceIconTests.swift, ScreenshotTests/Tests/ScreenshotTests/SourceIconGalleryFixtures.swift, ScreenshotTests/Tests/ScreenshotTests/Resources/GalleryAssets.xcassets (SampleSourceIcon). Changed: Sources/AgentViewKit/Items/AgentSymbol.swift (sizeTemplate), Sources/AgentViewKit/Lists/AgentRowList.swift (#Preview "Sections" only), ScreenshotTests/Package.swift (resources), ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift (theSourceIconsOfTheRowsOfARowList). Headless `swift test`: 1651 tests in 187 suites pass plus 54 tests in 11 suites, no code warning. Gallery (temp HOME): 42 tests in 4 suites pass. PNGs: ~/Library/Caches/AgentViewKit/screenshot-check/generated/HostedSnapshotTests/row-source-icons-light.png and row-source-icons-dark.png. In the PNGs, the symbol source, the image source and the kit symbols stand in one column, and the titles start at one x.
    - next: /review
  timestamp: 2026-11-23T18:13:13.014963+00:00
- actor: claude-code
  id: 01m84swhk3dx4a03kqgfm9rvhq
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 3318090e). 7 files reviewed. 0 findings, 0 confirmed, 0 refuted, 0 failed. No prior Review Findings section. Implement evidence: swift test 1651 + 54 pass; screenshot gallery 42 pass; PNGs row-source-icons-light and row-source-icons-dark.
    - next: The task moves to done.
  timestamp: 2026-11-23T18:14:57.379598+00:00
position_column: done
position_ordinal: ffffffff9580
title: 'AgentRowSourceIcon: a leading source icon for a row in the symbol column'
---
## What
TestudoApp decision D212 (design /Users/wballard/github/swissarmyhammer/TestudoApp/features/session-import-redesign.md, 5.1, 5.2 and 6): a row of the section "Other Agents" and a Search result row show the icon of the source (Claude Code or Codex).

Research result: `AgentRowList<Item, Row: View, Footer: View>` gives no row content. The host builds each row. TestudoApp builds a session row in /Users/wballard/github/swissarmyhammer/TestudoApp/Sources/SAHKit/Layout/ViewSidebar.swift (`SessionRowLabel`: a `Label` with the title and the icon `SessionStateIndicator`). The kit puts leading symbols in the symbol column with EditorKit `symbolColumn()` (EditorKit/Sources/EditorStyle/SymbolColumn.swift), for example Sources/AgentViewKit/Activity/ActivityTimeline.swift and Sources/AgentViewKit/Code/CodeBlockView.swift.

Design choice: do NOT change `AgentRowList` or `AgentRowSection`. Add one small public view that the host puts as the icon of its row label. This is the smallest API, it keeps rows as host views, and the same view works in the Search row.

Create /Users/wballard/github/swissarmyhammer/AgentViewKit/Sources/AgentViewKit/Lists/AgentRowSourceIcon.swift:
- `public struct AgentRowSourceIcon: View` with `public enum Source: Hashable, Sendable { case symbol(EditorSymbol); case image(name: String, bundle: Bundle?) }` (if `EditorSymbol` is not `Sendable`, drop `Sendable` and say why in the doc comment).
- `public init(_ source: Source, name: String)`: `name` is the localized source name, for example "Claude Code".
- The body draws `.symbol` with `EditorSymbolImage(_:)` and `.image` with `Image(name, bundle:)` `.resizable().scaledToFit()` at the symbol size of the `ui` font. Both use `.symbolColumn()`, so the title after the icon starts at the same x as in the other rows of the kit.
- VoiceOver: the accessibility label is `name`. The host combines the row, so the row reads "<name>, <title>".
- The kit writes no source symbol name: the host gives the `EditorSymbol` or the asset (the rule of Sources/AgentViewKit/Items/AgentSymbol.swift).

Add one row with the icon to `#Preview("Sections")` of /Users/wballard/github/swissarmyhammer/AgentViewKit/Sources/AgentViewKit/Lists/AgentRowList.swift. Do not change Sources/AgentViewKit/StatusLine/*.

## Acceptance Criteria
- [x] `AgentRowSourceIcon(.symbol(...), name:)` and `AgentRowSourceIcon(.image(name:bundle:), name:)` compile from a host module.
- [x] Both cases have the width `EditorStyle.symbolColumnWidth`, so the title text of a row with a source icon starts at the same x as a row with a kit symbol.
- [x] The accessibility label of the icon is the source name.
- [x] `AgentRowList` and `AgentRowSection` have no API change.

## Tests
- [x] Unit tests first (headless `swift test`), in a new file /Users/wballard/github/swissarmyhammer/AgentViewKit/Tests/AgentViewKitTests/Lists/AgentRowSourceIconTests.swift: the accessibility label is "Claude Code" for a symbol source and "Codex" for an image source; the fitted width of each case equals `EditorStyle.symbolColumnWidth` (use the sizing helpers of AgentViewKitTestSupport); `Source` equality.
- [x] Screenshot gallery screen in /Users/wballard/github/swissarmyhammer/AgentViewKit/ScreenshotTests/Tests/ScreenshotTests: an `AgentRowList` with rows that show a source icon (one symbol source, one image source from a test asset) above rows with a kit symbol, so the title column shows aligned. Add the snapshot in HostedSnapshotTests.swift. Run: `HOME=$(mktemp -d) swift test --package-path ScreenshotTests`. Give the PNG paths for review.
- [x] `swift test` passes with no new warning.

## Workflow
- Use /tdd -- write failing tests first, then implement to make them pass. #d212