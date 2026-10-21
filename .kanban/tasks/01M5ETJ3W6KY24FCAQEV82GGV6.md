---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5fahswgah65yfwrre3bpyt1
  text: |-
    Research (probes in new processes, one filtered `swift test` each; the probe file is temporary and is removed).

    - The two views draw in each render, also as the first render of a process: a raw `ImageRenderer` render of `AgentInfoHeader` gave 3565 opaque pixels as the first render, with and without the EditorKit theme, with and without an `NSHostingView` before it.
    - The defect is in the clear render, not in the drawn render. When the content of an `ImageRenderer` render draws nothing (`Color.clear`), the `cgImage` contains the pixels of an earlier render. Sequence in one process: header 3565, `Color.clear` 3565, `Color.clear` 3565, red 10x10 square 400, `Color.clear` 400. When `Color.clear` is the first render, it gives 0. A render that draws something writes each pixel again, so only a render that draws nothing gives old pixels. `Text("")` gave 0.
    - Thus `requireDrawn(_:blank:)` compared the header with a "blank" that was a copy of the header, and found them equal. The old note "draws nothing in that render and in each later render" is not correct: the blank was wrong. With the clear render first, the blank is the first render of the process, which has no old pixels.
    - Fix plan: `RenderedPixels.init(rendering:size:)` gets its pixels from `ImageRenderer.render(rasterizationScale:renderer:)` into a bitmap context that the type makes and clears itself, so no render can show the pixels of a different render. Then `drawnPixels(of:)` renders the view first and the clear view after it, and the order note is removed.
  timestamp: 2026-10-21T13:31:30.064089+00:00
- actor: claude-code
  id: 01m5fbpwh0t6qg3w9qct5y9jq6
  text: |-
    Implementation.

    - Root cause: `ImageRenderer.cgImage` does not draw a new image when the content draws nothing (an empty display list, for example `Color.clear`). It gives the pixels of an earlier render of the process. A render that draws something writes each pixel again. In `drawnPixels(of:)`, the clear render after `AgentInfoHeader` or `PendingRequestCountBadge` gave a copy of the header, so `requireDrawn(_:blank:)` found "no change". SF Symbols, fonts, the scale, `.symbolRenderingMode` and the theme default are not the cause.
    - Fix (one place): `RenderedPixels.init(rendering:size:)` puts the content in front of an empty `Canvas { _, _ in }`. The canvas draws no pixel, but the content is never empty, so each render starts from a clear image. Probe: after the header, a clear view in front of an empty canvas gave 0 non-zero bytes; a plain `Color.clear` gave 3565.
    - `EditorThemeViewsTests.drawnPixels(of:)` now renders the view first and the clear view after it. The work-around and its order note are removed.
    - New test `RenderedPixelsTests.aClearViewAfterADrawnViewHasNoColorOfTheDrawnView`. RED before the fix (`clear.contains(Self.drawn)` was true), GREEN after it.
    - Failed approach, do not repeat: render with `ImageRenderer.render(rasterizationScale:renderer:)` into a `CGContext` that the type clears. It fixed the clear render, but 6 glass tests failed in each of 3 full runs (GlassRenderProbeTests.theGlassFollowsTheSetting, AgentSurfacesTests reduce transparency and clear glass, PromptInputGlassTests, RequestDeckSurfaceTests): that render path does not draw the accessibility settings of Liquid Glass. The doc comment of the initializer records this.
    - Not in scope, possible relation: other notes say `ImageRenderer` "does not draw" a `ScrollView` or a focusable view, and the glass edge "changes after the first renders". These notes were made with the old `cgImage` path. They were not checked again.
  timestamp: 2026-10-21T13:51:45.184466+00:00
- actor: claude-code
  id: 01m5fbq196jq32djwpe1nqeks8
  text: |-
    ### implement — changed
    - evidence: 3 files — Sources/AgentViewKitTestSupport/RenderedPixels.swift (empty `Canvas` behind the content of each render), Tests/AgentViewKitTests/Theme/EditorThemeViewsTests.swift (work-around removed, view renders first), Tests/AgentViewKitTests/TestSupport/RenderedPixelsTests.swift (new test, RED then GREEN). Acceptance: `swift test --filter AgentInfoHeaderColorTests/theHeaderDrawsNoPixelOfTheAccent` passed 2 times, each a new process with the header as the first render. 3 full `swift test` runs one after the other: each 1488 tests in 187 suites passed with the 2 known issues, 177 tests in 25 suites passed, 1 test passed. Only the known mlx bundle warning.
    - next: /review
  timestamp: 2026-10-21T13:51:50.054755+00:00
- actor: claude-code
  id: 01m5fbwk09s5vr0scy3aa6ba1w
  text: |-
    ### test — green
    - evidence: swift test, 131 s. 1488 tests in 187 suites passed. 0 failed. 0 skipped. 2 known issues (HostedLayoutExpectationsTests, ThemeHeightExpectationsTests). They existed before.
    - warnings: only the mlx bundle build warning. It existed before. No new warning.
    - the package structure suites and ReadmeSnippetsTests ran and passed.
    - next: review
  timestamp: 2026-10-21T13:54:52.041619+00:00
position_column: doing
position_ordinal: '80'
title: Find why ImageRenderer draws nothing when the first render of a process is AgentInfoHeader or PendingRequestCountBadge
---
Source: ^2g7w4mz (AVK-8aj) implement step.

Problem: when the first `ImageRenderer` render of the test process is `AgentInfoHeader` or `PendingRequestCountBadge`, these two views draw nothing in that render and in all later renders. A plain `Text` still draws. When the first render is a clear view, they draw. This happened the same way in each probe run. A clear warm-up render inside `RenderedPixels` did not prevent it.

Today `EditorThemeViewsTests.drawnPixels(of:)` renders a clear view first as a work-around. A render test that renders such a view first, with no clear render before it, can fail. The result of such a test depends on the order of the tests, and the test rules forbid this.

Do:
- Find the root cause (for example SF Symbol or font loading, the first `NSHostingView`, a `.symbolRenderingMode`, the `@Environment(\.editorTheme)` default, or the image scale of the first render).
- Fix it in one place, so each render gives the same result in any order: in `RenderedPixels` (Sources/AgentViewKitTestSupport/RenderedPixels.swift) or in the view if the view is wrong.
- Remove the work-around from `drawnPixels(of:)` if the fix makes it unnecessary.
- Do not add a retry, a sleep, a poll, a clock or a time limit.

Acceptance:
- A test that renders `AgentInfoHeader` as the first render of a new process draws pixels. Run it alone in a new process, with a filter, two times.
- 3 full `swift test` runs one after the other pass. #avk-8