# AgentViewKit: the SwiftUI view kit for an ACP client

Revised 2026-10-08.

**Target:** macOS 27 or later, Apple Silicon, the macOS 27 SDK. No back-deployment.
**What:** the native SwiftUI counterpart to Vercel AI Elements and assistant-ui. A reusable, open-source Swift package with the same posture as the Swift ACP SDK.
**What it shows:** one ACP client. The views bind to the observable models of FoundationModelsACPClient. Each ACP v2 agent reaches the kit through that client.

---

## 1. What it is

A component library for the UI of an ACP client in SwiftUI. It is not only a chat bubble list. It gives the agent-grade surfaces: streaming responses, reasoning, tool-call activity, terminals, diffs, plans, citations, permission requests, elicitation, artifacts, config options, and context usage.

**One source: the ACP client.** FoundationModelsACPClient connects to the agent and keeps the session state in two observable models: `ConnectionModel` and its `SessionModel` objects. The views of the kit bind directly to these models. The kit keeps no session state of its own (§3, `Docs/decisions/acp-client-kit.md`).

A FoundationModels agent or a Router agent reaches the kit as an ACP agent:

```
LanguageModelSession / Router  ->  FoundationModelsACPAgent  ->  ACP  ->  ACP client  ->  AgentViewKit
```

The agent runs in a subprocess (`AgentProcess` of FoundationModelsACPClient), or in the same process through `InProcessAgent` of FoundationModelsACPClient (§3.9).

**The dependencies.** The direct dependencies are FoundationModelsACPClient, FoundationModelsACP, EditorKit, Textual and swiftui-math (`Docs/decisions/dependencies.md`). FoundationModels, FoundationModelsRouter and FoundationModelsExtras are not direct dependencies. The package has two library products, each with its own library target: `AgentViewKit` and `AgentViewKitStyle` (§11 decision 1). `AgentViewKitStyle` holds the shared look of the view kits and links only EditorKit products. `AgentViewKit` holds the views and the ACP helpers, depends on `AgentViewKitStyle` and re-exports it.

**Two levels of use.** The drop-in `AgentThreadView(session:connection:)` shows the whole surface of one session. The composable primitives below it give full control. The README has two quick starts, each a compiled snippet: an ACP agent program, and an agent in this process. A test holds the README and the compiled snippets equal.

The bet: the web has three good answers (Vercel AI Elements, assistant-ui, CopilotKit). SwiftUI has none that are agent-grade. A survey on 2026-09-08 found no SwiftUI package with native tool-call and reasoning views above a few GitHub stars. The gap is real.

## 2. Landscape survey: what exists, what to take

**Vercel AI Elements** (1.9.0, 2026-03). The most complete component taxonomy. Chatbot: Attachments, Chain of Thought, Checkpoint, Confirmation, Context, Conversation, Inline Citation, Message, Model Selector, Plan, Prompt Input, Queue, Reasoning, Shimmer, Sources, Suggestion, Task, Tool. Code: Agent, Artifact, Code Block, Commit, File Tree, Sandbox, Stack Trace, Terminal, Test Results, Web Preview. Voice and Workflow sets. **Take:** the inventory, for the surfaces that ACP gives.

**assistant-ui** (0.15, 2026-09). Composable primitives plus a `Thread` drop-in. The key idea is the runtime abstraction: views bind to a runtime. 0.15 added a tool UI registry, approval parts, and a `ChainOfThoughtPrimitive`. **Take:** views that bind to one observable runtime. Here the runtime is the ACP client model (§3).

**CopilotKit and AG-UI.** Human-in-the-loop as a first-class component. AG-UI added `REASONING_*`, `ACTIVITY_*`, and `SUBAGENT_*` events in 2026. **Take:** HITL as a component. Skip the framework.

**Xcode 27 Coding Intelligence** (beta 6). Plan mode with editable Markdown plan artifacts, queued messages, `@` inline annotations, a History slider with Restore, per-response Undo, an agents-and-models picker that accepts any ACP agent, permission settings for allowed commands and tools, skills and slash commands. **Take:** the visual default (§5).

**Claude Code, Cursor, Codex** (2026). Approval is mode-based: default, accept edits, plan, auto with a circuit breaker. All three ship a diff review panel and a context usage meter. **Take:** these as the component bar for v1.

**SwiftUI building blocks.**
- **Textual** (gonzalezreal, 0.5.0, macOS 15). The MarkdownUI successor. Pure SwiftUI, GFM, theming, a `CodeBlockStyle` hook, and a `.math` extension. It has no streaming mode and re-parses the whole document on each update. AgentViewKit renders prose through Textual with the paragraph split in §8.
- **SwiftStreamingMarkdown** (Microsoft, 0.7.0). Streams well but does not allow a custom code-block view. It cannot host EditorKit. Not used.
- **EditorKit** (ours). A TextKit 2 code editor and a command system. Renders code, hosts the composer, and supplies commands and keymaps (§4.1).
- **SwiftMath / iosMath / swiftui-math.** Core Text math engines. Research R9 chose swiftui-math (`Docs/decisions/math-engine.md`).
- **stream-chat-swift-ai** (GetStream, 0.7.0). Chat-centric. Nothing for tools or reasoning. Reuse the composer pattern only.

## 3. Architecture: the views bind to the client models

### 3.1 Why the client models

ACP is the correct layer. It defines all of the agent surfaces that the kit shows: messages, thoughts, tool calls, terminals, plans, permission requests, elicitations, config options, slash commands, usage, the agent state and the stop reason. FoundationModelsACPClient keeps these as client-side state in `@MainActor` `@Observable` models. `Docs/decisions/acp-client-kit.md` gives the reasons, and why the earlier plans with a FoundationModels `Transcript` and with Router types failed.

**The binding rule** (`Docs/decisions/acp-client-kit.md`, section "Binding rule"). Each view of the kit binds directly to `ConnectionModel`, `SessionModel` and the `TranscriptEntry` objects. A view shows what the model holds, and it calls the methods of the model. The kit keeps no parallel state, no copy of model data, and no logic that the model owns: no tracking of prompts, no order of prompts, no queue that waits for the end of the work of a prompt, no list of pending requests, no connection state, no session list, and no copy of the usage or of the config options. A view keeps only view state: the open state of a row, the scroll position, the focus, a selection, and the draft of the composer.

The models are in FoundationModelsACPClient. The pins of the two ACP packages are in `Docs/decisions/dependencies.md` and in the three `Package.resolved` files. When a pin moves, read the real API of the models, and change §3.2 to §3.7 first.

### 3.2 What the session model gives

- `SessionModel` is a `@MainActor` `@Observable` class. It gives each update to the `SessionMergeEngine` of FoundationModelsACP, and keeps no merge rule of its own. SwiftUI uses it directly. Its identity is `sessionId`. It also holds the `cwd` and the `additionalDirectories` of the session.
- **Fine granularity.** `transcript` is an array of `TranscriptEntry`, in the order of first appearance. `TranscriptEntry` is an enum. Each case holds one `@Observable` entry object:

  | Case | Entry object | Main properties |
  |---|---|---|
  | `.userMessage` | `UserMessageEntry` | `content`, `messageId`, `sendState` |
  | `.agentMessage` | `AgentMessageEntry` | `content`, `messageId` |
  | `.thought` | `ThoughtEntry` | `content`, `messageId` |
  | `.toolCall` | `ToolCallEntry` | `name`, `title`, `status`, `content`, `locations`, `linkedElicitationIDs` |
  | `.terminal` | `TerminalEntry` | `bytes`, and the computed `text` |
  | `.plan` | `PlanTranscriptEntry` | `planId`, `entries` |
  | `.unknown` | `UnknownEntry` | the type string and the raw JSON |
  | `.compaction` | `CompactionEntry` | the compaction status and its summary (stable ACP since schema alpha.8) |
  | `.error` | `ErrorEntry` | `code`, `message`, `data` |

  Each entry object also has `meta`. A streamed chunk changes only its own entry object. Thus only that row draws again.
- **Chunk buffer.** The model keeps `agent_message_chunk` and `agent_thought_chunk` updates in a buffer. It applies the buffer at display rate (`defaultCoalescingCadence`, 33 ms), so the entry of a streamed message changes one time for each flush. Each other update applies the buffer first, so the order stays the arrival order. `flushPendingChunks()` applies the buffer at once. `updateTap()` gives each raw `SessionUpdate` at its arrival, for a consumer that is not a view.
- **Row identity.** `TranscriptEntry.id` is a `TranscriptEntry.ID`: `.wire` with the `SessionEntry.ID` for an entry from the wire, or `.local` with a `UUID` for an entry that the client made. The identity does not change when a local user message gets its `messageId`. **The views use `TranscriptEntry.id` as the row identity**, not `SessionEntry.ID` and not `MessageId`. A thought and an agent message with the same `MessageId` are two entries.
- **Last-value state:** `availableCommands` (an optional array of `AvailableCommand`), `configOptions` (an optional array of `SessionConfigOption`), `usage` (an optional `UsageUpdate`), `agentState`, `sessionInfo` (a `SessionInfoUpdate` with the title and `updatedAt`, folded as a patch) and `mcpServers` (an array of `MCPServerItem`).
  - `agentState` is an optional `StateUpdate`: `.running`, `.idle` with an `IdleStateUpdate` that has an optional `stopReason`, `.requiresAction`, and `.unknown` with the wire string and the raw `JSONValue`.
- **Notices (stable ACP since schema alpha.8):** `notices` is an array of `SessionNotice`, in arrival order. A notice is not in the transcript, and no replay gives it again. `dismissNotice(_:)` removes one notice. The start of a resume and the close remove all notices.
- **Stream state:** `hasMissedUpdates`, `isReplaying`, `history` (a `SessionHistory`: `.live` or `.retained(replayFrom:)`) and `isClosed`. Only the connection model changes them.
- **Pending requests:** `pendingPermissions` (an array of `PendingPermissionRequest`) and `pendingElicitations` (an array of `PendingElicitation`) for the session. The reply methods are `selectPermission(_:option:)`, `cancelPermission(_:)`, `acceptElicitation(_:content:)`, `declineElicitation(_:)` and `cancelElicitation(_:)`. `cancelAllPending()` cancels each pending request. A session elicitation with a `toolCallId` is linked to its tool call entry, in `ToolCallEntry.linkedElicitationIDs`, while it is pending.
- **Prompt helper.** `prompt(_:meta:)` adds a local `UserMessageEntry` with the `sendState` `.pending` before it sends `session/prompt`. `PendingPromptCorrelator` links the entry to the `messageId` of the `PromptResponse` or of the echoed `user_message`, in each order. The entry then gets `.sent`, and keeps its object and its identity. The echo adds no second entry. If the request fails, the entry gets `.failed`, the model adds a local `ErrorEntry` with the JSON-RPC code, message and data, and the call throws the error again.
- **Other requests.** `cancel(meta:)` sends `session/cancel`. `setConfigOption(_:)` sends `session/set_config_option`. `appendError(code:message:data:)` adds a local `ErrorEntry` for a request that the model did not send, for example a login.

