# Update plan: AgentViewKit becomes the SwiftUI kit for an ACP client

Date: 2026-10-02. Checked against FoundationModelsACP `e14d853` and
FoundationModelsACPClient `108e2d6` on the same day.

This plan replaces the earlier version of this file. The earlier version
planned to adopt more FoundationModelsRouter API. That direction was wrong.

References in this plan use type and function names, not line numbers.

## 1. The new scope

AgentViewKit is the SwiftUI view kit to make the UI of an ACP client. It shows
the client-side ACP objects and types. It does not keep its own session state.
The views bind to the observable models of FoundationModelsACPClient:
`ConnectionModel` and its `SessionModel` objects (section 4).

The direct dependencies are:

- **FoundationModelsACPClient**. It will hold `ConnectionModel` and
  `SessionModel`, and it brings the ACP v2 types of FoundationModelsACP. The
  kit also lists the `FoundationModelsACP` product, because
  `ClientSideConnection`, `InMemoryTransport` and the schema types are in that
  package.
- **EditorKit**.

These are removed as direct dependencies: FoundationModels,
FoundationModelsRouter and FoundationModelsExtras. The
`AgentViewKitFoundationModels` and `AgentViewKitRouter` targets are removed.
Note: FoundationModelsExtras stays in the package graph, because the library
target of FoundationModelsACPClient depends on it.

A FoundationModels agent or a Router agent reaches the kit as an ACP agent:

```
LanguageModelSession / Router  ->  FoundationModelsACPAgent  ->  ACP  ->  ACP client  ->  AgentViewKit
```

The agent can run in a subprocess, or in the same process through
`InMemoryTransport.pair()` (section 8).

## 2. Why: the error in the earlier plan

1. The first plan (June 2026, commit `82547cd`) showed a FoundationModels
   `Transcript`. A `Transcript` has no elicitation, permission request, plan,
   terminal, config option, slash command, authorization, session state or
   stop reason. ACP has all of these.
2. The plan rewrite of 2026-09-08 (commit `5200485`, `plan-review.md`) found
   these gaps. It filled them with Router types: `SessionEvent`,
   `SessionProjection`, `OperationEvent`, `PersistableStructuredSegment` and
   `RouterSegmentSchemaNames`. It made `AgentViewKitRouter` a product
   (`plan.md` §11 decision 1). Research item R5 (the runtime contract) was to
   examine this decision, but it did not get a task.
3. Some premises were not correct:
   - `RouterSegmentSchemaNames` and `PersistableStructuredSegment` are
     internal to the Router. There was nothing public to agree with.
   - The Router has a `transcript` property. The Router target did not use it
     correctly. A seeded Router thread showed no user messages.
4. Thus each Router update breaks the kit. The Router update of 2026-10-01
   (251 commits) removed the `turn` API and broke `AgentViewKitRouter`.

ACP is the correct layer. It defines all of the agent-grade surfaces, and the
ACP packages hold them as client-side state.

## 3. Decisions

| # | Decision | Status |
|---|---|---|
| D1 | The direct dependencies are FoundationModelsACPClient (with FoundationModelsACP) and EditorKit. | Decided by the owner. |
| D2 | Keep Textual (Markdown) and swiftui-math (math) as UI dependencies. | **Decided by the owner, 2026-10-02.** |
| D3 | The views bind to `ConnectionModel` and `SessionModel` (working names) in FoundationModelsACPClient. The kit removes its own session state: `AgentThread`, `ThreadItem`, `ThreadChange`, the records, `ACPThreadSource`, `SessionUpdateMapping` and `ACPSessionList`. | Agreed, 2026-10-02. **The client models are not built yet.** |
| D4 | One library product: merge `AgentViewKit` and `AgentViewKitACP` into one target. | **Decided by the owner, 2026-10-02.** |
| D5 | Remove branches, checkpoints, subagents and compaction markers now. Add them again when ACP gives a producer. | **Decided by the owner, 2026-10-02.** |
| D6 | Do not send trace context (`_meta.traceparent`) now. | **Decided by the owner, 2026-10-02.** |
| D7 | The pending permission and elicitation requests of a session are in `SessionModel` (`pendingPermissions`, `pendingElicitations`, with reply methods). `ACPSessionState` goes away. The kit binds to the client models only, not to `SwiftUIACPClient` or `ACPSessionState`. | **Decided by the owner, 2026-10-02.** |
| D8 | `ConnectionModel` is the root observable. It holds many `SessionModel` objects. Both are in FoundationModelsACPClient. | **Decided by the owner, 2026-10-02.** |

