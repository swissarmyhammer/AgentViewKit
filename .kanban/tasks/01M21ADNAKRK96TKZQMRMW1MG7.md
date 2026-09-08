---
depends_on:
- 01M21ABCXCQMMYMRK3QBM7CCJV
- 01M21ACSE9JBXMRD2FQQD4CYR6
position_column: todo
position_ordinal: 8b80
title: 'ACPThreadSource: fold ACP v2 SessionUpdate into ThreadChange (plan §3.3)'
---
## What
Create `Sources/AgentViewKitACP/ACPThreadSource.swift` and `Sources/AgentViewKitACP/SessionUpdateMapping.swift`, per the table in plan.md §3.3.

- `SessionUpdateMapping.changes(for update: SessionUpdate) -> [ThreadChange]`: a pure function over the generated types in `../FoundationModelsACP/Sources/FoundationModelsACP/Generated/`. Map every variant in the table: message chunks and whole-message upserts by `messageId`, `tool_call_update` and `tool_call_content_chunk` by `toolCallId`, terminals, plans by `planId`, `state_update` with `StopReason`, config options (both the flat and the grouped `SessionConfigSelectOptions` shape, which is a raw `JSONValue`), available commands, usage with cost, session info, and `unknown` to `.insert(.unknown)`.
- Translate ACP `PatchField` to the kit `PatchField` one to one. Keep `_meta` on every record.
- `ToolCallStatus.unknown("_lost")` maps to `.lost`.
- `ContentBlock` mapping: `text`, `image`, `audio`, `resource_link` with `icons`, `resource` (probe the raw `EmbeddedResourceResource` for `text` or `blob`), `unknown`.
- `ACPThreadSource` (`@MainActor`): takes an `AgentThread` and an `AsyncStream<SessionUpdate>` from `ClientSideConnection.updates(for:)`, applies changes, and routes message chunks to `thread.streaming[id]`. Also takes the `pendingPermissionRequests` and `pendingElicitations` from `ACPSessionState` and `SwiftUIACPClient` and mirrors them into the thread's pending lists.
- This target must not import FoundationModels.

## Acceptance Criteria
- [ ] Every `SessionUpdate` case in the generated enum has a mapping test, including `unknown`.
- [ ] A `tool_call_update` for an unseen id produces a patch that `AgentThread.apply` turns into a new record.
- [ ] Grouped select options decode to `ConfigOption.kind.select` with groups.
- [ ] A chunk stream of three `agent_message_chunk`s produces one `StreamingMessage` with the joined text.

## Tests
- [ ] `Tests/AgentViewKitACPTests/SessionUpdateMappingTests.swift`: one test per variant, with JSON fixtures decoded through the ACP SDK's decoder.
- [ ] `Tests/AgentViewKitACPTests/ACPThreadSourceTests.swift`: feed a scripted `AsyncStream` and assert the thread state.
- [ ] `swift test --filter AgentViewKitACPTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.