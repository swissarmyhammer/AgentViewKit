---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5edxs8zmy8ztp0sv39ncc5c
  text: |-
    Implementation and discoveries:

    - The four views now use `.agentContentEdge()`. Their DocC says: content, no fill, no glass, a separator stroke marks the edge (D113). No `GroupBox` and no `Form` were added.
    - Discovery (measured with a temporary test, then deleted): the cache of a window shows no glass with Reduce Transparency off AND on. A `.glass` button also gives the same cache pixels with Reduce Transparency off and on. Thus no hosted pixel check can see glass. The old check "no backdrop pixel" proved an opaque fill, not "no glass".
    - The new shared check is `ContentSurfaceHostedProbe.expectBackdropShowsInsideTheEdge(of:reducesTransparency:size:)`. The backdrop fills the full frame of the view (new placement `BackdropPlacement.behindToTheEdge`). The check needs one row where the point on the leading edge (0.25 pt) does not show the backdrop and the point inside the edge (1.5 pt) shows it. A fill fails it (RED was seen with `agentContentSurface`). A view with no stroke fails it (seen with a temporary removal of the edge from StatusBar). A view on glass has no stroke, so it also fails. `GlassPlacementTests` keeps glass out of these files by the source.
    - Each of the four suites now has one test with Reduce Transparency off and on, in place of the old in-front control and the old "no pixel" test.
    - The probe keeps its name: `TranscriptEntrySurfaceHostedTests` (ErrorView, CompactionEntryView: AVK-8x) still uses `expectBackdropShowsOnlyInFront` for the filled surface, so the probe still checks the content surface. A rename to `ContentEdgeHostedProbe` fits when AVK-8x moves that suite and AVK-8ab removes `agentContentSurface`.
  timestamp: 2026-10-21T05:11:13.951526+00:00
- actor: claude-code
  id: 01m5edxwh7fp8354xfqf7npzhg
  text: |-
    ### implement — changed
    - evidence: 9 files — Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift, Sources/AgentViewKit/Connections/AgentAuthView.swift, Sources/AgentViewKit/Status/SessionNoticeBanner.swift, Sources/AgentViewKit/Status/StatusBar.swift, Tests/AgentViewKitTests/Theme/ContentSurfaceHostedProbe.swift, Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewSurfaceHostedTests.swift, Tests/AgentViewKitTests/Connections/AgentAuthViewSurfaceHostedTests.swift, Tests/AgentViewKitTests/Status/SessionNoticeBannerSurfaceHostedTests.swift, Tests/AgentViewKitTests/Status/StatusBarSurfaceHostedTests.swift. `swift test`: 1447 tests in 178 suites passed with 2 known issues (and 173 tests in 23 suites passed); only the mlx bundle warning, which existed before.
    - next: /review
  timestamp: 2026-10-21T05:11:17.287406+00:00
- actor: claude-code
  id: 01m5ee2r9csn0b9xza6zqg30z3
  text: |-
    ### test — green
    - evidence: `swift test` (full suite, one run, 108 s wall time). Exit code 0.
    - PackageStructureTests target: 173 tests in 23 suites, all passed (20.8 s).
    - AgentViewKitTests target: 1447 tests in 178 suites, all passed (70.1 s), with 2 known issues. Both known issues existed before this change (HostedLayoutExpectationsTests, ThemeHeightExpectationsTests).
    - Warnings: only the mlx bundle build warning that existed before. No new warning.
    - Failures: 0. Skipped tests: 0. I changed no file.
    - next: review
  timestamp: 2026-10-21T05:13:56.780227+00:00
- actor: claude-code
  id: 01m5ee58x37pj54yhh9jcwabc6
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 2ffc81f). 0 findings, 0 confirmed, 0 refuted. 9 files reviewed. 2 files in .kanban/ are not reviewed because of .reviewignore.
    - next: The task is in done. No more work is necessary.
  timestamp: 2026-10-21T05:15:19.331472+00:00
- actor: claude-code
  id: 01m5ee5tvvgfrj928vd17ry16b
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 9 files
    - test: green — swift test, 1447 passed, 2 known issues that were there before; 173 structure tests passed
    - commit: 2ffc81f
    - review: clean — 0 findings
  timestamp: 2026-10-21T05:15:37.723662+00:00
depends_on:
- 01M5E8S3KAQ7EV2C2K13Y1K31Q
position_column: done
position_ordinal: ffff8d80
title: 'AVK-8w Request cards and notices: change PermissionView, AgentAuthView, SessionNoticeBanner and StatusBar from the filled content surface to agentContentEdge (D113 answer 1)'
---
## Why

D113 answer 1: the fills go. A content card has no fill, only a `.separator` stroke in a `ConcentricRectangle` (`agentContentEdge(radius:)`, AVK-8v).

## Files and lines

- `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift:173` (`.agentContentSurface()`)
- `Sources/AgentViewKit/Connections/AgentAuthView.swift:271` (`.agentContentSurface()`)
- `Sources/AgentViewKit/Status/SessionNoticeBanner.swift:199` (`.agentContentSurface()`)
- `Sources/AgentViewKit/Status/StatusBar.swift:88` (`.agentContentSurface()`)
- The DocC comments that name `agentContentSurface` in these files (`PermissionView.swift:15`, `AgentAuthView.swift:58`, `SessionNoticeBanner.swift:133`, `StatusBar.swift:9`).
- Tests: `Tests/AgentViewKitTests/Theme/ContentSurfaceHostedProbe.swift`, `Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewSurfaceHostedTests.swift`, `Tests/AgentViewKitTests/Connections/AgentAuthViewSurfaceHostedTests.swift`, `Tests/AgentViewKitTests/Status/SessionNoticeBannerSurfaceHostedTests.swift`, `Tests/AgentViewKitTests/Status/StatusBarSurfaceHostedTests.swift`.

## What to do

- [x] Replace each `.agentContentSurface()` above with `.agentContentEdge()`.
- [x] Change the DocC comments: the card is content, has no fill and no glass, and a separator stroke marks its edge (D113).
- [x] Change `ContentSurfaceHostedProbe` and the four hosted tests. Today they prove that an opaque surface hides the backdrop. Now they must prove the opposite: the backdrop color shows inside the card, with Reduce Transparency off and on (the ^dbbyg9w method). Keep the check that the card has no glass. Rename the probe if its name says "surface" and the meaning changed (for example `ContentEdgeHostedProbe`).
- [x] Do not add a `GroupBox` or a `Form` here. AVK-8u decides with a screenshot if a group needs more.

## Acceptance

- No `agentContentSurface` in the four source files.
- Each of the four hosted tests passes: a pixel inside the card frame has the backdrop color, with Reduce Transparency off and on.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8