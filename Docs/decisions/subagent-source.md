# Subagent data source (R14)

Status: decided. Source: plan.md §9 C, §11 decision 15, and §14 R14.

This file records which data source supplies `SubagentRun` values for
`SubagentTreeView`. `Tests/AgentViewKitTests/Subagents/SubagentSourceTests.swift`
reads the `decision:` line and compares it with `SubagentSource.v1`. It also
makes sure that the table has one row for each `SubagentSource` case. Keep the
form of the `decision:` line and the table rows.

decision: `router`

## Survey

| candidate | carries parent id | carries state | carries child thread id | available today |
|---|---|---|---|---|
| `router` | yes: `agentSpawn.parentSessionId` and `agentSpawn.parentToolCallId` | yes, but not on the spawn event: the parent reports the spawning tool call with `toolStatus` and `runSettled`; the child reports `elicitationRequested` | yes: `TranscriptEvent.sessionId` of the child `session` event | yes: the API and the recording form. No production tool starts a subagent yet |
| `acpMeta` | no: no `_meta` key is defined | tool call status only | no | no: the ACP agent sets no `_meta` on a `tool_call_update` |
| `agUI` | yes: `parentToolCallId`, `parentMessageId`, `parentSubagentRunId` | yes: `SUBAGENT_STARTED`, `SUBAGENT_FINISHED` with `outcome`, `SUBAGENT_ERROR` | no: only `subagentRunId` | no: the kit has no AG-UI adapter. Reference shape only |

### `router`: FoundationModelsRouter

- `SessionEvent`
  (`../FoundationModelsRouter/Sources/FoundationModelsRouter/Session/SessionEvent.swift`)
  has no child-session case and no fork case. The spawn link is not on the
  live session event stream.
- `RoutedModel.makeSession(...agentSpawn:...)` takes a
  `SessionSidecar.AgentSpawn(parentSessionId:parentToolCallId:)`. The Router
  writes it to the `session.json` sidecar of the child session. It also
  writes it to the first `TranscriptEvent` of the child session, which has
  the kind `session`.
- `TranscriptEvent.agentSpawn` is public. A live recorder sink gets the
  `session` event when the first turn of the child session starts. It does
  not get the event when the session is made.
- `TranscriptEvent.parentId` is the fork link. It is `nil` for a spawned
  session. A fork has no `agentSpawn`. Thus the two kinds of child session
  stay different.
- `SessionSidecar` has no public stored property. Read the spawn link from
  `TranscriptEvent`, not from the sidecar.
- `agentSpawn.parentToolCallId` is the same id as the ACP `toolCallId` of the
  spawning tool call (`../FoundationModelsACPAgent/plan.md` §4.2).
- The limit: no tool in the FoundationModelsACPAgent roster starts a
  subagent yet. The Multitool agents capability is a later iteration. Only a
  test can make a spawned session today, through `makeSession(agentSpawn:)`.

### `acpMeta`: ACP `_meta` on `tool_call_update`

- `../FoundationModelsACPAgent/Sources/FoundationModelsACPAgent/Agent/EventProjection.swift`
  makes each `ToolCallUpdate` without `_meta`. The agent uses `_meta` only on
  the `session/resume` response, for the missing tool names.
- In the ACP agent, a subagent is not an ACP session. It gets no ACP
  `sessionId`, and it is not in `session/list`. To a client, it is a tool
  call only. Thus ACP has no child thread id to send.
- A `_meta` key for the spawn link would be a new contract between
  FoundationModelsACPAgent and AgentViewKit. No such key exists today.

### `agUI`: AG-UI subagent events

- `SUBAGENT_STARTED` has `subagentRunId`, `name`, `description`,
  `parentSubagentRunId`, `parentToolCallId`, and `parentMessageId`.
- `SUBAGENT_FINISHED` has `subagentRunId`, `result`, and `outcome`. The
  `outcome` can be success or suspended.
- `SUBAGENT_ERROR` has `subagentRunId`, `message`, and `code`.
- Source: https://docs.ag-ui.com/concepts/events.
- The kit takes the state set and the parent links as a reference shape
  (plan.md §2). It does not use the framework.

## Decision

v1 reads the Router. The Router is the only candidate that has a parent id and
a child thread id in a public, typed form today. `RouterThreadSource` reads
the `session` `TranscriptEvent` of each child session and the tool call events
of the parent session. The Router cannot start a subagent in production yet,
so the tree is empty until the Multitool agents capability arrives. The model
and the view do not change when it arrives.

`ACPThreadSource` supplies no subagent in v1. When the ACP agent adds a
`_meta` spawn key, a new decision adds `acpMeta`. That key must carry the child
thread id and the parent tool call id, with the AG-UI field names as the model.

## Field mapping onto `SubagentRun`

| `SubagentRun` field | Router value |
|---|---|
| `id` | `agentSpawn.parentToolCallId`. The id is known when the parent starts the tool call, before the child records an event. |
| `parentID` | The `id` of the run whose `threadID` is `agentSpawn.parentSessionId`. `nil` when the parent session is the thread root. |
| `title` | The `name` of the parent `toolCall` event, or the `op` of its `runSettled` `OperationEvent`. |
| `state` | See the state table below. |
| `startedAt` | The host clock when the parent `toolCall` or open `toolInvocation` event arrives (plan.md §3.2). |
| `endedAt` | The host clock when the terminal `toolStatus` or `runSettled` event arrives. |
| `threadID` | `TranscriptEvent.sessionId` of the child `session` event. `nil` until that event arrives. |

| Router signal | `SubagentRun.state` |
|---|---|
| `toolStatus` `running` on the parent | `working` |
| `elicitationRequested` whose `correlationID` is the run id | `needsInput` |
| `toolStatus` `completed`, or `runSettled` with a success outcome | `done` |
| `toolStatus` `failed`, or `runSettled` with a failure outcome | `failed` |
| No Router signal | `readyForReview` is not used by the Router source |
| A status that the adapter does not know | `unknown(String)` with the raw value |

## Adapter

- `SubagentMapping` (`Sources/AgentViewKitRouter/SubagentMapping.swift`)
  holds the pure mapping. `spawnChange(for:parentRunID:)` changes the
  `session` event into `ThreadChange.upsertSubagent`. `patch(for:now:)`
  changes a parent session event into a `SubagentPatch` for the run with the
  id of its tool call.
- `RouterThreadSource.apply(_: TranscriptEvent)` adds the run. The source
  applies a parent session patch only to a run that the thread has, because a
  session event does not tell whether its tool call started a subagent.
- A cancelled `runSettled` outcome gives `unknown("cancelled")`, because a
  cancelled run can still do work.
- The adapter tests are in
  `Tests/AgentViewKitRouterTests/Subagents/SubagentAdapterTests.swift`. The
  `AgentViewKitTests` target cannot import the Router (ImportBoundaryTests).

## Fixture

`Tests/Fixtures/subagent/router-agent-spawn.jsonl` holds the
`transcript.jsonl` lines of one spawned child session. Each line has the key
set of the Router `JSONLRecorder`. The line form comes from
`../FoundationModelsRouter/Tests/FoundationModelsRouterRealModelSupport/Fixtures/CompactionRecording`.
The first line is the `session` event with `agentSpawn`. No production tool
starts a subagent, so the ids and the text are sample values.
