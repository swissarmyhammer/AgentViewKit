---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5ysd7sbmrdgs07ah5hmtwpr
  text: |-
    Research (2026-10-27), with probes (scratch, deleted) and one ground-truth capture of the real demo window:

    1. Root cause is not the appearance. The hosted views are VibrantDark/DarkAqua as expected; setting the appearance of the window before the content, of NSApp, of the NSGlassEffectView or of its subviews changes nothing. The text of a sidebar List row, a grouped Form row in an inspector, a `.glass` button label and the composer mic/Send glyphs are VIBRANT layers: SwiftUI draws a white mask into the layer and puts a private `vibrantColorMatrix` CAFilter on it (dark: identity + 0.3 bias, light: identity - 0.4 bias, alpha passed through). The render server composites them. `cacheDisplay` (path A) ignores layer filters and backdrop layers, and redraws the vibrant text as its black mask: black on dark. Same reason for no glass, the white inspector rows and the missing mic/Send glyphs.
    2. Core Animation's own in-process renderer, `CARenderer` (public, Metal texture), draws the window's layer tree WITH filters, backdrops and Liquid Glass: GlassOverBackdrop changes colour under glass, the inspector rows go dark, the mic and Send buttons appear, the scroll pocket draws (no blank band), and two renders give identical pixels. The layer tree must be moved into a flipped, scaled container layer for the render and put back.
    3. CARenderer applies `vibrantColorMatrix` to the BACKDROP, not to the content, so vibrant text comes out mid gray (dark sidebar row 114 on 37 = 3.2:1; light 140 on 242 = 3.0:1; dark glass label 101 on 30). A real window does not do that: an XCUITest screenshot of the demo Gallery (AgentViewKitDemoUITests, run under the shared UI-test lock, Look popover set to Dark) shows sidebar row text 255 on 46 (13.6:1) in dark and 0 on 237 (17.9:1) in light, secondary text about 120/135. So the gallery render swaps each foreground vibrancy filter (identity matrix + uniform bias, alpha passed through) for a CIColorMatrix that paints the mask in white (bias > 0, dark) or black (bias < 0, light) for the render, then restores the filter. With that, dark sidebar text = 255 on 37 (15.3:1), inspector Form text 255 on 43 (14.2:1), dark glass label 255.
    4. Cannot be drawn in-process: a POPOVER (it is its own window that AppKit orders onto the screen; the harness never orders a window in, AVK-12), and the window server's exact vibrancy and colour space (needs Screen Recording permission, a system setting; CGPreflightScreenCaptureAccess() is false here).
    5. Plan: keep path A (`hostedPixels`, the recorded `__Snapshots__`) unchanged; add path C to ViewSnapshot (CARenderer of the hosted window) and move the review gallery to it.
  timestamp: 2026-10-27T13:39:45.579285+00:00
- actor: claude-code
  id: 01m5yt3esqh5dwvgtwqevj8b6s
  text: |-
    Implementation landed (2026-10-27): path C `ViewSnapshot.compositedPixels` (CARenderer of the hidden window, `LayerTreeRenderer`) with the label-paint swap (`VibrantLabelFilters`); the review gallery now uses it. Path A and `__Snapshots__` unchanged. Gallery dark sidebar now 255 on 37 (15.3:1; the real window measured 255 on 46), light 0 on 242 (real 0 on 237); dark inspector form text 255 on 43.

    What cannot be drawn in process, and why:
    1. A POPOVER (the Look popover of the Gallery columns, any `.popover`): AppKit shows it in its own window, ordered onto the screen. The harness never orders a window in and the test process has the `.prohibited` activation policy (AVK-12), so no popover window exists to render.
    2. The exact compositing of the window server: the desktop behind a translucent window, the display color space (the real screenshot is Display P3, the gallery is sRGB), and the server's own vibrancy math. Reading it needs a capture of the screen, which needs the Screen Recording permission, a system setting (`CGPreflightScreenCaptureAccess()` is false in this shell). The one ground truth used was an XCUITest window screenshot, run under the shared UI-test lock with a temporary test that was deleted afterwards.
    3. Vibrant labels are painted in the primary label color (white in dark, black in light) by alpha of their mask. A secondary vibrant label whose mask is opaque gray would show brighter than in a window; not measured.

    Dead ends, for the next agent: setting the appearance earlier (window before content, NSApp, NSGlassEffectView or its subviews) changes nothing; `CARenderer` on a layer that stays in the window draws at 1 px/pt and upside down (hence the scaled, flipped container); `.managed` textures are deprecated on macOS 27 (shared only).
  timestamp: 2026-10-27T13:51:53.655367+00:00
- actor: claude-code
  id: 01m5yt3kqwvzc7ay1hnn1n2h3m
  text: |-
    ### implement — changed
    - evidence: `swift test --filter "CompositedSnapshotTests|ReviewGalleryScreenTests/theDarkImage"` red (9 issues on path A), then green; `swift test --filter ReviewGallery` 13 tests in 2 suites passed; full `swift test` 1854 tests in 230 suites passed (7 known issues, all pre-existing withKnownIssue), no warnings. Files: Sources/AgentViewKitTestSupport/{ViewSnapshot,LayerTreeRenderer,VibrantLabelFilters}.swift; Tests/AgentViewKitTests/Snapshots/{CompositedSnapshotTests,RegionColors,ReviewGalleryScreen,ReviewGalleryScreenTests,ReviewGalleryNotes}.swift. Gallery regenerated at ~/Library/Caches/AgentViewKit/screenshot-check/.
    - next: /review; a person re-judges the gallery images (glass, bars, buttons) and updates ReviewGalleryNotes.
  timestamp: 2026-10-27T13:51:58.716963+00:00
