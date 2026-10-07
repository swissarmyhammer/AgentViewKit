---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4c68qqrqhxj1zmaejd9s9ck
  text: |-
    Research (implement step):
    - The thread path is still in about 30 source files: ConversationSource, ToolCallSource and TerminalSource have a `.thread`/`.record` case beside the session case; ItemRow has `init(item:)`; ConversationView, MessageActions, AgentCommandTarget, AgentCommandScope, ThreadExporter, AgentAuthView, ActivityIndicator, ReasoningView, ResponseView, UnknownItemView, ErrorView, TerminalView, ToolCallView, TaskListView and StateBanner have thread or record initializers or branches.
    - ToolCallRecord.swift also declares the kit ToolCallStatus, ToolKind, ToolContent and ToolCallLocation. Plan.swift declares PlanEntry. Requests/ declares AuthMethod, PermissionOption, ElicitationResult and more. Task ^71k836q removes the kit value copies. Thus this task deletes the files on the card, and moves each value type that a remaining view still uses to its own file. It deletes a value type only when no remaining code uses it.
    - ThreadError is an @Observable ThreadRecord too. It is not on the card list, but it is part of the record model and it holds a model value, so it goes with the records.
    - The Benchmarks package (separate SwiftPM package) uses StreamingMessage and StreamingCoalescer. Those benchmarks go with the types; ^tjr0bxm adds the SessionModel benchmark.
    - The focus segment kind string "agentThread" of AgentCommandTarget is a text value, not the removed type, so the vocabulary scan does not list `agentThread`.
  timestamp: 2026-10-07T22:03:13.528080+00:00
- actor: claude-code
  id: 01m4cc0xr42vcvj9m2spk5edg6
  text: |-
    ### implement — changed

    The kit session model is removed. Each view binds to `ConnectionModel`, `SessionModel` and the `TranscriptEntry` objects. All subtasks are done.

    **Removed**
    - Model: `AgentThread`, `AgentThreadActions`, `ThreadItem`, `ThreadChange`, `ItemPatch`, `ThreadRecord`, `Message`, `Reasoning`, `UnknownRecord`, `ThreadInfo`, `ToolCallRecord`, `TerminalRecord`, `Plan`, `ThreadError`, `Requests/`.
    - The thread path of the views: `AgentThreadEnvironment`, `ConversationSource`, `ToolCallSource` (now `ToolCallPart` over `ToolCallEntry`), `TerminalSource`, `ThreadMessageItemView`, `ErrorActions`, `ComposerTurn`, `EnvironmentComposerTurn`, the `threadActions` value, and the `actions:` parameter of `AgentThreadView`.
    - `StreamingMessage`, `StreamingCoalescer`, the streaming tail of `ResponseView` and `lazyResponseParagraphs`.
    - Test support: `ThreadFixtures`, `NoopThreadActions`, `threadViewHarness`. `ThreadViewHarness.swift` is now `HostedViewHarness+TextViews.swift`.
    - Benchmarks: the streaming scenarios, the corpus and their baselines. They measured `StreamingMessage`. `Benchmarks/` builds and has no scenario until ^tjr0bxm.

    **Added**
    - `RemovedVocabularyTests`: the removed-symbol scan, the `actions:` call scan, and the `@Observable` allow list (`AccessibilityFocusMover`, `CitationSelection`, `DiffLineSelection`, `ExpandedBlocksStore`, `Entry`, `InspectorSelection`, `ScrollAnchorManager`). They failed before the removal.
    - `DecisionRecordTests`: the host hook section names `terminalAuthRunner` and `agentReconnect`; `required-thread-actions.md` is marked not current. They failed before the record change.
    - `Docs/decisions/acp-client-kit.md`: section "Host hooks".
    - Session ports of the hosted tests: conversation pages, empty state, scroll anchors, the Show Error jump, composer submit and stop, EditorKit editor keys, attachments, suggestions, tool call view, terminal view, agent commands, message actions, diff in a tool call.

    **Notes for the next tasks**
    - ^71k836q: these kit types are now used only by their own tests: `ThreadState` (and the kit `StopReason`), `ConfigOption`, `ConfigValue`, `ContextUsage`, `SlashCommand`, `PatchField`, `WireValueEnum`. I did not delete them, because that card owns them.
    - The reasoning row of an entry shows no in-progress shimmer and no duration. The old thread path showed them from kit timestamps. `ThoughtEntry` has no start or end time. The entry path already showed no duration before this task, so this is not a new gap.

    **Evidence**
    - `swift test`: 1091 tests in 115 suites passed (AgentViewKitTests), and 91 tests in 12 suites passed (PackageStructureTests).
    - `Scripts/check-readme.sh`: passed.
    - `Scripts/test-examples.sh AgentViewKitDemo`: passed.
    - `swift build --package-path Benchmarks`: passed.
    - `periphery scan --retain-public`: no new finding.
  timestamp: 2026-10-07T23:43:48.996456+00:00
- actor: claude-code
  id: 01m4cccjv01apmntm6mnetqsnq
  text: |-
    ### test — green
    - evidence: swift test: 1091 tests in 115 suites passed, 0 failed. Scripts/check-readme.sh: passed (3 snippets compile). Scripts/test-examples.sh AgentViewKitDemo: 4 UI tests, 0 failures, PASS. swift build --package-path Benchmarks: build complete.
    - warnings: only the expected mlx-swift "missing creator for mutated node" and the Xcode "Metadata extraction skipped" notices. No skipped tests. No time-limit failure, so no uptime run.
    - changes: none. Nothing committed.
    - next: review
  timestamp: 2026-10-07T23:50:11.040109+00:00
