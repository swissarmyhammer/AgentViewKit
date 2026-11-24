---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m856cfwmt21xxhfj32tva40v
  text: |-
    Research (implement step).
    - The card names the wrong insert point. `AgentThreadView.floatingControls` shows `ConversationPill` under `AgentThreadLayout.showsPill(unavailableMessage:)`. That condition reads only the unavailable message of the host, not the pin state. The insert on unpin is in `ConversationPill.body` (ConversationView.swift): `if !anchors.isPinnedToBottom { ScrollToBottomPill(...) }`. Thus each unpin makes the whole pill subtree: the EditorKit button, the glass button style, the glass id, the leaf control scope and the command click block.
    - The pill is already in the overlay of the floating controls, so the height of the bar and the bottom inset of the list do not change on unpin (^66has33).
    - Prevailing pattern for a mounted hidden view: `RequestDeck` card uses `.opacity`, `.accessibilityHidden`, `.allowsHitTesting` and `.disabled` together.
    - EditorKit: a disabled leaf control gets no jump label and no nav stop (EditorCommandsUI docs). So `.disabled` on the hidden pill removes it from the jump labels, from the nav moves and from the keyboard focus.
    - Plan: `ConversationPill` always mounts a `ConversationPillButton` (a new view that reads only `newItemsSinceUnpinned`), and hides it in place while pinned. An unpin then evaluates only the body of `ConversationPill`, not the button.
    - Headless tests can lay out `ConversationPill` and `AgentThreadView` in an `NSHostingView` with no window, and an observed change shows after one more layout pass (as in LiveRowModelsTests).
    - Open risk: an opacity of zero on a glass button in a `GlassEffectContainer`. Only a hosted run or a snapshot on the screen can show that the hidden glass does not draw. The hosted tests of this card check the frame of the floating controls in both states.
  timestamp: 2026-11-23T21:53:22.836155+00:00
- actor: claude-code
  id: 01m856ze5pmy7wvg62tbw88mpe
  text: |-
    Implementation landed (TDD).
    - DEBUG counter keys, all from `BodyEvaluationKey.make(prefix:id:)`: `AgentThreadLayout.floatingControlsCounterKey(for:)` (noted in `AgentThreadView.floatingControls`), `ConversationPill.counterKey(for:)` and `ConversationPill.buttonCounterKey(for:)`. The id is the `ObjectIdentifier` of the session model or of the manager, as in `TranscriptEntryLookup`.
    - Fix: `ConversationPill` always mounts the new `ConversationPillButton` (it reads only `newItemsSinceUnpinned`). While pinned, the pill applies `.opacity(0)`, `.allowsHitTesting(false)`, `.accessibilityHidden(true)` and `.disabled(true)`. The `.disabled` takes the hidden pill out of the jump labels, the nav moves and the keyboard focus (EditorKit leaf control scope). The pill stays in its overlay, so the layout of the bar does not change.
    - RED (headless, ConversationPillMountTests): `aPinnedPillHasTheSizeOfTheShownPill` and `anUnpinDoesNotEvaluateTheButtonOfThePill` failed for the expected reasons. `anUnpinEvaluatesThePillOneTime` (1) and `anUnpinDoesNotEvaluateTheFloatingControlsOfTheThread` (0) passed before the fix: today an unpin already evaluates the pill one time and the floating controls zero times. The cost was the insert of the button subtree, which these counts do not see. The two tests stay as guards of the fixed count.
    - GREEN: 4/4. Full root `swift test`: 1689 tests in 190 suites and 59 tests in 12 suites pass, no code warnings.
    - Hosted test written, NOT run (the user needs the screen): IntegrationTests/Tests/IntegrationTests/Thread/ConversationPillMountHostedTests.swift. `swift build --build-tests` passes in IntegrationTests and in ScreenshotTests.
    - Not done, to do when the screen is free: run the hosted tests one at a time; run the snapshot tests of a pinned thread (HostedSnapshotTests `theThread`, `theButtonsOfTheBottomBarBelowTheTranscript`) to see that the hidden glass of the pill does not draw in the `GlassEffectContainer`; update the images if the look changes.
    - The card names AgentThreadView.swift as the insert point. That `if` reads only the unavailable message of the host, so I did not change it. The insert on unpin was in `ConversationPill.body`.
  timestamp: 2026-11-23T22:03:43.670425+00:00
