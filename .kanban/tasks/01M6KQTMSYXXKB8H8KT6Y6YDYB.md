---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6kzgy4eb1h0gdm1fx0ctpzn
  text: 'Slow IntegrationTests (~990 s, with `AgentWorkOrderHostedTests.runningAndIdleWithNoPromptOpenShowTheStateAndAnnounceNothing` ~930 s): the cause is not in that test or its harness. Evidence: that test has no timed wait. Its waits are `ObservationWait.until` with no limit, on changes that are sure to come. The time is spent waiting for EditorKit''s machine-wide UI test gate. `.hostedSerially` takes the `flock`''d gate at `~/Library/Caches/swissarmyhammer/ui-test-gate.lock` in the trait''s `provideScope`. Swift Testing counts that wait in the test''s duration. So the first hosted test of a run that reaches the gate absorbs the whole wait, and the hosted tests after it queue in-process behind it. AgentWorkOrderHostedTests sorts first, which is why the time showed up on that test. While I was on this card, pid 16950 `ui-test-gate -- ... xcodebuild -project TestudoApp/.claude/worktrees/agent-a44f3c3eda33e4cf3/Testudo.xcodeproj` (a TestudoApp XCUITest run) held the gate exclusive for over 15 min, and `ui-test-gate.holders` named it. My own `swift test --filter ThreadFloatingControlsHostedTests` printed nothing for 10+ min, waiting on it. In short, the slowness is contention with other UI suites on the Mac. It is not an AVK timeout that never fires. Possible EK follow-up (I did not change EK): have the gate wait log a line naming the holder, or record the wait apart from the test duration, so a slow run says why it is slow.'
  timestamp: 2026-11-04T19:10:41.294659+00:00
position_column: doing
position_ordinal: '8180'
title: ThreadFloatingControlsHostedTests.aStreamedTurnKeepsTheThreadPinnedToTheBottom fails on main with EditorKit 50414d62
---
Found while implementing ^e4857xj. It reproduces on a clean worktree of main 69856eae, with deps resolved to EditorKit 50414d62 (the run only needs IntegrationTests/Style/InspectorPreviewFrameTests.swift removed to compile, see below).

`swift test --package-path IntegrationTests --filter ThreadFloatingControlsHostedTests` fails 2 expectations, every run:
- ThreadFloatingControlsHostedTests.swift:300 `!unpinned.isRaised` ("the thread unpinned during the turn")
- ThreadFloatingControlsHostedTests.swift:301 `harness.element(identifier: ScrollToBottomPill.identifier) == nil`

It is not caused by the inspector work, because it fails without those changes too. Likely cause: a change in EditorKit between the previous resolved SHA and 50414d62 (e.g. ^268hf35 `.commandClick` shape parameter, or a scroll/anchor change). Find the cause and fix it.

Also on main 69856eae with EK 50414d62: IntegrationTests does not compile. `InspectorPreviewFrameTests.swift:11` reports `ambiguous use of 'inspectorPreviewFrame()'`, because EditorTestSupport brings EditorInspector's `inspectorPreviewFrame()` into scope next to AVK's copy. ^e4857xj removes AVK's copy, which fixes it once it lands.

## Acceptance Criteria
- [ ] aStreamedTurnKeepsTheThreadPinnedToTheBottom passes against the current EditorKit main.

## Tests
- [ ] `swift test --package-path IntegrationTests --filter ThreadFloatingControlsHostedTests` passes.