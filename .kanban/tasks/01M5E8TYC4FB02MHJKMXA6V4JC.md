---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5edyr1t4w5gqj05x3x58q0e
  text: |-
    ### note from ^2f1arb7 (AVK-8w)
    - The shared test probe `ContentSurfaceHostedProbe` keeps its name for now, because `TranscriptEntrySurfaceHostedTests` (AVK-8x) still uses the old opaque check.
    - When this card removes `agentContentSurface`, also remove the old opaque check `expectBackdropShowsOnlyInFront` and `BackdropPlacement.behind` if nothing uses them, and rename the probe to `ContentEdgeHostedProbe`.
  timestamp: 2026-10-21T05:11:45.466551+00:00
- actor: claude-code
  id: 01m5exjzg3rmr4m15t4r7kdnat
  text: |-
    ### research
    - `agentContentSurface` / `AgentContentSurface` show only in `Theme/AgentSurfaces.swift`, `AgentSurfacesTests.swift` and `ContentSurfaceHostedProbe.swift` (doc). No hit in README, plan.md, Docs or Examples.
    - `AgentContentEdge` already has `shape(in:)`. The surface only forwarded to it, so no shape code must move.
    - `expectBackdropShowsOnlyInFront` has no caller. `BackdropPlacement.behind` has one caller (`RequestDeckSurfaceHostedTests.inTheBarTheBackdropShowsBehindTheCard`), so it stays. `BackdropPlacement.inFront` has only the removed check as its caller, so it goes too.
    - `GlassPlacementTests` allow lists name `Theme/AgentSurfaces.swift`. That file stays, so no change there.
    - Doc comments in `StateBanner.swift` and `RequestDeckWithdrawn.swift` still say "content surface of the kit". They will name the content edge.
  timestamp: 2026-10-21T09:44:57.091751+00:00
- actor: claude-code
  id: 01m5exvd0rwmvhx1ks3dwa1g1f
  text: |-
    ### implementation landed
    - Removed `AgentContentSurface` and both `agentContentSurface` overloads from `Sources/AgentViewKit/Theme/AgentSurfaces.swift`. `AgentContentEdge.shape(in:)` already held the shape selection, so no code moved. The doc comments of `AgentSurface` and `agentFloatingGlass()` now name `agentContentEdge(radius:)`.
    - Doc comments in `Status/StateBanner.swift` and `HumanInTheLoop/RequestDeckWithdrawn.swift` said "content surface of the kit". They now name the content edge.
    - `AgentSurfacesTests`: removed `contentSurface`, `surfaceFill`, the fill test, the hide-backdrop test and `ContentShapeModifier`. The two parameterized shape tests now test `AgentContentEdge` only. The no-glass test now uses the content edge (`theContentEdgeHasNoGlassThatFollowsReduceTransparency`). `OverBackdrop` stays, because the edge and glass fixtures use it.
    - Renamed `ContentSurfaceHostedProbe` to `ContentEdgeHostedProbe` (file is now `Tests/AgentViewKitTests/Theme/ContentEdgeHostedProbe.swift`, with `git mv`) and changed the 11 test files that use it.
    - Removed `expectBackdropShowsOnlyInFront` (no caller). Kept `BackdropPlacement.behind`, because `RequestDeckSurfaceHostedTests.inTheBarTheBackdropShowsBehindTheCard` uses it. Removed `BackdropPlacement.inFront`, because only the removed check used it.
    - Guard: the compiler. The symbols are gone, so a new use of `agentContentSurface` does not compile. I added no source-scan test.
    - `GlassPlacementTests` needs no change: `Theme/AgentSurfaces.swift` stays.
    - Note: the `replace_all` flag of the `files` edit op replaced only the first hit in each file. I did the other hits with separate edits.
  timestamp: 2026-10-21T09:49:33.080925+00:00
- actor: claude-code
  id: 01m5exvg781dyhdrfqe3tzgf4n
  text: |-
    ### implement — changed
    - evidence: `swift test` (full suite, output in a scratchpad file): 1473 tests in 184 suites passed, with the 2 known issues and the old mlx bundle warning only. GlassPlacementTests, AgentSurfacesTests, RequestDeckSurfaceHostedTests and EditorThemeViewsTests pass. `rg` for agentContentSurface / AgentContentSurface / ContentSurfaceHostedProbe / expectBackdropShowsOnlyInFront in Sources, Tests, Examples, Docs, README and plan.md gives no hit.
    - files: Sources/AgentViewKit/Theme/AgentSurfaces.swift, Sources/AgentViewKit/Status/StateBanner.swift, Sources/AgentViewKit/HumanInTheLoop/RequestDeckWithdrawn.swift, Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift, Tests/AgentViewKitTests/Theme/ContentEdgeHostedProbe.swift (renamed from ContentSurfaceHostedProbe.swift), and the probe rename in 11 test files.
    - next: /review
  timestamp: 2026-10-21T09:49:36.360940+00:00
