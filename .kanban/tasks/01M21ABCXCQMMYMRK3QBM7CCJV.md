---
comments:
- actor: claude-code
  id: 01m2ngcqs5bbeahxk7pt6yxt4r
  text: |-
    Research and design decisions (no user question; these follow plan.md §3.2 and §8):
    - All dependencies are done. The records (ThreadRecord, ThreadItem), TerminalRecord, the request types, ThreadInfo, ThreadState, Plan, ConfigOption, SlashCommand, and ContextUsage exist in Sources/AgentViewKit/Model.
    - The package sets defaultIsolation(MainActor). So PatchField, ItemPatch, TerminalPatch, and ThreadInfoPatch are `nonisolated` value types. The code that changes records is in `@MainActor` extensions.
    - StreamingMessage shell goes in Sources/AgentViewKit/Streaming/StreamingMessage.swift, because task ^cyr6 (StreamingMessage) names that path. The shell has `id`, `text`, and `append(_:)`.
    - ItemPatch has one case for each ThreadItem case (system, userMessage, assistantMessage, reasoning, toolCall, structured, compaction, error, unknown). A content chunk has its own case: userMessageChunk(ContentBlock), assistantMessageChunk(ContentBlock), reasoningChunk(String) (adds one segment), toolCallChunk(ToolContent). Each chunk appends to the content.
    - `.cleared` on a field that is not optional sets the empty value: "" or [] for a collection, `.other` for ToolKind, `.pending` for ToolCallStatus, `.null` for a JSONValue payload, `.unknown(message: "")` for ThreadError.Kind.
    - A patch whose kind is different from the kind of the existing item replaces that item at the same position.
    - `replace` and a kind change give the new record the revision of the old record plus one, so that a row that compares id and revision sees the change.
    - `insert(item, after: nil)` and `insert` after an unknown id append at the end. An `insert` of an id that exists replaces that item.
    - `clear` empties items, index, plans, terminals, the three pending lists, and streaming. It keeps state, configOptions, availableCommands, usage, and info, because these belong to the session.
    - TerminalPatch has PatchField members for command, cwd, exitStatus, output, and meta, plus `outputChunk: Data` that appends after the output field.
    - AgentThread has a public `item(id:)` lookup that uses the index. The tests use it to check that the index stays correct.
  timestamp: 2026-09-16T16:21:56.645994+00:00
- actor: claude-code
  id: 01m2ngvt81c9wg0x4sfb23v8m5
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 8 files: Sources/AgentViewKit/Model/{AgentThread,ItemPatch,PatchField,ThreadChange}.swift, Sources/AgentViewKit/Streaming/StreamingMessage.swift, Tests/AgentViewKitTests/Model/{PatchFieldTests,AgentThreadApplyTests,AgentThreadObservationTests}.swift
    - test: green — swift test: 458 tests in 37 suites, 20 tests in 3 suites, 3 more suites of 1 test each; all pass; no warnings except the accepted mlx-swift build warnings
    - commit: 606ea6f
    - review: clean — review sha HEAD~1..HEAD, 0 findings; task moved to done
    - note for ^qd4cyr6 (StreamingMessage): the shell is at Sources/AgentViewKit/Streaming/StreamingMessage.swift with `id`, `text`, and `append(_:)`. AgentThread uses `append(_:)` for `appendStreaming`. If that task changes the API, it must update AgentThread.appendStreaming and AgentThreadApplyTests.
  timestamp: 2026-09-16T16:30:10.689872+00:00
depends_on:
- 01M21A961W19N9FWQ92FETNVP6
- 01M21A9KJGPPJE0X01JE0B9V33
- 01M21BYFK7KVCKXYXJFCJW7FSM
- 01M21BD0YVS2J4MD6VXDM317W6
position_column: done
position_ordinal: '9380'
title: AgentThread and ThreadChange with PatchField upsert semantics (plan §3.2)
---
## What
Create `Sources/AgentViewKit/Model/AgentThread.swift`, `ThreadChange.swift`, `PatchField.swift`, and the shell of `StreamingMessage.swift`, per plan.md §3.2.

- `PatchField<T>`: `unchanged`, `cleared`, `value(T)`, with `folded(onto:)`. Same rule as the ACP `PatchField` but defined locally so the core has no ACP import.
- `ThreadChange`: `insert(ThreadItem, after: String?)`, `patch(id: String, ItemPatch)`, `replace(ThreadItem)`, `remove(id: String)`, `clear`, `setState(ThreadState)`, `setPlan(Plan)`, `removePlan(PlanID)`, `upsertTerminal(TerminalPatch)`, `setConfigOptions([ConfigOption])`, `setAvailableCommands([SlashCommand])`, `setUsage(ContextUsage?)`, `patchInfo(ThreadInfoPatch)`, `addPermission(PermissionRequest)`, `resolvePermission(id)`, `addElicitation`, `resolveElicitation(id)`, `addAuthorization`, `resolveAuthorization(id)`, `appendStreaming(id: String, text: String)`, `closeStreaming(id: String)`.
- `ItemPatch`: one case per record kind with `PatchField` members, for example `.message(content: PatchField<[ContentBlock]>, meta: PatchField<JSONValue>)` and `.toolCall(title:, kind:, status:, content:, locations:, rawInput:, rawOutput:, meta:)`. A content chunk appends to `content`.
- `StreamingMessage` shell: `@MainActor @Observable final class` with `id` and `text`. The streaming task adds the balancer and the paragraph split on top of this shell.
- `AgentThread` (`@MainActor @Observable final class`) with the properties in §3.2 as `private(set)`: `items`, `state`, `plans`, `terminals`, `configOptions`, `availableCommands`, `usage`, `info`, `pendingPermissions`, `pendingElicitations`, `pendingAuthorizations`, and `streaming: [String: StreamingMessage]`. Plus `apply(_ change: ThreadChange)`. A patch to an existing record mutates it in place and calls `bump()`. A patch to an unknown id inserts a new record at the end (first sight creates). `clear` empties `items` and the side tables.
- `items` stays an array of `ThreadItem`. Keep an `index: [String: Int]` for O(1) patch.

## Acceptance Criteria
- [x] A patch to an existing tool call changes only that record and increments its `revision` by one.
- [x] A patch to an unknown id inserts a new record.
- [x] `PatchField.cleared` sets the target to nil or empty; `.unchanged` leaves it.
- [x] `remove` and `clear` keep `index` consistent.
- [x] `setUsage` does not change any record revision.
- [x] `appendStreaming` on a new id creates the `StreamingMessage`; `closeStreaming` removes it.

## Tests
- [x] `Tests/AgentViewKitTests/Model/PatchFieldTests.swift`: fold table for the nine combinations.
- [x] `Tests/AgentViewKitTests/Model/AgentThreadApplyTests.swift`: one test per `ThreadChange` case, plus the first-sight-creates rule and the revision rule.
- [x] `Tests/AgentViewKitTests/Model/AgentThreadObservationTests.swift`: with `withObservationTracking`, a usage update does not fire an observer that read only `items`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.