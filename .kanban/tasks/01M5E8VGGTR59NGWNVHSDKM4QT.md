---
assignees:
- claude-code
depends_on:
- 01M5E8S3KAQ7EV2C2K13Y1K31Q
position_column: todo
position_ordinal: a780
title: 'AVK-8ad Floating glass is always .regular: remove the materialLevel control of the glass (AgentSurfaces.swift:81, AgentTheme+Glass.swift) (D113 answer 3)'
---
## Why

D113 answer 3 and `style.md` "Glass variant and shape": "Floating glass is `.regular`. The Clear look is a system setting, and the system applies it to `.regular` glass. A theme does not select the glass variant."

Today `AgentFloatingGlass` uses `theme.materialLevel.glass` (`Sources/AgentViewKit/Theme/AgentSurfaces.swift:81`). `.thin` and `.clear` give `.clear` glass (`Sources/AgentViewKit/Theme/AgentTheme+Glass.swift:9-13`).

## Files and lines

- `Sources/AgentViewKit/Theme/AgentSurfaces.swift:75-83` (`AgentFloatingGlass`), `:121-134` (doc comment of `agentFloatingGlass()`).
- `Sources/AgentViewKit/Theme/AgentTheme+Glass.swift` (the whole file).

## What to do

- [ ] Change `AgentFloatingGlass.body` to `content.glassEffect(.regular, in: AgentSurface.shape(for: theme))`. Keep the `ConcentricRectangle` shape: the composer field has more than one line (D113 answer 3). AVK-8af does the capsule controls.
- [ ] Remove `AgentTheme+Glass.swift` (the `MaterialLevel.glass` property). Search for `.glass` on a `MaterialLevel` value: there must be no other user.
- [ ] Change the DocC comment of `agentFloatingGlass()`: the glass is always `.regular`; the system applies the Clear and Tinted looks; no theme value changes the glass (D113).
- [ ] Do not remove the `materialLevel` token of `AgentTheme` in this card. AVK-8ae does that.
- [ ] Do not add `Glass.tint(_:)` anywhere (D113 answer 6).

## Acceptance

- A test in `Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift` renders a view with `agentFloatingGlass()` with each `AgentTheme.MaterialLevel` case and gets the same pixels for each case (`RenderedPixels`, light mode, `_accessibilityReduceTransparency = false`, `_colorSchemeContrast = .standard`, as in `GlassRenderProbeTests.pixels(of:with:on:)`). If AVK-8ae runs first and the enum is gone, this test is not necessary; then a source check in `GlassPlacementTests` holds that `.glassEffect(` in `Theme/AgentSurfaces.swift` has the argument `.regular`.
- `GlassPlacementTests` passes.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8