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
position_column: todo
position_ordinal: '8880'
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

- [ ] Write a probe test in `Tests/AgentViewKitTests/Theme/GlassRenderProbeTests.swift`. Render a view with `.glassEffect(.regular, in: .rect)` over a backdrop of one unique color with `RenderedPixels`. Record what the render shows.
- [ ] In the probe, set `_accessibilityReduceTransparency = true`. Record if the render changes.
- [ ] In the probe, set `_colorSchemeContrast = .increased`. Record if the render changes.
- [ ] Find if a hosted window (`HostedViewHarness`) draws glass when `ImageRenderer` does not.
- [ ] Find an API for the Tinted look. If there is none, write the proposal: a kit environment value that the glass views read, for example `\.agentGlassLook` with `.clear` and `.tinted`, where `.tinted` maps to `Glass.tint(editorTheme.accent)`.
- [ ] Write the decision as a comment on this card: the method for each of the three settings, and the assertion that each test makes.

## Acceptance

- The comment on this card names one deterministic method for each setting, or says that a setting cannot be tested and why.
- `GlassRenderProbeTests` passes. It keeps only the facts that the decision uses, for example that `_accessibilityReduceTransparency` set to `true` reaches the `accessibilityReduceTransparency` of a child view.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event.

## Open question

If the Tinted look has no API, does the user accept a kit environment value as its stand-in? #avk-8