- actor: claude-code
  id: 01m856zhqhr9wnsfp91d9js09v
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Thread/ConversationView.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Thread/ScrollToBottomPill.swift, Tests/AgentViewKitTests/Thread/ConversationPillMountTests.swift (new), IntegrationTests/Tests/IntegrationTests/Thread/ConversationPillMountHostedTests.swift (new). Root `swift test`: 1689 + 59 pass, 0 failures, no code warnings. `swift build --build-tests` passes in IntegrationTests and ScreenshotTests.
    - next: when the screen is free, run each test of ConversationPillMountHostedTests alone (`cd IntegrationTests && swift test --filter ConversationPillMountHostedTests/<test>`), and the snapshot tests HostedSnapshotTests/theThread and HostedSnapshotTests/theButtonsOfTheBottomBarBelowTheTranscript; update the images if the look changes. Then /review.
  timestamp: 2026-11-23T22:03:47.313434+00:00
- actor: claude-code
  id: 01m85754pvca5wqsw1xe9d59kh
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (commit 3b88266a): 1 finding (1 confirmed, 2 refuted, 7 attempted, 0 failed) — Sources/AgentViewKit/Thread/AgentThreadView.swift:685 (reuse/reuse).
    - next: implement the finding. Make one shared object-key helper and call it from `AgentThreadLayout.floatingControlsCounterKey(for:)` and `ConversationPill.counterKeyID`. Remove the repeated ObjectIdentifier key construction from all of AgentThreadView.swift. After that, run the hosted tests of ConversationPillMountHostedTests one at a time when the screen is free. The hosted runs and the snapshot subtask are the last open items.
  timestamp: 2026-11-23T22:06:50.587286+00:00
- actor: claude-code
  id: 01m857cc9cy50vfkr7s3b7gvj2
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 5 files
    - test: green — swift test 1689 + 59; builds clean; hosted not run (screen in use)
    - commit: 3b88266a
    - review: findings — Sources/AgentViewKit/Thread/AgentThreadView.swift:685

    ### implement — changed
    - evidence: new `BodyEvaluationKey.make(prefix:object:)` makes the key of an object from its identity. AgentThreadLayout.floatingControlsCounterKey(for:) and the two pill keys call it; ConversationPill.counterKeyID(of:) is removed. The keys did not change. swift test 1689 + 59 passed; IntegrationTests build complete.
    - open: the 7 hosted tests of ConversationPillMountHostedTests and the 2 snapshots run when the screen is free.
  timestamp: 2026-11-23T22:10:47.724020+00:00
- actor: claude-code
  id: 01m857eedgjnbja4vgk5gkwwcw
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 7f9320cc). 0 findings, 0 confirmed, 0 refuted, 7 attempted, 0 failed. The engine reviewed 3 source files. It did not review 2 .kanban files because of .reviewignore. The prior finding at AgentThreadView.swift:685 (reuse/reuse) is checked.
    - next: The task stays in review. Two subtasks are open: "Add the hosted test (it fails first)" and "Update snapshot images if the look changes and give the paths". Do the hosted runs only when the user permits them. Then move the task to done.
  timestamp: 2026-11-23T22:11:55.440858+00:00
- actor: claude-code
  id: 01m85f6r0t9cr1fydx5jhs9bcx
  text: |-
    Causes of the 3 CI findings (run 45280376533), from the code and the log.
    - :191 and :204 have one cause. EditorKit takes a disabled leaf control out of the jump labels only through the accessibility tree: `GeometryRegistry.targetRects(in:)` calls `disabledLeafControlPaths`, which reads `isAccessibilityEnabled` of the control at the scope center (LeafControl.swift, LeafControlAppKit.swift). The hidden pill has `.accessibilityHidden(true)` (and since dbc80b63 a scale of zero), so the read finds no control, the path is not in the disabled set, and the pill gets a label. The log shows the chip `/agentThread:scripted-session/agentControl:scroll-to-bottom-pill`. `JumpModeController.commit(_:)` returns true for each candidate, so :204 fails for the same reason. dbc80b63 does not change this.
    - EditorKit opt-out: `.targetable(_:)` / `ScopeTargeting.untargetable` is "the one switch that takes a scope out of jump, nav and commands together". Toggle it with a value. `targetRects` drops a path that `nonTargets.isTarget` refuses, before the accessibility read.
    - Fix: `AgentControlScope` reads the new environment value `isAgentControlTargetable` (modifier `agentControlTargetable(_:)`) and applies `.targetable(isTargetable ? .targetable : .untargetable, asksForLeafLanding: true)`. The leaf landing request stays true in both states, so the EditorButton in the scope does not add a scope of its own on a toggle (`ControlScopePlacement.takesScope`). `ConversationPill` applies `.agentControlTargetable(!isHidden)`. Only the scope modifier reads the value, so the button body is not evaluated on unpin (test still green).
    - :170 is not a frame change. Column 29 is the `try #require` of the PINNED frame, and the log shows `harness.frame(identifier: controls) → nil`. The test mounts the thread with `EmptyView()` in the slot, the scripted session has no agent state (no banner), and the hidden pill is not in the accessibility tree. So the `.accessibilityElement(children: .contain)` container of the floating controls has no child, and SwiftUI gives it no element. Fix in the test: the slot holds `PromptInputHost(model: PromptInputHostedTestModel())`, so the container is an element in both states. The comparison after the unpin is not proven yet: CI shows it. Risk: on macOS 27 the frame of an element that holds Liquid Glass follows the glass (ThreadBarAccessibilityFrameHostedTests). If the shown pill glass widens that frame, CI will show a real frame change.
  timestamp: 2026-11-24T00:27:31.739+00:00
