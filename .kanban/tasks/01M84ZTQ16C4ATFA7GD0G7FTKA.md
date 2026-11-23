---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m85423nc1a6wvmnr335125gc
  text: |-
    Research done.
    - ResponseView.body calls `MarkdownCodeFences.pieces(in:)` in `text` at each evaluation. The `chips` property calls `CitationPayload.editorCitations(in:)` one time for the whole text, and one more time for each prose segment of a text with a fence.
    - EntryContentView.body calls `joiningAdjacentText(in:)` at each evaluation. `joinedText` copies the text of the last joined block and adds one chunk with `+=`. The copy shares its storage with the array element, so each add copies the full text (copy on write). A run of n chunks thus costs O(n^2).
    - ThreadExporter also calls `joiningAdjacentText(in:)`. Its output must not change.
    - Plan: one new generic memo class with one entry (the last input and its output), kept in `@State` as `LaidOutHeight` is kept. The memo notes one `BodyEvaluationCounter` count for each parse under DEBUG. The join becomes one pass: find the runs, then join the texts of each run with `joined()`.
    - The unit tests mount the views in an `NSHostingView` with no window, change an environment value or give an equal input to evaluate the body again, and count the parses.
  timestamp: 2026-11-23T21:12:45.484019+00:00
- actor: claude-code
  id: 01m854v46433z573nyhdxj9za0
  text: |-
    Implementation landed.
    - New `ParseMemo<Input: Equatable, Output>` (Sources/AgentViewKit/Content/ParseMemo.swift): a @MainActor final class with one entry (the last input and its output). A view keeps it in `@State`, as `LaidOutHeight` is kept. Each parse notes one `BodyEvaluationCounter` count under DEBUG.
    - ResponseView: `pieces` and `chips` read two memos. The chip memo is keyed by `CitedText` (text and citations).
    - EntryContentView: the join reads a memo. `joiningAdjacentText` is now one pass: it finds the run ranges, then joins the texts of each run with one `joined()`. EntryContentView also got a DEBUG body counter (`counterKey(for:)`), so a test can prove that the body evaluated again.
    - Counts before the memo: fences 2 parses for 2 evaluations; chips 2 for 2 evaluations; chips of a fenced text 4 (one for each prose segment, for each evaluation); join 2 for 2 evaluations. After: 1 in each case. A new text gives one more parse in each case.
    - Discovery: in a window-less host, SwiftUI does NOT evaluate the body of EntryContentView again when its content is equal and its id is equal, also when the content is a new array buffer. EntryContentView reads no environment, so nothing else makes it evaluate again. Thus the join memo saves a join only when the body evaluates for another reason (the test gives a new id with equal content). The large cost of the join was the O(n^2) `+=` on each new chunk, which the one-pass join removes. ResponseView does evaluate again on an environment change (for example `\.transcriptRowIsLive` or the message group), so its memos save real work.
    - Tried first: give the entry a copy of the content in a new array buffer to make it evaluate again. That did not work (see above).
    - A String.Index of a piece is used on the current text. The memo gives the pieces of an equal text, so the indices are valid for native strings.
  timestamp: 2026-11-23T21:26:25.220577+00:00
- actor: claude-code
  id: 01m854v9qd2gkcpcaegdcn47cw
  text: |-
    ### implement — changed
    - evidence: `swift test` in the root: 1676 tests in 188 suites passed, and 59 tests in 12 suites passed; 0 failures, 0 code warnings. `swift build --build-tests` in IntegrationTests and ScreenshotTests: Build complete, 0 warnings. RED seen first: the fence and chip tests (2, 2, 4 parses, not 1) and the join test (2 joins, not 1).
    - files: Sources/AgentViewKit/Content/ParseMemo.swift (new), Sources/AgentViewKit/Content/ResponseView.swift, Sources/AgentViewKit/Content/EntryContentView.swift, Tests/AgentViewKitTests/Content/RowBodyParseCountTests.swift (new), Tests/AgentViewKitTests/Content/EntryContentViewTests.swift.
    - hosted tests: none is necessary. No hosted test was written or run.
    - next: /review.
  timestamp: 2026-11-23T21:26:30.893523+00:00
position_column: doing
position_ordinal: '80'
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
- [x] One parse for each text change, not one for each body evaluation.
- [x] `joiningAdjacentText` is linear.
- [x] Output of each function does not change.

## Tests
Write the tests first.
- Add a DEBUG counter for each parse.
- Headless unit tests in Tests/AgentViewKitTests: evaluate twice with equal input, assert one parse; change the text, assert one more parse. Assert equal output of the new `joiningAdjacentText`.
- Run `swift test` in the root. If a hosted test is necessary, run it alone: `cd IntegrationTests && swift test --filter <TestName>`.
- No sleep, poll, retry or time limit.

## Workflow
Use /tdd.

## Subtasks
- [x] Add DEBUG parse counters.
- [x] Write the unit tests (they fail first).
- [x] Memoize the fence pieces and citation chips.
- [x] Memoize and make linear `joiningAdjacentText`.

Files: ResponseView.swift, EntryContentView.swift, the memo helper (new), one test file. #scroll-perf