## 4. The observable models (D3, D7, D8)

### 4.1 Status

| Part | Package | Status on 2026-10-02 |
|---|---|---|
| alpha.7 schema, wire types | FoundationModelsACP | **Built**, `main` at `e14d853`. |
| `SessionMergeEngine` (`Sendable`), `SessionEntry` with `SessionEntry.ID` | FoundationModelsACP | **Built.** |
| Update buffer, `subscribe(to:)` with `hasMissedUpdates` | FoundationModelsACP | **Built.** |
| `PendingPromptCorrelator` (the message ID link) | FoundationModelsACP | **Built.** |
| `subscribeToOutgoingRequests()`, `inFlightMethod(for:)` (for request-scoped elicitations) | FoundationModelsACP | **Built.** |
| `ConnectionModel`, `SessionModel`, `TranscriptEntry` | FoundationModelsACPClient | **Complete** (2026-10-04, local commit `a65af8a`, not pushed yet): connect, initialize, capability flags, auth, new session, resume session, close, session list, delete session, request-scoped elicitations. |
| Removal of `ACPSessionState`, the old client `SessionEntry` and `SwiftUIACPClient` | FoundationModelsACPClient | **Done** in the same commit `a65af8a`. |
| Removal of `ClientSideConnection.updates(for:)` and `SessionUpdateAggregator` | FoundationModelsACP | **Done**, `main` at `27419fa` (2026-10-04). The replacement is `subscribe(to:)`. Its `updates` stream gives `SessionStreamEvent`: `.update(SessionUpdate)` and `.requestFinished(id:method:outcome:)`. With the client models, the kit does not need it. |

**Before the kit binds to the client models, read their real API in
FoundationModelsACPClient (or ask its session).** The names in sections 4.2
and 4.3 are from the design, and they can be different in the code.

**The migration is now required, not optional.** The kit follows
`branch: "main"` of both packages. When the commits above are pushed, the
next package resolve breaks the build of these files:
`ACPDemoSession`, `ACPQuickStart.swift`, `ACPThreadSource`,
`ACPThreadActions`, and the tests `ACPThreadActionsTests`,
`ProtocolVersionTests`, `ACPThreadSourceTests` and `ACPSessionListTests`.
`Package.resolved` keeps the old revisions until somebody runs a package
update, so the build is safe until then. Do not run `swift package update`
before the migration (step 7) is ready.

Contacts for questions:

| Subject | Session |
|---|---|
| The model API (`ConnectionModel`, `SessionModel`, `TranscriptEntry`) | FoundationModelsACPClient (`foundationmodelsacpclient-ae`) |
| Wire types, the update buffer, the merge engine | FoundationModelsACP (`foundationmodelsacp-c7`) |

### 4.2 What the session model gives (design)

- `SessionModel` is a `@MainActor @Observable` class. It wraps
  `SessionMergeEngine` of FoundationModelsACP. SwiftUI uses it directly.
- **Fine granularity.** Each transcript entry is its own `@Observable`
  object (`TranscriptEntry`): user message, agent message, thought, tool call,
  terminal, plan, unknown, local pending message, local error. A streamed
  chunk changes only its own entry. Thus only that row draws again.
- **Row identity.** Each `TranscriptEntry` has its own stable `id`. The `id`
  does not change when a local pending message gets its `messageId`. Local and
  error entries have no `SessionEntry.ID`. **The views use `TranscriptEntry.id`
  as the row identity**, not `SessionEntry.ID` and not `MessageId`. Note: a
  thought and an agent message with the same `MessageId` are two entries.
- **Last-value state:** `availableCommands`, `configOptions`, `usage`,
  `agentState` and `sessionInfo` (title and `updatedAt`, folded as a patch).
  - `agentState` is `StateUpdate?`: `.running`, `.idle(IdleStateUpdate)` with
    `stopReason: StopReason?`, `.requiresAction`, and
    `.unknown(String, JSONValue)`.
- **Pending requests (D7):** `pendingPermissions` and `pendingElicitations`
  for the session, with reply methods: select a permission option; accept,
  decline or cancel an elicitation.
