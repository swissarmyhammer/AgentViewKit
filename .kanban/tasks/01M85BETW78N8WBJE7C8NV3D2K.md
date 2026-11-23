---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m85cgy5vx98sc1dqqfep49kb
  text: |-
    Research: the cause is not the liveness of the row. The hidden Scroll to Bottom pill takes the hit.

    Git evidence:
    - 3a5b9e0b, 749d87b2 and 461c37a6 (the scroll cards ^6w0xfxp and ^3qvtsgh) are ancestors of cba06915, the last green run (45266852416). Thus they are not the cause.
    - The AVK commits after cba06915 are 2e6a94a4 (parse memo), 42965097 (row index), 3b88266a (the pill stays in the view tree) and refactors.
    - EditorKit: the green run resolved 65a0926, the red run resolved ca04c90.

    Measurement (a window that is never ordered in, size 480 x 600, as the hosted suite): after one layout pass the answer row is live (its EditorView and its NSTextView are in the tree). The text is at y 482..498, center x 240. The hidden pill is at x 170..310, y 478..502, alpha 0. A hitTest at y 490 gives the text view for x < 170 and x >= 310, and the pane NSHostingView for each x in 170..300. That is the frame of the hidden pill exactly. The pane hosting view gives no menu, so `contextMenu(identifier:)` is nil.

    The pill is in the `GlassEffectContainer` of the floating controls. The container does the hit test of the glass of each child. `.opacity(0)` and `.allowsHitTesting(false)` (3b88266a) do not remove the glass from that hit test. Before 3b88266a, a pinned pill was not in the tree, so it had no glass.

    EditorKit ca04c906 is excluded: the local checkout is ca04c906 too. With it, the change of only the pill (`.hidden()`, then `.scaleEffect(0)`) gives the text view at each x.

    What did not work: a hitTest on an NSHostingView with no window gives nil at each point, so StyleViewHost alone cannot do the hit test. The test puts the host in a borderless window that it never orders in (no window shows, no focus).
  timestamp: 2026-11-23T23:40:39.995391+00:00
- actor: claude-code
  id: 01m85ch4hrffdksa31f9nss062
  text: |-
    Implementation landed (not committed).
    - Fix: `ConversationPill` adds `.scaleEffect(isHidden ? 0 : 1)`. The hidden glass then has no area, so it is not in the hit test of the glass container. The layout size of the button does not change, and the button stays in the view tree, so the gain of ^ts5hyjr stays (`ConversationPillMountTests` pass: same pinned size, zero button evaluations on an unpin).
    - New test: `AnswerTextHitTests.theCenterOfTheAnswerTextHitsTheTextViewOfTheAnswer`. It requires the NSTextView of the answer (thus the row is live after one layout pass), then hit-tests the center of the text. RED before the fix (`hit.isDescendant(of: text)` false), GREEN after.
    - The hosted proof (`AnswerTextContextMenuPointerHostedTests`, `LiveRowRangeRedrawScopeTests`, `ThreadModelCacheHostedTests`) must come from CI. These items stay open on the card.
  timestamp: 2026-11-23T23:40:46.520862+00:00
- actor: claude-code
  id: 01m85ch6v9ta2jx503mkwps1qn
  text: |-
    ### implement — changed
    - evidence: `swift test` (root): 1705 tests in 192 suites passed, and 59 tests in 12 suites passed, no code warnings. `swift build --build-tests` in IntegrationTests and ScreenshotTests: build complete, no warnings. New test RED then GREEN. 2 files: Sources/AgentViewKit/Thread/ConversationView.swift, Tests/AgentViewKitTests/Thread/AnswerTextHitTests.swift.
    - next: /review; CI must run the hosted suites (no hosted run on this Mac).
  timestamp: 2026-11-23T23:40:48.873897+00:00
position_column: doing
position_ordinal: '80'
title: 'Regression: the answer row is not live on the first render pass, so its text has no context menu'
---
## What
AVK CI run 45280376533 (main 72067e53, Integration job 138079951178) fails two hosted tests that passed on cba06915:
- `AnswerTextContextMenuPointerHostedTests.aRightClickOnTheAnswerTextShowsTheItemMenu` and `aRightClickOnTheAnswerTextShowsNoItemOfTheTextMenu`, at `IntegrationTests/Tests/IntegrationTests/Content/AnswerTextContextMenuPointerHostedTests.swift:78`: `harness.contextMenu(identifier: ResponseView.textIdentifier)` is nil.

The element with `ResponseView.textIdentifier` exists, but no view under it gives a menu. Only the placeholder of a row that is not live has that identifier and no menu. Thus the answer row is possibly not live after one render pass (`mountThread` renders one time). Probable cause: the scroll cards of 2026-11-23: `^6w0xfxp` (3a5b9e0b, 749d87b2: `TranscriptRowLiveness` and `\.transcriptRowIsLive`) or `^3qvtsgh` (461c37a6: `LiveRowRange` margin 8 and slack 4, the thread model cache). The other change between the two runs is EditorKit ca04c906 (command click geometry); exclude it with evidence.

- [x] Find the cause. Write a headless test first that fails: mount a thread with one answer (as `ThreadHeaderContextMenuHostedTests.mountThread`, headless with `StyleViewHost` if possible) and check that the answer row is live (shows its editor, not its placeholder) after one layout pass.
- [x] Fix it in SwiftUI. A row that is in view, or a short transcript before the first visible-rows report, must be live.
- [ ] Keep the gains of the scroll cards (`LiveRowRangeRedrawScopeTests`, `ThreadModelCacheHostedTests` counts).

## Acceptance Criteria
- [x] The new headless test passes, and failed before the fix.
- [ ] The two failing hosted tests pass on CI.
- [ ] The counting tests of the scroll cards still pass.

## Tests
- [x] The new headless test (fails first).
- [x] `swift test` in the root: all pass, no code warnings.
- [ ] Hosted (`AnswerTextContextMenuPointerHostedTests`, `LiveRowRangeRedrawScopeTests`, `ThreadModelCacheHostedTests`): run on CI if the screen of this Mac is not free.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #scroll-perf