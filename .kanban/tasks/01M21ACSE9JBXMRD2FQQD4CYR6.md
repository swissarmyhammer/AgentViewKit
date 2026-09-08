---
depends_on:
- 01M21A961W19N9FWQ92FETNVP6
- 01M21A9YFZF5JJ00NGJC3P1RWB
- 01M21ABCXCQMMYMRK3QBM7CCJV
position_column: todo
position_ordinal: 8a80
title: 'StreamingMessage: the isolated streaming tail observable (plan §8)'
---
## What
Create `Sources/AgentViewKit/Streaming/StreamingMessage.swift`, per plan.md §8.

- `StreamingMessage` (`@MainActor @Observable final class`): the in-flight message for one record id. Properties: `settledParagraphs: [Paragraph]`, `tail: BalancedTail`, `isOpen: Bool`.
- `append(_ chunk: String)`: pushes to the `StreamingCoalescer`; on flush it runs `ParagraphSplitter` and `StreamingMarkdownBalancer` and updates the two properties. Settled paragraphs only grow; the tail is replaced.
- `replace(_ text: String)`: for a whole-message upsert. Recomputes from scratch.
- `close()`: settles the tail as the last paragraph and sets `isOpen = false`.
- `AgentThread` holds `streaming: [String: StreamingMessage]` keyed by record id, and sources write to it instead of patching the record on every chunk. The record's `content` gets the final text on `close()`.

## Acceptance Criteria
- [ ] Appending three paragraphs in twelve chunks yields two settled paragraphs and one tail before `close()`, three settled after.
- [ ] A view that reads `settledParagraphs` is not invalidated by a chunk that only changes the tail (verify with `withObservationTracking`).
- [ ] `replace` with shorter text shrinks `settledParagraphs`.

## Tests
- [ ] `Tests/AgentViewKitTests/Streaming/StreamingMessageTests.swift`: the three cases above plus a fence that opens in one chunk and closes in a later one.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.