- **Prompt helper.** It adds a local pending user message before it sends
  `session/prompt`. `PendingPromptCorrelator` links the entry to the
  `messageId` of the `PromptResponse` or of the echoed `user_message`, in
  each order. If the request fails, it adds a local error entry with the
  JSON-RPC code, message and data.

### 4.3 What the connection model gives (design)

`ConnectionModel` is a `@MainActor @Observable` class. It holds:

- The session factory: `newSession(_ request: NewSessionRequest) async throws
  -> SessionModel` and `resumeSession(_ request: ResumeSessionRequest)`. They
  take the generated request types, so `cwd`, `additionalDirectories`,
  `mcpServers`, `_meta` and future fields pass through unchanged. They
  subscribe to the update stream at the correct time, so no update is lost.
  It keeps the open `SessionModel` objects by session ID.
- The session list: `sessions: [SessionInfo]`, `refreshSessions(cwd:)`,
  `loadMoreSessions()` and `hasMoreSessions`. A refresh starts again at the
  first page. A `session_info_update` of an open session also changes its
  item in `sessions`.
- `close(_ session: SessionModel)`: sends `session/close`, removes the model
  from the open set, and stops its stream. The model stays readable, with
  `isClosed = true`. Note: `ClientSideConnection.closeSession` clears the
  update buffer, but it does not end the subscriptions. Thus `ConnectionModel`
  must stop the stream itself.
- `deleteSession(_ id: SessionId)`: closes the session first if it is open,
  then removes it from `sessions`.
- `pendingElicitations` for request-scoped elicitations (requests that the
  client sent outside a session, for example `auth/login`). Each item keeps
  its `requestId`. When the client request completes or fails, its
  elicitations are removed.
- The `initialize` result, the agent capabilities, and the auth state.
- `state: ConnectionState`: `.connecting`, `.connected`, `.disconnected`,
  `.failed(Error)`. On `.disconnected` or `.failed`, each open `SessionModel`
  is closed, and its pending requests are cancelled.
- Capability flags from the `initialize` result, for example
  `canListSessions`, `canDeleteSessions`, `canResumeSessions`. A call to a
  method that the agent does not support throws a clear error and sends no
  request.

### 4.4 Rules that are built in FoundationModelsACP

| Rule | Detail |
|---|---|
| Unknown updates stay visible | An unknown `session/update` becomes an unknown entry with the type string and the raw JSON. |
| Extension stop reasons | `StopReason.unknown(String)` keeps the wire value, for example `_truncated`. |
| `_meta` | Each entry keeps its `_meta`, folded with the same patch rules as the wire field. |
| Commands "not reported" | `availableCommands` is nil until a list is reported. A new or resume response with no list, **or with an empty list**, leaves it nil. Only an `available_commands_update` with `[]` sets it to `[]` ("no commands"). |
| Plans | A plan entry with a `planId` is replaced by `planId` and keeps the position where it first appeared. A plan update with no `planId` always adds a new entry. |
| Terminals | `AccumulatedTerminal` keeps the decoded bytes as `output: Data`. A chunk appends bytes. An `output` snapshot replaces them. The computed `text` (UTF-8, with replacement of bytes that are not valid) is planned in the client `TranscriptEntry`, not in FoundationModelsACP. |
| Update buffer | `ClientSideConnection.subscribe(to:)` returns `SessionUpdateSubscription { updates, hasMissedUpdates }`. The router buffers updates for a session that has no subscriber: at most 1024 updates for each session and at most 64 sessions (`bufferLimits` can change them). When a buffer is full, the router discards it and the new update, marks the session as overflowed, and writes a warning. The 65th session evicts the oldest. The buffer is cleared on `session/close` and on connection close. |
| Resume replay | Subscribe before `session/resume`. Then the replay goes directly to the subscriber and does not use the buffer. |
| `updates(for:)` | It no longer drops updates, but it is **deprecated**. Use `subscribe(to:)`, or the `ConnectionModel` factory. |

### 4.5 What this removes from the kit

