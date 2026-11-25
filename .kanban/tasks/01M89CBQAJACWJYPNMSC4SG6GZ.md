---
assignees:
- claude-code
position_column: todo
position_ordinal: '8780'
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