---
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