| Kit part | Replaced by |
|---|---|
| `AgentThread`, `ThreadItem`, `ThreadChange`, `ItemPatch`, `ThreadRecord` and the record classes | `SessionModel` and its `TranscriptEntry` objects |
| `ACPThreadSource` (397 lines) | `ConnectionModel.newSession(_:)` and `resumeSession(_:)` |
| `SessionUpdateMapping` (736 lines), with its copy of the `PatchField` fold, the terminal decode and the JSON round trips | `SessionMergeEngine`, through `SessionModel` |
| `ACPSessionList` (the kit already pages the list) | `ConnectionModel.sessions`, `refreshSessions(cwd:)`, `loadMoreSessions()` |
| The kit `StopReason`, `ThreadState`, `ToolKind`, `ToolCallStatus`, `PlanEntry`, `SlashCommand`, `ConfigOption` (410 lines), `AuthMethod` (276 lines), `ContextUsage`, `SessionSummary`, `JSONValue`, `PatchField` | The ACP types |
| All use of `ACPSessionState` and of the `SwiftUIACPClient` session state | `SessionModel` and `ConnectionModel` (D7) |
| The mirror code of the pending requests in `ACPThreadSource`, and the reply code in `ACPThreadActions` | `pendingPermissions`, `pendingElicitations` and their reply methods |

This also fixes the double fold. At present, every update is folded two
times: by `ACPThreadSource` and by `SwiftUIACPClient.sessionUpdate` into
`ACPSessionState`.

### 4.6 What the kit keeps

The kit keeps view-side work only:

1. **The streaming tail.** The paragraph split and the Markdown balancer
   (`StreamingMessage`, `ParagraphSplitter`, `StreamingMarkdownBalancer`)
   operate on the text of one entry. They become view helpers. They do not
   keep session state.
2. **The views and the registries.** The tool call views, the diff view, the
   terminal view, the plan view, the composer, the banners.
3. **The permission and elicitation views.** They bind to the pending
   requests of `SessionModel` and of `ConnectionModel`, and they call the reply
   methods. The kit keeps no copy of the pending requests.

### 4.7 View tasks from the models

- **Row identity:** `ForEach` over the transcript uses `TranscriptEntry.id`.
- **Composer:** use the prompt helper of `SessionModel`, so that the pending
  user message shows at once.
- **Error rows** come from the model. The kit keeps no error list. For a
  failed request that the kit did not send through the model, call the public
  method of the model that adds an error entry.
- **Agent state:** show `.running`, `.idle` with its stop reason, and
  `.requiresAction`. Show a general state for `.unknown(String, JSONValue)`.
- **Resume:** show a marker when `isReplaying` is true. Show a "history can
  be partial" note from `history`.
- **Missed updates:** when `hasMissedUpdates` is true, show a banner with a
  "Reload" action. The action resumes the session again with
  `replayFrom: .start`. The client model clears `hasMissedUpdates` only after
  a successful `.start` replay.
- **Terminal view:** show the computed `text` of the terminal entry.
- **Plan view:** read the plan entry at its position in the transcript.
- **Tool call view:** show a linked elicitation next to its tool call (a
  session elicitation with a `toolCallId`).
- **Session picker:** bind to `ConnectionModel.sessions`, with "load more"
  when `hasMoreSessions` is true.
- **Capabilities:** hide each action when its capability flag is false.
- **Closed thread:** show a closed state when `isClosed` is true.
- **Connection banner:** show `ConnectionModel.state`.

## 5. Schema bump: alpha.3 to alpha.7

FoundationModelsACP moved from `schema-v2.0.0-alpha.3` (`acf7700`) to
`schema-v2.0.0-alpha.7` (`e14d853`). There are four structural changes in the
schema, and one change of meaning:

| Change | Kit task |
|---|---|
| `PromptResponse.messageId` is **required**. It is the ID of the user message that the agent added. The agent echoes that message in a `user_message` update with the same ID. The echo can come before or after the response. | Show a pending user message (section 4.7). Test the two orders. **Also see section 7, item 3: the scripted demo agents must send `messageId`.** |
| `ToolCallUpdate.name`: optional, with patch rules. It is the program name of the tool. `title` stays the label for people. | Use `name` to select the tool view in the registry. Show `title` as the label. |
| `NewSessionResponse.availableCommands` and `ResumeSessionResponse.availableCommands`: optional. | The model seeds the command list from the response (section 4.4, "Commands"). |
| `ResumeSessionRequest.replayFrom` now means "retained history". Omitted means no replay. `{type: "start"}` means all retained history. | Do not tell the user that the history is complete after a resume. |

These features already exist in alpha.3. They are not new in alpha.7:
`ElicitationRequestScope` with `requestId`, and the `session/list` pages
(`cursor`, `nextCursor`) with the `cwd` filter.

