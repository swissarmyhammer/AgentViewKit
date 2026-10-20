---
assignees:
- claude-code
position_column: todo
position_ordinal: '8980'
title: 'AVK-8b Add the two shared surfaces: agentContentSurface() and agentFloatingGlass()'
---
## Why

D110 (b), (c), (e). Today each view writes its own `.glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))`. Content and floating controls use the same glass. Two shared modifiers give one place for each rule, so that each later AVK-8 card changes one line in a view.

## Files

- New: `Sources/AgentViewKit/Theme/AgentSurfaces.swift`
- `Sources/AgentViewKit/Theme/AgentTheme+Glass.swift` lines 3-15 (`MaterialLevel.glass`). Keep it. Make it the only input of `agentFloatingGlass()`.
- `Sources/AgentViewKitTestSupport/RenderedPixels.swift`: add a read of the color of one pixel at a point, if the tests need it.

## What to do

- [ ] Add `agentContentSurface()`. It draws a standard opaque background (`.background.secondary`) in a concentric shape (`ConcentricRectangle` with the `.concentric` corner style), with `theme.radii.l` as the radius when no container gives one, and a `.separator` stroke. It has no glass.
- [ ] Add `agentFloatingGlass()`. It applies `.glassEffect(theme.materialLevel.glass, in:)` with the same concentric shape. Its documentation says: use it only on a floating control, only inside a `GlassEffectContainer`, and never on top of other glass.
- [ ] Make the shape one internal static function, so a test can read the shape and the fallback radius.
- [ ] Add DocC comments in STE that name D110.

## Acceptance

- New tests in `Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift`:
  - A view with `agentContentSurface()` over a backdrop of one unique color, rendered with `RenderedPixels`, shows no pixel of the backdrop color inside the surface.
  - The shape function gives the concentric style and uses `theme.radii.l` as the fallback radius. A theme with a different `radii.l` gives a different fallback radius.
- No view changes in this card. All tests that pass before this card still pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8