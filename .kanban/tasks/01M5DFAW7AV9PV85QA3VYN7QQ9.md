---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dfe0zv8n6qh249p67c2qf1
  text: |-
    ### decision (testudoapp-4c, AVK-8 "Decisions for the plan")
    - Use `ConcentricRectangle` and the `.concentric` style of the SDK. `.containerConcentric` is not in the macOS 27 SDK. The peer corrected the research file and D110 (e).
  timestamp: 2026-10-20T20:18:20.283496+00:00
- actor: claude-code
  id: 01m5e20fcppqdbrff643t938km
  text: |-
    ### research
    - The kit has 10 fixed `RoundedRectangle(cornerRadius:` uses in 7 files: ArtifactView (2, radii.m), EditorBlockChrome (2, radii.m), AttachmentChip (1, radii.m), DiffView (1, radii.s, not continuous), SourcesView (1, radii.s, not continuous), ElicitationFieldViews (1, radii.s), RequestDeck (1, radii.l, after ^56y8q6a). The kit has no `.rect(cornerRadius:` use.
    - `AgentSurface.shape(for:)` (^c5mvvt4) gives only the large radius. Plan: add `AgentSurface.shape(radius:)`, and make `shape(for:)` call it with `theme.radii.l`. Each site calls `shape(radius:)` with its token.
    - A `ConcentricRectangle` path is continuous. Thus DiffView and SourcesView change from a circular corner to a continuous corner. This is the style of the other shapes of the kit.
    - Structure test: a new scan in Tests/PackageStructureTests finds `RoundedRectangle(cornerRadius:` and `.rect(cornerRadius:` in Sources/AgentViewKit, in the style of TernaryLocalizedKeyTests.
  timestamp: 2026-10-21T01:42:59.222680+00:00
- actor: claude-code
  id: 01m5e2gt6ka8cbm1vmc14j7amz
  text: |-
    ### implementation
    - New `AgentSurface.shape(radius:)` in Sources/AgentViewKit/Theme/AgentSurfaces.swift: `ConcentricRectangle(corners: .concentric(minimum: .fixed(radius)), isUniform: true)`. `shape(for:)` now calls it with `theme.radii.l`.
    - The 10 fixed corners now use `AgentSurface.shape(radius:)` with the same token (s or m). RequestDeck uses `AgentSurface.shape(for: theme)` (radii.l).
    - Discovery: `ConcentricRectangle` is a `Shape`, but it is NOT an `InsettableShape`. Thus it has no `strokeBorder`. The compiler gave only "failed to produce diagnostic for expression" in EditorBlockChrome. The 4 sites with `strokeBorder(.separator)` (ArtifactView, EditorBlockChrome, ElicitationFieldViews, RequestDeck) now use `stroke(.separator)`, as `AgentContentSurface` (^c5mvvt4) does. A `stroke` is on the center line of the edge, so half of the 1 pt border is outside the shape. In RequestDeck the `clipShape` after the overlay cuts that half.
    - A `ConcentricRectangle` path is continuous, so DiffView and SourcesView change from a circular corner to a continuous corner.
    - Tests: AgentSurfacesTests has 2 new parameterized tests over radii.s and radii.m (concentric minimum, and the path with no container). New Tests/PackageStructureTests/FixedCornerRadiusTests.swift: a source scan that finds `RoundedRectangle(cornerRadius:` (whole word, with `WordPattern`) and `.rect(cornerRadius:` in Sources/AgentViewKit. It failed with the 10 sites before the change.
  timestamp: 2026-10-21T01:51:54.579736+00:00
- actor: claude-code
  id: 01m5e2gzpqkn00fq82yjjwyc2m
  text: |-
    ### implement — changed
    - evidence: 10 files — Sources/AgentViewKit/Theme/AgentSurfaces.swift, Attachments/ArtifactView.swift, Attachments/AttachmentChip.swift, Citations/SourcesView.swift, Code/EditorBlockChrome.swift, Diff/DiffView.swift, Elicitation/ElicitationFieldViews.swift, HumanInTheLoop/RequestDeck.swift, Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift, Tests/PackageStructureTests/FixedCornerRadiusTests.swift (new). `swift test`: 1437 tests in 176 suites passed with 2 known issues, plus 148 tests in 21 structure suites passed; only the mlx bundle warning. EditorThemeViewsTests passed. `rg 'RoundedRectangle\(cornerRadius' Sources/AgentViewKit` finds no match.
    - next: /review
  timestamp: 2026-10-21T01:52:00.215569+00:00
- actor: claude-code
  id: 01m5e2rkh4pxfdr9qxz84pyz3r
  text: |-
    ### test - green
    - evidence: `swift test` (full suite), 177 s. PackageStructureTests ran: 148 tests in 21 suites passed, and this includes FixedCornerRadiusTests. All targets: 1437 tests in 176 suites passed, 0 failures, 0 skipped, with 2 known issues (HostedLayoutExpectationsTests, ThemeHeightExpectationsTests). Those 2 existed before.
    - warnings: only the mlx-swift_Cmlx bundle build warning, which existed before. No new warning.
    - next: review
  timestamp: 2026-10-21T01:56:09.892667+00:00
depends_on:
- 01M5DF892NSFBA3B087C5MVVT4
- 01M5D07S5WH2JTTWW8B56Y8Q6A
position_column: doing
position_ordinal: '80'
title: AVK-8m Use concentric corners in place of fixed RoundedRectangle radii
---
## Why

D110 (e): concentric corners. A shape inside a container uses a radius that follows the radius of the container. Today the kit uses `RoundedRectangle(cornerRadius: theme.radii.x)` with a fixed token.

## Files and lines

- `Sources/AgentViewKit/Attachments/ArtifactView.swift` lines 63, 65.
- `Sources/AgentViewKit/Code/EditorBlockChrome.swift` lines 24, 26 (code blocks and command output).
- `Sources/AgentViewKit/Attachments/AttachmentChip.swift` line 52.
- `Sources/AgentViewKit/Diff/DiffView.swift` lines 260-262.
- `Sources/AgentViewKit/Citations/SourcesView.swift` lines 145-147.
- `Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift` lines 228-229.
- `Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift` lines 517-523. This file has changes in the work tree from AVK-7d (^56y8q6a). Do this file after that card is done.
- Capsules (`ToolCallView.swift:750`, `InlineCitation.swift:257`, `PendingRequestCountBadge.swift:85`, `ElicitationLayout.swift:159-163`) stay capsules.

## What to do

- [x] Replace each `RoundedRectangle(cornerRadius:)` above with the concentric shape function of AVK-8b, with the same token as the fallback radius.
- [x] Keep the fills and the strokes. Content keeps its standard backgrounds, for example `editorTheme.editorBackground` in `EditorBlockChrome` and `.background.secondary` in `ArtifactView`.
- [x] Add no glass.

## Acceptance

- `rg 'RoundedRectangle\(cornerRadius' Sources/AgentViewKit` finds no match.
- The `RenderedPixels` tests in `Tests/AgentViewKitTests/Theme/EditorThemeViewsTests.swift` pass. The code block, the command output, the diff and the citation still draw the theme colors.
- All tests pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8