- actor: claude-code
  id: 01m5ytd1zy44bz324xg96xczmb
  text: |-
    ### test — green
    - evidence: `swift test` run twice (flakiness check for the CARenderer CompositedSnapshotTests): run 1 and run 2 each "1854 tests in 230 suites passed with 7 known issues" (82.5s / 82.2s), exit 0, 0 failures, 0 skipped. Only compiler-side output is a SwiftPM "missing creator for mutated node" note on the mlx-swift_Cmlx.bundle dependency product (not repo code). No source changes, no re-recorded __Snapshots__, no demo/UI launch (UI-test lock not needed).
    - next: review/commit
  timestamp: 2026-10-27T13:57:08.222380+00:00
position_column: doing
position_ordinal: '8380'
title: 'AVK-8 review gallery: render through Core Animation so the images show the dark look of sidebar lists, inspector forms and glass controls, Liquid Glass, the scroll edge effect and the mic/Send buttons (found by ^8q34yt8)'
---
Found while building the review gallery of ^8q34yt8 (2026-10-27). This is a limit of the test render path, not a kit finding.

The review gallery rendered with path A of `ViewSnapshot` (the cache of a hidden window). In the dark variant some parts did not take the dark look:
- A SwiftUI `List` in a `NavigationSplitView` sidebar drew black text on the dark sidebar (`gallery--dark.png`: the session list rows, 1.2:1).
- A grouped `Form` in a SwiftUI `.inspector` drew white rows with black text (`inspector--dark.png`).
- A `.glass` button drew a black label (`Show Error`, `Sign In`, the suggestion chips, the pill), and a `.bordered` button on the floating glass of the bar deck drew a white bezel (`request-deck--dark.png`).
- The symbol-only glass buttons of the composer accessory row (mic, Send) were not drawn at all, in light and dark.
The same path also drew no Liquid Glass and no scroll edge effect.

Cause (measured, see the comments): these parts are vibrant layers and glass backdrops that only a compositor draws. `cacheDisplay` draws each layer alone, with no layer filter and no backdrop, so a vibrant label shows as its bare mask. The appearance of the window is right (VibrantDark); setting it earlier changes nothing.

Fix: a third render path, path C (`ViewSnapshot.compositedPixels`), renders the layer tree of the same hidden window with `CARenderer`, Core Animation's own renderer (`LayerTreeRenderer`). It draws Liquid Glass, the scroll edge effect, the glass buttons and their glyphs. `CARenderer` applies the private vibrancy filter to the backdrop instead of the label, so for the render each label filter is swapped for a paint of the label mask in the primary label color (`VibrantLabelFilters`), as an XCUITest screenshot of the real demo window measured (sidebar text 255 on 46 in dark, 0 on 237 in light). The review gallery uses path C. Path A, `HostedSnapshotTests` and the recorded `__Snapshots__` stay unchanged. The window never shows (AVK-12); no system setting changes.

Not drawn in process: a popover (its own window, which AppKit puts on the screen), and what only the render server knows (the desktop behind the window, the display color space, its exact vibrancy). See the comments.

Files: `Sources/AgentViewKitTestSupport/ViewSnapshot.swift`, `LayerTreeRenderer.swift`, `VibrantLabelFilters.swift`; `Tests/AgentViewKitTests/Snapshots/CompositedSnapshotTests.swift`, `RegionColors.swift`, `ReviewGalleryScreen.swift`, `ReviewGalleryScreenTests.swift`, `ReviewGalleryNotes.swift`.

## Acceptance
- [x] Hosted tests render, in path C, `NavigationSplitView { List { Text("Row") } } detail: { Text("Detail") }`, `Color.clear.inspector(isPresented: .constant(true)) { Form { Section { Text("Name") } }.formStyle(.grouped) }` and a `.glass` button, in light and dark, and require a text contrast of at least 4.5:1 with its background. No clock and no wait.
- [x] In dark, the background of the sidebar row and of the inspector form row has a relative luminance of at most 0.05, and the text is lighter than it.
- [x] The composer mic and Send buttons show a glyph with a contrast of at least 3:1, in light and dark.
- [x] Path C shows Liquid Glass: a glass over a backdrop changes the pixels under it.
- [x] A path C render leaves the window as it was: the same pixels twice, the layer back in its superlayer, and the same path A pixels after it.
- [x] The review gallery renders with path C, and its dark `gallery` and `inspector` images show light text (at least 4.5:1) on a dark (luminance at most 0.05) glass column.
- [x] `ReviewGalleryNotes` no longer say the glass, the scroll edge effect, the mic and Send buttons or the dark look are missing.
- [x] Path A, `HostedSnapshotTests` and the recorded `__Snapshots__` are unchanged.
- [x] What cannot be drawn in process is recorded in a comment.
#avk-8