---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dfdxt1ya23c55dd1qg708q
  text: |-
    ### decision (testudoapp-4c, AVK-8 "Decisions for the plan")
    - Use a kit environment value that selects the look as the test seam for the Tinted look.
    - A person checks the real system Tinted setting one time for each release. AVK-8q writes this as a manual check in plan.md.
  timestamp: 2026-10-20T20:18:17.025467+00:00
- actor: claude-code
  id: 01m5dmgsqstrzwsnr8jcdjtb2q
  text: |-
    ### research — facts from the probe (SDK MacOSX27.0)
    1. `ImageRenderer` draws Liquid Glass only after the process makes its first `NSHostingView` (or `NSHostingController`). Before that, a `glassEffect` draws nothing, and the render is byte-equal to the render with no glass. A plain `NSWindow` does not start it. One `NSHostingView(rootView: EmptyView())` with no window is sufficient. After that, the state stays for the life of the process.
    2. Thus a pixel result of a glass view changed with the order of the tests. The first full `swift test` run showed this: the probe passed with `--filter` and failed in the full run. `RenderedPixels(rendering:size:)` now makes one `NSHostingView` before its first render, so the result is the same in each order.
    3. After that, the glass follows the environment. `_accessibilityReduceTransparency = true` changes the pixels. `_colorSchemeContrast = .increased` changes the pixels. A tint changes the pixels. `.clear` and `.regular` differ. Dark mode differs. Two renders of one view are byte-equal.
    4. With Reduce Transparency, the glass is more frosted, but it does not hide the backdrop fully: over two different backdrops, the pixels are different. The regular glass also shows no pixel of the exact backdrop color. Thus "no pixel of the backdrop color inside the glass" is not a useful assertion.
    5. A hosted window (`HostedViewHarness`) makes a `CABackdropLayer` with the `glassBackground` filter, and the render server draws it. `cacheDisplay` of the hosting view shows no glass (byte-equal to no glass). With a tinted glass, `cacheDisplay` gave a fully transparent image. Do not use the hosted cache for glass.
    6. In the hosted layer tree, `_accessibilityReduceTransparency = true` changes only the private `CABackdropLayer.scale` (0.5 to 0.125). `_colorSchemeContrast = .increased` makes no change in the layer tree. These are private properties. Do not use them in tests.
    7. Both underscored values reach `accessibilityReduceTransparency` and `colorSchemeContrast` of a child view.
    8. `Glass` is `Equatable`. Two glasses with the same tint are equal. A tinted glass is not equal to `.regular`, to a glass with a different tint, or to `.clear` with the same tint.
    9. SwiftUI has no API for the Clear or Tinted look of the system setting. `Glass` has only `.regular`, `.clear`, `.identity`, `tint(_:)` and `interactive(_:)`.

    What did not work: pixels of `ImageRenderer` before a hosting view exists (no glass), pixels of `cacheDisplay` in a hosted window (no glass), and `layer.render(in:)` of the hosted layer (no glass).
  timestamp: 2026-10-20T21:47:14.041269+00:00
- actor: claude-code
  id: 01m5dmhf5zk4qfg80302vy77gk
  text: |-
    ### decision — the method and the assertion for each setting (for AVK-8p)

    Common setup: render the glass view with `RenderedPixels(rendering:size:)` (it makes the `NSHostingView` that `ImageRenderer` needs to draw glass). Put the view over a backdrop of one unique color. Set light mode, `_accessibilityReduceTransparency = false` and `_colorSchemeContrast = .standard` first, and then change only the setting under test. `GlassRenderProbeTests.pixels(of:with:on:)` shows the setup. Do not use the hosted `cacheDisplay` and do not read private layer properties.

    - **Reduce Transparency.** Method: `.environment(\._accessibilityReduceTransparency, true)` against `false`. Assertion: the two renders are not equal (the glass of the view follows the setting). Optional: the setting reaches the view (a child reads `accessibilityReduceTransparency`). Do not assert "no pixel of the backdrop color inside the glass": the frosted glass still shows the backdrop, and the regular glass also shows no exact backdrop color.
    - **Increase Contrast.** Method: `.environment(\._colorSchemeContrast, .increased)` against `.standard`. Assertion: the two renders are not equal.
    - **Tinted look.** There is no SwiftUI API. Method: the kit environment value `\.agentGlassLook` with `.clear` (default) and `.tinted`; `.tinted` gives `theme.materialLevel.glass.tint(editorTheme.accent)` (new card ^w9y5tq6). Assertions: (a) the `Glass` that the view resolves for `.tinted` is equal to `theme.materialLevel.glass.tint(accent)`, and for `.clear` it is equal to `theme.materialLevel.glass` (`Glass` is `Equatable`); (b) the render with `.tinted` is not equal to the render with `.clear`. A person checks the real system Tinted setting one time for each release (AVK-8q puts this manual check in plan.md).

    What the tests cannot check: the real system switches (Reduce Transparency, Increase Contrast, Clear or Tinted). The tests set the environment values, not the system settings. If a new SDK changes a fact, `GlassRenderProbeTests` fails, and this decision must be done again.

    Count for AVK-8p: 5 views x 3 settings = 15 cases stay possible. AVK-8p needs ^w9y5tq6 for the Tinted cases. I did not change AVK-8p; its `depends_on` must get ^w9y5tq6.
  timestamp: 2026-10-20T21:47:35.999347+00:00
