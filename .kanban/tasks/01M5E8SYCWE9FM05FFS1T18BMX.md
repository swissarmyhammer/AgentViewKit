---
assignees:
- claude-code
depends_on:
- 01M5E8S3KAQ7EV2C2K13Y1K31Q
- 01M5E8SRKB36TVJNFAE2F1ARB7
position_column: todo
position_ordinal: a180
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

- [ ] Replace `.agentContentSurface()` with `.agentContentEdge()` in `ErrorView` and `CompactionEntryView`.
- [ ] Replace `.agentContentSurface(radius: theme.radii.m)` with `.agentContentEdge(radius: theme.radii.m)` in `ArtifactView`.
- [ ] Change the DocC comments: no fill, no glass, a separator stroke marks the edge (D113).
- [ ] Change `TranscriptEntrySurfaceHostedTests`: the backdrop color shows inside each entry, with Reduce Transparency off and on.
- [ ] Add a test for `ArtifactView` with the same method, if no test checks its surface today.

## Acceptance

- No `agentContentSurface` in the three source files.
- The hosted tests pass: a pixel inside each entry frame has the backdrop color, with Reduce Transparency off and on.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8