# Checkpoint sources (R13)

Status: decided. Source: plan.md §9 E and §14 R13.

This file records what each data source can restore from a checkpoint, and
the v1 fields of the `Checkpoint` model. `CheckpointView` uses these fields.
`Tests/AgentViewKitTests/Checkpoints/CheckpointCapabilitiesTests.swift` parses
the table below. It compares each row with the `CheckpointCapabilities` value
of the same source. Keep the header and the form of the rows. Use `yes` or
`no` in the two restore columns. Put the source, the granularity, and the wire
call in backticks.

## Capabilities

| source | restores code | restores conversation | granularity | wire call |
|---|---|---|---|---|
| `router` | no | yes | `turn` | `RoutedSession.fork(workingDirectory:)` |
| `acp` | no | no | `unavailable` | `session/fork` |

Granularity values:

- `turn`: one restore point for each completed turn.
- `unavailable`: the kit cannot use the source to restore anything in v1.

## Survey

### `router`: FoundationModelsRouter

- `LanguageModelSessionBackend.makeFork()`
  (`../FoundationModelsRouter/Sources/FoundationModelsRouter/Session/LanguageModelSessionBackend.swift`)
  makes a new backend from the full transcript of the session at the time of
  the call. The new backend then diverges and shares no state. The call has
  no parameter for an earlier point.
- `RoutedSession.fork(workingDirectory:)` is the public call. It forks a
  child session with `parentId` set to the parent id. It refuses a fork from
  a tool call of the turn of the same session
  (`SessionReentryError.forkDuringSameSessionTurn`). Thus a fork occurs only
  between turns. The granularity is `turn`: the kit forks after each
  completed turn and keeps the child session as the restore point.
- A fork holds one slot of the Router `maxConcurrentForks` limit until the
  child session is deinitialized. A thread with many turns must not keep a
  live fork for each turn. The source keeps the child session id, then closes
  and releases the child. To restore, it calls
  `RoutedModel.restoreSession(id:recordingRoot:instructions:tools:)` with the
  child id. That call rebuilds the child from its recorded transcript. The
  task that adds the Router checkpoint source must prove this path with a
  test on a nested fork.
- The fork copies the conversation only. The `workingDirectory` argument is a
  path, not a copy of the files. `ForkableTool` forks the state of a tool,
  not the files that the tool changed. Thus the Router cannot restore code.
- The transcript rewrite on compaction
  (`RoutedSessionActorCompaction.swift`) calls
  `backend.replacingTranscript(_:)` with the folded transcript and records a
  `CompactionSegment` checkpoint. A later restore reads the newest
  `CompactionSegment` and the entries after it. This checkpoint is a context
  fold, not a restore point: the Router never goes back to the entries before
  the fold. A fork after a fold copies the folded window.
- `replacingTranscript(_:)` is a requirement of the public backend protocol,
  but no public `RoutedSession` call exposes it. The recording has one event
  for each transcript entry, but no public call restores a session at an
  entry. Thus the Router has no `entry` granularity.

### `acp`: ACP `session/fork`

- `../FoundationModelsACP/Sources/FoundationModelsACP/Generated/MethodTable.generated.swift`
  lists `session/fork` as an unstable agent method. The vendored manifest
  `acp-v2.meta.unstable.json` routes it by name and side only. The package
  has no typed request or response for it.
- `../FoundationModelsACP/plan.md` says that nothing may be built on the
  unstable methods. `../FoundationModelsACPAgent/plan.md` §7.5 says that the
  agent does not build `session/fork` against the unstable schema.
- The upstream unstable request carries the session id, the working
  directory, and the MCP servers. It has no message id, so it forks at the
  newest point of the session, as the Router does. It copies the
  conversation into a new ACP session. It does not copy files.
- The stable v2 surface (`session/new`, `session/list`, `session/resume`,
  `session/close`, `session/prompt`, `session/cancel`) has no rewind method.
  `session/resume` with `replayFrom` replays updates. It does not remove
  turns.
- Thus v1 restores nothing from an ACP agent. When `session/fork` becomes
  stable, a new decision changes the `acp` row to restore the conversation
  at `turn` granularity.

## Decision

The v1 `Checkpoint` model has these fields:

| field | type | value |
|---|---|---|
| `id` | `Identifier<Checkpoint>` | The id of the restore point. For the Router, the id of the child session that the fork made. |
| `turnIndex` | `Int` | The zero-based index of the completed turn that the restore point follows. |
| `createdAt` | `Date` | The host clock when the source made the restore point (plan.md §3.2). |
| `label` | `String` | A short text for the slider stop, such as the start of the user prompt of the turn. |
| `canRestoreCode` | `Bool` | `CheckpointCapabilities.restoresCode` of the source. |
| `canRestoreConversation` | `Bool` | `CheckpointCapabilities.restoresConversation` of the source. |

Rules:

- A source sets the two flags of each `Checkpoint` from the
  `CheckpointCapabilities` value of that source. It does not set them per
  checkpoint.
- No v1 source restores code, so `canRestoreCode` is `false` for each v1
  checkpoint. `CheckpointView` shows the restore code action as disabled. A
  host that keeps its own file snapshots, for example with git, can supply a
  source that sets the flag.
- A source with `unavailable` granularity supplies no checkpoints. The ACP
  thread shows no checkpoint slider in v1.
- A conversation restore to turn `n` removes the turns after `n` from the
  thread. `CheckpointView` asks for a confirmation first.
