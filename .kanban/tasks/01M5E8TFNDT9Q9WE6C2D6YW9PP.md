---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5ee99dyymg8hjrsf6c1n921
  text: |-
    Research:
    - `editorBlockFrame()` has one caller: `CodeBlockView` (`Sources/AgentViewKit/Code/CodeBlockView.swift`). `TerminalBlockFrame` gives `EditorBlockFrame` the fill `palette[.background]` (TerminalView, CommandOutputView).
    - EditorKit editor background: the EditorKit checkout (`.build/checkouts/EditorKit/Sources/EditorSwiftUI`, `EditorCore`) does not draw `editorBackground` or `gutterBackground` behind the text. A search for `editorBackground`, `isOpaque`, `drawsBackground` and `backgroundColor` finds only `EditorInTextJumpOverlay.swift` (the foreground of the jump label), `InlineWidgetRenderKey.swift` (a cache key) and `HighlightStyle.swift` (the selection). Thus the editor is clear, and the frame gave the only fill. No EditorKit card is necessary.
    - `ImageRenderer` does not draw the `NSViewRepresentable` editor. Thus the `EditorThemeViewsTests` check sees only the header, the divider and the frame. A hosted check with `ContentSurfaceHostedProbe.expectBackdropShowsInsideTheEdge(...)` reads the window cache, which draws the editor.
    - The header row keeps `editorBlockBar()` (status bar background). AVK-8ac (^6dvspvv) removes it, not this card.
  timestamp: 2026-10-21T05:17:30.942767+00:00
- actor: claude-code
  id: 01m5eekxqpx2b1rq2xx004xshd
  text: |-
    Implementation:
    - `EditorBlockFrame` clips to `AgentSurface.shape(radius: theme.radii.m)`, draws `.background(fill ?? .clear, in: shape)` and applies `.agentContentEdge(radius: theme.radii.m)`. A code block (`fill == nil`) has no fill. The terminal frame keeps `palette[.background]` until AVK-8aa. `EditorBlockChrome.swift` has no `agentContentSurface` now.
    - What did not work: the `ImageRenderer` check in `EditorThemeViewsTests` (`!pixels.contains(Role.editorBackground)`) passed before the change. `ImageRenderer` does not draw the `NSViewRepresentable` editor, and the editor covers the frame below the header, so no frame pixel shows. The new test `theCodeBlockFrameHasNoEditorBackground` has the `.hostedSerially` trait and reads the window cache (`GlassRenderProbeHostedTests.cachedPixels`). It failed before the change and passes after it.
    - New hosted test `Tests/AgentViewKitTests/Code/CodeBlockViewSurfaceHostedTests.swift` uses `ContentSurfaceHostedProbe.expectBackdropShowsInsideTheEdge(...)` with both Reduce Transparency values. It failed before the change and passes after it. The EditorKit editor is clear, so no EditorKit card is necessary.
  timestamp: 2026-10-21T05:23:19.414880+00:00
- actor: claude-code
  id: 01m5eekzer17b9svqj5g7hmxvx
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Code/EditorBlockChrome.swift, Tests/AgentViewKitTests/Theme/EditorThemeViewsTests.swift, Tests/AgentViewKitTests/Code/CodeBlockViewSurfaceHostedTests.swift (new); `swift test`: 1449 tests in 179 suites passed, 2 known issues (existed before), plus 173 tests in 23 suites passed; only the mlx bundle warning (existed before).
    - next: /review
  timestamp: 2026-10-21T05:23:21.176847+00:00
- actor: claude-code
  id: 01m5eerx3721avesb7epnxfrvh
  text: |-
    ### test — green
    - evidence: swift test (full suite, one run, 107 s wall). Exit code 0. PackageStructureTests target: 173 tests in 23 suites passed (19.9 s). AgentViewKitTests: 1449 tests in 179 suites passed (71.1 s) with 2 known issues (the 2 known issues from before). CodeBlockViewSurfaceHostedTests passed. 0 failures, 0 skipped.
    - warnings: only the mlx bundle build warning ("missing creator for mutated node ... mlx-swift_Cmlx.bundle"), which existed before. No new warning.
    - next: review
  timestamp: 2026-10-21T05:26:02.599860+00:00
depends_on:
- 01M5E8S3KAQ7EV2C2K13Y1K31Q
position_column: doing
position_ordinal: '80'
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

- [x] Change `EditorBlockFrame`: when `fill` is `nil` (a code block), it clips to `AgentSurface.shape(radius: theme.radii.m)` and applies `.agentContentEdge(radius: theme.radii.m)`, with no fill. When `fill` has a value (the terminal frame), it keeps today's behavior until AVK-8aa, but it must not call `agentContentSurface`: draw `.background(fill, in: shape)` plus `.agentContentEdge(radius:)` in this one place, so that AVK-8ab can remove `agentContentSurface`.
- [x] Change the DocC comment of `EditorBlockFrame` and `editorBlockFrame()`: a code block has no fill (D113).
- [x] If the EditorKit editor in the block draws its own opaque editor background, record it in a comment on this card with the file and line in EditorKit. Do not change EditorKit in this card. Make a new small card if the editor must be clear.
- [x] Change `EditorThemeViewsTests`: a `CodeBlockView` shows no `Role.editorBackground` pixel in the frame of the block, outside the editor text area. If the EditorKit editor paints the editor background, assert only on the frame padding area and record why.

## Acceptance

- No `agentContentSurface` in `EditorBlockChrome.swift`.
- The changed `EditorThemeViewsTests` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8