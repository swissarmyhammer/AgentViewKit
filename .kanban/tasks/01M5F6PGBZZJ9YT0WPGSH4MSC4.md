---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5f8axe9xpp7g2tz9jseadtr
  text: |-
    ### research — the stuck test is not RecordedSessionsAgentTests
    - Reproduced the hang in the first full `swift test` run (scratchpad repro1.txt). The test helper had 0% CPU. `sample` showed only idle threads (an async hang, not a lock).
    - `swift-inspect dump-concurrency <pid>` (scratchpad concurrency1.txt) showed the real stuck task: `ThreadFloatingControlsHostedTests.aPressOnThePillOfTheThreadScrollsTheListToTheBottom()` waits in `HostedViewHarness.render(when:)` -> `ObservationWait.until` for `anchors.visibleIDs.last == lastKey`. That test holds the `HostedTestLock`. 59 other hosted tests wait in `HostedTestLock.acquire()`, which includes the next hosted test of the serialized suite RecordedSessionsAgentTests. No task had a frame of RecordedSessionsAgentTests, DemoAgent or a session resume.
    - The log tail named `theAgentWritesItsProjectRegistryIntoTheConfigurationDirectoryOfTheStage` only because `swift test` output to a file is block-buffered: the file ends in the middle of a line. The last line in the file is not the stuck test. The hung run of AVK-10 (scratchpad test2.log) also has "aPressOnThePillOfTheThreadScrollsTheListToTheBottom() started" with no "passed".
    - Root cause: commit f9c7fd4 (^c16tvb7) made the test wait for the list to report the last row after the press. Only a layout pass of the list can write that report, and the test starts no pass: it depends on a pass that SwiftUI starts by itself in the off-screen harness window. That pass is not certain to come, so the wait can stay suspended forever.
    - Plan: after the event that the recorder gets the bottom target, make one `harness.render()` pass (the pattern of `ConversationViewHostedTests.aPressOnThePillScrollsTheListToTheLastRow`: the pass moves the list, and the list reports its rows in that pass). Then check `anchors.visibleIDs.last == lastKey` with `#expect`, so the test fails at once with a clear message when the list does not report the last row.
  timestamp: 2026-10-21T12:52:47.177158+00:00
- actor: claude-code
  id: 01m5f9vk9xcbza22en1q4tb74m
  text: |-
    ### implementation, and what did not work
    - First try (did not work): after the bottom target, one `harness.render()`, then `#expect(anchors.visibleIDs.last == lastKey)`. The focused run failed one time: after the pass, `visibleIDs.last` was nil. Diagnostic runs (code removed after) showed that the end of the scroll is not always the same in the off-screen window: when an update of SwiftUI applies the scroll, the list goes to m29 (the last row); when a render pass of the test applies it (`anchors.onScroll(.bottom)` + `render()`), the list stops at m27, two rows above the last row, and stays there after 6 more passes, `CATransaction.flush()`, `layoutIfNeeded()` and `display()`. That fixed point is the hang: the wait for `visibleIDs.last == lastKey` can never end. In `ConversationView` alone, the same scroll in a render pass goes to m29, so the difference is in `AgentThreadView` (possibly the `.safeAreaBar` of the floating controls). New card ^92k32m0 records this.
    - The project already documents this hazard in the doc comment of `ConversationViewHostedTests.reportRows(at:of:to:)`: "The hosted tests do not wait for the report of SwiftUI ... A wait for it holds `HostedTestLock` and stops all hosted tests."
    - Change: `ThreadFloatingControlsHostedTests.aPressOnThePillOfTheThreadScrollsTheListToTheBottom` is now `aPressOnThePillOfTheThreadRequestsTheScrollToTheBottom`. It waits only for the bottom scroll target (certain: the press always requests it, and no jump cancels it), makes one `render()` pass, and checks the pin and that the pill is gone. It no longer checks `showsRow(lastKey)` (and does not wait for the last-row report), because no certain check of the last row is possible in the harness now. The doc comment states the gap and names `ConversationViewHostedTests.aPressOnThePillScrollsTheListToTheLastRow`, which checks the scroll to the last row for the conversation. ^92k32m0 restores a certain last-row check for the thread.
    - RecordedSessionsAgentTests is not changed. It was not the cause.
  timestamp: 2026-10-21T13:19:22.429750+00:00
