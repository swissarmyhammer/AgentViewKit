---
assignees:
- claude-code
depends_on:
- 01M48MQS1Q5HBNDFMBD2CT0C6C
- 01M48MR5W3YAB8VFA4KTJZVCYN
position_column: todo
position_ordinal: b180
title: Key the item view overrides, the message footer and the expanded-blocks policy on the transcript entry objects
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. The host extension points still take the old kit records, so a host that shows a `SessionModel` cannot use them, and the kit model removal cannot delete the records:

- `Sources/AgentViewKit/Thread/ItemViewOverrides.swift`: `userMessageViewOverride`, `assistantMessageViewOverride` (kit `Message`), `reasoningViewOverride` (kit `Reasoning`), `toolCallViewOverride` (`ToolCallRecord`), `errorViewOverride` (`ThreadError`), `unknownItemViewOverride` (`UnknownRecord`).
- `Sources/AgentViewKit/Thread/ItemRow.swift`: `entryContent(_:)` applies no override.
- `Sources/AgentViewKit/Items/MessageItemView.swift`: `messageFooter` takes a kit `Message`.
- `Sources/AgentViewKit/Infrastructure/ExpandedBlocksStore.swift`: `defaultExpanded`, `isExpanded(_:)` and `seed(_:)` take a `ThreadItem`, so an entry gets no policy (`ToolCallSource.isExpanded(in:)` uses `false`).

The open state stays view state in the store. Only the type that the policy reads changes.

- [ ] Change each override to take the entry object of its case: `UserMessageEntry`, `AgentMessageEntry`, `ThoughtEntry`, `ToolCallEntry`, `ErrorEntry`, `UnknownEntry`. Add overrides for `TerminalEntry`, `PlanTranscriptEntry` and `CompactionEntry`.
- [ ] `ItemRow.entryContent(_:)` shows the override of the entry case when the environment has one, else the default view. The override gets the entry object, so it reads the model directly.
- [ ] `messageFooter` takes the message entry object.
- [ ] `ExpandedBlocksStore.defaultExpanded` takes a `TranscriptEntry`. `isExpanded(_:)` and `seed(_:)` take a `TranscriptEntry` and use `TranscriptEntry.ID.rowKey`. The tool call view of an entry uses the policy.

## Acceptance Criteria
- [ ] A host override for tool call entries shows in place of the default tool call view, and shows a status change of the model with no other step.
- [ ] A policy that expands the tool call entries with the status `.failed` opens such a row when the model sets that status.
- [ ] `ItemViewOverrides.swift`, `MessageItemView.swift` and `ExpandedBlocksStore.swift` do not name `Message`, `Reasoning`, `ToolCallRecord`, `ThreadError`, `UnknownRecord` or `ThreadItem`.

## Tests
- [ ] `Tests/AgentViewKitTests/Thread/RegistryResolutionTests.swift`: one override for each entry case resolves in `ItemRow(entry:)`.
- [ ] `Tests/AgentViewKitTests/Thread/SessionTranscriptViewHostedTests.swift`: a hosted override reads a status change from the scripted agent; the expanded policy opens a failed tool call entry.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.