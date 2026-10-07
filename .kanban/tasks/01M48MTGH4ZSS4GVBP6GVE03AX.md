---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4a6w0yq4r094vayg1et4y28
  text: |-
    Research done.
    - The client has no public common type for the user and agent message objects (`MessageTranscriptEntry` is internal at be7e615). The footer closure needs one type, so the kit adds a small public enum `MessageEntry` with the cases `user(UserMessageEntry)` and `agent(AgentMessageEntry)`. It holds only the model objects; it keeps no data.
    - `RemovedVocabularyTests` forbids `compactionView` and `compactionViewOverride`. The compaction override is therefore `compactionEntryView` / `compactionEntryViewOverride`. The terminal and plan overrides are `terminalView` / `planView`.
    - Entries can only come from a `ScriptedSession` (the client entry initializers are internal), so the policy tests in `ExpandedBlocksStoreTests` move to entries made by a scripted session.
    - The old thread path (`AgentThreadView(thread:actions:)`) keeps: its default item views with no override, `MessageActions(message:)`, and the kit-message views (`MessageItemView`, `MessageBodyView`), which move out of `MessageItemView.swift` into `ThreadMessageItemView.swift`. The old path loses the overrides, the footer slot and the expanded policy, because those now take entry objects.
    - Plan: overrides keyed on entries in `ItemRow.entryContent`; footer in `TranscriptMessageView`; policy on `TranscriptEntry` used by `ToolCallSource`, `ThoughtEntryBlock` and `AgentCommandTarget`.
  timestamp: 2026-10-07T03:35:16.695377+00:00
- actor: claude-code
  id: 01m4a7ka7gtw24mmpdygz0944w
  text: |-
    Implementation landed (TDD: the new tests first failed to compile against the record-keyed API, then passed).
    - Overrides: each `EnvironmentValues` override key and typed modifier now takes the entry object of its case. New keys and modifiers: `terminalViewOverride` / `terminalView`, `planViewOverride` / `planView`, `compactionEntryViewOverride` / `compactionEntryView`. `ItemRow.entryContent(_:)` wraps each case in `OverridableItemView`, which reads only the environment key, so the row still reads nothing of the entry.
    - Footer: `messageFooter` takes the new public enum `MessageEntry` (`.user` / `.agent`, holds the model object only). `TranscriptMessageView` takes the `MessageEntry` and shows the footer below the content. `MessageActions(entry: MessageEntry)` is added, so `.messageFooter { MessageActions(entry: $0) }` works. The default footer stays `nil` (the existing "empty by default" contract); README, the HostApp snippet and the `MessageActions` doc now show `MessageActions(entry:)` as the footer.
    - Policy: `ExpandedBlocksStore.defaultExpanded` is `@MainActor (TranscriptEntry) -> Bool`; `isExpanded(_:)` and `seed(_:)` take a `TranscriptEntry` and key on its row key. `ToolCallSource` (entry), `ThoughtEntryBlock` (thought entry) and `AgentCommandTarget.isEachRowExpanded` (session) use the policy.
    - Old thread path keeps only: its default item views with no override, `MessageActions(message:)` outside the footer, and the kit-message views, now `ThreadMessageItemView` and `MessageBodyView` in `Items/ThreadMessageItemView.swift`. It loses the overrides, the footer slot and the expanded policy. The deprecated-thread tests that used `.messageFooter { MessageActions(message:) }` now mount `MessageActions(message:)` directly; the thread copy-thread footer test and the thread tool-call override test moved to the session path.
    - Note: the README HostApp snippet still mounts the deprecated `AgentThreadView(thread:actions:)`, so its entry overrides do not apply there; the README text says so. The quick-start rewrite (^43rtqwk / ^g95wwbs) owns the snippet shape.
    - Docs/decisions/accessibility.md named `MessageItemView`; it now names `MessageLayout`, the view that gives the message id.
  timestamp: 2026-10-07T03:47:59.856831+00:00
