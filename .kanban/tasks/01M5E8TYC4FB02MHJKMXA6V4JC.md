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
depends_on:
- 01M5E8SRKB36TVJNFAE2F1ARB7
- 01M5E8SYCWE9FM05FFS1T18BMX
- 01M5E8T69B91ATX31Q3BR70YR3
- 01M5E8TFNDT9Q9WE6C2D6YW9PP
- 01M5E8TQ4JA20GAATH7MZ0NFKA
position_column: todo
position_ordinal: a580
title: AVK-8ab Remove agentContentSurface and AgentContentSurface after all callers moved to agentContentEdge (D113 answer 1)
---
## Why

D113 answer 1: "`agentContentSurface()` ... removed." After AVK-8w, AVK-8x, AVK-8y, AVK-8z and AVK-8aa, no view calls it. This card removes the API, so that no new code can use a filled content surface.

## Files and lines

- `Sources/AgentViewKit/Theme/AgentSurfaces.swift:45-73` (`AgentContentSurface`), `:86-119` (both `agentContentSurface` overloads), and the doc comment at `:3-7` that names it.
- `Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift:6`, `:140-155`, `:188-194` (tests of the old surface).
- `Tests/PackageStructureTests/GlassPlacementTests.swift:64-65`: `GlassForm.surfacesFile` is `Theme/AgentSurfaces.swift`. If this card moves or renames that file, change the constant and the allow lists.

## What to do

- [ ] Search the package (Sources, Tests, Examples, Docs) for `agentContentSurface` and `AgentContentSurface`. The only hits must be in the files above.
- [ ] Remove `AgentContentSurface` and both `agentContentSurface` overloads.
- [ ] Remove or move the tests of the old surface to `agentContentEdge` (AVK-8v already has the edge tests: do not duplicate them).
- [ ] Change the doc comments that name the old modifier (for example `AgentSurfaces.swift:5`, `:92`, `:129`) to name `agentContentEdge(radius:)`.
- [ ] Keep `GlassPlacementTests` green: its allow lists must name files that exist (`eachAllowedFileIsInThePackage`).

## Acceptance

- A search for `agentContentSurface` and `AgentContentSurface` in Sources, Tests and Examples gives no code hit.
- `swift test --filter PackageStructureTests` and the theme tests pass. Write the output of the full suite to a file, not to a pipe.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8