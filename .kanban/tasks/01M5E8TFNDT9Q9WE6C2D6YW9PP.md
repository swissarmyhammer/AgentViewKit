---
assignees:
- claude-code
depends_on:
- 01M5E8S3KAQ7EV2C2K13Y1K31Q
position_column: todo
position_ordinal: a380
title: 'AVK-8z Code blocks: remove the editor background fill of EditorBlockFrame (EditorBlockChrome.swift:24) and use agentContentEdge (D113 answer 1)'
---
## Why

D113 answer 1 and `style.md` "How the steps apply": "Cards and panels in content (a permission request, a notice, an error, a code block, a request card) have no fill." Today `EditorBlockFrame` fills each code block with `editorTheme.editorBackground` through `agentContentSurface(_:radius:)` (`Sources/AgentViewKit/Code/EditorBlockChrome.swift:24`).

The terminal frame (`TerminalBlockFrame`, `EditorBlockChrome.swift:36-44`) gives the fill `palette[.background]` to the same `EditorBlockFrame`. This card does NOT decide the terminal fill. AVK-8aa does that. Keep the terminal fill as it is in this card.

## Files and lines

- `Sources/AgentViewKit/Code/EditorBlockChrome.swift:13-26` (`EditorBlockFrame`), `:62-64` (`editorBlockFrame()`).
- Users: `Sources/AgentViewKit/Code/CodeBlockView.swift`, and each other caller of `editorBlockFrame()` (find them with a search).
- Test: `Tests/AgentViewKitTests/Theme/EditorThemeViewsTests.swift:50-57` (the code block test expects the editor background pixel today).

## What to do

- [ ] Change `EditorBlockFrame`: when `fill` is `nil` (a code block), it clips to `AgentSurface.shape(radius: theme.radii.m)` and applies `.agentContentEdge(radius: theme.radii.m)`, with no fill. When `fill` has a value (the terminal frame), it keeps today's behavior until AVK-8aa, but it must not call `agentContentSurface`: draw `.background(fill, in: shape)` plus `.agentContentEdge(radius:)` in this one place, so that AVK-8ab can remove `agentContentSurface`.
- [ ] Change the DocC comment of `EditorBlockFrame` and `editorBlockFrame()`: a code block has no fill (D113).
- [ ] If the EditorKit editor in the block draws its own opaque editor background, record it in a comment on this card with the file and line in EditorKit. Do not change EditorKit in this card. Make a new small card if the editor must be clear.
- [ ] Change `EditorThemeViewsTests`: a `CodeBlockView` shows no `Role.editorBackground` pixel in the frame of the block, outside the editor text area. If the EditorKit editor paints the editor background, assert only on the frame padding area and record why.

## Acceptance

- No `agentContentSurface` in `EditorBlockChrome.swift`.
- The changed `EditorThemeViewsTests` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8