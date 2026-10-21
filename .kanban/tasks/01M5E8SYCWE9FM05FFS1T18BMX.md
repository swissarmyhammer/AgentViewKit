---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5efq9dqe6sq785f40yptjt2
  text: 'Research: no test checked the surface of `ArtifactView` before this card. `AttachmentInspectorHostedTests` only checks its title, inline text and actions. Thus a new suite `ArtifactViewSurfaceHostedTests` is added. It shows an artifact with inline text, because an artifact with a URL needs a file on the disk. The pattern is the same as ^2f1arb7: one test per suite calls `ContentSurfaceHostedProbe.expectBackdropShowsInsideTheEdge`, with Reduce Transparency off and on. ErrorView, CompactionEntryView and ArtifactView fill the width of the window (each has a Spacer in an HStack), so the edge check finds the leading edge. RED: 6 cases failed with "No row shows the edge with the backdrop inside it". GREEN after the change to `agentContentEdge`. Other `agentContentSurface` uses (RequestDeck, AgentSurfaces, AgentSurfacesTests, the probe) are for other cards and stay.'
  timestamp: 2026-10-21T05:42:38.263779+00:00
- actor: claude-code
  id: 01m5efqc2be0t3stcjxtr8wc1s
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Items/ErrorView.swift, Sources/AgentViewKit/Items/CompactionEntryView.swift, Sources/AgentViewKit/Attachments/ArtifactView.swift, Tests/AgentViewKitTests/Items/TranscriptEntrySurfaceHostedTests.swift, Tests/AgentViewKitTests/Attachments/ArtifactViewSurfaceHostedTests.swift (new), plus the card. `swift test`: 1450 tests in 180 suites passed with 2 known issues (existed before); the mlx bundle warning existed before.
    - next: /review
  timestamp: 2026-10-21T05:42:40.971461+00:00
- actor: claude-code
  id: 01m5efwzmexf977zabca6jryzg
  text: |-
    ### test — green
    - evidence: swift test, 71 s. Swift Testing: 1450 tests in 180 suites passed, 2 known issues (these existed before). PackageStructureTests target: 173 tests in 23 suites passed. ArtifactViewSurfaceHostedTests passed. XCTest: 0 tests, 0 failures.
    - warnings: a rebuild of the 5 changed files with swift build --build-tests gave only the known mlx bundle warning (missing creator for mutated node). No new warning.
    - next: review.
  timestamp: 2026-10-21T05:45:44.846776+00:00
- actor: claude-code
  id: 01m5efzgsh6x0y49xvqcb3rhz5
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 20404fa). 0 findings, 0 confirmed, 0 refuted. 5 files reviewed. 2 .kanban files were not reviewed because of .reviewignore.
    - next: The task is in done. No work remains.
  timestamp: 2026-10-21T05:47:07.953368+00:00
- actor: claude-code
  id: 01m5efzwm1pq4jqtjbh2p6fy4g
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 5 files
    - test: green — swift test, 1450 passed, 2 known issues that were there before; 173 structure tests passed
    - commit: 20404fa
    - review: clean — 0 findings
  timestamp: 2026-10-21T05:47:20.065698+00:00
depends_on:
- 01M5E8S3KAQ7EV2C2K13Y1K31Q
- 01M5E8SRKB36TVJNFAE2F1ARB7
position_column: done
position_ordinal: ffff9080
title: 'AVK-8x Transcript entries and artifacts: change ErrorView, CompactionEntryView and ArtifactView to agentContentEdge (D113 answer 1)'
---
## Why

D113 answer 1: the fills go. A content card has no fill, only a `.separator` stroke in a `ConcentricRectangle` (`agentContentEdge(radius:)`, AVK-8v).

## Files and lines

- `Sources/AgentViewKit/Items/ErrorView.swift:96` (`.agentContentSurface()`) and the comment at `:17`.
- `Sources/AgentViewKit/Items/CompactionEntryView.swift:100` (`.agentContentSurface()`) and the comment at `:33`.
- `Sources/AgentViewKit/Attachments/ArtifactView.swift:63` (`.agentContentSurface(radius: theme.radii.m)`).
- Test: `Tests/AgentViewKitTests/Items/TranscriptEntrySurfaceHostedTests.swift` (uses `ContentSurfaceHostedProbe`; AVK-8w changes the probe).

## What to do

- [x] Replace `.agentContentSurface()` with `.agentContentEdge()` in `ErrorView` and `CompactionEntryView`.
- [x] Replace `.agentContentSurface(radius: theme.radii.m)` with `.agentContentEdge(radius: theme.radii.m)` in `ArtifactView`.
- [x] Change the DocC comments: no fill, no glass, a separator stroke marks the edge (D113).
- [x] Change `TranscriptEntrySurfaceHostedTests`: the backdrop color shows inside each entry, with Reduce Transparency off and on.
- [x] Add a test for `ArtifactView` with the same method, if no test checks its surface today.

## Acceptance

- No `agentContentSurface` in the three source files.
- The hosted tests pass: a pixel inside each entry frame has the backdrop color, with Reduce Transparency off and on.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8