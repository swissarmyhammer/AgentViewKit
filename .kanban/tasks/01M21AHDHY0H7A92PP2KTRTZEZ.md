---
comments:
- actor: claude-code
  id: 01m2nxv7wwcdhwamz5cjr4rfyn
  text: 'Note from ^r061h51: `AssistantMessageView` (and `UserMessageView` for its text) must show the text body with `ResponseView(message: record, streaming: thread.streaming[record.id])` (Sources/AgentViewKit/Content/ResponseView.swift). Read `thread` from the environment or pass the `StreamingMessage` down; do not read `thread.streaming` in the `ItemRow` body, so that a chunk does not evaluate the row. Replace the `item-placeholder-<id>` views for these kinds.'
  timestamp: 2026-09-16T20:17:03.388830+00:00
- actor: claude-code
  id: 01m2prq652jn4d6461js894vhn
  text: 'Note from ^b6geery: a ResponseView in a scroll view must put its settled paragraphs in a lazy stack, or the cost of a streamed chunk grows with the message (Benchmarks/README.md, R1). ConversationView sets `.lazyResponseParagraphs()` for its rows. An AssistantMessageView in another scroll view must apply `.lazyResponseParagraphs()` itself. Do not apply it outside a scroll view: a lazy stack there shows nothing.'
  timestamp: 2026-09-17T04:06:42.082576+00:00
- actor: claude-code
  id: 01m2pytk89vevb6p99xnvnmcfs
  text: 'Note from ^pfbg4pq: ConversationView now shows a TurnSummaryRow ("Worked N s, K tools, +A −R") above the first agent item of each turn that has work (TurnSummary.anchors(in:), ThreadTurnSummary). The row wraps that item in a VStack in the ForEach. AssistantMessageView must not show the summary again.'
  timestamp: 2026-09-17T05:53:25.257080+00:00
- actor: claude-code
  id: 01m2q1p3wq1ksa65q3ecp653wh
  text: |-
    ### finish iteration 1 — done
    - implement: added SystemPromptView, UserMessageView, AssistantMessageView, MessageHeader (with MessageRole), and the shared MessageItemView with the `messageFooter` environment slot and the `.messageFooter { message in }` modifier. ItemRow uses the new views. A streaming message shows its text through ResponseView with `thread.streaming[id]`, and its other blocks through ContentBlockView.
    - test: `swift test` passed. AgentViewKitTests 1148, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44. `Scripts/check-benchmarks.sh` passed.
    - commit: 4667f23
    - review: `review sha HEAD~1..HEAD`, 0 findings. Moved to done.
  timestamp: 2026-09-17T06:43:24.183829+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BDXGQ5HYN8GCKAEH8GN3P
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: done
position_ordinal: c180
title: 'Message item views: SystemPromptView, UserMessageView, AssistantMessageView (plan §9 A2)'
---
## What
Create `Sources/AgentViewKit/Items/SystemPromptView.swift`, `UserMessageView.swift`, `AssistantMessageView.swift`, and `MessageHeader.swift`, per plan.md §9 A2. They replace the placeholders in `ItemRow`. `StructuredItemView`, `UnknownItemView`, `ErrorView`, and `CompactionMarkerView` are in other tasks.

- `SystemPromptView(record:)`: a disclosure labelled "Instructions", collapsed by default, that reveals the text. Expanded state lives in `ExpandedBlocksStore`.
- `MessageHeader(role:date:)`: the role label and a relative time.
- `UserMessageView(message:)` and `AssistantMessageView(message:)`: the header, the content blocks through `ContentBlockView`, and a footer slot `messageFooter` (`@ViewBuilder`, empty by default) that `MessageActions` fills later.
- Every view reads `AgentTheme` for spacing and fonts.
- Accessibility identifiers: `system-prompt`, `user-message-<id>`, `assistant-message-<id>`. Labels: "Instructions", "You said", "Assistant said".

## Acceptance Criteria
- [x] Each view mounts for its record with its identifier and label.
- [x] `system-prompt` is collapsed by default; a press expands it and the text becomes an element.
- [x] A message with two blocks mounts two `content-block-*` elements in order.

## Tests
- [x] `Tests/AgentViewKitTests/Items/MessageViewsHostedTests.swift`: one mount per view, the disclosure toggle, the block order.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-17 01:38)

Scope: `review sha HEAD~1..HEAD` (commit 4667f23). 8 files reviewed. 0 findings. 1 candidate refuted.