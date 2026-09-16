---
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: doing
position_ordinal: '8180'
title: StreamingMarkdownBalancer and paragraph splitter, pure functions (plan §8)
---
## What
Create `Sources/AgentViewKit/Streaming/ParagraphSplitter.swift` and `Sources/AgentViewKit/Streaming/StreamingMarkdownBalancer.swift`, per plan.md §8. Both are pure functions on `String`, with no SwiftUI import.

- `ParagraphSplitter.split(_ markdown: String) -> (settled: [Paragraph], tail: String)`. A paragraph is a block separated by a blank line. A fenced code block is one paragraph and is never split. The last block is the tail while a stream is open. Each settled paragraph gets a stable id from its index and a hash of its text.
- `StreamingMarkdownBalancer.balance(tail: String) -> BalancedTail`. It closes a dangling `**`, `*`, `_`, `` ` ``, and `[` in the tail. It detects an open code fence by an odd count of ```` ``` ```` in the whole message and returns `.openFence(language, body)` so the caller routes the body to the EditorKit append path. It never touches settled paragraphs.
- `StreamingCoalescer`: an actor or `@MainActor` helper that batches appended chunks and flushes at a 33 ms cadence, with `flushNow()`.

## Acceptance Criteria
- [ ] Splitting a message with three paragraphs and an open fourth returns three settled paragraphs and the fourth as tail.
- [ ] A fenced block with blank lines inside stays one paragraph.
- [ ] `balance("some **bold")` returns `"some **bold**"`.
- [ ] `balance` on an open fence returns `.openFence` and does not add closing markers.
- [ ] Settled paragraph ids are stable when more text is appended to the tail.

## Tests
- [ ] `Tests/AgentViewKitTests/Streaming/ParagraphSplitterTests.swift`: the cases above plus CRLF input.
- [ ] `Tests/AgentViewKitTests/Streaming/StreamingMarkdownBalancerTests.swift`: each delimiter, nested delimiters, an escaped delimiter, a fence with a language.
- [ ] `Tests/AgentViewKitTests/Streaming/StreamingCoalescerTests.swift`: ten chunks in 10 ms flush as one; `flushNow` flushes at once.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #foundation #streaming