Update `Docs/decisions/acp-version.md` for alpha.7.

## 6. Remove the vocabulary that has no ACP source

| Remove | Reason |
|---|---|
| `.system` / `SystemPrompt` and `SystemPromptView` | Only `TranscriptMapping` makes it. |
| `.structured` / `StructuredRecord`, `Catalog/*`, `catalog.md`, `StructuredItemView`, the structured registry | Only the Router and FoundationModels sources make it. |
| `ThreadChange.upsertSubagent`, `SubagentSource` (D5) | Only the Router makes it. |
| `setCheckpoints`, `CheckpointCapabilities` (D5) | No source makes it. |
| `.compact` / `CompactionMarker` (D5) | ACP has no history-invalidation signal. |
| `addAuthorization`, `AuthorizationPayload.elicitationId` | No source makes it. Authorization is the Router model. |
| `removePlan` | No source makes it. |
| `ContextUsage.init(used:fill:)`, `Input`, `Output`, `Quota` | Only the Router and FoundationModels sources make them. |
| `ThreadError.Kind` cases `contextSizeExceeded`, `rateLimited`, `guardrailViolation`, `timeout` | Only `SessionErrorMapping` makes them. |
| `addBranch` / `selectBranch` and `BranchNavigator` (D5) | Only the FoundationModels source uses them. |

Most of these are parts of `AgentThread`. Thus most of this work occurs when
the kit model goes (section 4.5). Do the removal first, so that the change to
the client models is smaller.

## 7. Package changes

1. `Package.swift`:
   - Remove the FoundationModelsRouter and FoundationModelsExtras packages as
     direct dependencies.
   - Remove the targets `AgentViewKitFoundationModels`, `AgentViewKitRouter`
     and their test targets.
   - Merge `AgentViewKitACP` into `AgentViewKit` (D4).
   - Remove the FoundationModels files from `DemoSupport`:
     `FoundationModelsDemoSession.swift`, `FakeLanguageModel.swift`,
     `DemoTools.swift`.
   - Keep Textual and swiftui-math (D2).
2. **Benchmarks, demo app and README (do these with item 1, or the CI gates
   fail):**
   - `Benchmarks/Package.swift` uses the `AgentViewKitFoundationModels`
     product, and `ObservationBenchmarks` imports it and FoundationModels.
     Remove these benchmarks, or write them again against the client models
     when the models exist.
   - `Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb`: remove the
     removed products from `PACKAGE_PRODUCTS`.
   - Remove `FoundationModelsTabView` from the demo app, and its end-to-end
     test.
   - `README.md`: remove the FoundationModels launch flags and the Router and
     FoundationModels quick starts.
   - README snippets: remove `RouterQuickStart.swift` and
     `FoundationModelsQuickStart.swift`.
3. **Pins. Move them two times.** Each move changes three `Package.resolved`
   files: the root file, `Benchmarks/Package.resolved`, and the
   `Package.resolved` of the demo Xcode project.
   - **Now:** FoundationModelsACP `3b0a4fd` to `acf7700` (alpha.3, adds the
     trace context codec), and FoundationModelsACPClient `144b168` to
     `108e2d6`. This pair is consistent. It brings `swift-metrics`,
     `swift-otel` and swift-log 1.15.1 or later. Make sure that the package
     resolves.
   - **Later:** FoundationModelsACP `e14d853` or later (alpha.7), together
     with the FoundationModelsACPClient revision that has `ConnectionModel`
     and `SessionModel`.
   - **Before the later move, fix the demo agents.** In alpha.7,
     `PromptResponse` decodes `messageId` as required. `ScriptedWireAgent`
     answers `session/prompt` with `{}`, and `InMemoryDemoAgent` does the
     same. With alpha.7, each prompt in the tests and in the in-memory demo
     fails at runtime. Give a `messageId` in each prompt result, and echo a
     `user_message` with the same ID. Do this in the same step as the pin
     move.
   - **Before the later move, stop using `updates(for:)`.** It is deprecated.
     `ACPDemoSession` and `ACPQuickStart.swift` use it. Use `subscribe(to:)`,
     or remove this code with the code of section 4.5.