- actor: claude-code
  id: 01m5dmj3zmef8vmk905hat05dr
  text: |-
    ### implement — changed
    - evidence: 3 files — Sources/AgentViewKitTestSupport/RenderedPixels.swift (`Equatable`, `init?(cachingDisplayOf:)`, one `NSHostingView` before the first render), Tests/AgentViewKitTests/TestSupport/RenderedPixelsTests.swift (4 new tests), Tests/AgentViewKitTests/Theme/GlassRenderProbeTests.swift (new). `swift test`: 1386 tests in 164 suites passed, 2 known issues, only the mlx bundle warning that existed before.
    - new card: ^w9y5tq6 (AVK-8a1, the `\.agentGlassLook` value). AVK-8p must depend on it; I did not change AVK-8p.
    - next: /review
  timestamp: 2026-10-20T21:47:57.300634+00:00
- actor: claude-code
  id: 01m5dmss9bcrn244shpfrm7037
  text: |-
    ### test — green
    - evidence: swift test — 1386 tests in 164 suites passed, 0 failed, 0 skipped, 2 known issues (before this work). The only warning is the mlx bundle build warning (before this work).
    - next: review
  timestamp: 2026-10-20T21:52:08.491402+00:00
- actor: claude-code
  id: 01m5dmwqreskfbyk21qq7a0mn4
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 1384a69). 0 findings, 0 confirmed, 3 refuted. 3 files reviewed. 2 files in .kanban/ not reviewed (ignore rule).
    - next: The task is in done. No more work for this review.
  timestamp: 2026-10-20T21:53:45.230086+00:00
- actor: claude-code
  id: 01m5dmwz7drc510e8jf1rda6b0
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 3 files
    - test: green — swift test, 1386 passed, 2 known issues that were there before
    - commit: 1384a69
    - review: clean — 0 findings
  timestamp: 2026-10-20T21:53:52.877667+00:00
position_column: done
position_ordinal: fff880
title: AVK-8a Find a deterministic method to test glass with Reduce Transparency, Increase Contrast and the Tinted look
---
## Why

D110 (f) and AVK-8 tell us to test each glass view with Reduce Transparency, Increase Contrast and the Tinted look. We do not know yet how to do this in a test that is deterministic. This card finds the method before AVK-8p writes the tests.

## What we know now (SDK MacOSX27.0)

- `EnvironmentValues.accessibilityReduceTransparency` and `colorSchemeContrast` are get-only. The underscored values `_accessibilityReduceTransparency` and `_colorSchemeContrast` have `get set` in `SwiftUICore.swiftinterface` (about lines 23459-23921).
- `Glass` has `.regular`, `.clear`, `.identity`, `tint(_:)` and `interactive(_:)`. We found no SwiftUI API for the Clear or Tinted look of the system setting.
- `ConcentricRectangle` and the corner style `.concentric` exist. `.containerConcentric` (named in the research page) does not exist in this SDK.
- `RenderedPixels` (`Sources/AgentViewKitTestSupport/RenderedPixels.swift`) uses `ImageRenderer`. We do not know if `ImageRenderer` draws `.glassEffect`.

## What to do

- [x] Write a probe test in `Tests/AgentViewKitTests/Theme/GlassRenderProbeTests.swift`. Render a view with `.glassEffect(.regular, in: .rect)` over a backdrop of one unique color with `RenderedPixels`. Record what the render shows.
- [x] In the probe, set `_accessibilityReduceTransparency = true`. Record if the render changes.
- [x] In the probe, set `_colorSchemeContrast = .increased`. Record if the render changes.
- [x] Find if a hosted window (`HostedViewHarness`) draws glass when `ImageRenderer` does not.
- [x] Find an API for the Tinted look. If there is none, write the proposal: a kit environment value that the glass views read, for example `\.agentGlassLook` with `.clear` and `.tinted`, where `.tinted` maps to `Glass.tint(editorTheme.accent)`.
- [x] Write the decision as a comment on this card: the method for each of the three settings, and the assertion that each test makes.

## Acceptance

- The comment on this card names one deterministic method for each setting, or says that a setting cannot be tested and why.
- `GlassRenderProbeTests` passes. It keeps only the facts that the decision uses, for example that `_accessibilityReduceTransparency` set to `true` reaches the `accessibilityReduceTransparency` of a child view.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event.

## Open question

If the Tinted look has no API, does the user accept a kit environment value as its stand-in? #avk-8