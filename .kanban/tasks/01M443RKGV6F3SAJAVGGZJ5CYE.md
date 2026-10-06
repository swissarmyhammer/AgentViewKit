---
assignees:
- claude-code
depends_on:
- 01M443RA2PMKC5MXXBNH1116AB
- 01M48MQ0BVDHNY798PTF3VYEQH
- 01M48MQDWDPN98ZSWQ4N7S44FW
- 01M48MS20B5GS4711S119KD9GM
- 01M48MSB7741KRK4BVHBGFFCF1
- 01M48MSNZ644ZZQGK3K8YWX4HY
- 01M48MT3CW529Q3MWWN8XRVRW5
- 01M48MTGH4ZSS4GVBP6GVE03AX
position_column: todo
position_ordinal: a180
title: 'Remove the kit session model: AgentThread, ThreadItem, ThreadChange, ItemPatch and the records'
---
## What
The views bind to the client models, so the kit keeps no session state. Source: update.md §4.5 (row 1). The kit copies of the ACP value types are removed in a separate task after this one. Owner rule (2026-10-06): each view binds directly to the observable model of FoundationModelsACPClient (`ConnectionModel`, `SessionModel`, the `TranscriptEntry` objects) and calls the model methods. After this task the kit has no second model, no turn tracking and no copy of model data. The binding tasks that this task depends on move each view group to the models first.

- [ ] Delete from `Sources/AgentViewKit/Model/`: `AgentThread.swift`, `AgentThreadActions.swift`, `ThreadItem.swift`, `ThreadChange.swift`, `ItemPatch.swift`, `ThreadRecord.swift`, `Message.swift`, `Reasoning.swift`, `ToolCallRecord.swift`, `TerminalRecord.swift`, `UnknownRecord.swift`, `Plan.swift`, `ThreadInfo.swift`, `Requests/`.
- [ ] Delete the thread path of the views: `Sources/AgentViewKit/Thread/AgentThreadEnvironment.swift` (the `agentThread` value), the `threadActions` value, the `.thread`, `.record` and `.item` cases of `ConversationSource`, `ToolCallSource`, `TerminalSource`, `ItemRow` and `AgentThreadView`, `PendingRequestsHost(thread:)`, `ComposerTurn` and `EnvironmentComposerTurn` (the composer views read the `sessionModel` value and call `prompt(_:meta:)` and `cancel(meta:)` directly), and `PromptQueue.dequeueNext(after:)`.
- [ ] Delete `Sources/AgentViewKit/Streaming/StreamingMessage.swift` and `StreamingCoalescer.swift`: the model applies the chunks at display rate, so the kit needs no second coalescer and no copy of the text. Keep `ParagraphSplitter` and `StreamingMarkdownBalancer` as pure functions.
- [ ] Remove the `actions:` parameter of `AgentThreadView(session:actions:)`. Keep a host closure only for work that no model gives (the terminal auth process), and name it in the decision record.
- [ ] Rewrite `Sources/AgentViewKitTestSupport/ThreadFixtures.swift`, `ThreadViewHarness.swift` and `NoopThreadActions.swift` on the session test helper (`ScriptedSession`), or delete them. Remove each remaining use of `AgentThread` in `README.md` and `Examples/ReadmeSnippets/Snippets/HostApp.swift`. Run `Scripts/extract-readme-snippets.sh`. Delete or move the tests in `Tests/AgentViewKitTests/Model/` that test the removed types; the merge rules are tested in FoundationModelsACP.
- [ ] Add `AgentThread`, `ThreadChange`, `ItemPatch`, `StreamingMessage`, `StreamingCoalescer`, `ComposerTurn` and `isLastWhileRunning` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [ ] No file in `Sources/`, `Tests/`, `Examples/` or `README.md` uses `AgentThread`, `ThreadItem`, `ThreadChange`, `ItemPatch`, `StreamingMessage`, `StreamingCoalescer` or `ComposerTurn`.
- [ ] Each `@Observable` class in `Sources/AgentViewKit/` holds view state only (open state, scroll position, focus, selection, composer draft); none holds a value that `ConnectionModel`, `SessionModel` or a `TranscriptEntry` object holds.
- [ ] `swift test`, `Scripts/check-readme.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.
- [ ] No code in the kit keeps a list of pending requests: `AgentThread.pendingPermissions` and `pendingElicitations` are gone, and `ThreadAccessibility` and `AgentCommandTarget` read the pending requests of `SessionModel` (moved from ^6a6x9x9).

## Tests
- [ ] `RemovedVocabularyTests` fails before the removal and passes after it.
- [ ] Add a test in `Tests/PackageStructureTests/RemovedVocabularyTests.swift` that lists the `@Observable` classes of `Sources/AgentViewKit/` and fails on a class that is not in the allowed view-state list.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.