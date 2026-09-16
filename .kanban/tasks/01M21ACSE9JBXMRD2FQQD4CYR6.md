---
comments:
- actor: claude-code
  id: 01m2nhmb6kztxg1bsg495c028n
  text: |-
    Implementation notes and decisions:
    - `StreamingMessage` keeps `text` (the flushed text), `settledParagraphs: [ParagraphSplitter.Paragraph]`, `tail: StreamingMarkdownBalancer.BalancedTail`, and `isOpen`. It owns a `StreamingCoalescer` (lazy, `@ObservationIgnored`, weak self). The init takes `interval:` (default 33 ms) so that tests can use a long interval and call `flush()`.
    - New public `flush()`: flushes the coalescer at once. `close()` calls it first, so no chunk is lost.
    - `render()` writes a property only when its value changes. This is what keeps a view of `settledParagraphs` valid when a chunk changes only the tail.
    - The initial `text` renders at once. So the first `appendStreaming` chunk shows with no delay; later chunks wait for the coalescer.
    - `append` after `close()` does nothing. `replace` after `close()` keeps the message closed and settles the new tail.
    - `AgentThread.closeStreaming` now closes the message, removes it, and writes the final text in one patch: user/assistant message -> `content = [text block]`; reasoning -> `segments = [text]`; system -> `text`; no item -> a new assistant message; tool call, structured, compaction, error, unknown -> no change and an `OSLog` error (a caller can send this, so no assertionFailure).
    - The existing test `appendStreamingOnAnExistingIdAddsTheText` now calls `message.flush()`, because a second chunk now waits for the coalescer.
    - Cross-task note for the source tasks (^ACP, Session, Router) and ResponseView: send chunks with `.appendStreaming`, end with `.closeStreaming`; the tail row reads `thread.streaming[id]`.
  timestamp: 2026-09-16T16:43:34.483438+00:00
depends_on:
- 01M21A961W19N9FWQ92FETNVP6
- 01M21A9YFZF5JJ00NGJC3P1RWB
- 01M21ABCXCQMMYMRK3QBM7CCJV
position_column: doing
position_ordinal: '8180'
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
- [x] Appending three paragraphs in twelve chunks yields two settled paragraphs and one tail before `close()`, three settled after.
- [x] A view that reads `settledParagraphs` is not invalidated by a chunk that only changes the tail (verify with `withObservationTracking`).
- [x] `replace` with shorter text shrinks `settledParagraphs`.

## Tests
- [x] `Tests/AgentViewKitTests/Streaming/StreamingMessageTests.swift`: the three cases above plus a fence that opens in one chunk and closes in a later one.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.