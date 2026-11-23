---
assignees:
- claude-code
position_column: todo
position_ordinal: '8280'
title: Memoize the markdown parses in row bodies on the input string
---
## Rule
Stay with SwiftUI and use it smarter. Do not replace views with AppKit.

## What
Bug: "scrolling is not very smooth in the agent view". Row bodies parse text at each evaluation, with no cache.
- Sources/AgentViewKit/Content/ResponseView.swift:245 `MarkdownCodeFences.pieces(in: markdown)`.
- Sources/AgentViewKit/Content/ResponseView.swift:104-106 `chips` (`citations?.editorCitations(in:)`), used at :289.
- Sources/AgentViewKit/Content/EntryContentView.swift:72 `joiningAdjacentText(in:)`, which joins text with `+=` (O(n^2)).
- Fix: memoize each result on its input (string or content). Use a small cache keyed by the input, so a new parse occurs only when the text changes. Change `joiningAdjacentText` to build the joined text in one pass.

## Acceptance Criteria
- [ ] One parse for each text change, not one for each body evaluation.
- [ ] `joiningAdjacentText` is linear.
- [ ] Output of each function does not change.

## Tests
Write the tests first.
- Add a DEBUG counter for each parse.
- Headless unit tests in Tests/AgentViewKitTests: evaluate twice with equal input, assert one parse; change the text, assert one more parse. Assert equal output of the new `joiningAdjacentText`.
- Run `swift test` in the root. If a hosted test is necessary, run it alone: `cd IntegrationTests && swift test --filter <TestName>`.
- No sleep, poll, retry or time limit.

## Workflow
Use /tdd.

## Subtasks
- [ ] Add DEBUG parse counters.
- [ ] Write the unit tests (they fail first).
- [ ] Memoize the fence pieces and citation chips.
- [ ] Memoize and make linear `joiningAdjacentText`.

Files: ResponseView.swift, EntryContentView.swift, the memo helper (new), one test file. #scroll-perf