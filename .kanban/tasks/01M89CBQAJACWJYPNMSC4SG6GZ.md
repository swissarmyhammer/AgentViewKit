---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m89p6hmcbxzzte8rg7a2nbjv
  text: |-
    Research (worktree agent-aee6bfe5f7f9cff61):
    - `ConversationView.rows(shownCount:placements:)` gives a ForEach element of a row plus a nested ForEach of status lines. The `.start` lines are a ForEach in the LazyVStack before the rows.
    - The scroll target id is `.id(row.id)` on the row. When the row and its lines go in one VStack, the `.id` must go on the VStack, because the scroll target layout reads the ids of its direct children.
    - An empty VStack in a LazyVStack still gets the stack spacing. The `.start` view must be absent when there is no line.
    - The scroll profile harness (`scratchpad/ScrollProfile`) shows a real window (`orderFrontRegardless`). This agent must not run windowed suites, so the `measureEstimates` numbers need a run by a person or a session that can show a window.
    - The kanban tool writes to the board of the main checkout, not to the `.kanban` of this worktree.
  timestamp: 2026-11-25T15:46:42.956315+00:00
- actor: claude-code
  id: 01m89rfbdz1h2tt4kkvsr6r359
  text: |-
    Implementation landed:
    - `ConversationView.rows` now runs `ForEach` over a lazy map of the positions of the shown entries to `TranscriptRowSlot` (id = `TranscriptEntry.id`). No `Array(enumerated())` on each body. The id is not the position, because a replay (`resetTranscript`) gives a position to a new entry.
    - Each element is one `TranscriptRowElement` (new file `Sources/AgentViewKit/Thread/TranscriptRowElement.swift`): a `VStack` with the list spacing of the row and its status lines. `.id(rowKey)` is on the element. The lines at `.start` are one `VStack` before the first row, and absent when there is no line.
    - New unit test `ConversationRowElementTests.aScrollEvaluatesEachRowBodyAtMostOneTime`: 120 messages, a notice after each 4th, 60 jump steps of one row (window never ordered in). Before the change: 60 row bodies, each row one time. After: the same.
    What did not work:
    - A scroll by the clip view origin: the anchors move the list back, so the scroll does not go far.
    - Jumps of 4 rows: a jump to a far row lands at an estimated place. The count then depends on the earlier tests (order dependent, not certain). With that scroll, both new shapes (a VStack in the ForEach closure, and the element struct) evaluated some rows two times when ModelChangeNoticeTests ran in parallel; the old code did not. Steps of one row give the same count in each order for old and new code.
    - Mutation check: a new element identity on each body fails the test. Removing `.equatable()` from the row does not fail it.
    Not done here: the `measureEstimates` profile numbers. The harness (`scratchpad/ScrollProfile`) shows a real window, and this agent must not run windowed suites. It needs a run.
  timestamp: 2026-11-25T16:26:28.671557+00:00
- actor: claude-code
  id: 01m89ryke5xnje6gr5svxb97sv
  text: |-
    ### test — green
    - evidence: `swift test` at the worktree root: 1743 tests in 197 suites passed, 59 tests in 12 suites passed, 0 failures, 0 code warnings (only warnings in `.build/checkouts`). The command ran without `HOME=$(mktemp -d)`: the sandbox refuses a command that sets HOME. The new test does not touch home.

    ### commit — changed
    - evidence: 574ebdf9 on branch worktree-agent-aee6bfe5f7f9cff61

    ### review — stuck
    - evidence: `review sha 574ebdf9~1..574ebdf9` gave 0 findings, but 10 tool-rule items were declined: disallowed-constructs-swift, function-length-swift, idioms-swift, magic-numbers-swift and missing-docs-swift each "found no file at" `Sources/AgentViewKit/Thread/TranscriptRowElement.swift` and `Tests/AgentViewKitTests/Thread/ConversationRowElementTests.swift`. The review engine (like the kanban tool) runs in the main checkout, not in the worktree, so the tool rules cannot read the new files, and they read the old ConversationView.swift. This is not a full review, so the card does not go to done.
    - open item of the card: the `measureEstimates` share before and after (profile harness `scratchpad/ScrollProfile`) needs a run that can show a window.
    - next: merge or check out the branch in the main checkout, then run `/review ^c4sg6gz 574ebdf9~1..574ebdf9` there, and run the profile harness.
  timestamp: 2026-11-25T16:34:48.389649+00:00
position_column: review
position_ordinal: '8280'
title: 'Scroll perf 5: one view for each ForEach element of the transcript'
---
User request (2026-11-25): "scrolling is still way too slow", stay with SwiftUI. The scroll profile found `LazyStack.measureEstimates` → `ForEachList.applyNodes` over all 200 elements at 9.25% of main-thread time. Each element gives a row and a nested `ForEach` of modelChanged status lines, so the view count of an element is not fixed. This gain is an estimate; the card measures it first.

## What

- `Sources/AgentViewKit/Thread/ConversationView.swift`, `rows(shownCount:placements:)` (about lines 461–490): `ForEach(Array(transcript.suffix(shownCount).enumerated()), id: \.element.id)` builds a new array on each body, and each element has a row plus a nested `ForEach` of `ModelChangeNoticeView`.
- [ ] Put the status lines of an entry inside the row view of that entry (one `VStack` for each element), so each element is one view. Put the lines at `.start` in one fixed view before the first row.
- [ ] Use the indices of the suffix (`ForEach(firstPosition..<transcript.count, id:)` with a stable id) and do not build `Array(enumerated())` on each body.
- [ ] Keep the row ids, the scroll targets, the accessibility order and the place of each status line the same.

## Acceptance Criteria

- [ ] Each `ForEach` element gives exactly one view.
- [ ] `ModelChangeNoticeTests` and the row id and scroll tests pass with no change.
- [ ] The profile harness shows the `measureEstimates` share before and after (numbers on the card). If the gain is less than 2%, keep only the change that makes the code simpler and say so on the card.

## Tests

- [ ] The existing `Tests/AgentViewKitTests/Items/ModelChangeNoticeTests.swift` (place and accessibility order) passes with no change.
- [ ] New test: the row body count during a scroll of N steps (window never ordered in) is not higher than before the change (`BodyEvaluationCounter`).
- [ ] `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #perf