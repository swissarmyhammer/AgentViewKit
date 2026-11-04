---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6kzgy4eb1h0gdm1fx0ctpzn
  text: 'Slow IntegrationTests (~990 s, with `AgentWorkOrderHostedTests.runningAndIdleWithNoPromptOpenShowTheStateAndAnnounceNothing` ~930 s): the cause is not in that test or its harness. Evidence: that test has no timed wait. Its waits are `ObservationWait.until` with no limit, on changes that are sure to come. The time is spent waiting for EditorKit''s machine-wide UI test gate. `.hostedSerially` takes the `flock`''d gate at `~/Library/Caches/swissarmyhammer/ui-test-gate.lock` in the trait''s `provideScope`. Swift Testing counts that wait in the test''s duration. So the first hosted test of a run that reaches the gate absorbs the whole wait, and the hosted tests after it queue in-process behind it. AgentWorkOrderHostedTests sorts first, which is why the time showed up on that test. While I was on this card, pid 16950 `ui-test-gate -- ... xcodebuild -project TestudoApp/.claude/worktrees/agent-a44f3c3eda33e4cf3/Testudo.xcodeproj` (a TestudoApp XCUITest run) held the gate exclusive for over 15 min, and `ui-test-gate.holders` named it. My own `swift test --filter ThreadFloatingControlsHostedTests` printed nothing for 10+ min, waiting on it. In short, the slowness is contention with other UI suites on the Mac. It is not an AVK timeout that never fires. Possible EK follow-up (I did not change EK): have the gate wait log a line naming the holder, or record the wait apart from the test duration, so a slow run says why it is slow.'
  timestamp: 2026-11-04T19:10:41.294659+00:00
- actor: claude-code
  id: 01m6m0cbrbhptgtaws4ycge65z
  text: |-
    Build pin: EK 09bf6449 does not compile AVK 1f82d1cc. ConfigOptionFields.swift fails with "cannot convert String to FieldLabel", because FieldLabel came in with EK 91bdbfda. I used EK 50414d62 instead, the newest commit before 91bdbfda, in all three gitignored Package.resolved files. It builds clean. (f79a6d63 is older than 50414d62.)

    Root cause of the failure (reproduced: 2 issues at lines 300 and 301): ConversationView's `onScrollTargetVisibilityChange` reported `[u1, reply]` in the layout pass that showed the reply. That came before `.onChange(of: lastRowKey)` told the manager about the append, so the manager still held `lastItemID == u1`. `isAtBottom` compares `visibleIDs.last` to `lastItemID`, so reply != u1 read as not at bottom, and the manager unpinned. Debug trace: `setPinned false visible=[u1, reply] last=u1`, and no scroll target was ever held.

    Fix: ConversationView.noteLastItem() takes no arguments now. It compares the transcript's last row key with the manager's `lastItemID` (now `private(set)`, internal read) and tells the manager about the change only when they differ. Both the onChange action and every visibility or geometry report call it, so the manager hears of a new last item exactly once, whichever call comes first. No public API changed.
  timestamp: 2026-11-04T19:25:39.979402+00:00
- actor: claude-code
  id: 01m6m0j39pcy91xepkpwcgsbbv
  text: |-
    ### implement — changed
    - evidence: EK pinned to 50414d62 (09bf6449 fails on FieldLabel). RED: `aStreamedTurnKeepsTheThreadPinnedToTheBottom` failed at lines 300 and 301. GREEN: the same test passes. Root `swift test`: 944 tests (104 suites) + 67 tests (10 suites) passed. `swift test --package-path IntegrationTests`: 936 tests in 123 suites passed in 92.9 s, with 5 known issues, which are the intentional FontRoleExpectationsTests negatives. With no gate contention, runningAndIdle... took 4.5 s. The only warnings are mlx's. Commit af251ae6 on branch worktree-agent-adc4f403d7ba8d4b7, not pushed. Files: Sources/AgentViewKit/Thread/ConversationView.swift, Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift
    - next: /review
  timestamp: 2026-11-04T19:28:47.926659+00:00
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
- [ ] aStreamedTurnKeepsTheThreadPinnedToTheBottom passes against the current EditorKit main. (Passes on EK 50414d62 with af251ae6. AVK main does not build against EK main yet (FieldLabel, liveSymbolEffect), so re-run once those fixes land.)

## Tests
- [x] `swift test --package-path IntegrationTests --filter ThreadFloatingControlsHostedTests` passes.