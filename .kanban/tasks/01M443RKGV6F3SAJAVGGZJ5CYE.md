---
assignees:
- claude-code
depends_on:
- 01M443RA2PMKC5MXXBNH1116AB
position_column: todo
position_ordinal: a180
title: 'Remove the kit session model: AgentThread, ThreadItem, ThreadChange, ItemPatch and the records'
---
## What
The views bind to the client models, so the kit keeps no session state. Source: update.md §4.5 (row 1). The kit copies of the ACP value types are removed in a separate task after this one.

- [ ] Delete from `Sources/AgentViewKit/Model/`: `AgentThread.swift`, `AgentThreadActions.swift`, `ThreadItem.swift`, `ThreadChange.swift`, `ItemPatch.swift`, `ThreadRecord.swift`, `Message.swift`, `Reasoning.swift`, `ToolCallRecord.swift`, `TerminalRecord.swift`, `UnknownRecord.swift`, `Plan.swift`, `ThreadInfo.swift`, `Requests/`.
- [ ] Rewrite `Sources/AgentViewKitTestSupport/ThreadFixtures.swift`, `ThreadViewHarness.swift` and `NoopThreadActions.swift` on the session test helper, or delete them.
- [ ] Remove each remaining use of `AgentThread` in `README.md` and `Examples/ReadmeSnippets/Snippets/HostApp.swift` (if the quick-start task left one). Run `Scripts/extract-readme-snippets.sh`.
- [ ] Delete or move the tests in `Tests/AgentViewKitTests/Model/` that test the removed types. The merge rules are tested in FoundationModelsACP.
- [ ] Add `AgentThread`, `ThreadChange` and `ItemPatch` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [ ] No file in `Sources/`, `Tests/`, `Examples/` or `README.md` uses `AgentThread`, `ThreadItem`, `ThreadChange` or `ItemPatch`.
- [ ] `swift test`, `Scripts/check-readme.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Tests
- [ ] `RemovedVocabularyTests` fails before the removal and passes after it.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.