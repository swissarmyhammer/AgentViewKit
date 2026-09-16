---
comments:
- actor: claude-code
  id: 01m2njq2q7fqkd3wem3d9d5hdw
  text: |-
    ### Design decisions (implement)
    - The kit id of a mirrored permission request or elicitation is `UUID.uuidString` of the local id from `PendingPermissionRequest` or `PendingElicitation`. The ACP verbs task (^agckbq) must map the kit id back to that UUID.
    - `ACPThreadSource.init(thread:updates:agentName:)`. ACP elicitations have no server name, so `agentName` is the `server` of each kit `ElicitationRequest`.
    - `mirrorPendingRequests(of:client:sessionId:)` uses `Observations` and copies only the elicitations of the session (`client.pendingElicitations(for:)`). Request-scoped elicitations are not for a thread.
    - An elicitation with an unknown mode, or a URL that is not valid, is not added (the kit `Mode` has only form and url). The mapping logs it.
    - When a permission request has a `tool_call` subject, the source applies the tool call update of the subject before it adds the request.
    - Streams: a text chunk with no annotations goes to `thread.streaming`. The source closes a stream on a whole-message update for the same id, on a chunk for another id, on `state_update`, and at the end of the update stream. The content that the record had before the stream goes back before the streamed text.
    - Thought content that is not text goes to an unknown record with the id `<messageId>#content`, after the reasoning.
    - A diff shows as `ToolContent.diff(patch:)` only with a `git_patch` text. Other diffs, and image, audio, or resource data that the kit cannot read, stay as unknown content with the JSON.
    - Config options go through their JSON form into the kit `ConfigOption` decoder (flat and grouped shapes). An option that does not decode keeps its JSON in `.unknown(type:raw:)`.
    - A chunk `_meta` (message, thought, tool call, terminal) is written to the record only when the chunk has one.
    - `PendingPermissionRequestValue` and `PendingElicitationValue` protocols exist because the client types have no public initializer. The client types conform to them.
  timestamp: 2026-09-16T17:02:32.679816+00:00
depends_on:
- 01M21ABCXCQMMYMRK3QBM7CCJV
- 01M21ACSE9JBXMRD2FQQD4CYR6
position_column: doing
position_ordinal: '8180'
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
- [x] Every `SessionUpdate` case in the generated enum has a mapping test, including `unknown`.
- [x] A `tool_call_update` for an unseen id produces a patch that `AgentThread.apply` turns into a new record.
- [x] Grouped select options decode to `ConfigOption.kind.select` with groups.
- [x] A chunk stream of three `agent_message_chunk`s produces one `StreamingMessage` with the joined text.

## Tests
- [x] `Tests/AgentViewKitACPTests/SessionUpdateMappingTests.swift`: one test per variant, with JSON fixtures decoded through the ACP SDK's decoder.
- [x] `Tests/AgentViewKitACPTests/ACPThreadSourceTests.swift`: feed a scripted `AsyncStream` and assert the thread state.
- [x] `swift test --filter AgentViewKitACPTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.