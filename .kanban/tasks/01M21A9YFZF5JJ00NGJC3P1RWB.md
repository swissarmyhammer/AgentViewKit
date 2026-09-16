---
comments:
- actor: claude-code
  id: 01m2n88qasjcewm6h2t5n0fehb
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 4 source files and 3 test files under Streaming/. Decision: `Paragraph` and `BalancedTail` are nested types (`ParagraphSplitter.Paragraph`, `StreamingMarkdownBalancer.BalancedTail`), so that they do not collide with Textual names. The id hash is FNV-1a, because Swift `Hasher` has a random seed for each process. The balancer finds an open fence in the tail alone, because the splitter never settles an open fence. `StreamingCoalescer` is a `@MainActor` class.
    - test: green — swift test, all suites pass (126 tests in AgentViewKitTests), no new warnings
    - commit: b4fa7af
    - review: findings — StreamingCoalescer.swift:20, StreamingMarkdownBalancer.swift:156, StreamingMarkdownBalancer.swift:162 (code-hygiene/magic-numbers-swift)
  timestamp: 2026-09-16T13:59:56.505601+00:00
- actor: claude-code
  id: 01m2n8c6v4spav6aatqj9w1ehx
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — named constants `defaultIntervalMilliseconds` (StreamingCoalescer.swift) and `escapeLength` (StreamingMarkdownBalancer.swift). `swiftlint` with `no_magic_numbers` gives no result on Sources/AgentViewKit/Streaming.
    - test: green — swift test, all suites pass, no new warnings
    - commit: 55f5434
    - review: clean — review sha HEAD~1..HEAD, 0 findings; the 3 earlier findings are checked. Task moved to done.
  timestamp: 2026-09-16T14:01:50.692685+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: done
position_ordinal: '8680'
title: StreamingMarkdownBalancer and paragraph splitter, pure functions (plan §8)
---
## What
Create `Sources/AgentViewKit/Streaming/ParagraphSplitter.swift` and `Sources/AgentViewKit/Streaming/StreamingMarkdownBalancer.swift`, per plan.md §8. Both are pure functions on `String`, with no SwiftUI import.

- `ParagraphSplitter.split(_ markdown: String) -> (settled: [Paragraph], tail: String)`. A paragraph is a block separated by a blank line. A fenced code block is one paragraph and is never split. The last block is the tail while a stream is open. Each settled paragraph gets a stable id from its index and a hash of its text.
- `StreamingMarkdownBalancer.balance(tail: String) -> BalancedTail`. It closes a dangling `**`, `*`, `_`, `` ` ``, and `[` in the tail. It detects an open code fence by an odd count of ```` ``` ```` in the whole message and returns `.openFence(language, body)` so the caller routes the body to the EditorKit append path. It never touches settled paragraphs.
- `StreamingCoalescer`: an actor or `@MainActor` helper that batches appended chunks and flushes at a 33 ms cadence, with `flushNow()`.

## Acceptance Criteria
- [x] Splitting a message with three paragraphs and an open fourth returns three settled paragraphs and the fourth as tail.
- [x] A fenced block with blank lines inside stays one paragraph.
- [x] `balance("some **bold")` returns `"some **bold**"`.
- [x] `balance` on an open fence returns `.openFence` and does not add closing markers.
- [x] Settled paragraph ids are stable when more text is appended to the tail.

## Tests
- [x] `Tests/AgentViewKitTests/Streaming/ParagraphSplitterTests.swift`: the cases above plus CRLF input.
- [x] `Tests/AgentViewKitTests/Streaming/StreamingMarkdownBalancerTests.swift`: each delimiter, nested delimiters, an escaped delimiter, a fence with a language.
- [x] `Tests/AgentViewKitTests/Streaming/StreamingCoalescerTests.swift`: ten chunks in 10 ms flush as one; `flushNow` flushes at once.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #foundation #streaming

## Review Findings (2026-09-16 08:56)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 7 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKit/Streaming/StreamingCoalescer.swift:20` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Streaming/StreamingMarkdownBalancer.swift:156` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Streaming/StreamingMarkdownBalancer.swift:162` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