### 3.3 What the connection model gives

`ConnectionModel` is a `@MainActor` `@Observable` class. `init(coalescingCadence:clock:logger:)` makes a model with no connection. It holds:

- **The connection.** `connect(over:logger:bufferLimits:client:)` connects over a transport and returns the `ClientSideConnection`. `bufferLimits` is a `SessionUpdateBufferLimits`. The `client` closure gets the router `Client` of the model, and a host can put its own `Client` in front of it. `disconnect()` closes the connection. The model never connects again on its own. After a close, the host calls `connect` again with a new transport. Each call forgets the `initialize` answer and the auth state of the last connection.
- **The connection state.** `state` is a `ConnectionState`: `.disconnected` (the start value), `.connecting`, `.connected` and `.failed` with the error. Two states are equal when they have the same case. When the connection closes, the model closes each open `SessionModel` (each gets `isClosed`, and its pending requests are cancelled) and empties `openSessions`.
- **Initialize and auth.** `initialize(_:)` sends `initialize` and keeps the answer in `initializeResponse`. `agentCapabilities` and `authMethods` read that answer. `authState` is an `AuthState`: `.unknown`, `.notRequired`, `.required`, `.authenticated`, `.reconnectRequired` or `.failed`. `login(_:)`, `loginWithTerminal(_:runner:)` and `logout(_:)` change it.
- **Capability flags.** `canListSessions`, `canResumeSessions` and `canCloseSessions` are true when the `initialize` answer has a `session` capability object. `canDeleteSessions` is true when that object has `delete`. `canLogin` and `canLogout` read the auth methods. Each flag is false before `initialize(_:)` succeeds. A call to a method that the agent does not support throws `ConnectionModelError.unsupported(method:)` and sends no request. `newSession(_:)` has no flag.
- **The session factory.** `newSession(_:)` takes a `NewSessionRequest`, and `resumeSession(_:)` takes a `ResumeSessionRequest`. Each returns a `SessionModel`. They take the generated request types, so `cwd`, `additionalDirectories`, `mcpServers`, `_meta` and future fields pass through unchanged. They subscribe to the update stream at the correct time, so no update is lost. The response seeds `availableCommands` and `configOptions`. A resume of an open session uses the same model again. The resumes of one session run one after the other.
- **The open set.** `openSessions` is an ordered list of `SessionModel`, in the order that the sessions opened. Each `SessionModel` is `Identifiable` by its `SessionId`, so a view can use `ForEach(connection.openSessions)`. `session(for:)` gives the model of one open session, or `nil`. `sessions` is the session list, not the open set.
- **The session list.** `sessions` is an array of `SessionInfo`. `refreshSessions(cwd:)` replaces the list with the first page. `loadMoreSessions()` adds the next page, and `hasMoreSessions` tells if there is one. A `session_info_update` of an open session also changes its item in `sessions`.
- **Close.** `close(_:)` sends `session/close` for a `SessionModel`. When the agent accepts it, the model of the session goes out of `openSessions`, its stream stops, and it gets `isClosed`. The closed model stays readable. When the agent refuses the close, the model stays open.
- **Delete.** `deleteSession(_:)` takes a `SessionId`. It closes the session first if it is open, then sends `session/delete`, then removes the item from `sessions`.
- **Request-scoped elicitations.** `pendingElicitations` is an array of `PendingElicitation` for requests that the client sent outside a session, for example `auth/login`. Each item has its `requestId` and its `requestMethod`. The reply methods are `acceptElicitation(_:content:)`, `declineElicitation(_:)` and `cancelElicitation(_:)`. The end of the client request, the close of the connection and a new connection each cancel its elicitations.

### 3.4 Verbs: the views call the models

The kit has no actions protocol. Each verb of a view calls a method of the models:

| Verb | Model method |
|---|---|
| Send a prompt | `SessionModel.prompt(_:meta:)`. The composer makes the ACP content blocks from its draft (`UserInput`). |
| Stop | `SessionModel.cancel(meta:)` |
| Answer a permission request | `SessionModel.selectPermission(_:option:)` or `cancelPermission(_:)` |
| Answer an elicitation | `acceptElicitation(_:content:)`, `declineElicitation(_:)` or `cancelElicitation(_:)` of the model that holds the request |
| Set a config option | `SessionModel.setConfigOption(_:)` |
| Resume, reload | `ConnectionModel.resumeSession(_:)` with the `cwd` and the `additionalDirectories` of the session model |
| Close, delete | `ConnectionModel.close(_:)`, `deleteSession(_:)` |
| Sign in, sign out | `ConnectionModel.login(_:)`, `loginWithTerminal(_:runner:)`, `logout(_:)` |

The wire has no field for a permission comment. When a comment exists, the card waits for `selectPermission(_:option:)`, then sends the comment as the next prompt. Claude Code does the same with a deny reason.

**Host hooks.** The host gives only work that no model does: `terminalAuthRunner` runs a `terminal` auth method, and `agentReconnect` connects again after a terminal sign-in (`Docs/decisions/acp-client-kit.md`, section "Host hooks"). The other host values are platform services and host actions, such as `diffActions` and `pasteboard`.

### 3.5 In-progress state comes from the model

There is no `isStreaming` flag on a view, and the kit does not track prompts. `SessionModel.agentState` tells if the agent runs. A `ToolCallEntry` with the status `inProgress` still runs. The shimmer (§5) and `ActivityIndicator` are functions of these model values.

### 3.6 Views per entry kind, each replaceable by a typed modifier

`AgentThreadView` switches over `TranscriptEntry` inside. You never see the switch. To replace the view of one case, chain the typed modifier of that case. Its closure gets the observable entry object of the session model:

```swift
AgentThreadView(session: session, connection: connection)
    .toolCallView        { call in MyToolCall(call) }
    .assistantMessageView { entry in MyMessage(entry) }
    .reasoningView       { _ in EmptyView() }
```

There is one modifier for each case: `userMessageView`, `assistantMessageView`, `reasoningView`, `toolCallView`, `terminalView`, `planView`, `errorView`, `unknownItemView` and `compactionEntryView`. An inner modifier wins over an outer modifier for the same case.

The open-ended kinds get keyed modifiers:

```swift
    .contentBlockView(for: .resourceLink) { block in MyLinkCard(block) }   // by the kind of the ACP ContentBlock
    .attachmentView(for: .pdf)            { url in MyPDFPreview(url) }      // by UTType
    .messageFooter                        { entry in MessageActions(entry: entry) }
```

The tool call registry selects a view by the `name` of the `ToolCallEntry`, the program name of the tool. The view shows `title` as the label. Registrations resolve last-writer-wins through the environment. An unregistered `UTType` falls to the nearest conforming supertype, then to the generic file chip. A block kind or an entry case that the kit does not know shows in `UnknownItemView`. Nothing is dropped.

**Attachments are per-type.** An attachment is keyed by `UTType`. Defaults: image preview, PDF and QuickLook thumbnail, plain text and markdown via Textual, source code via EditorKit, audio and video player, and a generic file chip. One `AttachmentView` family renders in the composer, in prompts, and in artifacts. The composer reads the `promptCapabilities` of the agent before it sends a block (`Docs/decisions/attachment-types.md`).

**Click to preview.** Tapping an attachment, artifact, or file output opens it in a trailing `.inspector` with a live `QLPreviewView` and the actions Open, Reveal in Finder, Share, Save, and pop-out Quick Look.

**The host can own the inspector (AVK-10).** A window that has its own `.inspector`, such as a `NavigationSplitView` with an inspector, applies `.agentAttachmentInspector(.host($selection))` one time at its root. Then each `AgentThreadView` in the window applies no `.inspector`, because two inspectors in one window make AppKit stop the app (NSGenericException, TestudoApp rule D40). A tap on an attachment writes an `AgentAttachmentSelection` to the binding: the file and the `sessionId` of the thread that the user pressed, so more than one thread view can share one binding. The host shows the file in its own inspector, for example with `AttachmentInspector`, whose actions work in each mode, and it closes the inspector with a write of `nil`. The default, `.builtIn`, keeps the trailing inspector of the kit.

### 3.7 Rules that are built in FoundationModelsACP

| Rule | Detail |
|---|---|
| Unknown updates stay visible | An unknown `session/update` becomes an unknown entry with the type string and the raw JSON. |
| Extension stop reasons | `StopReason.unknown(String)` keeps the wire value, for example `_truncated`. |
| `_meta` | Each entry keeps its `_meta`, folded with the same patch rules as the wire field. |
| Commands "not reported" | `availableCommands` is nil until a list is reported. A new or resume response with no list, **or with an empty list**, leaves it nil. Only an `available_commands_update` with `[]` sets it to `[]` ("no commands"). |
| Plans | A plan entry with a `planId` is replaced by `planId` and keeps the position where it first appeared. A plan update with no `planId` always adds a new entry. |
| Terminals | `AccumulatedTerminal` keeps the decoded bytes as `output: Data`. A chunk appends bytes. An `output` snapshot replaces them. The computed `text` (UTF-8, with replacement of bytes that are not valid) is in the client `TerminalEntry`. |
| Update buffer | `ClientSideConnection.subscribe(to:)` returns `SessionUpdateSubscription { updates, hasMissedUpdates }`. The router buffers updates for a session that has no subscriber: at most 1024 updates for each session and at most 64 sessions (`bufferLimits` can change them). When a buffer is full, the router discards it and the new update, marks the session as overflowed, and writes a warning. The 65th session evicts the oldest. The buffer is cleared on `session/close` and on connection close. |
| Resume replay | Subscribe before `session/resume`. Then the replay goes directly to the subscriber and does not use the buffer. |
| ACP version | The kit speaks ACP v2 only. `ConnectionModel.initializeCheckingProtocolVersion(_:)` refuses each other version with `UnsupportedProtocolVersionError` (§11 decision 20, `Docs/decisions/acp-version.md`). |