- actor: claude-code
  id: 01m4a7kf0dcwp1x2zp4qhwry81
  text: |-
    ### implement — changed
    - evidence: 24 files. Sources: ItemViewOverrides.swift, ItemRow.swift, AgentThreadView.swift, ExpandedBlocksStore.swift, MessageItemView.swift, ThreadMessageItemView.swift (new), TranscriptMessageView.swift, UserMessageView.swift, AssistantMessageView.swift, MessageActions.swift, ReasoningView.swift, ThoughtEntryBlock.swift, ToolCallSource.swift, ToolCallView.swift, AgentCommandTarget.swift. Tests: RegistryResolutionTests, SessionTranscriptViewHostedTests, ExpandedBlocksStoreTests, SessionEntryRowsHostedTests, MessageViewsHostedTests, MessageActionsHostedTests, AgentThreadViewHostedTests, AgentCommandsTests. Docs: README.md, Examples/ReadmeSnippets/Snippets/HostApp.swift, Docs/decisions/accessibility.md. Commands: `swift test` (1383 tests in 126 suites passed, plus 78 and 1; only the mlx-swift "missing creator" warning), `Scripts/check-readme.sh` (pass). Demo not changed, so no demo gate.
    - next: /review
  timestamp: 2026-10-07T03:48:04.749469+00:00
depends_on:
- 01M48MQS1Q5HBNDFMBD2CT0C6C
- 01M48MR5W3YAB8VFA4KTJZVCYN
position_column: doing
position_ordinal: '80'
title: Key the item view overrides, the message footer and the expanded-blocks policy on the transcript entry objects
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. The host extension points still take the old kit records, so a host that shows a `SessionModel` cannot use them, and the kit model removal cannot delete the records:

- `Sources/AgentViewKit/Thread/ItemViewOverrides.swift`: `userMessageViewOverride`, `assistantMessageViewOverride` (kit `Message`), `reasoningViewOverride` (kit `Reasoning`), `toolCallViewOverride` (`ToolCallRecord`), `errorViewOverride` (`ThreadError`), `unknownItemViewOverride` (`UnknownRecord`).
- `Sources/AgentViewKit/Thread/ItemRow.swift`: `entryContent(_:)` applies no override.
- `Sources/AgentViewKit/Items/MessageItemView.swift`: `messageFooter` takes a kit `Message`.
- `Sources/AgentViewKit/Infrastructure/ExpandedBlocksStore.swift`: `defaultExpanded`, `isExpanded(_:)` and `seed(_:)` take a `ThreadItem`, so an entry gets no policy (`ToolCallSource.isExpanded(in:)` uses `false`).

The open state stays view state in the store. Only the type that the policy reads changes.

- [x] Change each override to take the entry object of its case: `UserMessageEntry`, `AgentMessageEntry`, `ThoughtEntry`, `ToolCallEntry`, `ErrorEntry`, `UnknownEntry`. Add overrides for `TerminalEntry`, `PlanTranscriptEntry` and `CompactionEntry`.
- [x] `ItemRow.entryContent(_:)` shows the override of the entry case when the environment has one, else the default view. The override gets the entry object, so it reads the model directly.
- [x] `messageFooter` takes the message entry object.
- [x] `ExpandedBlocksStore.defaultExpanded` takes a `TranscriptEntry`. `isExpanded(_:)` and `seed(_:)` take a `TranscriptEntry` and use `TranscriptEntry.ID.rowKey`. The tool call view of an entry uses the policy.

## Acceptance Criteria
- [x] A host override for tool call entries shows in place of the default tool call view, and shows a status change of the model with no other step.
- [x] A policy that expands the tool call entries with the status `.failed` opens such a row when the model sets that status.
- [x] `ItemViewOverrides.swift`, `MessageItemView.swift` and `ExpandedBlocksStore.swift` do not name `Message`, `Reasoning`, `ToolCallRecord`, `ThreadError`, `UnknownRecord` or `ThreadItem`.

## Tests
- [x] `Tests/AgentViewKitTests/Thread/RegistryResolutionTests.swift`: one override for each entry case resolves in `ItemRow(entry:)`.
- [x] `Tests/AgentViewKitTests/Thread/SessionTranscriptViewHostedTests.swift`: a hosted override reads a status change from the scripted agent; the expanded policy opens a failed tool call entry.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.