4. Tests:
   - Remove `Tests/AgentViewKitRouterTests` and
     `Tests/AgentViewKitFoundationModelsTests`.
   - In `AgentViewKitTests`, remove or change `StructuredCatalogTests`,
     `CheckpointCapabilitiesTests`, `CheckpointTests`, `SubagentSourceTests`,
     `ContextUsageTests` and `CompactionChangeTests`.
   - The tests of the kit model and of `SessionUpdateMapping` go with section
     4.5. The merge rules are tested in FoundationModelsACP. The kit tests the
     views with a `SessionModel` that a scripted agent feeds.
   - Change `ImportBoundaryTests` and `ManifestTests`. The new rules: no
     target imports FoundationModels, FoundationModelsRouter or
     FoundationModelsExtras.
   - Add an ACP client quick start and an in-process quick start to the README
     snippets.
5. **Name conflict (solved).** The old client `SessionEntry` conflicted with
   the `SessionEntry` of FoundationModelsACP. The client commit `a65af8a`
   removes the old type, so the conflict goes away with the pin move.

## 8. Session controller and in-process agent

At present, `initialize`, `session/new` and resume are only in `DemoSupport`
(`ACPDemoSession`). `DemoSupport` is not a product.

1. Use `ConnectionModel` as the session controller. Do not write a kit
   controller. The demo app and the README use `ConnectionModel`, not
   `DemoSupport`.
2. Call `ConnectionModel.close(_:)` when a thread closes. At present nobody
   sends `session/close`.
3. **Defect:** resume shows no history. `ACPDemoSession.selectSession` calls
   `resumeSession` without `replayFrom`. If `replayFrom` is not there, the
   agent does not replay. Pass `replayFrom: .start` in the
   `ResumeSessionRequest` to `ConnectionModel.resumeSession(_:)`.
4. Add an optional in-process helper. It pairs `InMemoryTransport.pair()`
   with an `Agent` and an `AgentSideConnection`. FoundationModelsACPAgent has
   a public `RoutedACPAgent` with `init(...)` and `bind(connection:)`. The
   helper must not import the agent. The host gives the `Agent`.
5. Make a task in FoundationModelsACPAgent: make the `serve`/`compose` helper
   public. At present it is in the executable target only.

## 9. ACP defects and gaps

### 9.1 Demo launch (high priority)

`ACPDemoSession` calls `AgentProcess(command:)` without arguments. The
default subcommand of `acp-agent` is `run` (`AcpAgentCommand` in
FoundationModelsACPAgent). Thus the agent does not speak ACP.

1. Pass `arguments: ["acp"]`.
2. There is no `--acp` flag. Change the tests in `ACPThreadActionsTests` that
   use `--acp`.
3. Make sure that the README text for `--agent-command` is correct.

### 9.2 Stop reasons

The agent sends extension stop reasons: `_truncated`, `_ended_in_reasoning`,
`_repeated`, `_reasoning_limit`, `_error`, `_no_output`, `_stalled`
(`PromptExecution` in FoundationModelsACPAgent).

The kit mapping keeps the raw value (`StopReason(wireValue:)`). The defect is
in `StateBanner`: it shows nothing for `.idle(.unknown)`. Thus a cut, empty,
stalled or failed prompt looks like a correct end. The ACP `StopReason`
keeps the raw value too (`StopReason.unknown(String)`), so this fix works
before and after the client models.

1. Show a banner for each `_` value that the kit knows, with clear text.
2. Show a general banner for each other unknown value. Do not show nothing.
3. Add tests.

### 9.3 Background runs

After the streamed answer ends, the agent keeps the prompt `running` until
all background runs end. In this time, the client can get more
`tool_call_update` messages and a full `agent_message_chunk` with a new
`messageId`. Then `idle` comes.

1. Add a view test for this order: `running`, streamed text, tool updates, a
   full chunk with a new `messageId`, `idle`. The thread must show two
   assistant messages.
2. Show "waiting for background work" when the state is `running` and no
   text streams.

### 9.4 Other gaps