### 3.8 View tasks from the models

Each item is built. Each view reads the model value in its body and keeps no copy.

- **Row identity:** `ForEach` over the transcript uses `TranscriptEntry.id`.
- **Composer:** each submit calls the prompt helper of `SessionModel` at once, also while the agent runs. The pending user message shows at once. The composer keeps no queue and does not wait for the end of the work of a prompt. More than one prompt can be open. Esc and the Stop button call `cancel(meta:)` with the one cancel rule of the kit: the user can cancel while the agent runs, while it requires action, and while it is idle and the session has a pending permission request or elicitation.
- **Prompt capabilities:** the composer reads `ConnectionModel.agentCapabilities` at each submit. An image goes out only when the agent advertises `image`. A file goes out as an embedded resource when the agent advertises `embeddedContext`, else as a resource link.
- **Error rows** come from the model. The kit keeps no error list. For a failed request that the kit did not send through the model, the kit calls `appendError(code:message:data:)`.
- **Login on error `-32000`:** while the last entry of the transcript is an error entry with the code `-32000` (authentication required), `AgentThreadView` shows `AgentAuthView` for the auth methods of the connection model.
- **Agent state and stop reasons:** `StateBanner` shows `.running`, `.idle` with its stop reason, and `.requiresAction`. It shows a banner with clear text for each extension stop reason that the kit knows (`_truncated`, `_ended_in_reasoning`, `_repeated`, `_reasoning_limit`, `_error`, `_no_output`, `_stalled`), and a general banner with the raw value for each other unknown value. It shows a general state for `.unknown`. While the state is `.idle` and the session has a pending permission request or elicitation, `StateBanner` shows the `.requiresAction` text. The reason: FoundationModelsACPAgent never sends `requires_action`, and its session can be idle while a question waits. Other agents can still send `.requiresAction`. An idle can have no stop reason (after background work only). Then the banner shows the ready text.
- **Background runs:** `running` and `idle` follow the work of the agent, also when no prompt is open (background work, a compaction). After the streamed answer, the agent keeps `agentState` at `.running` until its background runs end. An idle after background work only has no stop reason. One idle can end the work of two open prompts. The transcript shows each entry of the model in its order, also a second agent message and an entry that comes after the prompt ended, such as a compaction entry. The state banner shows `.running` until `.idle`. The kit adds no logic for this order.
- **Resume:** a resume sends `replayFrom: .start`. `SessionStreamBanner` shows a marker while `isReplaying` is true, and a "history can be partial" note from `history`. It does not tell the user that the history is complete.
- **Missed updates:** when `hasMissedUpdates` is true, `SessionStreamBanner` shows a banner with a "Reload" action. The action resumes the session again with `replayFrom: .start`. The client model clears `hasMissedUpdates` only after a successful `.start` replay. When the resume fails, the banner tells that the reload failed, as a failure, with the localized description of the error in its explanation, and keeps the Reload action, as the stream banner of KanbanViewKit does.
- **Closed thread:** `SessionStreamBanner` shows a closed state when `isClosed` is true, and the composer is disabled.
- **Close:** when the host gives the connection model, `AgentThreadView` calls `ConnectionModel.close(_:)` when the view goes away, if `canCloseSessions` is true and the session is not closed.
- **Terminal view:** shows the computed `text` of the terminal entry.
- **Plan view:** reads the plan entry at its position in the transcript.
- **Tool call view:** selects the registry view by `name` and shows `title` as the label. It shows the structured `Diff.changes` of a diff in `DiffView`, and a linked elicitation next to its tool call (a session elicitation with a `toolCallId`).
- **Session picker:** `SessionListView` binds to `ConnectionModel.sessions`, with "load more" when `hasMoreSessions` is true.
- **Capabilities:** each action hides when its capability flag is false.
- **Connection banner:** `AgentConnectionBanner` shows `ConnectionModel.state` (`Docs/decisions/connection-states.md`). `AgentInfoHeader` names the agent from the `initialize` answer.

### 3.9 The agent in this process

`InProcessAgent.makeConnection(serving:)` of FoundationModelsACPClient runs an ACP agent in the process of the app. The kit has no copy of this helper. It pairs an `InMemoryTransport`, serves the agent on one end with an `AgentSideConnection`, and connects a new `ConnectionModel` on the other end. The two sides speak the real ACP wire. The helper returns the connection model and keeps no state of its own. The kit does not import an agent: the app gives it, for example the `RoutedACPAgent` of FoundationModelsACPAgent.

## 4. Building blocks: reuse, do not reinvent

All-Swift, native. No WebView or JSCore anywhere. Links open in the user's browser, optionally shown as an `LPLinkView` card.

| Concern | Use | Why |
|---|---|---|
| Session state | **FoundationModelsACPClient** `ConnectionModel`, `SessionModel` | the observable models that the views bind to (§3) |
| Prose and markdown | **Textual** | mature GFM plus theming; a `CodeBlockStyle` hook for EditorKit |
| Streaming balance | `StreamingMarkdownBalancer` (§8) | closes dangling delimiters in the trailing paragraph |
| Code render, diffs, text input | **EditorKit** | one engine for code blocks, diffs, and the composer |
| Commands and keymaps | **EditorKit** `EditorCommands` and `EditorCommandsUI` | the kit verbs are commands; palette and keybindings come free |
| Math | `MathView` on swiftui-math | inline and block LaTeX (§11, decision 7) |
| Layout and scroll | `ScrollView`, `LazyVStack`, `ScrollViewReader` | scroll anchoring; lazy rows |
| Chrome | Liquid Glass, design tokens | Xcode-assistant look (§5) |
| Activity | shimmer, `ProgressView`, SF Symbols | native affordances (§5) |
| Speech | native `Speech`, the whisper path | voice composer |

### 4.1 Dependency: EditorKit

EditorKit is a TextKit 2 editor over a rope, with a CodeMirror-shaped state algebra, tree-sitter highlighting, and a focus-scoped command system. It is pre-1.0. Pin `branch: "main"`. It targets macOS 15 and Swift 6.2 with strict concurrency and `MainActor` default isolation in UI targets. The kit adopts the same isolation defaults.

What the kit takes from it:

- **Code render.** Fenced code blocks render in an `EditorView` with `isReadOnly`. Textual's `CodeBlockStyle` hands the code and the language hint to the kit, which hosts EditorKit. A code block in prose looks identical to the editor.
- **Grammars.** EditorKit links JSON and Markdown only. Other languages need a host TextMate grammar through `TextMateGrammarRegistry`. The kit ships a grammar bundle for the languages agents emit most (research R2).
- **Diffs.** A unified-diff view is an EditorKit capability, in the `EditorDiff` product. It takes unified diff text and renders it, inline or side-by-side, with its own gutter marks, line colors, and hunk folding (research R3, `Docs/decisions/diff-renderer.md`). The kit's `DiffView` hosts that view and adds the per-file list with counts and the review actions. Input is `git_patch` text, or the structured changes of an ACP diff. The kit does not build its own diff renderer.
- **Streaming code.** EditorKit has no append API. The kit adds a small append helper on `EditorModel.dispatch` with a tail replacement. The balancer (§8) routes an open code fence to this path.
- **Rich input.** The composer hosts EditorKit. Slash commands, chips, and `@file` references are assembled from `TokenField`, `SmartTag`, `CompletionEngine`, `CompletionPopup`, `PathCompletionSource`, and `SingleLineField`. A `SlashCommandSource` completion source is fed by `SessionModel.availableCommands`.
- **Text input.** Every place where the user types is an EditorKit editor: `EditorView` for multi-line text, `SingleLineField` for one line (EditorKit `style.md`, "Text input"). No file of the kit, its style library, the demo support or the demo names a SwiftUI `TextField`, `TextEditor` or `SecureField`, an AppKit or UIKit text input, or calls `.searchable`. Review holds this (EditorKit `style.md`). `PromptCaretProbe.swift` only reads EditorKit's own `NSTextView` to find the caret, and shows no input.
- **Commands.** The kit verbs (send, cancel, approve, jump to item, copy thread) register as EditorKit `Command`s with a default keymap. The host's palette and keybindings editor pick them up. `ProgressCenter` backs tool-call progress.
- **One theme.** EditorKit themes are the themes of the kit. The kit has one theme: the EditorKit `Theme` in `\.editorTheme`, set with `.editorTheme(_:)`. Every color of the kit views and each font come from it, so code colors match the chrome. The fonts are the EditorKit font roles: `uiFont` for the chrome, `displayFont` for the prose, the composer and the text fields, and `codeFont` for the code. With no theme set, EditorKit gives `SystemTheme`. Hosts can import Zed, VS Code, and tmTheme files.

Boundary: EditorKit's `EditorIntelligence` and `EditorServices.MCPClient` are editor features. The kit does not duplicate them.

### 4.2 Dependency: Textual

Textual renders message bodies, plain text, and streaming responses. It is pure SwiftUI, so it sits in the `LazyVStack` rows and inherits Dynamic Type and accessibility. Its `CodeBlockStyle` is the one seam to EditorKit. Its `.math` extension detects `$…$` and `$$…$$` spans and routes them to `MathView`.

Textual has no streaming mode. Each update re-parses the whole input. So the kit never feeds a whole message during streaming. It feeds settled paragraphs once, and the streaming paragraph alone (§8). Research R1 measures this.

The cost of pure SwiftUI prose is transcript-wide selection. See decision 8.

## 5. Default styling: make it look like Apple shipped it

Out of the box, the kit reads as the Coding Intelligence assistant in Xcode 27: chat with plan artifacts, compact tool rows, and a usage ring.

