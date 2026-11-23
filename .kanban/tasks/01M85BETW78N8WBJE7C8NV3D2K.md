---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: 'Regression: the answer row is not live on the first render pass, so its text has no context menu'
---
## What
AVK CI run 45280376533 (main 72067e53, Integration job 138079951178) fails two hosted tests that passed on cba06915:
- `AnswerTextContextMenuPointerHostedTests.aRightClickOnTheAnswerTextShowsTheItemMenu` and `aRightClickOnTheAnswerTextShowsNoItemOfTheTextMenu`, at `IntegrationTests/Tests/IntegrationTests/Content/AnswerTextContextMenuPointerHostedTests.swift:78`: `harness.contextMenu(identifier: ResponseView.textIdentifier)` is nil.

The element with `ResponseView.textIdentifier` exists, but no view under it gives a menu. Only the placeholder of a row that is not live has that identifier and no menu. Thus the answer row is possibly not live after one render pass (`mountThread` renders one time). Probable cause: the scroll cards of 2026-11-23: `^6w0xfxp` (3a5b9e0b, 749d87b2: `TranscriptRowLiveness` and `\.transcriptRowIsLive`) or `^3qvtsgh` (461c37a6: `LiveRowRange` margin 8 and slack 4, the thread model cache). The other change between the two runs is EditorKit ca04c906 (command click geometry); exclude it with evidence.

- [ ] Find the cause. Write a headless test first that fails: mount a thread with one answer (as `ThreadHeaderContextMenuHostedTests.mountThread`, headless with `StyleViewHost` if possible) and check that the answer row is live (shows its editor, not its placeholder) after one layout pass.
- [ ] Fix it in SwiftUI. A row that is in view, or a short transcript before the first visible-rows report, must be live.
- [ ] Keep the gains of the scroll cards (`LiveRowRangeRedrawScopeTests`, `ThreadModelCacheHostedTests` counts).

## Acceptance Criteria
- [ ] The new headless test passes, and failed before the fix.
- [ ] The two failing hosted tests pass on CI.
- [ ] The counting tests of the scroll cards still pass.

## Tests
- [ ] The new headless test (fails first).
- [ ] `swift test` in the root: all pass, no code warnings.
- [ ] Hosted (`AnswerTextContextMenuPointerHostedTests`, `LiveRowRangeRedrawScopeTests`, `ThreadModelCacheHostedTests`): run on CI if the screen of this Mac is not free.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #scroll-perf