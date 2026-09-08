---
depends_on:
- 01M21AHDHY0H7A92PP2KTRTZEZ
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: a280
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