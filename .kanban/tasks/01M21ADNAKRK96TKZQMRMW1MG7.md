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
- actor: claude-code
  id: 01m2nk19e7wsg7n9z0y137jhh1
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 5 files and Package.swift
    - test: green — swift test, 59 ACP tests and 521 kit tests passed
    - commit: 7d4dd0e
    - review: findings — SessionUpdateMapping.swift:264, SessionUpdateMapping.swift:407, ACPThreadSourceTests.swift:12, ACPThreadSourceTests.swift:50, ACPThreadSourceTests.swift:56, SessionUpdateMappingTests.swift:11
  timestamp: 2026-09-16T17:08:07.239928+00:00
- actor: claude-code
  id: 01m2nk8eqrw102wah4tk696wwk
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — added `ISO8601Time` in the kit (the ACP mapping and `ElicitationDateCoding` use it), added one failable `wirePatch(_:failure:_:)` helper, moved `TestPermission` and `TestElicitation` to SessionUpdateFixtures.swift, named the test numbers
    - test: green — swift test, 59 ACP tests, 524 kit tests (3 new ISO8601TimeTests)
    - commit: 78c59aa
    - review: clean — 0 findings, all 6 prior items checked
  timestamp: 2026-09-16T17:12:02.040940+00:00
depends_on:
- 01M21ABCXCQMMYMRK3QBM7CCJV
- 01M21ACSE9JBXMRD2FQQD4CYR6
position_column: done
position_ordinal: '9780'
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

## Review Findings (2026-09-16 12:02)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 6 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKitACP/SessionUpdateMapping.swift:264` `duplication/duplication` — outputPatch and datePatch duplicate the same error-handling pattern: both switch on a PatchField with three cases (.unchanged, .cleared, .value), attempt a type-specific transformation in the .value case with a guard that returns .unchanged on failure with a logged error. The blocks differ only in their transformation logic (base64 decode vs iso8601 parse) and error messages, making them candidates for extraction into a parameterized helper. Extract a shared helper function (e.g., `wirePatchWithFallback<Wire, Kit>(_ field: PatchField<Wire>, errorMessage: String, transform: (Wire) -> Kit?) -> PatchField<Kit>`) that implements this pattern. Rewrite both outputPatch and datePatch to call it, passing their specific transformation logic and error message.
- [x] `Sources/AgentViewKitACP/SessionUpdateMapping.swift:407` `reuse/reuse` — iso8601Date() reimplements the same ISO 8601 date parsing with fractional-second fallback that already exists in ElicitationDateCoding.date(from:). Both functions parse ISO 8601 dates and fall back to parsing with fractional seconds support. Extract shared ISO 8601 date parsing to a public utility function (e.g., in a DateParsing struct or similar module) that both SessionUpdateMapping and ElicitationDateCoding can call, rather than maintaining two parallel implementations.
- [x] `Tests/AgentViewKitACPTests/ACPThreadSourceTests.swift:12` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitACPTests/ACPThreadSourceTests.swift:50` `reuse/reuse` — TestPermission struct is duplicated in SessionUpdateMappingTests.swift:37. Both test files define identical stubs that should be shared in a single location. Define TestPermission once in SessionUpdateFixtures.swift and remove the duplicate definition from ACPThreadSourceTests.swift, allowing both test files to reuse it.
- [x] `Tests/AgentViewKitACPTests/ACPThreadSourceTests.swift:56` `reuse/reuse` — TestElicitation struct is duplicated in SessionUpdateMappingTests.swift:43. Both test files define identical stubs that should be shared in a single location. Define TestElicitation once in SessionUpdateFixtures.swift and remove the duplicate definition from ACPThreadSourceTests.swift, allowing both test files to reuse it.
- [x] `Tests/AgentViewKitACPTests/SessionUpdateMappingTests.swift:11` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