- actor: claude-code
  id: 01m85f6y6gnvm87sygv8eepz6q
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/Commands/AgentControlScope.swift, Sources/AgentViewKit/Thread/ConversationView.swift, Tests/AgentViewKitTests/Thread/ConversationPillMountTests.swift, IntegrationTests/Tests/IntegrationTests/Thread/ConversationPillMountHostedTests.swift. RED: `aPinnedPillIsNoTargetOfJumpAndNavigation` failed at `!system.geometry.isTargetable(at: path)` with the scope live; GREEN 6/6 in ConversationPillMountTests. Root `swift test`: 1720 tests in 193 suites and 59 tests in 12 suites pass, no code warnings. `swift build --build-tests` complete in IntegrationTests and ScreenshotTests. No hosted test run on this Mac.
    - next: the 3 findings of "Review Findings (2026-11-23 CI)" stay open until CI runs ConversationPillMountHostedTests on a commit with this change. Then /review.
  timestamp: 2026-11-24T00:27:38.064722+00:00
- actor: claude-code
  id: 01m85fb5hb73k9txdgmar2tjbf
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (b7496ae1); 1 finding, 1 confirmed, 0 refuted. Tests/AgentViewKitTests/Thread/ConversationPillMountTests.swift:82 (reuse/reuse: mountScopedPill repeats the host setup of mountPill).
    - open: the 3 CI findings stay open until CI runs ConversationPillMountHostedTests. The hosted test subtask and the snapshot subtask are open.
    - next: extend mountPill and use it from both tests. Then run swift test and review again. The task stays in review.
  timestamp: 2026-11-24T00:29:56.651251+00:00
- actor: claude-code
  id: 01m85fem49zz1b0s1aj149jqdm
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — 4 files (targetable opt-out of the hidden pill; frame test has a composer)
    - test: green — swift test 1720 + 59; hosted not run
    - commit: b7496ae1
    - review: findings — Tests/AgentViewKitTests/Thread/ConversationPillMountTests.swift:82

    ### implement — changed
    - evidence: one helper `mountPill(_:wrap:)` makes the host of the pill; `mountPill(_:)` and `mountScopedPill(_:system:)` call it. ConversationPillMountTests 6/6; swift test 1720 + 59 passed.
    - open: the 3 CI findings (:191, :204, :170) and the hosted and snapshot subtasks wait for CI.
  timestamp: 2026-11-24T00:31:49.897212+00:00
- actor: claude-code
  id: 01m85fh35aagsc8kdcvhmhcdws
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (16b54df4): 0 findings, 0 confirmed, 0 refuted (7 attempted, 0 failed). The 18:28 finding (ConversationPillMountTests.swift:82) is checked. ConversationPillMountTests 6/6; swift test 1720 + 59.
    - next: the 3 CI findings (:191, :204, :170) and the hosted and snapshot subtasks stay open until CI. The task stays in review.
  timestamp: 2026-11-24T00:33:10.826361+00:00
- actor: claude-code
  id: 01m86std7jepfw51kn1h22em3p
  text: |-
    ### review — clean
    - evidence: no new review run. Each code commit of this card has a clean review record. 3b88266a (findings) was fixed by 7f9320cc (clean). b7496ae1 (findings) was fixed by 16b54df4 (clean). 16b54df4 is the newest code commit of this card. dbc80b63 and 62a86ab9 belong to card ^8nv3d2k and have their own clean reviews. b57c8c89 belongs to card ^ctzmqh3 and has its own clean review. All subtasks and all review findings are checked. CI 45299061645 passed ConversationPillMountHostedTests. The gallery run of 2026-11-24 06:46 shows no hidden pill.
    - next: none. The card moves to done.
  timestamp: 2026-11-24T12:52:16.242631+00:00