**Liquid Glass, used correctly.** [EditorKit/style.md](../EditorKit/style.md) is the one style guide of the app and of each view kit (D112 (a)): EditorKit, KanbanViewKit, AgentViewKit, SnapshotViewKit and TestudoApp follow it, and the kit keeps no copy of its rules. It gives the two layers, the Liquid Glass rules (D110), the eight steps of the procedure (D111), the section "How the steps apply" (D113, which answers the eight questions of the kit about AVK-8) and the themes (D112). [EditorKit/Docs/research-liquid-glass.md](../EditorKit/Docs/research-liquid-glass.md) gives the sources of the rules. This section does not repeat the rules. It gives only how the kit does each rule, and the test that holds the rule.

- **Two layers.** The navigation and control layer is the sidebar, the toolbar, the inspector, the sheets, the popovers, the menus, the composer bar, floating action buttons, the command palette, the jump overlay and floating control clusters. The system decides the look of the standard structure (style.md rule 1). On macOS 27, the sidebar has a system gray, as in Notes, Safari and News, and the toolbar controls are glass groups (D116). The kit adds glass only to floating controls. The content layer has no glass: the chat transcript and its messages, tool call cards, the board columns and cards, the checkpoints, the lists of the views, the inspector content, the editor text, the gutter, diffs and code blocks. Glass never goes on glass.
- **No fill in content (D113 answer 1).** The transcript, the messages, the tool call cards, the request cards, the notices, the state banners, the code blocks and the artifacts have no fill and no glass of their own. A request deck in the bottom bar of a thread is on the floating glass of the deck (see "Glass only on floating controls"). `.inlineEdge(radius:)` of the EditorKit `EditorStyle` target marks the edge of a card with a thin `.separator` stroke in the concentric surface shape `EditorSurface.shape(radius:)` (AVK-8v, ^7dn35sm). The kit sets no `.inlineFill(_:)`: a fill below that edge is a decoration that only a host opts into. AVK-8ab removed `agentContentSurface`. If a group needs more, the kit uses a system container (`GroupBox`, or a `Form` with the grouped style), never a custom fill. Small chips and badges are marks, not cards: the tool call badge, the attachment chip and the pending-request badge keep a `.quaternary` fill, and the citation chip keeps a fill of the theme accent because it is a link. Terminal output keeps the background of the `TerminalPalette` of the theme (the answer of AVK-8aa): the background is terminal data, and the ANSI colors need it for contrast. Since EditorKit ^0apj6a2, the default terminal palette has a clear background, so with a theme that sets no terminal background (such as `SystemTheme`) the frame of terminal output shows no fill. The user decided that terminal output stays clear (^4rck1pf, after ^xqday3k): with no terminal background, `ANSIText` remaps the four ANSI grays (SGR 30, 90, 37 and 97, as text and as fills) to label-relative system colors, so that they contrast with the window that shows through. `TerminalPalette+Contrast.swift` holds the mapping. A theme that sets a terminal background keeps its fill and its palette. `TerminalContrastHostedTests` checks the contrast in light and dark mode only (EditorKit `style.md` rule 9). A fill also marks the selection or the focus: the selected file of a diff and the selected tab of an elicitation form. A current item that is not the selection and has no focus has no fill (the user decision of 2026-10-24, relayed by kanbanviewkit-84: the shared style rule 1 permits only the code diff, the terminal background, the `.quaternary` fill of the small chips and badges, and the accent fill of the citation chip; card ^y2mrfxt removes the fill of the current source). Review holds this (EditorKit style.md).
- **Header rows (D113 answer 4).** The header row of a code block, a terminal and command output is content, not a bar. It has no fill. A system `Divider` under the row draws the separator line (`editorBlockHeader()`, AVK-8ac). No view draws the `statusBarBackground` color of the theme.
- **Glass only on floating controls.** The composer field and the menu of the editor are on `floatingGlass(id:)` of the EditorKit `EditorStyle` target. The accessory row of the composer is below the field and not on its glass, so its glass buttons are not glass on glass. The suggestion chips and the scroll-to-bottom pill are `.glass` buttons. A `RequestDeck` in the bottom bar of a thread is user input: the whole deck is on `floatingGlass()`, and its cards have no glass of their own. The `AgentInfoHeader` in the top bar of `AgentThreadView` is a floating surface, the same as the conversation header in Messages: it is on `floatingGlass()`, in its own `FloatingGlassContainer`. The connection banner, the notice banner and the stream banner of the top bar are content: they have no glass and no fill, and they are out of the container of the header. The composer keeps the `.regular` glass. Each group of floating controls is in one `GlassEffectContainer`, the shared `FloatingGlassContainer` of EditorStyle (AVK-8l, ^7dn35sm). The deck and the action buttons read whether a container is above them from its glass namespace (`\.floatingGlassNamespace`). A container in a container makes no second container, so in `AgentThreadView` the state banner, the sign-in prompt, the pill and the composer slot share one container. The EditorKit editor in the field has no glass, and the menu is a sibling of the field glass, not in it. Outside the floating controls (the composer, the suggestion chips, the dictation button and the pill), only `RequestDeckPlace.style(of:)` gives a glass button style. It gives `.glass` to the action buttons of a request card, a notice, a status bar and the sign-in card in content and in a bar with no glass surface (see "Button styles first"). No button uses `.glassProminent` (card ^k06v4gt). The kit makes no glass of its own, so it uses no `.glassEffect(`, `.glassEffectID(` or `GlassEffectContainer`. `PromptInputView.swift` uses `FloatingGlassContainer` on one line, and `AgentThreadView.swift` uses it on two lines (the header in the top bar, and the floating controls in the bottom bar). `PromptInputView.swift` has two `floatingGlass(` lines (the field and the menu of the editor) and no `.glassEffect(` line. `AgentThreadView.swift` has one `floatingGlass(` line (the header in the top bar) and no `.glassEffect(` line, and `EditorKitPromptEditor.swift` has neither of them.
- **Variant and shape (D113 answer 3).** The floating glass is always `.regular`. The Clear look and the Tinted look are system settings, and the system applies them to `.regular` glass. No theme value selects the variant, and the shared style `EditorStyle` has no glass token (AVK-8ad, AVK-8ae). The pill and the suggestion chips are `.capsule` buttons. The icon-only buttons (Send, Stop and dictation) are `.circle` buttons. The composer field and the menu of the editor are a `ConcentricRectangle` with the `.concentric` corner style: `floatingGlass` of EditorStyle draws its glass in `EditorSurface.shape(radius:)`, with the large radius of `\.editorStyle` as the smallest corner. AVK-8b and AVK-8m added this shared shape to the kit as `AgentSurface`, and used it in place of each `RoundedRectangle` with a fixed corner radius. ^7dn35sm replaced it with the one copy in EditorStyle, `EditorSurface.shape(radius:)`. Each rounded shape of the kit takes its radius from the radius scale of `\.editorStyle`. AVK-8af gave the suggestion chips the `.capsule` border shape. The kit uses no `RoundedRectangle(cornerRadius:`, `UnevenRoundedRectangle(cornerRadius:` or `.rect(cornerRadius:`, makes no `ConcentricRectangle` itself, and gives no corner radius as a number (AVK-8m, ^7dn35sm).
- **Button styles first.** The kit uses `.glass` before custom glass. The user decision of 2026-10-24 (shared style rule 2, relayed by kanbanviewkit-84) is strict: the accent is only for the selection and the focus. A prominent button style gives the accent tint, so no button of the kit, the demo support or the demo uses `.glassProminent` or `.borderedProminent` (card ^k06v4gt). Send and Stop of the composer use `.glass`, while the agent runs and at other times. The action buttons of a request card, and the buttons of a notice, a status bar and the sign-in card, get their style from their place (`requestActionStyle(_:)` and `RequestDeckPlace.style(of:)`, style.md "Buttons on glass"). In content, the primary and the secondary action use `.glass`, and a standard action (for example Cancel and Decline of an elicitation card) keeps the button style of its environment. On the deck glass in a bar (`RequestDeckPlace.bar`), each action uses `.bordered`, because a glass button there is glass on glass. The primary action has no tint and keeps its place in the row: Submit of an elicitation card is last in its row and is the default action (`.keyboardShortcut(.defaultAction)`), so Return presses it. Of the buttons that get their style from `RequestDeckPlace.style(of:)`, only a button on the deck glass in a bar uses a bordered style. The one other bordered button of the kit is the Load Earlier button at the top of the transcript (`Thread/ConversationView.swift`). It uses `.bordered` in content. A bar with no glass surface keeps the glass styles on its buttons, because the content scrolls under them (style.md rule 4). The state banner and the sign-in prompt in the bottom bar have no glass surface, but they are in the glass container of the bar. Thus each of them declares the place of a bar with no glass, `.requestActionPlace(.barWithoutGlass)`, and a declared place comes before the place from the container. In `RequestDeckPlace.barWithoutGlass`, each action uses `.glass`. In the top bar of a thread, only the header is in a glass container, and the header has no buttons. The banners are out of that container, so their buttons get the place of content, and the Dismiss button of a notice there keeps `.glass`. The files of the permission card, the two elicitation cards, the notice, the status bar and the sign-in card each call `requestActionStyle(_:)`, and only `StateBanner.swift` and `AgentLoginPrompt.swift` declare `.requestActionPlace(.barWithoutGlass)`. `RequestDeckSurfaceTests` checks the style that `RequestDeckPlace.style(of:)` gives to the primary, the secondary and the standard action in a bar, in a bar with no glass and in content, and that a declared place comes before the place from the container. `HostedSnapshotTests` keeps the images `bottom-bar-buttons-*.png` of a thread at rest with the state banner and the sign-in card in the bottom bar below the transcript, in light and dark only (EditorKit `style.md` rule 9). The transcript fits between the two bars, so no row is under a bar (^zg9tysk). The capture is of the real window from the window server, so each glass button shows its Liquid Glass bezel.
- **Morphs (D113 answer 2).** No glass morphs the composer into a tool tray. When one glass shows or hides next to another glass in the same container, each one has a `FloatingGlassID` in the one `@Namespace` of the `FloatingGlassContainer` of EditorStyle (AVK-8ag, AVK-8ah): the composer field and the menu of the editor (`floatingGlass(id:)`), and the scroll-to-bottom pill and the suggestion chips (`floatingGlassID(_:)`). EditorStyle applies `glassEffectID(_:in:)`, and the kit applies it in no file. The modifiers take any `Hashable` id, so the kit keeps its own id type, `FloatingGlassID`, and each call names it, such as `FloatingGlassID.scrollPill`. The Reduce Motion method (AVK-8ag): the kit adds no animation to the show and the hide of a glass. Thus a glass morphs only in an animation that the host gives. A host that animates the change must give `nil` as the animation while Reduce Motion is on (§6).
- **Tint and accent (D113 answers 5 and 6, changed by the user decision of 2026-10-24).** The accent is only for the selection and the focus (shared style rule 2, relayed by kanbanviewkit-84). No action has a tint: no button uses a prominent button style (card ^k06v4gt). A link does not use the accent as its text color, and a current item that is not the selection and has no focus does not use the accent (card ^y2mrfxt). The accent fill of the citation chip is a permitted exception (shared style rule 1). The digits of a citation pill keep the text color of the environment. In the sources list, the link of each source has the link mark (`SharedSymbol.link`, `.secondary`, an accessibility element with the label "Link") in place of an accent text color, and the current source draws no accent and no fill: it differs from the other rows only in its accessibility value, its selected trait and the scroll that brings it into view. The current source is not a selection, so it does not use `.selectionSurface` of EditorStyle (that is for a selection, card ^dn1m56r). EditorKit draws the current symbol of its outline with `.selectionSurface`, because that symbol follows the editor selection. The band of the rows in view on the minimap is `.primary` at the band opacity, as the viewport of the Xcode minimap. No view uses a `.tint(_:)` modifier or `.foregroundStyle(.tint)` (AVK-8ai). No glass uses `Glass.tint(_:)`, because the Tinted look is a system setting. In content, the theme accent marks only the selection and the focus, and fills the citation chip (card ^y2mrfxt, which replaced the link and current item uses of AVK-8aj and AVK-8ak). Only 2 files read the theme accent: `InlineCitation.swift` (the capsule fill of a citation pill) and `ElicitationLayout.swift` (the fill of the selected tab). Review holds this (EditorKit style.md). `SourcesViewHostedTests` checks that a link of the sources list shows the link mark.
- **Scroll under the bars (D113 answer 7).** The list of `AgentThreadView` scrolls under its top bar (`.safeAreaBar(edge: .top)`: the header and the banners) and under its bottom bar (`.safeAreaBar(edge: .bottom)`: the state banner, the sign-in prompt and the composer slot, with the pill floating above them), with the scroll edge effect (AVK-8al, AVK-8am). The list asks for the soft effect at both edges (`.scrollEdgeEffectStyle(.soft, for: .vertical)`, ^ph0m0hf), so no window gives the opaque hard band. The rows under the top bar do not stay readable. AppKit gives the list one top edge effect, and makes it as tall as the whole top inset: the toolbar, the bars of the host and the top bar of the thread (124 pt in TestudoApp: toolbar 52, tab bar 24, thread bar 48). The effect blurs at full strength over the top part of that height and fades only near the top of the list, so the rows under the whole bar stack are washed out by design. No public or private property sets the height or the profile of the effect (^22wbz12). The user accepted this system look on 2026-10-23 (option A of ^22wbz12), and the kit adds nothing to change it. The snapshot images capture the real window from the window server, so they show the edge effect that the system draws. At rest no bar covers a row: the insets of the list grow with the banners of each bar, and a row goes under a bar only when the list is away from that end. A move to an item (the Show Error button, the minimap, the jump commands) puts the item below the top bar: the first scroll places the row from the estimated heights of the lazy stack, so `ConversationView` scrolls to the item again when the list first reports its row in view (^zg9tysk). `ThreadBarBannerOverlapHostedTests` checks the move and the last row at rest above the failure banner and the sign-in card. The content of the two bars has no background.
- **System chrome.** The system decides the look of toolbars, the sidebar, the inspector, sheets, popovers and menus (style.md rule 1). On macOS 27, the toolbar controls are glass groups, and the sidebar has a system gray (D116). The kit puts no background, no material and no visual-effect view on them: no `.toolbarBackground(`, `.toolbarBackgroundVisibility(`, `.containerBackground(`, `.presentationBackground(`, `NSVisualEffectView` or material fill style. The side panel of the kit is the system `.inspector`. No view uses a background color name of `AppKit/NSColor.h`, such as `windowBackgroundColor`, or `Color(nsColor:` or `Color(.` (D111 step 1).
- **Images under the sidebar.** The kit has no image under the sidebar, so it uses no `.backgroundExtensionEffect()` (D111 step 6).
- **Themes (D112).** There is one theme system: the `Theme` protocol of EditorTheme (EditorKit). The default is `SystemTheme`. The host injects the theme with `.editorTheme(_:)`. style.md ("Injection") says that the app injects the theme one time, at the root of each window. The demo injects `.editorTheme(.system)` at the root of its window. The Gallery tab of the demo also injects the theme of the selected Gallery look in its subtree (`galleryLook(_:)` in `GalleryLook.swift`), so that the gallery can show each theme. This second injection is in the demo, not in the kit. The kit sets no theme, has no theme type of its own and has no color constants of its own. A theme colors only the content layer. No view draws an opaque theme fill behind a bar, and no view uses the status bar color or the tab bar color of a theme. EditorKit has no editor background and no gutter background role (^0apj6a2): its editors draw no fill of their own, and a host that wants one adds it. The kit injects no theme, names no theme value and declares no theme type. No view uses a fixed color, such as `Color.red`, `Color(red:`, `NSColor.` or `.foregroundColor(`. Review holds this (EditorKit style.md).
- **Computed palettes (D113 answer 8).** The terminal colors 0 to 15 come from `TerminalPalette`. The colors 16 to 255 come from the xterm 256-color formula (`ANSIText.computedColor(_:)`). A standard formula is not a color constant of the kit.
- **Accessibility.** The tests and the snapshots are light and dark only (EditorKit `style.md` rule 9). No test sets Reduce Transparency or Increase Contrast, and no test compares the Tinted look or the Clear look. Apple tests its own glass, so a kit that follows the style rules gets the system behavior under each of those settings. The user decision of 2026-10-28 ("Remove all RT/IC tests") removed `GlassAccessibilityTests` (AVK-8p), the two snapshot variants of those settings and their reference images, and each other test that set one of them, the contrast checks of the kit logic included.
- **Snapshots and the hidden window.** `HostedSnapshotTests` (AVK-13) generates an image of 12 real views for the review gallery (no reference image is stored or compared): the thread, the idle composer, the composer while the agent runs, the permission card, the request deck in a bar, the session notice, the state banner, the code block, the terminal output and the elicitation form. It captures each view in a real key window on the screen, from the window server, with ScreenCaptureKit (EditorKit `CapturedImage`), and it writes the images as `<name>-light.png` and `<name>-dark.png` (`GeneratedImages`, in the build folder): light mode and dark mode only (EditorKit `style.md` rule 9). `GlassSnapshotTests` (AVK-13) captures 4 glass parts over text in the same way and in the same 2 variants, so its images show the real glass that the system draws: the composer, the composer while the agent runs, the request deck in a bar, and the floating controls of the thread (the pill and the field in one `FloatingGlassContainer`). The screenshots that the user reviews are the key screens of the review gallery (see "The screenshot check"). Each hosted test mounts its view in EditorKit's `HostedViewHarness`, whose window is never on the screen, and no test code sets an activation policy, so a hosted test shows no window and does not take the focus (AVK-12). The capture of EditorKit orders its own window in.
- **The screenshot check (D111 step 8).** There is no manual check (the user decisions of 2026-10-28 for AVK-8u, ^8q34yt8: "no manual checks", and no comparison with Finder or System Settings, because the kit uses the built-in glass effects and Apple tests its own glass). The automated tests take the screenshots, in light and dark only (EditorKit `style.md` rule 9). A run of the integration package (`swift test --package-path IntegrationTests`, §11 decision 21) writes them to the review gallery, `~/Library/Caches/AgentViewKit/screenshot-check/index.html` (EditorKit `style.md` "Review gallery", `ReviewGallery`), and the user reviews that page. No test sets Reduce Transparency or Increase Contrast, and no test compares the Tinted look, the Clear look, Finder, System Settings, Notes or Safari. In the gallery, no content card or header row has a fill, and the list scrolls under the bars. Under the top bars, the screens show the system look that the user accepted on 2026-10-23 (^22wbz12): the rows under the whole bar stack are washed out, and the fade is gradual only near the top of the list.

