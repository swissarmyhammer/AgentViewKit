---
depends_on:
- 01M21A961W19N9FWQ92FETNVP6
- 01M21A9KJGPPJE0X01JE0B9V33
- 01M21BYFK7KVCKXYXJFCJW7FSM
- 01M21BD0YVS2J4MD6VXDM317W6
position_column: todo
position_ordinal: '8580'
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
- [ ] A patch to an existing tool call changes only that record and increments its `revision` by one.
- [ ] A patch to an unknown id inserts a new record.
- [ ] `PatchField.cleared` sets the target to nil or empty; `.unchanged` leaves it.
- [ ] `remove` and `clear` keep `index` consistent.
- [ ] `setUsage` does not change any record revision.
- [ ] `appendStreaming` on a new id creates the `StreamingMessage`; `closeStreaming` removes it.

## Tests
- [ ] `Tests/AgentViewKitTests/Model/PatchFieldTests.swift`: fold table for the nine combinations.
- [ ] `Tests/AgentViewKitTests/Model/AgentThreadApplyTests.swift`: one test per `ThreadChange` case, plus the first-sight-creates rule and the revision rule.
- [ ] `Tests/AgentViewKitTests/Model/AgentThreadObservationTests.swift`: with `withObservationTracking`, a usage update does not fire an observer that read only `items`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.