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
- actor: claude-code
  id: 01m2q2sz875jcb8mg8r4xja0yr
  text: |-
    ### finish iteration 1 — findings
    - implement: MessageActions, ThreadExporter, the composer `load` hook, per-message Textual selection in MessageItemView, and Docs/decisions/text-selection.md (R10 probe result: perMessage).
    - test: `swift test` passed. AgentViewKitTests 1168, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44.
    - commit: 2a1117b
    - review: 2 findings (duplication and reuse of `exportDidFinish` in MessageActions.swift:253, the same as AttachmentActions.swift:94).
  timestamp: 2026-09-17T07:02:59.079917+00:00
- actor: claude-code
  id: 01m2q30rabc23epxfr96cpt5t8
  text: |-
    ### finish iteration 2 — done
    - implement: FileExportLog and ExportOnlyDocument (Sources/AgentViewKit/Platform/FileExport.swift). AttachmentActions and MessageActions use them. The two prior findings are checked.
    - test: `swift test` passed. AgentViewKitTests 1168, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44.
    - commit: 4478362
    - review: `review sha HEAD~1..HEAD` gave 0 findings (2026-09-17 02:05). All prior items are checked.
  timestamp: 2026-09-17T07:06:41.355785+00:00
depends_on:
- 01M21AHDHY0H7A92PP2KTRTZEZ
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: done
position_ordinal: c280
title: 'MessageActions: copy, copy thread, export Markdown, retry, edit; per-message selection (plan §9 A, §11#8, research R10)'
---
## What
Create `Sources/AgentViewKit/Items/MessageActions.swift` and `ThreadExporter.swift`, per plan.md §9 A and decision 8. This task also settles research R10.

- `MessageActions(message:)`: a footer row with Copy (the message text as Markdown, through the environment `Pasteboard`), Copy thread, Export thread as Markdown (`fileExporter`), Retry (calls `send` with the last user input; assistant messages only), and Edit (loads the text into the composer; user messages only). Buttons are `.glass` secondary. Identifiers `message-copy`, `message-copy-thread`, `message-export`, `message-retry`, `message-edit`.
- `ThreadExporter.markdown(for thread: AgentThread) -> String`: user and assistant messages as headed sections, reasoning as a quoted block, tool calls as a fenced JSON summary, and structured items as fenced JSON.
- Research R10, per-message selection: run a hosted probe that applies `.textSelection(.enabled)` on two message rows and drags across both. Record the result in `Docs/decisions/text-selection.md` with a `mode:` line (`perMessage` or `crossMessage`). `MessageActions.selectionMode` returns the mode the kit uses. The probe is research output, not a criterion.

## Acceptance Criteria
- [x] A press on `message-copy` writes the message Markdown to the `FakePasteboard`.
- [x] Export produces a Markdown document equal to the golden file for the fixture thread.
- [x] `message-retry` calls `send` with the last user input; `message-edit` sets the composer text.
- [x] `MessageActions.selectionMode` equals the `mode:` line in `Docs/decisions/text-selection.md` (a test parses it).

## Tests
- [x] `Tests/AgentViewKitTests/Items/ThreadExporterTests.swift`: a golden Markdown file for a fixture thread.
- [x] `Tests/AgentViewKitTests/Items/MessageActionsHostedTests.swift`: the four actions through `FakePasteboard` and `NoopThreadActions`; the decision-file match.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-17 01:53)

- [x] `Sources/AgentViewKit/Items/MessageActions.swift:253` `duplication/duplication` — The `exportDidFinish` method is 0.99 identical to existing code in `AttachmentActions.swift:94`. This near-verbatim copy should be refactored to call or reuse the existing implementation rather than duplicating error-handling logic that could drift out of sync. Extract a shared `handleExportFailure(_:logger:)` utility function, or call the existing `AttachmentActions.exportDidFinish` implementation if it is reusable. Avoid the copy that will require maintenance in two places.
- [x] `Sources/AgentViewKit/Items/MessageActions.swift:253` `reuse/reuse` — exportDidFinish() reimplements error logging that already exists in AttachmentActions.exportDidFinish with 0.99 similarity. The same error-handling and logging logic should be extracted to a shared utility rather than duplicated. Extract exportDidFinish() to a shared utility function, or have MessageActions call the existing AttachmentActions implementation.