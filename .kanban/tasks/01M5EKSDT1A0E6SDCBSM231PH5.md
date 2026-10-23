---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5ftt8sen5kqe74h7tt9pkqb
  text: |-
    Research done. The cause is in EditorKit, not in AgentViewKit and not in the window cache.

    Cause:
    - EditorKit `.build/checkouts/EditorKit/Sources/EditorText/EditorTextView.swift:368` (`EditorTextScaffold.init`) makes the text view with `EditorInputTextView(usingTextLayoutManager: true)` (class at EditorTextView.swift:797, an `NSTextView` subclass).
    - `configureForRowGrid()` (EditorTextView.swift:411) sets `isEditable`, `isRichText` and `delegate`. It does not set `drawsBackground`. The AppKit default of `NSTextView.drawsBackground` is `true`, and the default `backgroundColor` is `NSColor.textBackgroundColor`. Thus the text view fills its full frame with the system text background (white in light mode), and it reports `isOpaque == true`.
    - EditorKit sets `drawsBackground` or `backgroundColor` on this view at no location (search of `Sources/` for `drawsBackground` and `backgroundColor =` on macOS: no result for the text view). EditorKit gives no API to turn the fill off.
    - `GutterLaneView` draws no fill. This is why only the gutter shows the backdrop.

    AgentViewKit is clean: `EditorBlockFrame` (Sources/AgentViewKit/Code/EditorBlockChrome.swift) gives `fill ?? .clear`, and `editorBlockFrame()` passes `nil`. `CodeBlockView` and `EditorBlockHeader` draw no fill.

    Proof (a temporary probe test, now deleted): `CodeBlockView(code: "let x = 1\nprint(x)", language: "swift")` over the `GlassRenderProbeTests.backdrop` (230,25,76), window 320 x 160, `HostedViewHarness`, `RenderedPixels(cachingDisplayOf:)`. The view tree had:
    - `EditorInputTextView frame=(8.04, 77.5, 311.96, 32) opaque=true drawsBackground=true backgroundColor=Catalog color: System textBackgroundColor`
    - `GutterLaneView frame=(0, 77.5, 8.04, 32) opaque=false`
    Pixels at y = 100 pt (in the code rows): x = 1.5 (gutter) = (226,25,75,255), the backdrop; x = 21.5 ... 301.5 = (255,255,255,255), white. At y = 70 pt (header row) each x shows the backdrop (230,25,76,255). The property values are AppKit state, not a cache effect, so the fill also draws on a screen.

    Snapshot images: `code-block-light.png` and `code-block-dark.png` cannot show the fill. In them the backdrop is the window background, and it has the same color as the text background: light (255,254,255) and dark (40,40,40) in the full column x = 200 pt and in the full row y = 40 pt (sampled from the PNG files). No look change was made, so no image was recorded again.

    Why no fix in this repo: the only kit-side fix is to walk the AppKit views of the `EditorView` and set `drawsBackground = false` on the private `EditorInputTextView`. That reaches past the public EditorKit API into its private view tree. The card says do not change EditorKit from this repo, so I did not make a kit work-around.

    Necessary EditorKit change (card text for the EditorKit session):
    Title: "Let a host show the editor with no text background (EditorTextScaffold drawsBackground)"
    - In `EditorTextScaffold.configureForRowGrid()` (Sources/EditorText/EditorTextView.swift), set `textView.drawsBackground = false`, so that the text view draws no `textBackgroundColor` fill. If EditorKit wants an editor background, draw `theme.editorBackground` at the `EditorView` level, and give a public modifier (for example `.editorBackground(.hidden)` or an `EditorView` option) that a host such as AgentViewKit sets for a code block (D113: content gets no fill).
    - Test: host an `EditorView` over a known backdrop color, and check that a pixel in the text area (not the gutter) shows the backdrop; also check `firstTextView(in:)?.drawsBackground == false`.
    After EditorKit lands the change, AgentViewKit adds a hosted pixel test: a point in the text area of a `CodeBlockView` (for example x = 200 pt in the code rows) shows the backdrop, and uses the new modifier if EditorKit makes one.
  timestamp: 2026-10-21T18:15:44.686370+00:00
