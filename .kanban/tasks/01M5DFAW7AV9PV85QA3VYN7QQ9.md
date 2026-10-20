---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dfe0zv8n6qh249p67c2qf1
  text: |-
    ### decision (testudoapp-4c, AVK-8 "Decisions for the plan")
    - Use `ConcentricRectangle` and the `.concentric` style of the SDK. `.containerConcentric` is not in the macOS 27 SDK. The peer corrected the research file and D110 (e).
  timestamp: 2026-10-20T20:18:20.283496+00:00
depends_on:
- 01M5DF892NSFBA3B087C5MVVT4
- 01M5D07S5WH2JTTWW8B56Y8Q6A
position_column: todo
position_ordinal: '9480'
title: AVK-8m Use concentric corners in place of fixed RoundedRectangle radii
---
## Why

D110 (e): concentric corners. A shape inside a container uses a radius that follows the radius of the container. Today the kit uses `RoundedRectangle(cornerRadius: theme.radii.x)` with a fixed token.

## Files and lines

- `Sources/AgentViewKit/Attachments/ArtifactView.swift` lines 63, 65.
- `Sources/AgentViewKit/Code/EditorBlockChrome.swift` lines 24, 26 (code blocks and command output).
- `Sources/AgentViewKit/Attachments/AttachmentChip.swift` line 52.
- `Sources/AgentViewKit/Diff/DiffView.swift` lines 260-262.
- `Sources/AgentViewKit/Citations/SourcesView.swift` lines 145-147.
- `Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift` lines 228-229.
- `Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift` lines 517-523. This file has changes in the work tree from AVK-7d (^56y8q6a). Do this file after that card is done.
- Capsules (`ToolCallView.swift:750`, `InlineCitation.swift:257`, `PendingRequestCountBadge.swift:85`, `ElicitationLayout.swift:159-163`) stay capsules.

## What to do

- [ ] Replace each `RoundedRectangle(cornerRadius:)` above with the concentric shape function of AVK-8b, with the same token as the fallback radius.
- [ ] Keep the fills and the strokes. Content keeps its standard backgrounds, for example `editorTheme.editorBackground` in `EditorBlockChrome` and `.background.secondary` in `ArtifactView`.
- [ ] Add no glass.

## Acceptance

- `rg 'RoundedRectangle\(cornerRadius' Sources/AgentViewKit` finds no match.
- The `RenderedPixels` tests in `Tests/AgentViewKitTests/Theme/EditorThemeViewsTests.swift` pass. The code block, the command output, the diff and the citation still draw the theme colors.
- All tests pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8