**Open items.** These items are not done:

- ^m231ph5: a code block showed a white fill behind its text, because the EditorKit text view kept the AppKit default `drawsBackground = true`. EditorKit ^0apj6a2 (on EditorKit main at 69d04fc) answers it: the EditorKit editors are transparent by default. The card ^m231ph5 closes in its own review.

**Native components, not facsimiles.** Streaming text and reasoning use a shimmer. Discrete tool calls use `ProgressView`. Status uses SF Symbols with `.symbolEffect(.variableColor)` while live, `.contentTransition(.symbolEffect(.replace))` on running-to-done, and `.bounce` on completion. Buttons, toggles, menus, sheets, and the inspector are stock controls.

**Match Xcode's restraint.** Prose is SF Pro. Code, tool I/O, and terminals are SF Mono. Color stays neutral. The accent is only for the selection and the focus (the user decision of 2026-10-24, which changes D113 answer 5). Status uses the status roles of the theme. Reasoning is a quiet collapsible block. Tool calls are compact rows that expand. A plan is a checklist.

**Tokens, not hard-coded values.** The shared style of the EditorKit `EditorStyle` target (`\.editorStyle`) holds spacing, the corner radius scale, symbol weight, and density. The kit keeps no copy of it (^7dn35sm). The EditorKit theme gives the style (`Theme.style`), and `.editorTheme(_:)` writes it into the environment. A `.editorStyle(_:)` closer to the content sets a different style. Each rounded shape of the kit takes its radius from the scale, and no corner radius is a number. No token selects the glass: the floating glass is always `.regular` (D113 answer 3). Every color, the code font and the prose font come from the EditorKit theme in `\.editorTheme` (§4, "One theme"). `SystemTheme` is the default. Research R12 (`Docs/decisions/visual-audit.md`) sets the default token values from Xcode 27 and Claude Desktop.

## 6. Accessibility

Accessibility is a default. The kit ships fully accessible. A builder override inherits the duty to keep it.

**Lean on the styling system.** Stock controls emit correct elements. Restyle stock controls before you build custom ones. The kit documents what an override must re-expose: label, value, actions.

