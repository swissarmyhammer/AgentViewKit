---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8b8m2svcyw9qrwncs8zmhd8
  text: |-
    ### review — findings
    - evidence: review sha cb9d6737..f0315036; 1 finding (1 confirmed, 0 refuted); Tests/AgentViewKitTests/Thread/ConversationStreamedAppendPinTests.swift:36 reuse/reuse
    - next: Move runScheduledTasks() to one shared test support location. Call it from ConversationStreamedAppendPinTests and ScrollAnchorManagerTests. Delete both private copies. Then do the review again. The checklist items stay open until the review is clean. The item "One normal full run of IntegrationTests passes" stays open until the hosted run after the Testudo hold.
  timestamp: 2026-11-26T06:27:55.323730+00:00
- actor: claude-code
  id: 01m8baq04gaj0w47rzq4q406fs
  text: |-
    ### review — clean
    - evidence: review sha 0f3778df..527f7918; 0 findings (0 confirmed, 0 refuted); 3 files reviewed. All items are checked with the evidence in the "Evidence (2026-11-26 01:01)" section.
    - next: None. The card is in done.
  timestamp: 2026-11-26T07:04:28.048354+00:00
position_column: done
position_ordinal: ffffffffb480
title: aStreamedTurnKeepsTheThreadPinnedToTheBottom is not certain under load
---
`IntegrationTests/Tests/IntegrationTests/Thread/ThreadFloatingControlsHostedTests.swift:313` (`aStreamedTurnKeepsTheThreadPinnedToTheBottom`) fails with `Expectation failed: !unpinned.isRaised` in some full IntegrationTests runs, and passes alone. It failed on branch e428ddc6 and on the ^8sdsx64 branch 90138f37. The ^c4sg6gz sub agent also saw its headless copy fail in 2 of 4 group runs on main ecb3a865. The test rules require certain tests: no test may depend on the load or on the order.

## What
- [x] Find the event that the test assumes but does not wait for. Candidates: the visibility report after an append, the geometry action, and the manager unpin through `noteVisible` in `Sources/AgentViewKit/Thread/ConversationView.swift`.
- [x] Either make the product deterministic (the manager must not unpin during a streamed append while the list follows the bottom), or make the test wait for the certain event (`ObservationWait.until` on the manager state).
- [x] Add a headless test in `Tests/AgentViewKitTests/Thread/` that shows the cause, if a headless test can show it.

## Acceptance Criteria
- [x] A headless test that controls the order of the events fails before the fix and passes after it. This test is the proof. A repeat run is not a proof (user rule, relayed by testudoapp-9a on 2026-11-26).
- [x] No sleep, poll, retry or time limit is added.

## Tests
- [x] One normal full run of `swift test --no-parallel --package-path IntegrationTests` passes. If it fails, find the next timing dependency. This is a hosted run, so send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc.
- [x] `swift test` (root) passes with 0 failures and 0 warnings.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #bug #test

## Review Findings (2026-11-26 00:23)

> Scope: `review sha cb9d6737..f0315036` — reviewed the diffs only — lines this change added or modified. 3 file(s) reviewed, 0 not reviewed.

- [x] `Tests/AgentViewKitTests/Thread/ConversationStreamedAppendPinTests.swift:36` `reuse/reuse` — The new private helper runScheduledTasks() repeats the body of the helper with the same name in ScrollAnchorManagerTests. Two copies must now be kept the same. A change to one copy can leave the other wrong. Move runScheduledTasks() to one shared test support location, for example Sources/AgentViewKitTestSupport, and make it internal or public. Call it from both suites and delete both private copies.

## Evidence (2026-11-26 01:01)
- The fix of the finding is in 527f7918. The shared `ScheduledMainActorTasks.runScheduled()` in `Sources/AgentViewKitTestSupport` replaces the two private `runScheduledTasks()` copies.
- The headless test that controls the event order: RED 6 of 11 before the fix. GREEN 11 of 11 after the fix.
- The root `swift test` on main a7dd9878: 1832 + 59 tests passed.
- One normal full IntegrationTests run on main ed44e6e0 passed: 1090 tests, 5 known issues. `aStreamedTurnKeepsTheThreadPinnedToTheBottom` is in this run.
- The review of `0f3778df..527f7918` is clean: 0 findings.