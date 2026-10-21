---
assignees:
- claude-code
depends_on:
- 01M5FH4Z521FC705TKY8NT2787
position_column: todo
position_ordinal: b780
title: AVK-13 PNG snapshot images of the real views, with reference images and diffs
---
Source: the user, 2026-10-21: "i want you to actually test the view, not just the model. and i want you to have images to look at cause lots of my feedback is going to be 'this is ugly'". Depends on AVK-12 (the hidden-window harness).

Do:
- Add a small helper in Sources/AgentViewKitTestSupport, for example `ViewSnapshot`, with two render paths:
  - Path A (all views except the glass parts): mount the real view in the hidden-window `HostedViewHarness`, `render()`, then `RenderedPixels(cachingDisplayOf:)`, then write a PNG. This path draws AppKit-backed views (ScrollView, List, TextEditor, the EditorKit editor) and views with `.accessibilityFocused`.
  - Path B (glass parts in isolation: composer field, request deck in the bar, floating controls): `RenderedPixels(rendering:)` (`ImageRenderer`). Say in the doc comment that this is a glass look and maybe not the exact system Liquid Glass.
- Variants for each view: light, dark (set `window.appearance` aqua/darkAqua and `.environment(\.colorScheme)`), Reduce Transparency, Increase Contrast (the private environment keys that the repo already uses).
- Reference images next to the tests, for example `Tests/AgentViewKitTests/__Snapshots__/<Suite>/<view>-<variant>.png`. Compare with the existing tolerance (`RenderedPixels.isClose`). On a change, write `<name>.actual.png` and `<name>.diff.png` to one known folder (for example `.build/snapshots/`), and attach them with Swift Testing `Attachment`. A record mode with an environment variable (for example `AVK_SNAPSHOT_RECORD=1`) writes the reference images.
- Snapshot tests for: the thread (with messages, a tool call, a code block), the composer (idle and running), a permission request card, the request deck in the bar, a session notice, a status banner, a code block, the terminal output, an elicitation form. Light, dark, Reduce Transparency, Increase Contrast for each.
- Use no new package dependency unless the structure tests (ManifestTests, ResolvedPinsTests) permit it; the kit helper is preferred.
- Make each snapshot deterministic: fixed size, fixed scale 2x, sRGB color space, fixed data, fixed dates, no animation.
- Document in the README (Testing section) where the images are and how to record them.

Acceptance:
- The reference PNGs are in the repo, and a person can open them.
- A test fails, and writes the actual and diff PNGs, when a view's look changes (show this with one mutation, then put it back).
- 3 full `swift test` runs one after the other pass, with no window on the screen and no focus change.
- No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-13