- actor: claude-code
  id: 01m5fttf7gz48jjx52aj6kz4ax
  text: |-
    ### implement — stuck
    - evidence: cause is in EditorKit: `Sources/EditorText/EditorTextView.swift:368` makes `EditorInputTextView` (an `NSTextView`), and `configureForRowGrid()` (EditorTextView.swift:411) leaves the AppKit default `drawsBackground = true` with `backgroundColor = textBackgroundColor`. Probe: `EditorInputTextView opaque=true drawsBackground=true`; text-area pixels (255,255,255,255), gutter pixel shows the backdrop (226,25,75,255). No AgentViewKit file changed (the temporary probe test was deleted). Full suite with the window monitor: 1544 tests in 194 suites passed with 3 known issues, plus 190 tests in 27 suites and 1 test in 1 suite; only the known mlx bundle build warning; on-screen test-process windows: 0. Snapshot images not changed: Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/code-block-{light,dark,increase-contrast,reduce-transparency}.png (the window background there has the same color as the text background, so the fill does not show).
    - next: a person moves the EditorKit card text in the comment above to the EditorKit board. After EditorKit sets `drawsBackground = false` (or gives a public modifier), add the hosted pixel test in this repo: a point in the text area of a `CodeBlockView` shows the backdrop.
  timestamp: 2026-10-21T18:15:51.280971+00:00
- actor: claude-code
  id: 01m5ftv5dtkeketxebcag7bf1m
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — cause is in EditorKit: Sources/EditorText/EditorTextView.swift:411 configureForRowGrid() keeps NSTextView drawsBackground=true (textBackgroundColor). EditorKit has no public API to turn the fill off. A person must add the EditorKit change, then this repo adds a hosted pixel test for the text area of CodeBlockView.
    - test: green — full suite with the window monitor, 1544 passed (3 known issues); on-screen test windows 0
    - commit: none — no file changed
    - review: not run
  timestamp: 2026-10-21T18:16:14.010508+00:00
- actor: claude-code
  id: 01m5n5d27025y3kktf0t4d7kzx
  text: |-
    From testudoapp-2c (2026-10-23): new user rule. Every kit component draws a transparent background by default, and the host's single app background shows through. A background is opt-in decoration.
    - The white fill of the code block's text area comes from EditorKit `EditorView` leaving `NSTextView.drawsBackground` on. testudoapp-2c has asked editorkit-28 to make it clear by default. When that EditorKit change lands: bump EditorKit, confirm the AVK snapshot tests pass (re-record only the code block and composer snapshots that change, and list them), and this card's cause is answered.
    - `TerminalBlockFrame` (EditorBlockChrome.swift:52) fills `terminalPalette[.background]` (AVK-8aa). Testudo is asking the user whether that stays or goes clear. Don't change it until the answer is relayed.
  timestamp: 2026-10-23T19:56:58.464205+00:00
- actor: claude-code
  id: 01m5nc9804wr65mm47vjdrwqd8
  text: 'EditorKit ^0apj6a2 (EditorKit main at 69d04fc, code f8ff1bc) removes the white fill of the code block''s text area: EditorTextView now sets drawsBackground = false, and Theme.editorBackground is gone, so the EditorKit editors are transparent by default. AVK adopts it in ^xqday3k. The hosted pixel test this card asked for now exists: EditorThemeViewsTests.theTextAreaOfACodeBlockShowsTheContentBehindTheBlock puts a CodeBlockView over a backdrop in a window and reads the cached pixels at the trailing end of the text view. It passes at 69d04fc and fails at the old pin 8e4d27a (checked in a scratch export of HEAD), so it holds the fix. plan.md "Open items" and Docs/decisions/visual-audit.md now say the item is answered; this card still closes in its own review.'
  timestamp: 2026-10-23T21:57:13.348792+00:00
position_column: doing
position_ordinal: '80'
title: Examine the white fill of the EditorKit text area in a code block (D113 answer 1)
---
Source: ^6dvspvv (AVK-8ac) implement step.

Problem: in the window cache, the EditorKit text area of a `CodeBlockView` shows opaque white. The color is not `editorBackground`. Only the gutter lets the backdrop through. This can be a real fill of the editor. D113 answer 1 forbids a custom fill behind a code block.

Do:
- Find where the white comes from (EditorKit text view background, `drawsBackground`, an NSScrollView background, or the window cache).
- If it is a real fill in AgentViewKit, remove it. If it is in EditorKit, write a card for the EditorKit session and record it here; do not change EditorKit from this repo.
- If it is only a result of the window cache, record the proof here and close this card.

Acceptance:
- The cause is recorded on this card with file:line.
- If the kit had the fill: a test shows that the backdrop shows inside the text area of a code block. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8