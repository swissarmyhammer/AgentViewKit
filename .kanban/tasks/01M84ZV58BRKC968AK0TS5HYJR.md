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
position_column: review
position_ordinal: '8180'
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
- [ ] The pill view is in the tree in both states.
- [ ] A hidden pill is not visible, not clickable, and not in accessibility.
- [ ] One unpin evaluates the floating controls a small, fixed number of times.

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
- [ ] Add the hosted test (it fails first).
- [x] Keep the pill mounted and hide it with opacity and hit testing.
- [ ] Update snapshot images if the look changes and give the paths.

Files: AgentThreadView.swift, ConversationPill source file, one new test file. #scroll-perf

## Review Findings (2026-11-23 16:04)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKit/Thread/AgentThreadView.swift:685` `reuse/reuse` — floatingControlsCounterKey repeats the object-identity key construction of ConversationPill.counterKeyID. It is the same capability in a second place. Call the shared object-key helper proposed for ConversationView.swift:759 instead of building the ObjectIdentifier string here.
