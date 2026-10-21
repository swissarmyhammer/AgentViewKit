---
assignees:
- claude-code
position_column: todo
position_ordinal: b580
title: Fix the hang in RecordedSessionsAgentTests.theAgentWritesItsProjectRegistryIntoTheConfigurationDirectoryOfTheStage
---
Source: the test step of AVK-10 (^0svs7g7).

Problem: in 2 of 3 full `swift test` runs, the run stopped with 0% CPU in `RecordedSessionsAgentTests.theAgentWritesItsProjectRegistryIntoTheConfigurationDirectoryOfTheStage`. The test waited on a session resume that never returned. The runs had to be killed. The suite alone passed (7 of 7), and the third full run passed. The machine load average was about 5. The AVK-10 change does not touch this test or the ACP code that it uses.

The test rules forbid a test that hangs: an event wait must wait only on an event that is certain to come.

Do:
- Find the root cause: why the session resume does not return in a full run (for example a shared directory or port between parallel tests, a missing `.serialized` trait, a race between the stage setup and the resume, or an event that the test can miss if it comes before the wait starts).
- Fix it so the wait is on an event that is certain to come, or so the test fails at once with a clear message when the resume cannot start. Do not add a retry, a sleep, a poll, a clock or a time limit.

Acceptance:
- 5 full `swift test` runs one after the other end with no hang.
- The test alone passes. #avk-8