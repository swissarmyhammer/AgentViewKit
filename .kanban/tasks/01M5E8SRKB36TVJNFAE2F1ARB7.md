---
assignees:
- claude-code
depends_on:
- 01M5E8S3KAQ7EV2C2K13Y1K31Q
position_column: todo
position_ordinal: a080
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

- [ ] Replace each `.agentContentSurface()` above with `.agentContentEdge()`.
- [ ] Change the DocC comments: the card is content, has no fill and no glass, and a separator stroke marks its edge (D113).
- [ ] Change `ContentSurfaceHostedProbe` and the four hosted tests. Today they prove that an opaque surface hides the backdrop. Now they must prove the opposite: the backdrop color shows inside the card, with Reduce Transparency off and on (the ^dbbyg9w method). Keep the check that the card has no glass. Rename the probe if its name says "surface" and the meaning changed (for example `ContentEdgeHostedProbe`).
- [ ] Do not add a `GroupBox` or a `Form` here. AVK-8u decides with a screenshot if a group needs more.

## Acceptance

- No `agentContentSurface` in the four source files.
- Each of the four hosted tests passes: a pixel inside the card frame has the backdrop color, with Reduce Transparency off and on.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8