**Streaming, made VoiceOver-sane.** Stream silently. Announce at boundaries only: the end of the work of a prompt of this client (the first idle after the echo of the prompt), a tool call gets its result, a request needs an action. The tool result and the request boundaries are each one change of a model value. The end of the work of a prompt comes from the order of the session updates (`Docs/decisions/accessibility.md`). Expose the settled message as the accessible value. Respect Reduce Motion: no glass morphing, no streaming animation. The kit adds no animation to the show and the hide of a glass, so a glass morphs only in an animation of the host (the method of AVK-8ag, §5 "Morphs"). The tests are light and dark only, and no test flips an accessibility setting (EditorKit `style.md` rule 9, §5 "Accessibility"). Honor Dynamic Type throughout. Research R11 checks EditorKit font scaling.

**Long-form reading.** The SwiftUI API is `accessibilityLinkedGroup(id:in:)`. When every element in the group is text, VoiceOver treats the group as one text element, and line, word, and character navigation crosses element boundaries. The transcript uses one linked group per message and one for the thread, so a VoiceOver user reads across rows. `causesPageTurn` is an existing trait, not new in 27. Pair it with `accessibilityScrollAction` on the "load earlier" row for windowed pages (§8).

**Focus and semantics.** Move VoiceOver focus to a permission or elicitation card when it appears, and back to the composer when it resolves. Label tool calls by effect and status. Label diffs by language and change summary. Every interactive element gets a label and, where it acts, an action.

## 7. Composability: sensible defaults plus overridable subcomponents

Every composite view ships a working default and lets you swap its parts through builder slots. The mechanism is a generic slot per part plus a constrained-extension overload that supplies the default, so the short init compiles.

```swift
public struct PromptInputView<Editor: View, Accessory: View>: View {
    @Binding var text: AttributedString
    let onSubmit: () -> Void
    @ViewBuilder var editor: (PromptEditorContext) -> Editor
    @ViewBuilder var accessory: () -> Accessory
}

public struct PromptEditorContext {           // what the kit hands whatever editor you pass
    public let text: Binding<AttributedString>
    public let placeholder: String
    public let onSubmit: Submit
    public let onSendNow: Submit
    public let onCancel: Submit?               // nil while the user cannot cancel
    public let commands: [AvailableCommand]?   // SessionModel.availableCommands, for the slash completion source
}

extension PromptInputView where Editor == EditorKitPromptEditor, Accessory == DefaultPromptAccessory {
    public init(text: Binding<AttributedString>, onSubmit: @escaping () -> Void) { /* defaults */ }
}
extension PromptInputView where Accessory == DefaultPromptAccessory {
    public init(text: Binding<AttributedString>, onSubmit: @escaping () -> Void,
                @ViewBuilder editor: @escaping (PromptEditorContext) -> Editor) { /* … */ }
}
```

Use the explicit `editor:` label. A bare trailing closure binds to the last slot. Keep defaulted slots few. The composer reads the session model from the `sessionModel` environment value and calls it directly (§3.4).

`CodeBlockView` and `DiffView` default the other direction: they default to EditorKit, with a `code:` slot for a custom renderer. Higher-level composites forward their slots down, so a substitution is chosen once. Use constrained-extension overloads, not default arguments. The typed override modifiers in §3.6 are the same principle at the thread level.

## 8. Rendering in a loop: LazyVStack at scale

The thread is a long, append-heavy list in `ScrollView { LazyVStack { ForEach … } }`. The failure mode is re-diffing the whole list on every token.

- **Stable identity.** Rows key off `TranscriptEntry.id`. Never the index. Never a fresh `UUID()` per render.
- **Fine observation.** Each entry is its own `@Observable` object of the session model. A streamed chunk changes only its entry, so only the row that reads that entry draws again. The list body reads only the ids of the transcript, and each row reads its entry. The kit keeps no stream copy of the text: the row reads the `content` of the entry.
- **Coalescing is the model's work.** The session model applies the chunk buffer at display rate (`defaultCoalescingCadence`, 33 ms, §3.2). The kit adds no second coalescer.
- **Scoped state.** No single property drives the whole screen. Observation tracks each property of the model, so a `usage_update` or a `config_option_update` does not invalidate the list. Each banner and each card reads only its part of the model.
- **Equatable rows.** Rows conform to `Equatable` with a small equality input and apply `.equatable()`.
- **Precompute, never in body.** Parse settled markdown, highlight code, and format times when the change arrives. Cache in the view layer, keyed by the entry id.
- **Paragraph split for Textual.** Settled paragraphs render once. Only the streaming paragraph re-parses. Without this, Textual re-parses the whole message per token.
- **Streaming balancer.** `StreamingMarkdownBalancer` closes a dangling `**` or `[` in the trailing paragraph, detects an open code fence, and routes the fence body to the EditorKit append path. Settled paragraphs are never touched.
- **Cache the code block per fence.** The EditorKit code-block hook caches one `EditorModel` per fenced-block id. A streaming tail re-render never relayouts a settled code block.
- **Windowing.** `LazyVStack` cells persist, so a long thread grows memory. Window older entries behind a "load earlier" row. `List` stays a documented escape hatch behind a flag.
- **Scroll anchoring.** `ScrollAnchorManager` tracks pinned-to-bottom with a tolerance, restores an item anchor across updates, drives the scroll-to-bottom pill with a new-message count, and coalesces auto-scrolls during streaming. Use `onScrollTargetVisibilityChange`, not absolute offsets.
- **Heavy text out of the cells.** Code, diffs, and terminals render inside EditorKit. Prose is cached. Cells stay thin.

## 9. Component inventory

Source: native (build on stock), reuse (existing library), net-new (agent-grade, build).

**A. Thread**
- `AgentThreadView`: the drop-in. Binds a `SessionModel`, and the `ConnectionModel` when the host gives it, and renders the whole surface except the request cards. Its top bar (`.safeAreaBar(edge: .top)`) holds, from the top, the `AgentInfoHeader`, the `AgentConnectionBanner`, the `SessionNoticeBanner` and the `SessionStreamBanner`, with no background (D112 (e)). The `AgentInfoHeader` floats on `.regular` glass (`floatingGlass()`), the same as the conversation header in Messages; the banners are content with no glass; the conversation scrolls under the bar and the toolbar, with the scroll edge effect (D113 answer 7). AppKit makes the top effect as tall as the whole top inset, so the rows under the bar stack are washed out, with a gradual fade only near the top of the list; the user accepted this system look on 2026-10-23 (^22wbz12). Its bottom bar (`.safeAreaBar(edge: .bottom)`) holds, from the top, the `StateBanner`, the sign-in card and the composer slot, in one `GlassEffectContainer` with the scroll-to-bottom pill (D110 (c)); the conversation scrolls under the bar (D113 answer 7). The pill is an overlay that floats over the list above the bar and takes no space in the bar, so the bottom inset of the list does not depend on the pin state (^66has33). The composer slot is directly below the conversation (D36). The default slot is `DefaultThreadComposer`. The app puts a `RequestDeck` in the slot above the composer, or next to the view. *net-new*
- `ConversationView`: container with auto-scroll, scroll-to-bottom, empty state. *native*
- `MessageActions`: copy, copy thread, export, retry, edit, in a footer. *native*
- `ThreadMinimapView`: scrubbable rail of the transcript entries, with the tool call status. *net-new*
- `StateBanner`: shows `requiresAction`, an idle session with a pending request, and a stop reason that needs attention (`max_tokens`, `refusal`, `max_turn_requests`, and the extension stop reasons). *net-new*
- `SessionStreamBanner`: the replay marker, the partial-history note, the missed-updates banner with Reload, the reload-failed banner with the error of the reload and Reload, and the closed state. *net-new*
- `SessionNoticeBanner`: one banner for each notice of the session model. *net-new*
- `SessionListView`: sessions from `ConnectionModel.sessions` with title and updated time, cursor paging. *net-new*

**A2. Entry views (one per `TranscriptEntry` case, each overridable). Each component has one entry in this inventory. Groups B and C give detail for two of these.**
- `UserMessageView` and `AssistantMessageView`: content-block based, share `MessageActions`. *net-new*
- `ReasoningView`: see group B. `ToolCallView`: see group C.
- `CompactionEntryView`: marks a context compaction at its position, with its status and its summary. *net-new*
- `UnknownItemView`: collapsible raw view for any unknown entry or content block. *net-new*
- `ErrorView`: the card of an error entry, with its JSON-RPC code, its message, and its data. *net-new*
- `ContentBlockView` family: text (Textual), image, audio, resource link (`LPLinkView` card), embedded resource, unknown. *native and net-new*

**B. Streaming content**
- `ResponseView`: paragraph-split Textual with the balancer and the EditorKit code-block hook. *reuse plus balancer*
- `CodeBlockView`: copy, filename, language; EditorKit read-only. *EditorKit*
- `MathView`: inline and block LaTeX. *net-new on a math engine*
- `ReasoningView`: collapsible; shimmering title while in progress; auto-collapse on done. *net-new*
- `ActivityIndicator` and `ShimmerView`. *native, net-new*

**C. Agent activity**
- `ToolCallView`: title, kind icon, status, locations, raw input and output, collapsible content. Status uses symbol effects. *net-new*
- `TerminalView`: agent-owned terminal from `terminal_update` and `terminal_output_chunk`; command, cwd, exit status; ANSI handling per research R7. *net-new*
- `DiffView`: hosts EditorKit's unified-diff view (§4.1); adds the per-file list with counts, accept or reject per hunk, and attach selected lines to the prompt; `git_patch` or structured input. *EditorKit for the render, net-new for the chrome*
- `TaskListView`: the checklist of a plan entry; priority and status including cancelled. *net-new*
- `ActivityTimeline`: thoughts, tool calls, terminals, and errors in transcript order. *net-new*
- `SourcesView` and `InlineCitation`. *net-new*
- `ContextUsageView`: the context usage meter from `SessionModel.usage`, with the cost. *net-new*
- `AgentGraphView`: multi-agent canvas. *post-v1*

**C2. Infrastructure (non-visual)**
- `StreamingMarkdownBalancer`, `ScrollAnchorManager`, `ExpandedBlocksStore`. *net-new*
- `AgentCommands`: the kit verbs as EditorKit commands with a default keymap. *EditorKit*
- `GrammarBundle`: TextMate grammars for the top agent languages. *net-new*

