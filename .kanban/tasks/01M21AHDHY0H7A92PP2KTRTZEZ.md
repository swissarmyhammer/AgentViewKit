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
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BDXGQ5HYN8GCKAEH8GN3P
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: '9480'
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
- [ ] Each view mounts for its record with its identifier and label.
- [ ] `system-prompt` is collapsed by default; a press expands it and the text becomes an element.
- [ ] A message with two blocks mounts two `content-block-*` elements in order.

## Tests
- [ ] `Tests/AgentViewKitTests/Items/MessageViewsHostedTests.swift`: one mount per view, the disclosure toggle, the block order.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.