| Gap | Location | Task |
|---|---|---|
| Prompt capabilities are not examined. Image blocks go out always. Embedded `resource` blocks never go out. | `ACPThreadActions` (prompt content) | Examine `promptCapabilities` before each block. |
| Structured diffs show as unknown when there is no `git_patch`. | `SessionUpdateMapping` (diff content) | Show `Diff.changes` in the diff view. |
| ACP errors lose their code. Error `-32000` (authentication required) does not start a login. | `ACPThreadActions` (error report) | Keep the code in the error entry. Start the login flow on `-32000`. |
| The connection state is not shown. | `SwiftUIACPClient.connectionState` | Show a banner. Bind to `ConnectionModel.state`. |
| Agent information is not used. The agent name comes from the host. | `ACPThreadSource` | Use the `initialize` result in `ConnectionModel`. |
| A permission comment goes out as a prompt after a fixed 50 ms wait. | `ACPThreadActions` (permission reply) | Remove the wait. Only the agent side has an "after the reply is written" hook (`AgentSideConnection.afterRespondingToCurrentRequest`). Make a task: ask for a client-side signal, in FoundationModelsACP or in the `SessionModel` reply method. |
| `AgentProcess` has only `init(command:arguments:)`. The kit launches through `/usr/bin/env`. The exit status is always nil. | `Sources/AgentViewKitACP/ProcessLauncher.swift` (`AgentProcessLauncher`). Note: a second `Sources/AgentViewKit/Platform/ProcessLauncher.swift` exists. | Make a task in FoundationModelsACPClient: an `environment` parameter, a `currentDirectory` parameter, and the exit status. |

## 10. Documents

1. `plan.md`: rewrite §1 (the sources), §3 (the model is the client models),
   §11 decisions 1 and 5, §13 (elicitation), and §14 R5, R13, R14 and R17,
   for an ACP client kit.
2. Remove or mark as not current: `Docs/decisions/subagent-source.md`,
   `checkpoints.md`, `usage-model.md`, `branches.md`, `compaction-ux.md`, and
   the Router column of `attachment-types.md`.
3. Change the records that refer to the kit model or the Router:
   `required-thread-actions.md`, `accessibility.md`, `permission-ux.md`, and
   `connection-states.md` (the states move to `ConnectionModel.state`).
4. `Docs/decisions/dependencies.md`: the new dependency list.
5. `Docs/decisions/acp-version.md`: alpha.7.
6. `README.md`: an ACP client kit.
7. Add a decision record: "AgentViewKit is an ACP client kit". Give the
   reasons of section 2.

## 11. Order of work

Steps 1 to 5 do not need the client models. Do them now.

1. Done: the owner decided D2, D4, D5 and D6 on 2026-10-02.
2. Section 9.1: fix the demo launch. Small and independent.
3. Section 7, items 1, 2 and 4, and the first pin move of item 3: remove the
   Router and FoundationModels targets, the benchmarks and the demo parts
   that use them. Make sure that the package builds, the tests pass, and the
   three CI gates pass.
4. Section 6: remove the vocabulary that has no ACP source.
5. Section 9.2: the stop reason banners. Section 10: the documents.

Steps 6 to 9 need `ConnectionModel` and `SessionModel` in
FoundationModelsACPClient. They are complete (local commit `a65af8a`).
FoundationModelsACP `27419fa` is on `main`. Start step 6 when the client
commit is pushed.
Then the first pin move of step 3 and the second pin move of step 7 can be
one move.

6. Make sure that the built client models agree with section 4. If a name or a
   shape changed, change this plan first.
7. The second pin move (section 7, item 3), with the demo agent `messageId`
   fix and the `updates(for:)` removal. Then bind the views to the client
   models (sections 4.5 to 4.7). Remove the kit model, `ACPThreadSource`,
   `SessionUpdateMapping` and `ACPSessionList`. Do this one view group at a
   time.
8. Section 5: the other alpha.7 changes (`ToolCallUpdate.name`, the command
   seed, the resume text).
9. Section 8 and sections 9.3 and 9.4: the session controller, the
   in-process helper, background runs, other gaps.

After each step, run `swift build` and `swift test`. Run the CI gates.

## 12. Risks and unknown items

- The client models are complete but not pushed yet (2026-10-04). Their
  real names and shape can be different from sections 4.2 and 4.3. Step 6
  checks this.
- The old client API is removed in both packages. A package update before
  the migration breaks the build (section 4.1).
- Nobody built AgentViewKit against the new pins. A static check found no
  compile break at `e14d853`, but it found the runtime break of the demo
  agents (section 7, item 3).
- Step 7 changes most of the views.
- The update buffer has limits (section 4.4). An overflow does not lose
  updates silently: the subscription reports `hasMissedUpdates`, and the kit
  shows a banner.
- Until the pin move, the old client API stays in `Package.resolved`. A
  build of the kit with new code and old pins mixes the two APIs.
