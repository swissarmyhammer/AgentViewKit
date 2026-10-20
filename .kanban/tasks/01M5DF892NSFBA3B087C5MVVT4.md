---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dndz9aqr99v7b8sv2nc0bt
  text: |-
    Research and implementation notes.

    - SDK facts (macOS 27 SwiftUICore interface): `ConcentricRectangle(corners: Edge.Corner.Style, isUniform:)` exists. `Edge.Corner.Style.concentric(minimum:)` and `.fixed(_:)` exist. `ConcentricRectangle` does not show its corners and is not an `InsettableShape`, so the stroke uses `.stroke(.separator)`, not `.strokeBorder`.
    - A probe showed: with no container, `ConcentricRectangle(corners: .concentric(minimum: .fixed(r)), isUniform: true).path(in:)` is equal to `RoundedRectangle(cornerRadius: r, style: .continuous).path(in:)`. Thus `minimum` is the fallback radius. Note: it is also the smallest radius when a container gives a smaller corner. `animatableData` is `Equatable` and is different for concentric and fixed corners, and for different radii. The shape tests use these two facts.
    - `AgentSurface.shape(for:)` (internal static) is the one shape. `agentContentSurface()` and `agentFloatingGlass()` are internal `View` extensions, as `editorBlockFrame()` is. No view uses them yet.
    - `RenderedPixels` got `contains(_:at:tolerance:)`, a read of one pixel at a point. It stores the width, height and scale of the image.
    - `GlassRenderProbeTests.pixels(of:with:on:size:)` got a `size` argument with the old size as its default. A first run without it rendered at 40x40, so 4 of 5 points were outside the render. The test `theBackdropShowsAtEachPointWhenTheViewHasNoSurface` found this. Keep that off test: it stops the on test from a pass with points outside the render.
    - Render tests follow ^dbbyg9w: the content surface gives equal pixels with Reduce Transparency off and on (no glass); the floating glass gives different pixels.
  timestamp: 2026-10-20T22:03:09.994522+00:00
- actor: claude-code
  id: 01m5dne2yh6t9v339kys6vcd89
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Theme/AgentSurfaces.swift (new), Sources/AgentViewKitTestSupport/RenderedPixels.swift, Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift (new), Tests/AgentViewKitTests/Theme/GlassRenderProbeTests.swift, Tests/AgentViewKitTests/TestSupport/RenderedPixelsTests.swift. `swift test`: 1396 tests in 165 suites passed, 2 known issues (existed before); 137 tests in 19 suites passed; only the mlx bundle warning.
    - next: /review
  timestamp: 2026-10-20T22:03:13.745067+00:00
- actor: claude-code
  id: 01m5dnnatr1523p0hf8n1rn7dp
  text: |-
    ### test — green
    - evidence: swift test — 1396 tests in 165 suites passed, 0 failed, 0 skipped, 2 known issues (as before). The only warning is the mlx bundle build warning (as before).
    - next: review
  timestamp: 2026-10-20T22:07:11.192510+00:00
- actor: claude-code
  id: 01m5dnr9xy02qb6rj4dkb8zq5q
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 5378713). 0 findings, 0 confirmed, 0 refuted. 7 files attempted, 0 failed. 5 files reviewed. 2 .kanban files are excluded by .reviewignore.
    - next: none. The task moved to done.
  timestamp: 2026-10-20T22:08:48.574358+00:00
- actor: claude-code
  id: 01m5dnry8k6dsavqq1fynj6hjt
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 5 files
    - test: green — swift test, 1396 passed, 2 known issues that were there before
    - commit: 5378713
    - review: clean — 0 findings
  timestamp: 2026-10-20T22:09:09.395660+00:00
position_column: done
position_ordinal: fff980
title: 'AVK-8b Add the two shared surfaces: agentContentSurface() and agentFloatingGlass()'
---
## Why

D110 (b), (c), (e). Today each view writes its own `.glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))`. Content and floating controls use the same glass. Two shared modifiers give one place for each rule, so that each later AVK-8 card changes one line in a view.

## Files

- New: `Sources/AgentViewKit/Theme/AgentSurfaces.swift`
- `Sources/AgentViewKit/Theme/AgentTheme+Glass.swift` lines 3-15 (`MaterialLevel.glass`). Keep it. Make it the only input of `agentFloatingGlass()`.
- `Sources/AgentViewKitTestSupport/RenderedPixels.swift`: add a read of the color of one pixel at a point, if the tests need it.

## What to do

- [x] Add `agentContentSurface()`. It draws a standard opaque background (`.background.secondary`) in a concentric shape (`ConcentricRectangle` with the `.concentric` corner style), with `theme.radii.l` as the radius when no container gives one, and a `.separator` stroke. It has no glass.
- [x] Add `agentFloatingGlass()`. It applies `.glassEffect(theme.materialLevel.glass, in:)` with the same concentric shape. Its documentation says: use it only on a floating control, only inside a `GlassEffectContainer`, and never on top of other glass.
- [x] Make the shape one internal static function, so a test can read the shape and the fallback radius.
- [x] Add DocC comments in STE that name D110.

## Acceptance

- New tests in `Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift`:
  - A view with `agentContentSurface()` over a backdrop of one unique color, rendered with `RenderedPixels`, shows no pixel of the backdrop color inside the surface.
  - The shape function gives the concentric style and uses `theme.radii.l` as the fallback radius. A theme with a different `radii.l` gives a different fallback radius.
- No view changes in this card. All tests that pass before this card still pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8