- actor: claude-code
  id: 01m5f9vtz6k6a7bz306k0ca5wr
  text: |-
    ### implement — changed
    - evidence: root cause: `ThreadFloatingControlsHostedTests.aPressOnThePillOfTheThreadScrollsTheListToTheBottom` (commit f9c7fd4, ^c16tvb7) waited in `harness.render(when:)` for `anchors.visibleIDs.last == lastKey`, a report that only a SwiftUI layout pass writes and that is not certain to come in the off-screen window. The test held `HostedTestLock`, so 59 hosted tests (with the next test of RecordedSessionsAgentTests) waited for ever. Proof: `swift-inspect dump-concurrency` of the hung run (scratchpad concurrency1.txt). The log named RecordedSessionsAgentTests only because the output file is block-buffered.
    - file: Tests/AgentViewKitTests/Thread/ThreadFloatingControlsHostedTests.swift (the test is now `aPressOnThePillOfTheThreadRequestsTheScrollToTheBottom`: wait for the bottom scroll target, one render pass, check the pin and the pill).
    - runs: 5 full `swift test` runs one after the other (scratchpad sh4msc4-full-1.txt to sh4msc4-full-5.txt): each exit 0, 1487 tests in 187 suites passed with 2 known issues (existed before), package structure 177 tests in 25 suites passed, no hang (76 s to 83 s each). Only warning: the mlx bundle "missing creator" warning that existed before. `swift test --filter RecordedSessionsAgentTests/theAgentWritesItsProjectRegistryIntoTheConfigurationDirectoryOfTheStage` alone: passed.
    - new card: ^92k32m0 (the scroll of the thread can stop two rows above the last row in the harness; restore a certain last-row check).
    - next: /review
  timestamp: 2026-10-21T13:19:30.278632+00:00
- actor: claude-code
  id: 01m5fa1fmyagxx1cbkwpgwbwy7
  text: |-
    ### test - green
    - evidence: swift test (one full run, exit 0, 135 s wall). Swift Testing: 1487 tests in 187 suites passed in 91.564 s with 2 known issues. 0 failures. The XCTest runner executed 0 tests.
    - suites: PackageFilesTests, ThreadBottomBarStructureTests, ThreadTopBarStructureTests, ComposerGlassStructureTests, ReadmeSnippetsTests, ReadmeSnippetTests and ReadmeCoverageTests all ran and passed.
    - warnings: only the known mlx bundle warning (missing creator for mutated node). No new warning.
    - known issues: aWrappedTextWithAFixedVerticalSizeFails and aViewThatIgnoresTheThemeFails (as before).
    - next: review. No source file was changed by this step.
  timestamp: 2026-10-21T13:22:35.294127+00:00
- actor: claude-code
  id: 01m5fa3wr7bnfrm8jbzs4jqba1
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (601e966). 0 findings, 0 confirmed, 0 refuted. 7 validator runs, 0 failed. 1 file reviewed: ThreadFloatingControlsHostedTests.swift. 2 .kanban files not reviewed (.reviewignore).
    - next: none. The task moves to done.
  timestamp: 2026-10-21T13:23:54.247818+00:00
- actor: claude-code
  id: 01m5fa499jyk2q93kb6xfyba1r
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 1 file (the thread pill test waits only for the bottom scroll target; the root cause was that test, not RecordedSessionsAgentTests)
    - test: green — swift test, 1487 passed, 2 known issues that were there before; 5 full runs in the implement step, no hang
    - commit: 601e966
    - review: clean — 0 findings
  timestamp: 2026-10-21T13:24:07.090403+00:00
position_column: done
position_ordinal: ffff9e80
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