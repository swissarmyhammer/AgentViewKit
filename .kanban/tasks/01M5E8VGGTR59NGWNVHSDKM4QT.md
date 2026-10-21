---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5eez1eb7v94wcp3ywqy2dv7
  text: 'Research: `MaterialLevel.glass` (AgentTheme+Glass.swift) has one user: `AgentFloatingGlass.body` in Theme/AgentSurfaces.swift. No `Glass.tint(_:)` is in Sources. GlassRenderProbeTests uses `.regular.tint(probe color)` only to probe SDK facts; it is not a kit glass and not the accent, so this card does not change it. README has no DocC catalog and does not name the glass variant. comparison.md (section 2.17, "Material / glass") names `AgentTheme+Glass.swift`; change it to `agentFloatingGlass()` in `Theme/AgentSurfaces.swift`. The `MaterialLevel` enum still exists (AVK-8ae not done), so the acceptance test is the pixel test for each case.'
  timestamp: 2026-10-21T05:29:23.659870+00:00
- actor: claude-code
  id: 01m5ef82zph5cxnvypnkwxf92q
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Theme/AgentSurfaces.swift (`AgentFloatingGlass.body` uses `.glassEffect(.regular, in: AgentSurface.shape(for: theme))`; the doc comments of `AgentFloatingGlass` and `agentFloatingGlass()` say the glass is always `.regular`, the system applies the Clear and Tinted looks, no theme value changes the glass, no tint); Sources/AgentViewKit/Theme/AgentTheme+Glass.swift deleted (not staged); Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift (new `floatingGlass(in:)` helper and `theFloatingGlassIsTheSameForEachMaterialLevel(level:)`; RED: `.clear` and `.thin` failed `glass == regular`; GREEN: 3 cases pass); comparison.md (section 2.17 row "Material / glass" names `agentFloatingGlass()` in place of the deleted file). `swift test`: 1450 tests in 179 suites passed with 2 known issues, and 173 tests in 23 suites (PackageStructureTests, GlassPlacementTests included) passed. Only the mlx bundle warning, which existed before.
    - note: No `Glass.tint(_:)` is in Sources. `GlassRenderProbeTests` keeps `.regular.tint(probe color)`: it probes SDK facts and is not a kit glass, so this card did not change it.
    - next: /review
  timestamp: 2026-10-21T05:34:20.150517+00:00
- actor: claude-code
  id: 01m5efcsa2nvt0tqvc7z9tsvxe
  text: |-
    ### test — green
    - evidence: swift test (one full run, 110 s). 1450 tests in 179 suites passed (74.6 s) with 2 known issues; 173 tests in 23 suites passed; 1 test in 1 suite passed. 0 failures, 0 skipped.
    - PackageStructureTests ran and passed: PackageFilesTests, ImportBoundaryTests, ComposerGlassStructureTests, GlassPlacementTests, DecisionRecordTests, FixedColorTests.
    - warnings: only the known mlx bundle build warning. No new warnings.
    - next: review.
  timestamp: 2026-10-21T05:36:54.082667+00:00
depends_on:
- 01M5E8S3KAQ7EV2C2K13Y1K31Q
position_column: doing
position_ordinal: '80'
title: 'AVK-8ad Floating glass is always .regular: remove the materialLevel control of the glass (AgentSurfaces.swift:81, AgentTheme+Glass.swift) (D113 answer 3)'
---
## Why

D113 answer 3 and `style.md` "Glass variant and shape": "Floating glass is `.regular`. The Clear look is a system setting, and the system applies it to `.regular` glass. A theme does not select the glass variant."

Today `AgentFloatingGlass` uses `theme.materialLevel.glass` (`Sources/AgentViewKit/Theme/AgentSurfaces.swift:81`). `.thin` and `.clear` give `.clear` glass (`Sources/AgentViewKit/Theme/AgentTheme+Glass.swift:9-13`).

## Files and lines

- `Sources/AgentViewKit/Theme/AgentSurfaces.swift:75-83` (`AgentFloatingGlass`), `:121-134` (doc comment of `agentFloatingGlass()`).
- `Sources/AgentViewKit/Theme/AgentTheme+Glass.swift` (the whole file).

## What to do

- [x] Change `AgentFloatingGlass.body` to `content.glassEffect(.regular, in: AgentSurface.shape(for: theme))`. Keep the `ConcentricRectangle` shape: the composer field has more than one line (D113 answer 3). AVK-8af does the capsule controls.
- [x] Remove `AgentTheme+Glass.swift` (the `MaterialLevel.glass` property). Search for `.glass` on a `MaterialLevel` value: there must be no other user.
- [x] Change the DocC comment of `agentFloatingGlass()`: the glass is always `.regular`; the system applies the Clear and Tinted looks; no theme value changes the glass (D113).
- [x] Do not remove the `materialLevel` token of `AgentTheme` in this card. AVK-8ae does that.
- [x] Do not add `Glass.tint(_:)` anywhere (D113 answer 6).

## Acceptance

- A test in `Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift` renders a view with `agentFloatingGlass()` with each `AgentTheme.MaterialLevel` case and gets the same pixels for each case (`RenderedPixels`, light mode, `_accessibilityReduceTransparency = false`, `_colorSchemeContrast = .standard`, as in `GlassRenderProbeTests.pixels(of:with:on:)`). If AVK-8ae runs first and the enum is gone, this test is not necessary; then a source check in `GlassPlacementTests` holds that `.glassEffect(` in `Theme/AgentSurfaces.swift` has the argument `.regular`.
- `GlassPlacementTests` passes.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8