- actor: claude-code
  id: 01m5ey11db3dvxs4hr4zwn81ph
  text: |-
    ### test — green
    - evidence: `swift test` (full suite, output in the scratchpad file test1.log), exit 0, 110 s. Swift Testing: 1473 tests in 184 suites passed (72.7 s, 2 known issues). PackageStructureTests target: 179 tests in 23 suites passed (GlassPlacementTests, SharedSymbolTreatmentTests, ImportBoundaryTests, and others). ReadmeSnippets target: 1 test passed. XCTest runs: 0 tests. 0 failures, 0 skipped.
    - warnings: only the known mlx bundle build warning. The 2 known issues are the same as before (HostedLayoutExpectationsTests, ThemeHeightExpectationsTests). Note: the build step took 2.57 s (incremental build).
    - search: no hit for agentContentSurface or AgentContentSurface in Sources, Tests, Examples.
    - next: review
  timestamp: 2026-10-21T09:52:37.803604+00:00
- actor: claude-code
  id: 01m5ey3j98smfahbcyvxh98bjv
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (c5e437b). 17 files reviewed. 0 findings, 0 confirmed, 0 refuted. Five code-hygiene tool rules did not read Tests/AgentViewKitTests/Theme/ContentSurfaceHostedProbe.swift, because the commit removed that file (rename of the probe).
    - next: none. The task moved to done.
  timestamp: 2026-10-21T09:54:00.616770+00:00
- actor: claude-code
  id: 01m5ey3wzj3zn54a8z0tk3h3tq
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 17 files (agentContentSurface removed; the probe renamed to ContentEdgeHostedProbe)
    - test: green — swift test, 1473 passed, 2 known issues that were there before; 179 structure tests passed
    - commit: c5e437b
    - review: clean — 0 findings
  timestamp: 2026-10-21T09:54:11.570634+00:00
depends_on:
- 01M5E8SRKB36TVJNFAE2F1ARB7
- 01M5E8SYCWE9FM05FFS1T18BMX
- 01M5E8T69B91ATX31Q3BR70YR3
- 01M5E8TFNDT9Q9WE6C2D6YW9PP
- 01M5E8TQ4JA20GAATH7MZ0NFKA
position_column: done
position_ordinal: ffff9980
title: AVK-8ab Remove agentContentSurface and AgentContentSurface after all callers moved to agentContentEdge (D113 answer 1)
---
## Why

D113 answer 1: "`agentContentSurface()` ... removed." After AVK-8w, AVK-8x, AVK-8y, AVK-8z and AVK-8aa, no view calls it. This card removes the API, so that no new code can use a filled content surface.

## Files and lines

- `Sources/AgentViewKit/Theme/AgentSurfaces.swift:45-73` (`AgentContentSurface`), `:86-119` (both `agentContentSurface` overloads), and the doc comment at `:3-7` that names it.
- `Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift:6`, `:140-155`, `:188-194` (tests of the old surface).
- `Tests/PackageStructureTests/GlassPlacementTests.swift:64-65`: `GlassForm.surfacesFile` is `Theme/AgentSurfaces.swift`. If this card moves or renames that file, change the constant and the allow lists.

## What to do

- [x] Search the package (Sources, Tests, Examples, Docs) for `agentContentSurface` and `AgentContentSurface`. The only hits must be in the files above.
- [x] Remove `AgentContentSurface` and both `agentContentSurface` overloads.
- [x] Remove or move the tests of the old surface to `agentContentEdge` (AVK-8v already has the edge tests: do not duplicate them).
- [x] Change the doc comments that name the old modifier (for example `AgentSurfaces.swift:5`, `:92`, `:129`) to name `agentContentEdge(radius:)`.
- [x] Keep `GlassPlacementTests` green: its allow lists must name files that exist (`eachAllowedFileIsInThePackage`).

## Acceptance

- A search for `agentContentSurface` and `AgentContentSurface` in Sources, Tests and Examples gives no code hit.
- `swift test --filter PackageStructureTests` and the theme tests pass. Write the output of the full suite to a file, not to a pipe.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8