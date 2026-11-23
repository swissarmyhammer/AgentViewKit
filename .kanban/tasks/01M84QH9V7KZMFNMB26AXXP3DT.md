---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
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
- [ ] `AgentRowSourceIcon(.symbol(...), name:)` and `AgentRowSourceIcon(.image(name:bundle:), name:)` compile from a host module.
- [ ] Both cases have the width `EditorStyle.symbolColumnWidth`, so the title text of a row with a source icon starts at the same x as a row with a kit symbol.
- [ ] The accessibility label of the icon is the source name.
- [ ] `AgentRowList` and `AgentRowSection` have no API change.

## Tests
- [ ] Unit tests first (headless `swift test`), in a new file /Users/wballard/github/swissarmyhammer/AgentViewKit/Tests/AgentViewKitTests/Lists/AgentRowSourceIconTests.swift: the accessibility label is "Claude Code" for a symbol source and "Codex" for an image source; the fitted width of each case equals `EditorStyle.symbolColumnWidth` (use the sizing helpers of AgentViewKitTestSupport); `Source` equality.
- [ ] Screenshot gallery screen in /Users/wballard/github/swissarmyhammer/AgentViewKit/ScreenshotTests/Tests/ScreenshotTests: an `AgentRowList` with rows that show a source icon (one symbol source, one image source from a test asset) above rows with a kit symbol, so the title column shows aligned. Add the snapshot in HostedSnapshotTests.swift. Run: `HOME=$(mktemp -d) swift test --package-path ScreenshotTests`. Give the PNG paths for review.
- [ ] `swift test` passes with no new warning.

## Workflow
- Use /tdd -- write failing tests first, then implement to make them pass. #d212