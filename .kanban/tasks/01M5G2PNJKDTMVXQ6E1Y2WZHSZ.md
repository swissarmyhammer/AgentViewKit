---
assignees:
- claude-code
position_column: todo
position_ordinal: 9f80
title: Find why aMountedViewThatGetsAKeyShowsNoWindowAndTakesNoFocus fails in some full runs
---
## Why

The test rules of the project forbid a test that fails in some runs only. In the full run `gqztxta-4` (window monitor `run-watched.sh`, 2026-10-21), `HostedViewHarnessTests.aMountedViewThatGetsAKeyShowsNoWindowAndTakesNoFocus` failed at `HostedViewHarnessTests.swift`:

`Expectation failed: NSApp.windows.allSatisfy { !$0.isKeyWindow }`

The next full run `gqztxta-5` had no code change and passed (1572 tests, 3 known issues). The window monitor showed 0 on-screen test windows in both runs. The change in that run touched only `Tests/AgentViewKitTests/Theme/GlassAccessibilityTests.swift`, which renders with `ImageRenderer` and opens no window.

The expectation reads `NSApp.windows` of the full process. Tests in other suites (not `.hostedSerially`) run in parallel and can make a window of the process the key window at that time.

## What to do

- [ ] Find the test that makes a window of the process the key window while `HostedViewHarnessTests` runs. Use the logs: `/private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/47eecec9-7dd0-49dd-b5a7-064ae713842b/scratchpad/winwatch/gqztxta-4.log`.
- [ ] Correct the cause, so that the expectation is always true. Do not add a retry, a sleep, a poll or a clock.

## Acceptance

- Two full runs with the window monitor pass, with 0 on-screen test windows. #avk-8