depends_on:
- 01M443RA2PMKC5MXXBNH1116AB
- 01M48MQ0BVDHNY798PTF3VYEQH
- 01M48MQDWDPN98ZSWQ4N7S44FW
- 01M48MS20B5GS4711S119KD9GM
- 01M48MSB7741KRK4BVHBGFFCF1
- 01M48MSNZ644ZZQGK3K8YWX4HY
- 01M48MT3CW529Q3MWWN8XRVRW5
- 01M48MTGH4ZSS4GVBP6GVE03AX
- 01M49EX269YQZDGYF6HS3ZYGVH
- 01M49GHXXC7CY7R1PRZ83200VG
- 01M49HGZQP3HMVTY4MC20J25QH
- 01M49HHYXB9KWKB949M0VYZMM0
position_column: doing
position_ordinal: '80'
title: 'Remove the kit session model: AgentThread, ThreadItem, ThreadChange, ItemPatch and the records'
---
## What
The views bind to the client models, so the kit keeps no session state. Source: update.md §4.5 (row 1). The kit copies of the ACP value types are removed in a separate task after this one. Owner rule (2026-10-06): each view binds directly to the observable model of FoundationModelsACPClient (`ConnectionModel`, `SessionModel`, the `TranscriptEntry` objects) and calls the model methods. After this task the kit has no second model, no turn tracking and no copy of model data. The binding tasks that this task depends on move each view group to the models first.

Note (2026-10-07): ^83200vg removed `runTerminalAuth`. The terminal sign-in now uses the `terminalAuthRunner` environment value (`TerminalAuthRunner` of the client), and the Reconnect button uses the `agentReconnect` environment value. ^0vyzmm0 changed the thread view to `AgentThreadView(session:connection:actions:)`.

- [x] Delete from `Sources/AgentViewKit/Model/`: `AgentThread.swift`, `AgentThreadActions.swift`, `ThreadItem.swift`, `ThreadChange.swift`, `ItemPatch.swift`, `ThreadRecord.swift`, `Message.swift`, `Reasoning.swift`, `ToolCallRecord.swift`, `TerminalRecord.swift`, `UnknownRecord.swift`, `Plan.swift`, `ThreadInfo.swift`, `Requests/`.
- [x] Delete the thread path of the views: `Sources/AgentViewKit/Thread/AgentThreadEnvironment.swift` (the `agentThread` value), the `threadActions` value, the `.thread`, `.record` and `.item` cases of `ConversationSource`, `ToolCallSource`, `TerminalSource`, `ItemRow` and `AgentThreadView`, `PendingRequestsHost(thread:)`, `ComposerTurn` and `EnvironmentComposerTurn` (the composer views read the `sessionModel` value and call `prompt(_:meta:)` and `cancel(meta:)` directly), and `PromptQueue.dequeueNext(after:)`.
- [x] Delete `Sources/AgentViewKit/Streaming/StreamingMessage.swift` and `StreamingCoalescer.swift`: the model applies the chunks at display rate, so the kit needs no second coalescer and no copy of the text. Keep `ParagraphSplitter` and `StreamingMarkdownBalancer` as pure functions.
- [x] Remove the `actions:` parameter of `AgentThreadView(session:connection:actions:)`. The only host hooks that stay are the `terminalAuthRunner` and `agentReconnect` environment values, because no model gives that work. Name them in the decision record.
- [x] Rewrite `Sources/AgentViewKitTestSupport/ThreadFixtures.swift`, `ThreadViewHarness.swift` and `NoopThreadActions.swift` on the session test helper (`ScriptedSession`), or delete them. Remove each remaining use of `AgentThread` in `README.md` and `Examples/ReadmeSnippets/Snippets/HostApp.swift`. Run `Scripts/extract-readme-snippets.sh`. Delete or move the tests in `Tests/AgentViewKitTests/Model/` that test the removed types; the merge rules are tested in FoundationModelsACP.
- [x] Add `AgentThread`, `ThreadChange`, `ItemPatch`, `StreamingMessage`, `StreamingCoalescer`, `ComposerTurn` and `isLastWhileRunning` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [x] No file in `Sources/`, `Tests/`, `Examples/` or `README.md` uses `AgentThread`, `ThreadItem`, `ThreadChange`, `ItemPatch`, `StreamingMessage`, `StreamingCoalescer` or `ComposerTurn`.
- [x] Each `@Observable` class in `Sources/AgentViewKit/` holds view state only (open state, scroll position, focus, selection, composer draft); none holds a value that `ConnectionModel`, `SessionModel` or a `TranscriptEntry` object holds.
- [x] `swift test`, `Scripts/check-readme.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.
- [x] No code in the kit keeps a list of pending requests: `AgentThread.pendingPermissions` and `pendingElicitations` are gone, and `ThreadAccessibility` and `AgentCommandTarget` read the pending requests of `SessionModel` (moved from ^6a6x9x9).

## Tests
- [x] `RemovedVocabularyTests` fails before the removal and passes after it.
- [x] Add a test in `Tests/PackageStructureTests/RemovedVocabularyTests.swift` that lists the `@Observable` classes of `Sources/AgentViewKit/` and fails on a class that is not in the allowed view-state list.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.