**D. Input**
- `PromptInputView`: hosts EditorKit; slash commands from `availableCommands`; chips; `@file`; attachments; submit or cancel with status; tool toggles; mic. Editor and accessory are slots. *net-new*
- `ConfigOptionsView`: the picker for `configOptions`, grouped by category: mode (permission mode), model, model config, thought level, and booleans. Replaces a bespoke model picker. *net-new*
- `SuggestionsView`, `SpeechInputButton`. *native, reuse*

**E. Human-in-the-loop**
- `PermissionView`: renders a `PendingPermissionRequest` of a `SessionModel`. Shows the required title, the description, and the subject: a tool call, or a command with its cwd. Options come from the request. The four ACP kinds (allow once, allow always, reject once, reject always) are the v1 bar. A directory-scoped grant ("always for this folder") is not on the ACP wire, and no agent sends it (`Docs/decisions/permission-ux.md`). When the subject has a `terminalId`, the card links to the related `TerminalView`. Adds a deny-with-comment field (§3.4). Offers "switch to auto" when the mode config option exists. *net-new*
- `PermissionModePicker`: the `mode` config option as a segmented control. *net-new*
- `RequestDeck`: the deck of the pending requests of a `SessionModel`, or of the request-scoped elicitations of a `ConnectionModel`. It is a component of its own, next to the thread view and the composer. *net-new*

**E2. Connections and authorization (§12)**
- `AgentConnectionBanner`: the banner of `ConnectionModel.state`. *net-new*
- `AgentInfoHeader`: the name and the version of the agent from its `initialize` answer. *net-new*
- `AgentAuthView`: an ACP agent's `AuthMethod`s: `agent` calls `login(_:)`; `terminal` runs through the host `terminalAuthRunner`; a sign-out control calls `logout(_:)`. *net-new*
- `ConnectionsView`, `ConnectionRow`, `ConnectionStatusChip`: the MCP servers of a session and their status. *net-new*
- `AuthorizationPresenter`: wraps `ASWebAuthenticationSession`. *net-new*

**E3. Elicitation (§13)**
- `ElicitationView`, the `ElicitationFieldView` family, `ElicitationURLConsentView`. *net-new*

**F. Artifacts and attachments**
- `AttachmentView`, `AttachmentInspector`, `ArtifactView`, `CommandOutputView`, `LinkView`, `ImageView`, `AudioPlayerView`. *native and net-new*

## 10. What we port, adapt, and skip

- **Port:** the component taxonomy (Vercel AI Elements) and views that bind to one runtime (assistant-ui).
- **Adapt:** HITL (CopilotKit) to `PermissionView`; composability via slots with default overloads.
- **Skip:** React-Flow canvas (use SwiftUI `Canvas`, later); shadcn theming (use Liquid Glass and tokens); copy-to-codebase (ship a real package); web voice stacks; third-party highlighters (use EditorKit); embedded web preview (open the browser); SwiftStreamingMarkdown (cannot host EditorKit).

## 11. Decisions

1. **Distribution: a standalone open-source SPM package with two library products, `AgentViewKit` and `AgentViewKitStyle`.** The `AgentViewKitStyle` target holds the shared look of the view kits: the content tile, the selectable surface and `SurfaceCorners`, the shared symbol table `SharedSymbol`, `StatusSymbolImage`, `StatusBar` (with `StatusBar.Message` and `StatusBar.Action`), `ToolCallLocationChips`, `ChipFlowLayout`, `DiffFileChip`, `DiffSummary`, `EditorKitDiffRenderer`, `DiffLayout` and `\.diffLayout`, and `AgentScopeKind.toolCall`. It links only EditorKit products (`EditorStyle`, `EditorTheme`, `EditorSwiftUI`, `EditorDiff`, `EditorCommands`). It links no ACP package, no Textual and no swiftui-math. The `AgentViewKit` target holds the views and the ACP helpers. It depends on `AgentViewKitStyle`, FoundationModelsACPClient, FoundationModelsACP, EditorKit (branch `main` until it tags), Textual, and swiftui-math. It re-exports `AgentViewKitStyle` and keeps no copy of it. SnapshotViewKit and KanbanViewKit link only `AgentViewKitStyle`. No target imports FoundationModels, FoundationModelsRouter or FoundationModelsExtras. The owner decided on one product on 2026-10-02 (`Docs/decisions/acp-client-kit.md`). The owner decided on 2026-10-28 that AgentViewKit is the shared visual layer of the view kits, and added the `AgentViewKitStyle` product for it. Two more library products, `AgentViewKitTestSupport` and `AgentViewKitDemoSupport`, are test support only: the nested `IntegrationTests/` package links them by path, because a test target cannot be a dependency (decision 21). No host links them.
2. **Binding: the views bind directly to `ConnectionModel` and `SessionModel` of FoundationModelsACPClient (§3).** The kit has no session model, no adapter and no snapshot renderer of its own. The binding rule is in `Docs/decisions/acp-client-kit.md`.
3. **The model shape follows ACP v2.** The client models fold the v2 update stream with three-state patches, replace, and clear. Every enum has an `unknown` case that renders.
4. **Pending requests are model state, not items.** `SessionModel.pendingPermissions`, `SessionModel.pendingElicitations` and `ConnectionModel.pendingElicitations` hold them. The cards read them and call the reply methods. The kit keeps no copy and no answered flag.
5. **Content that ACP does not model is not in v1.** There is no `schemaName` catalog and no structured item. An unknown update or block renders as a collapsible raw view. Branches, checkpoints, subagents and compaction markers are removed until ACP gives a producer. The kit shows the `CompactionEntry` rows and the `SessionNotice` banners that the client model gives.
6. **Cancel calls the model.** The Stop button and Esc call `SessionModel.cancel(meta:)`, which sends `session/cancel`.
7. **Math: a native `MathView` in v1** on swiftui-math, the Core Text engine that research R9 chose (`Docs/decisions/math-engine.md`).
8. **Selection: per-message plus copy thread in v1.** Cross-message drag-select is deferred unless research R10 shows macOS 27 `textSelection` gives it in containers.
9. **Streaming path: Textual with paragraph split and the balancer.** No fallback renderer unless research R1 fails.
10. **Long threads: `LazyVStack` with windowing.** `List` behind a flag.
11. **Design tokens: EditorKit themes are the themes of the kit.** Every color and each font come from the EditorKit `Theme` in `\.editorTheme` (`SystemTheme` by default). The fonts are the three EditorKit font roles: `uiFont` for the chrome, `displayFont` for the prose, the composer and the text fields, and `codeFont` for the code. The shared style of the EditorKit `EditorStyle` target holds only spacing, the corner radius scale, symbol weight, and density (^7dn35sm and KanbanViewKit plan.md decision 18 replaced the kit `AgentTheme` with `EditorStyle`; decision of 2026-10-11 for `AgentTheme`; the prose font moved to the EditorKit `proseFont` role at EditorKit 95ef6c4; EditorKit ^wg1hac2 replaced `editorFont` and `proseFont` with the three font roles, decision of 2026-10-23; D113 answer 3 removed the material level).
12. **Diff rendering is an EditorKit capability.** EditorKit takes unified diff text and renders it. The kit hosts it in `DiffView` and adds only the file list and the review actions. The kit does not build a stand-in.
13. **Grammars ship in the kit** until EditorKit links more.
14. **The kit verbs are EditorKit commands.** Palette, keybindings, and progress come from the command system.
15. **No subagent tree in v1.** ACP has no subagent producer. The canvas graph is post-v1.
16. **Config options replace the model picker and the mode picker.** One `ConfigOptionsView`, grouped by category.
17. **Reasoning binds to first-class data:** the `ThoughtEntry` objects of the session model, from `agent_thought_chunk`.
18. **Authorization and connections (§12):** the kit shows the auth methods of the agent and the MCP server status that the agent reports; the agent authorizes. App sign-in is the host's job.
19. **Elicitation (§13):** form mode as a schema-driven form; URL mode as a consent card. Both in v1.
20. **ACP version:** v2 only. The kit accepts only protocol version `2`. `SupportedProtocolVersions` holds the list, and `ConnectionModel.initializeCheckingProtocolVersion(_:)` refuses each other version with one error that names both versions. There is no v1 adapter, because the wire package has no v1 surface. Claude Code, Codex, Gemini CLI, Zed, and Xcode 27 speak v1 today. Research R6 records the survey and the reasons in `Docs/decisions/acp-version.md`.
21. **Test tiers: the unit tests in the root package, the hosted and capture tests in a nested `IntegrationTests/` package** (user decision of 2026-10-29, ^f89p8k). The root `swift test` is unit-only: no test mounts a view in a window, an `NSHostingView` or EditorKit's `HostedViewHarness`, and no test captures a window. It is the per-card gate. `swift test --package-path IntegrationTests` runs the hosted, snapshot and review gallery tests, once per batch and in the integration job of CI. No test reads or measures the pixels of a capture (user decision of 2026-10-31): the images exist only so that a person can look at them. The folder, the nested package and its one test target are all named `IntegrationTests`, with no kit prefix (user rule). The nested package depends on the root package by path and links the test support products `AgentViewKitTestSupport` and `AgentViewKitDemoSupport` (decision 1), so a fixture of both tiers lives once in `AgentViewKitTestSupport`. This is the shape of EditorKit and TestudoApp.

## 12. Authorization and connections

Four distinct things, kept distinct:

1. **App sign-in.** Out of scope. The host's job.
2. **Agent authentication.** An ACP agent advertises `AuthMethod`s at `initialize`. `ConnectionModel.authState` tells if a sign-in is necessary. The `agent` method goes through `auth/login` with `ConnectionModel.login(_:)`. The `terminal` method must not go through `auth/login`: the client runs the configured agent program as a separate interactive process, with the extra `args` and `env` of the method. `ConnectionModel.loginWithTerminal(_:runner:)` does that with the `terminalAuthRunner` of the host. After a terminal sign-in, `authState` is `.reconnectRequired`, and the Reconnect button calls the `agentReconnect` hook of the host. `AgentAuthView` renders both methods and a sign-out control that calls `logout(_:)`. A request-scoped elicitation of `auth/login` shows through `RequestDeck(connection:)`.
3. **MCP servers of a session.** The agent connects to the MCP servers and reports their status. `ConnectionsView` lists `SessionModel.mcpServers` with the transport and a `ConnectionStatusChip` for each server (`Docs/decisions/connection-states.md`). A tool call that waits for a server shows a chip inline when the host gives `toolCallConnectionState`. The kit keeps no connection store and no edge table.
4. **Per-action permission.** "Allow this tool to run?" `PermissionView` (§9 E). Separate from connecting.

