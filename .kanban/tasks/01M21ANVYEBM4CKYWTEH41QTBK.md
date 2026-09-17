---
comments:
- actor: claude-code
  id: 01m2psybytc6ybfztt21jfyjtz
  text: 'Note from ^czf33yz: `AgentCommandVerb.copyThread` (Sources/AgentViewKit/Commands) already copies the thread as plain text through `AgentCommandTarget.plainText(of:)`. The text has a role line ("User:" or "Assistant:") and the user-visible text blocks of each message. Other items are omitted. Use or replace this function for "copy thread", so that the command and the MessageActions button give the same text. A button can run the command with `commandTarget?.perform(.copyThread)`.'
  timestamp: 2026-09-17T04:28:05.978735+00:00
- actor: claude-code
  id: 01m2q1p59z1wag8z8ckrj81913
  text: 'Note from ^ktrtzez: the message footer slot is in Sources/AgentViewKit/Items/MessageItemView.swift. Fill it with `.messageFooter { message in MessageActions(...) }` (environment key `messageFooter`, type `ItemViewRenderer<Message>?`). UserMessageView and AssistantMessageView show the footer below the content blocks. `MessageRole` (MessageHeader.swift) tells the sender.'
  timestamp: 2026-09-17T06:43:25.631480+00:00
depends_on:
- 01M21AHDHY0H7A92PP2KTRTZEZ
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: doing
position_ordinal: '8180'
title: 'MessageActions: copy, copy thread, export Markdown, retry, edit; per-message selection (plan §9 A, §11#8, research R10)'
---
## What
Create `Sources/AgentViewKit/Items/MessageActions.swift` and `ThreadExporter.swift`, per plan.md §9 A and decision 8. This task also settles research R10.

- `MessageActions(message:)`: a footer row with Copy (the message text as Markdown, through the environment `Pasteboard`), Copy thread, Export thread as Markdown (`fileExporter`), Retry (calls `send` with the last user input; assistant messages only), and Edit (loads the text into the composer; user messages only). Buttons are `.glass` secondary. Identifiers `message-copy`, `message-copy-thread`, `message-export`, `message-retry`, `message-edit`.
- `ThreadExporter.markdown(for thread: AgentThread) -> String`: user and assistant messages as headed sections, reasoning as a quoted block, tool calls as a fenced JSON summary, and structured items as fenced JSON.
- Research R10, per-message selection: run a hosted probe that applies `.textSelection(.enabled)` on two message rows and drags across both. Record the result in `Docs/decisions/text-selection.md` with a `mode:` line (`perMessage` or `crossMessage`). `MessageActions.selectionMode` returns the mode the kit uses. The probe is research output, not a criterion.

## Acceptance Criteria
- [ ] A press on `message-copy` writes the message Markdown to the `FakePasteboard`.
- [ ] Export produces a Markdown document equal to the golden file for the fixture thread.
- [ ] `message-retry` calls `send` with the last user input; `message-edit` sets the composer text.
- [ ] `MessageActions.selectionMode` equals the `mode:` line in `Docs/decisions/text-selection.md` (a test parses it).

## Tests
- [ ] `Tests/AgentViewKitTests/Items/ThreadExporterTests.swift`: a golden Markdown file for a fixture thread.
- [ ] `Tests/AgentViewKitTests/Items/MessageActionsHostedTests.swift`: the four actions through `FakePasteboard` and `NoopThreadActions`; the decision-file match.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.