position_column: done
position_ordinal: ffffffffa280
title: Keep the conversation pill mounted so an unpin from the bottom does not hitch
---
## Rule
Stay with SwiftUI and use it smarter. Do not replace views with AppKit.

## What
Bug: "scrolling is not very smooth in the agent view". One hitch occurs when the list unpins from the bottom.
- Sources/AgentViewKit/Thread/AgentThreadView.swift:558-559 inserts `ConversationPill` in the `FloatingGlassContainer` (:535) only when `showsPill` is true. The insert changes the glass container layout.
- Sources/AgentViewKit/Thread/ConversationView.swift:709-716 `ConversationFollowAnchor` changes `defaultScrollAnchor` at the same time.
- Fix: keep `ConversationPill` always mounted. Hide it with `.opacity(0)`, `.allowsHitTesting(false)` and `.accessibilityHidden(true)` when it does not show.

## Acceptance Criteria
- [x] The pill view is in the tree in both states.
- [x] A hidden pill is not visible, not clickable, and not in accessibility.
- [x] One unpin evaluates the floating controls a small, fixed number of times.

## Tests
Write the tests first.
- Add a DEBUG `BodyEvaluationCounter` key in the floating control body.
- New hosted test in IntegrationTests/Tests/IntegrationTests/Thread/: pin at bottom, unpin one time, assert the count of floating-control evaluations.
- Run `swift test` in the root (headless). Run the hosted test alone: `cd IntegrationTests && swift test --filter <TestName>`. One hosted test at a time.
- No sleep, poll, retry or time limit.

## Workflow
Use /tdd.

## Subtasks
- [x] Add the DEBUG counter key.
- [x] Add the hosted test (it fails first).
- [x] Keep the pill mounted and hide it with opacity and hit testing.
- [x] Update snapshot images if the look changes and give the paths.

Files: AgentThreadView.swift, ConversationPill source file, one new test file. #scroll-perf

## Review Findings (2026-11-23 16:04)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKit/Thread/AgentThreadView.swift:685` `reuse/reuse` — floatingControlsCounterKey repeats the object-identity key construction of ConversationPill.counterKeyID. It is the same capability in a second place. Call the shared object-key helper proposed for ConversationView.swift:759 instead of building the ObjectIdentifier string here.

## Review Findings (2026-11-23 CI)

> Scope: CI run 45280376533 on main 72067e53, Integration job 138079951178. Three hosted tests of ConversationPillMountHostedTests failed.
> After that run, commit dbc80b63 added `.scaleEffect(isHidden ? 0 : 1)` to the hidden pill, because the glass took clicks over the transcript. The CI run on af4a5cc8 is in progress. It will show if that commit changed these 3 results.

- [x] IntegrationTests/Tests/IntegrationTests/Thread/ConversationPillMountHostedTests.swift:191 — aPinnedThreadGivesThePillNoJumpLabel: Expectation failed: !chips.contains { $0.id == shown.path }
- [x] ConversationPillMountHostedTests.swift:204 — aJumpCommitOnTheHiddenPillLandsNowhere: Expectation failed: !jump.commit(shown.path)
- [x] ConversationPillMountHostedTests.swift:170 — anUnpinKeepsTheFrameOfTheFloatingControls: Expectation failed: harness.frame(identifier: controls) ...

## Review Findings (2026-11-23 18:28)

> Scope: `review sha HEAD~1..HEAD` (b7496ae1) — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Tests/AgentViewKitTests/Thread/ConversationPillMountTests.swift:82` `reuse/reuse` — mountScopedPill builds the same NSHostingView of a ConversationPill and runs the same StyleViewHost.layOut call as the existing mountPill. It only adds the agent command scope, the command system and the path. This is a near-match that was not extended. A second copy of the host setup can drift from the first one. Extend `mountPill` with optional `session` and `system` parameters, or with a closure that wraps the root view. Use it from both tests. Keep `mountScopedPill` only as the path-returning wrapper, or inline it into the two tests that need the path.

## Review Findings (2026-11-23 18:32)

> Scope: `review sha HEAD~1..HEAD` (16b54df4) — reviewed the diffs only — lines this change added or modified. 1 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

Zero new findings. The 3 CI findings stay open until CI.