**Division of labor.** The kit owns `AuthorizationPresenter`, a thin wrapper over `ASWebAuthenticationSession`. It supplies the `NSWindow` presentation anchor, opens the system browser on a user action, and returns the callback URL. URL mode elicitation uses it (§13.3). Everything else is the agent's: discovery (RFC 9728, RFC 8414, OIDC), client identity, PKCE `S256`, the RFC 8707 `resource` binding, token exchange and refresh, and Keychain storage. `prefersEphemeralWebBrowserSession` is exposed.

**No prior art to port.** None of assistant-ui, Vercel AI Elements, or CopilotKit ships a first-class connection component. This is a differentiator.

## 13. Elicitation

Elicitation is how a server asks the user for input mid-tool-call. It reaches the kit through ACP `elicitation/create` with a `scope`, and the client models keep each request as a `PendingElicitation`:

- A session elicitation is in `SessionModel.pendingElicitations`. One with a `toolCallId` is also linked to its tool call entry (`ToolCallEntry.linkedElicitationIDs`). The tool call view then shows a "Waiting for your answer" status and no form. A press on the status calls `SessionModel.bringToFront(toolCall:)`, and the `RequestDeck` shows the card at the front.
- A request-scoped elicitation (for example of `auth/login`) is in `ConnectionModel.pendingElicitations`, with its `requestId` and its `requestMethod`.

`RequestDeck` shows one card for each request. The card calls the reply methods of the model that holds the request, through `PendingElicitationOwner`: `acceptElicitation(_:content:)`, `declineElicitation(_:)` or `cancelElicitation(_:)`. The model removes the request when it resolves, so the card goes away with no state of its own. `eventplan.md` in the Multitool repo names AgentViewKit as the presenting layer and lists the URL-mode obligations. They match §13.4.

**The spec** (MCP 2025-11-25). A server sends a `message` and a `mode`.

- **`form`** (default). Carries a `requestedSchema`: a flat object of primitive properties. The response is `accept` with `content`, `decline`, or `cancel`.
- **`url`**. Carries a `url` and an `elicitationId`. The client gets consent and opens the URL safely. The result arrives later via `elicitation/complete`, or the request came from a `-32042 URLElicitationRequiredError`.

### 13.1 Form mode: `ElicitationView`

`ElicitationView(request:owner:)` names the requesting server, generates a field per property, validates locally, and answers with `acceptElicitation(_:content:)` of the owner.

| `requestedSchema` property | Field kind | Default control |
|---|---|---|
| `string` with `minLength`, `maxLength`, `pattern` | text | EditorKit input, single or multi-line |
| `string` with `format: email` or `uri` | text, validated | EditorKit input plus validation |
| `string` with `format: date` or `date-time` | date | `DatePicker` |
| `number` or `integer` with `minimum`, `maximum` | number | stepper, or slider when both bounds exist |
| `boolean` | boolean | `Toggle` |
| `enum` or titled `oneOf` | single-choice | radio group up to 5, menu above |
| `array` with `items.enum` or `items.anyOf` plus `minItems`, `maxItems` | multi-choice | checkbox group |

Each choice normalizes to a `(value, title)` pair. ACP v2 carries `enum`, `oneOf`, and `anyOf`. Legacy `enumNames` is accepted from MCP sources only. `default`s pre-populate. Validation gates Submit: required, lengths, pattern, bounds, item counts, format. A new form shows no field error: a field shows its errors after the user changes it, or after a submit attempt with a form that is not complete, and VoiceOver announces the errors that appear.

**Multiple questions render tabbed.** One chip per property with required and answered marks. The threshold is a configuration point on the layout slot.

**Three actions, always available.** Submit (the default action, last in the row, with the plain style of its place: `.glass` in content and `.bordered` on the deck glass in a bar, never a prominent style (card ^k06v4gt); disabled until valid), Decline, Cancel. Esc maps to cancel. VoiceOver focus moves to the view when it appears.

### 13.2 Composability

Every constituent is a slot, with typed override modifiers for the closed set of field kinds:

```swift
ElicitationView(request: request, owner: session)
    .elicitationTextField         { ctx in EditorKitInput(ctx) }   // default
    .elicitationSingleChoiceField { ctx in MyRadioGroup(ctx) }
    .elicitationMultiChoiceField  { ctx in MyCheckboxes(ctx) }
    .elicitationHeader            { req in MyServerBanner(req) }
    .elicitationLayout            { fields in MyTabStrip(fields) }
    .elicitationFooter            { actions in MyActionBar(actions) }

public struct ElicitationFieldContext {       // what the kit hands each field renderer
    public let schema: ElicitationFieldSchema   // title, description, constraints, format, choices
    public let value: Binding<JSONValue?>       // the field's current answer, as the ACP JSONValue
    public let validation: FieldValidationState // live errors, required, satisfied
}
```

Free text defaults to EditorKit. This is the opposite default from `PromptInputView`, on purpose: one input engine for in-thread text.

### 13.3 URL mode

`ElicitationURLConsentView` shows the server, the message, and the full URL with the domain highlighted. It warns on Punycode or ambiguous hosts. On consent it opens the system browser through `AuthorizationPresenter`. It never auto-opens or pre-fetches. It answers `accept` for consent to open. The client model then keeps the request in `awaitingURLCompletions` until `elicitation/complete` by `elicitationId`, and the card shows "Waiting for <host> to finish" with Retry and Cancel. In the waiting state, Cancel stops the browser and the wait, and sends nothing to the agent. A `-32042` error renders the same card.

### 13.4 Security posture

- Form mode never carries secrets. Sensitive collection goes to URL mode.
- Every elicitation names the server and offers Decline and Cancel.
- Validate before sending. No clickable URLs in form fields.
- Open only in the safe system browser, never a `WKWebView`.
- Rate limiting is a runtime concern.

## 14. Research before build

Ordered by design impact. Each item names the question and the method. Each item is done. The result is in the named record or section.

- **R1. Textual streaming cost.** Measure the cost at 50 tokens per second on a 2,000-line message with the paragraph split and the balancer. Decide if the tail needs a lighter renderer. Result: no lighter renderer. With the paragraph split, the p90 cost of one chunk was 3.3 ms at each point of the message. With no split, it was 86 ms, and it grew with the message. A temporary benchmark package measured these numbers. That package is removed. `ParagraphReuseTests` keeps the guarantee: a settled paragraph does not evaluate again when the text grows.
- **R2. Grammar bundle.** List the languages agents emit most. Find MIT TextMate or tree-sitter grammars. Measure size. Decide kit bundle or EditorKit link. Result: `GrammarBundle`.
- **R3. EditorKit unified-diff feature.** Write the feature spec for EditorKit: input is unified diff text; output is inline and side-by-side, with gutter marks, line colors, and hunk folding. Result: the `EditorDiff` product of EditorKit (`Docs/decisions/diff-renderer.md`).
- **R4. Observation granularity.** Measure the redraws of the transcript view while chunks stream into one agent message of a `SessionModel`. Result: each row binds directly to its `TranscriptEntry` object, so a chunk draws again only the row of its entry (§8). For 1,000 chunks into one message, the p90 wall clock was 209 ms with the default cadence of 33 ms, and 10.9 s with the cadence zero. A temporary benchmark package measured these numbers. That package is removed. `SessionModelRedrawScopeTests` keeps the guarantee: 100 chunks into one agent message of a transcript of 10 rows evaluate the row of that message only.
- **R5. Runtime contract.** Decided: the contract is ACP. The client models of FoundationModelsACPClient are the runtime surface (§3, `Docs/decisions/acp-client-kit.md`). There is no `schemaName` catalog to agree with a runtime.
- **R6. ACP version.** List which agents speak v1 and which speak v2 today. Decide on a v1 adapter. Decided: v2 only (`Docs/decisions/acp-version.md`).
- **R7. Terminal output.** Pick an ANSI and VT parser, or strip escapes. Check licenses. Result: `ANSIText`.
- **R8. Permission and mode UX.** Map Claude Code, Cursor, and Codex option sets onto ACP options and config options. Result: `Docs/decisions/permission-ux.md`.
- **R9. Math engine.** Test Textual `.math`, SwiftMath, and iosMath on inline and block spans in a streaming paragraph. Result: `Docs/decisions/math-engine.md`.
- **R10. Text selection.** Test `textSelection` on a `LazyVStack` of Textual views on macOS 27. Result: `Docs/decisions/text-selection.md`.
- **R11. Dynamic Type and accessibility.** Prototype `accessibilityLinkedGroup` across lazy rows. Set the VoiceOver cadence. Check EditorKit font scaling. Result: `Docs/decisions/accessibility.md` and `Docs/decisions/dynamic-type.md`.
- **R12. Visual audit.** Capture Xcode 27 and Claude Desktop screens. Set the defaults of the layout tokens (now `EditorStyle.default`). Result: `Docs/decisions/visual-audit.md`.
- **R13. Checkpoints.** Decided: no checkpoints in v1. ACP has no stable checkpoint producer (`session/fork` is unstable), and the kit keeps no rewind model of its own. `Docs/decisions/checkpoints.md` is not current.
- **R14. Subagent data.** Decided: no subagent tree in v1. ACP has no subagent producer, and the kit does not read Router events or AG-UI events. `Docs/decisions/subagent-source.md` is not current.
- **R15. Attachments.** Find what each kind of file becomes in an ACP prompt. Result: `Docs/decisions/attachment-types.md`.
- **R16. Usage model.** Decided: the kit shows `SessionModel.usage`, the last ACP `usage_update`, with its cost. `Docs/decisions/usage-model.md` is not current.
- **R17. Compaction UX.** Decided: the kit shows the `CompactionEntry` of the client model as a row at its position, with its status and its summary (`CompactionEntryView`). The transcript keeps the full history, so the kit has no rewrite marker. `Docs/decisions/compaction-ux.md` is not current.
