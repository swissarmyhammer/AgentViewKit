---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5evvre3d5s6tdnz3te5t404
  text: 'Research done. The token has no reader in Sources: `AgentFloatingGlass` calls `.glassEffect(.regular, in: AgentSurface.shape(for: theme))` and reads only the large radius of the theme. Hits of `materialLevel`/`MaterialLevel`: AgentTheme.swift, DefaultTokens.json, AgentThemeTests, AgentThemeGoldenTests, ViewValueLayoutTests, AgentSurfacesTests (two render tests and the helper `floatingGlassPixels(for:)`), visual-audit.md. No caller of `AgentTheme.init` in Examples or DemoSupport, so the demo app does not use the token. Prose "material level" also is in README.md, plan.md (§5, §11 decision 11) and visual-audit.md. Plan: remove the enum, property, init parameter and default; replace the two material-level render tests with tests that compare the floating glass with a `.regular` glass in the same shape; add a structure scan that each `.glassEffect(` call of the kit names `.regular` (with a fixture that shows the scan finds another variant). This is a breaking change of the public API (enum `AgentTheme.MaterialLevel`, property `materialLevel`, init parameter `materialLevel:`).'
  timestamp: 2026-10-21T09:14:47.619378+00:00
- actor: claude-code
  id: 01m5ewc0m90g0angpqbkdyfq43
  text: |-
    Implementation landed.
    - RED: `ViewValueLayoutTests.theThemeHasNoPaddingByte` without `\.materialLevel` failed with `uncoveredByteCount → 1` (size 66, one byte not listed). GREEN after the removal.
    - `AgentTheme`: the enum `MaterialLevel`, the property `materialLevel`, the init parameter `materialLevel:` and the default are removed. The layout comment now names only `density` after `symbolWeight`. The type doc says that the type has no glass token (D113 answer 3).
    - `AgentSurfacesTests`: the two material-level render tests are replaced by `theFloatingGlassIsTheRegularGlassInsideTheEdge` and `eachPixelOfTheFloatingGlassInsideTheRimIsTheRegularGlass`. They compare the floating glass with a direct `.glassEffect(.regular, in:)` glass in the same shape. `aClearGlassIsDifferentFromTheFloatingGlassInsideTheEdge` stays, so the compared points can find another glass. One helper `glass(_:)` makes the `.regular` and the `.clear` glass.
    - New guard: `GlassPlacementTests.eachGlassEffectOfTheKitNamesTheRegularGlass` scans the kit; each `.glassEffect(` call must name `.regular` on the same line. Fixture `Violating/Variant/GlassVariants.swift` and `theVariantScanReportsEachGlassThatIsNotRegularInTheFixture` show that the scan reports a `.clear` glass and a glass with no variant. Note: the scan reads one line, so a `.glassEffect(` call with the variant on the next line is reported.
    - Docs: visual-audit.md (row removed, new section "The removed material level", prose), README.md "The theme", plan.md §5 and §11 decision 11. comparison.md already said "always `.regular`"; no change.
    - No caller of the init in Examples or DemoSupport. The demo app builds.
    - Breaking change of the public API: `AgentTheme.MaterialLevel`, `AgentTheme.materialLevel` and the init parameter `materialLevel:` are removed. The commit must mark it.
  timestamp: 2026-10-21T09:23:40.297330+00:00
- actor: claude-code
  id: 01m5ewc4g94g8vt4r0j5b9qagq
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Theme/AgentTheme.swift; Tests/AgentViewKitTests/Theme/{AgentSurfacesTests.swift,AgentThemeTests.swift,AgentThemeGoldenTests.swift,DefaultTokens.json}; Tests/AgentViewKitTests/Infrastructure/ViewValueLayoutTests.swift; Tests/PackageStructureTests/GlassPlacementTests.swift; new Tests/PackageStructureTests/Fixtures/GlassPlacement/Violating/Variant/GlassVariants.swift; Docs/decisions/visual-audit.md; README.md; plan.md. `swift test` (output in a file): 1473 tests in 184 suites passed, 2 known issues, only the known mlx bundle warning; PackageStructureTests 177 tests passed. Demo app `xcodebuild ... -scheme AgentViewKitDemo build`: BUILD SUCCEEDED. BREAKING public API change: `AgentTheme.MaterialLevel`, `AgentTheme.materialLevel`, init parameter `materialLevel:` removed.
    - next: /review
  timestamp: 2026-10-21T09:23:44.265189+00:00
- actor: claude-code
  id: 01m5ewgrcjaa74jv4a4cqnp8s8
  text: |-
    ### test — green
    - evidence: swift test, 110 s. PackageStructureTests: 177 tests in 23 suites, passed (GlassPlacementTests passed). AgentViewKitTests: 1473 tests in 184 suites, passed, 2 known issues (they existed before). ReadmeSnippetsTests: 1 test, passed. 0 failures, 0 skipped. Only warning: the mlx bundle build warning (it existed before). No new warning.
    - next: review
  timestamp: 2026-10-21T09:26:15.698984+00:00
depends_on:
- 01M5E8VGGTR59NGWNVHSDKM4QT
position_column: doing
position_ordinal: '80'
title: AVK-8ae Remove the materialLevel token and the MaterialLevel enum from AgentTheme, because no theme selects the glass variant (D113 answer 3)
---
## Why

D113 answer 3: "remove the `materialLevel` control of the glass". After AVK-8ad, no code reads `AgentTheme.materialLevel`. A token that does nothing is a wrong promise to a host. This is a change of the public API of `AgentTheme`.

## Files and lines

- `Sources/AgentViewKit/Theme/AgentTheme.swift:83-` (`public enum MaterialLevel`), `:111-112` (the property), `:121` and `:127` (the init parameter), `:133`, `:152` (the default), and the layout comment at `:25-30` (it names `materialLevel` for the padding rule).
- `Tests/AgentViewKitTests/Theme/DefaultTokens.json:4`
- `Tests/AgentViewKitTests/Theme/AgentThemeTests.swift:61`, `:138`
- `Tests/AgentViewKitTests/Theme/AgentThemeGoldenTests.swift:68`
- `Tests/AgentViewKitTests/Infrastructure/ViewValueLayoutTests.swift:20`
- `Docs/decisions/visual-audit.md:30` (the `materialLevel` row).
- Each other hit of `materialLevel` or `MaterialLevel` in Sources, Tests, Examples and Docs (search first).

## What to do

- [x] Remove the enum, the property, the init parameter and the default value.
- [x] Change the layout comment of `AgentTheme` and keep the type with no padding byte: `ViewValueLayoutTests.theThemeHasNoPaddingByte` must pass with the new list of stored properties.
- [x] Remove the token from `DefaultTokens.json`, `AgentThemeTests` and `AgentThemeGoldenTests`.
- [x] Change the row in `Docs/decisions/visual-audit.md:30`: the token is removed by D113 answer 3.
- [x] Change each caller of the init in Examples and DemoSupport.

## Acceptance

- A search for `materialLevel` and `MaterialLevel` gives no hit in Sources, Tests and Examples. `visual-audit.md` names the removal.
- `swift build` of the package and of the demo app succeeds. The theme tests and `ViewValueLayoutTests` pass. Write the output of the full suite to a file, not to a pipe.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8