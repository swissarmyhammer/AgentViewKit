---
assignees:
- claude-code
depends_on:
- 01M50ER0NN5DRGV5S3HGQ8H07P
position_column: todo
position_ordinal: '8980'
title: 'Mail step 7 T4-A1: Remove the clock waits and polls from the Input tests'
---
Part of T4 (^m7q9e97). Area: Tests/AgentViewKitTests/Input (about 97 sites). Replace each `pump(until:)`, `waitUntil`, `harness.pump()`, `pump(for:)` with the decided pattern: a direct render pass (from T4-A0), and an event wait (ObservationWait.until on a value that is certain to change) where the render pass is not enough; or a gate or a fixed order. No time bound. A hosted test holds HostedTestLock, so each wait with no bound must be for a certain event. Do not read back a value that the test wrote (test-integrity). Delete no test. If a wait has no event and no direct render, report it to the step owner with an example before you change it. One full run, one commit. Write all text in STE. #mail-step-7