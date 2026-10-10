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

The agent runs in a subprocess (`AgentProcess` of FoundationModelsACPClient), or in the same process through `InProcessAgent` (§3.9).

**The dependencies.** The direct dependencies are FoundationModelsACPClient, FoundationModelsACP, EditorKit, Textual and swiftui-math (`Docs/decisions/dependencies.md`). FoundationModels, FoundationModelsRouter and FoundationModelsExtras are not direct dependencies. The package has one library product and one library target, `AgentViewKit` (§11 decision 1).

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

**The binding rule** (`Docs/decisions/acp-client-kit.md`, section "Binding rule"). Each view of the kit binds directly to `ConnectionModel`, `SessionModel` and the `TranscriptEntry` objects. A view shows what the model holds, and it calls the methods of the model. The kit keeps no parallel state, no copy of model data, and no logic that the model owns: no turn tracking, no turn order, no queue that waits for a turn, no list of pending requests, no connection state, no session list, and no copy of the usage or of the config options. A view keeps only view state: the open state of a row, the scroll position, the focus, a selection, and the draft of the composer.

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
  | `.compaction` | `CompactionEntry` | the compaction status and its summary (unstable ACP) |
  | `.error` | `ErrorEntry` | `code`, `message`, `data` |

  Each entry object also has `meta`. A streamed chunk changes only its own entry object. Thus only that row draws again.
- **Chunk buffer.** The model keeps `agent_message_chunk` and `agent_thought_chunk` updates in a buffer. It applies the buffer at display rate (`defaultCoalescingCadence`, 33 ms), so the entry of a streamed message changes one time for each flush. Each other update applies the buffer first, so the order stays the arrival order. `flushPendingChunks()` applies the buffer at once. `updateTap()` gives each raw `SessionUpdate` at its arrival, for a consumer that is not a view.
- **Row identity.** `TranscriptEntry.id` is a `TranscriptEntry.ID`: `.wire` with the `SessionEntry.ID` for an entry from the wire, or `.local` with a `UUID` for an entry that the client made. The identity does not change when a local user message gets its `messageId`. **The views use `TranscriptEntry.id` as the row identity**, not `SessionEntry.ID` and not `MessageId`. A thought and an agent message with the same `MessageId` are two entries.
- **Last-value state:** `availableCommands` (an optional array of `AvailableCommand`), `configOptions` (an optional array of `SessionConfigOption`), `usage` (an optional `UsageUpdate`), `agentState`, `sessionInfo` (a `SessionInfoUpdate` with the title and `updatedAt`, folded as a patch) and `mcpServers` (an array of `MCPServerItem`).
  - `agentState` is an optional `StateUpdate`: `.running`, `.idle` with an `IdleStateUpdate` that has an optional `stopReason`, `.requiresAction`, and `.unknown` with the wire string and the raw `JSONValue`.
- **Notices (unstable ACP):** `notices` is an array of `SessionNotice`, in arrival order. A notice is not in the transcript, and no replay gives it again. `dismissNotice(_:)` removes one notice. The start of a resume and the close remove all notices.
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
- **The open set.** `openSessions` is a dictionary from `SessionId` to `SessionModel`. `session(for:)` gives the model of one open session, or `nil`. `sessions` is the session list, not the open set.
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

There is no `isStreaming` flag on a view, and no turn of the kit. `SessionModel.agentState` tells if the agent runs. A `ToolCallEntry` with the status `inProgress` still runs. The shimmer (§5) and `ActivityIndicator` are functions of these model values.

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
- **Composer:** each submit calls the prompt helper of `SessionModel` at once, also while the agent runs. The pending user message shows at once. The composer keeps no queue and waits for no turn. Esc and the Stop button call `cancel(meta:)`.
- **Prompt capabilities:** the composer reads `ConnectionModel.agentCapabilities` at each submit. An image goes out only when the agent advertises `image`. A file goes out as an embedded resource when the agent advertises `embeddedContext`, else as a resource link.
- **Error rows** come from the model. The kit keeps no error list. For a failed request that the kit did not send through the model, the kit calls `appendError(code:message:data:)`.
- **Login on error `-32000`:** while the last entry of the transcript is an error entry with the code `-32000` (authentication required), `AgentThreadView` shows `AgentAuthView` for the auth methods of the connection model.
- **Agent state and stop reasons:** `StateBanner` shows `.running`, `.idle` with its stop reason, and `.requiresAction`. It shows a banner with clear text for each extension stop reason that the kit knows (`_truncated`, `_ended_in_reasoning`, `_repeated`, `_reasoning_limit`, `_error`, `_no_output`, `_stalled`), and a general banner with the raw value for each other unknown value. It shows a general state for `.unknown`.
- **Background runs:** after the streamed answer, the agent keeps `agentState` at `.running` until its background runs end. The transcript shows each entry of the model in its order, also a second agent message, and the state banner shows `.running` until `.idle`. The kit adds no logic for this order.
- **Resume:** a resume sends `replayFrom: .start`. `SessionStreamBanner` shows a marker while `isReplaying` is true, and a "history can be partial" note from `history`. It does not tell the user that the history is complete.
- **Missed updates:** when `hasMissedUpdates` is true, `SessionStreamBanner` shows a banner with a "Reload" action. The action resumes the session again with `replayFrom: .start`. The client model clears `hasMissedUpdates` only after a successful `.start` replay.
- **Closed thread:** `SessionStreamBanner` shows a closed state when `isClosed` is true, and the composer is disabled.
- **Close:** when the host gives the connection model, `AgentThreadView` calls `ConnectionModel.close(_:)` when the view goes away, if `canCloseSessions` is true and the session is not closed.
- **Terminal view:** shows the computed `text` of the terminal entry.
- **Plan view:** reads the plan entry at its position in the transcript.
- **Tool call view:** selects the registry view by `name` and shows `title` as the label. It shows the structured `Diff.changes` of a diff in `DiffView`, and a linked elicitation next to its tool call (a session elicitation with a `toolCallId`).
- **Session picker:** `SessionListView` binds to `ConnectionModel.sessions`, with "load more" when `hasMoreSessions` is true.
- **Capabilities:** each action hides when its capability flag is false.
- **Connection banner:** `AgentConnectionBanner` shows `ConnectionModel.state` (`Docs/decisions/connection-states.md`). `AgentInfoHeader` names the agent from the `initialize` answer.

### 3.9 The agent in this process

`InProcessAgent.makeConnection(serving:)` runs an ACP agent in the process of the app. It pairs an `InMemoryTransport`, serves the agent on one end with an `AgentSideConnection`, and connects a new `ConnectionModel` on the other end. The two sides speak the real ACP wire. The helper returns the connection model and keeps no state of its own. The kit does not import an agent: the app gives it, for example the `RoutedACPAgent` of FoundationModelsACPAgent.

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
- **Commands.** The kit verbs (send, cancel, approve, jump to item, copy thread) register as EditorKit `Command`s with a default keymap. The host's palette and keybindings editor pick them up. `ProgressCenter` backs tool-call progress.
- **Theme bridge.** `AgentTheme` (§5) produces an EditorKit `Theme`, so code colors match the chrome. EditorKit can also import Zed, VS Code, and tmTheme files.

Boundary: EditorKit's `EditorIntelligence` and `EditorServices.MCPClient` are editor features. The kit does not duplicate them.

### 4.2 Dependency: Textual

Textual renders message bodies, plain text, and streaming responses. It is pure SwiftUI, so it sits in the `LazyVStack` rows and inherits Dynamic Type and accessibility. Its `CodeBlockStyle` is the one seam to EditorKit. Its `.math` extension detects `$…$` and `$$…$$` spans and routes them to `MathView`.

Textual has no streaming mode. Each update re-parses the whole input. So the kit never feeds a whole message during streaming. It feeds settled paragraphs once, and the streaming paragraph alone (§8). Research R1 measures this.

The cost of pure SwiftUI prose is transcript-wide selection. See decision 8.

## 5. Default styling: make it look like Apple shipped it

Out of the box, the kit reads as the Coding Intelligence assistant in Xcode 27: chat with plan artifacts, compact tool rows, and a usage ring.

**Liquid Glass, used correctly.** Glass is for chrome, never content. The composer bar, floating action clusters, the picker, toolbars, and the inspector use `GlassEffectContainer`, `.glassEffect(.regular, in:)`, `.buttonStyle(.glass)`, and `.buttonStyle(.glassProminent)` for primary actions. `.glassEffectID(_:in:)` with a `@Namespace` morphs the composer into a tool tray. macOS 27 adds no new glass API. Use the existing `appearsActive` environment value to dim chrome when the window is inactive. Never stack glass on glass. Research R12 sets the default token values from Xcode 27 and Claude Desktop captures.

**Native components, not facsimiles.** Streaming text and reasoning use a shimmer. Discrete tool calls use `ProgressView`. Status uses SF Symbols with `.symbolEffect(.variableColor)` while live, `.contentTransition(.symbolEffect(.replace))` on running-to-done, and `.bounce` on completion. Buttons, toggles, menus, sheets, and the inspector are stock controls.

**Match Xcode's restraint.** Prose is SF Pro. Code, tool I/O, and terminals are SF Mono. Color stays neutral. Tint is for primary actions and status. Reasoning is a quiet collapsible block. Tool calls are compact rows that expand. A plan is a checklist.

**Tokens, not hard-coded values.** A public `AgentTheme` holds spacing, radii, material levels, symbol weights, accent, and density. Apply it with `.agentTheme(_:)`. It also yields an EditorKit `Theme`.

## 6. Accessibility

Accessibility is a default. The kit ships fully accessible. A builder override inherits the duty to keep it.

**Lean on the styling system.** Stock controls emit correct elements. Restyle stock controls before you build custom ones. The kit documents what an override must re-expose: label, value, actions.

**Streaming, made VoiceOver-sane.** Stream silently. Announce at boundaries only: the agent state goes to idle, a tool call gets its result, a request needs an action. Each boundary is one change of a model value (`Docs/decisions/accessibility.md`). Expose the settled message as the accessible value. Respect Reduce Motion: no glass morphing, no streaming animation. Honor Dynamic Type throughout. Research R11 checks EditorKit font scaling.

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
    public let onCancel: Submit?               // nil while the agent does not run
    public let commands: [AvailableCommand]?   // SessionModel.availableCommands, for the slash completion source
}

extension PromptInputView where Editor == StockPromptEditor, Accessory == DefaultPromptAccessory {
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
- `AgentThreadView`: the drop-in. Binds a `SessionModel`, and the `ConnectionModel` when the host gives it, and renders the whole surface. *net-new*
- `ConversationView`: container with auto-scroll, scroll-to-bottom, empty state. *native*
- `MessageActions`: copy, copy thread, export, retry, edit, in a footer. *native*
- `ThreadMinimapView`: scrubbable rail of the transcript entries, with the tool call status. *net-new*
- `StateBanner`: shows `requiresAction` and a stop reason that needs attention (`max_tokens`, `refusal`, `max_turn_requests`, and the extension stop reasons). *net-new*
- `SessionStreamBanner`: the replay marker, the partial-history note, the missed-updates banner with Reload, and the closed state. *net-new*
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
- `PendingRequestsHost`: one card for each pending request of a `SessionModel`, or each request-scoped elicitation of a `ConnectionModel`. *net-new*

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

1. **Distribution: a standalone open-source SPM package with one library product.** The `AgentViewKit` target holds the views and the ACP helpers. It depends on FoundationModelsACPClient, FoundationModelsACP, EditorKit (branch `main` until it tags), Textual, and swiftui-math. No target imports FoundationModels, FoundationModelsRouter or FoundationModelsExtras. `ImportBoundaryTests` and `ManifestTests` enforce this. The owner decided this on 2026-10-02 (`Docs/decisions/acp-client-kit.md`).
2. **Binding: the views bind directly to `ConnectionModel` and `SessionModel` of FoundationModelsACPClient (§3).** The kit has no session model, no adapter and no snapshot renderer of its own. The binding rule is in `Docs/decisions/acp-client-kit.md`.
3. **The model shape follows ACP v2.** The client models fold the v2 update stream with three-state patches, replace, and clear. Every enum has an `unknown` case that renders.
4. **Pending requests are model state, not items.** `SessionModel.pendingPermissions`, `SessionModel.pendingElicitations` and `ConnectionModel.pendingElicitations` hold them. The cards read them and call the reply methods. The kit keeps no copy and no answered flag.
5. **Content that ACP does not model is not in v1.** There is no `schemaName` catalog and no structured item. An unknown update or block renders as a collapsible raw view. Branches, checkpoints, subagents and compaction markers are removed until ACP gives a producer. The kit shows the `CompactionEntry` rows and the `SessionNotice` banners that the client model gives.
6. **Cancel calls the model.** The Stop button and Esc call `SessionModel.cancel(meta:)`, which sends `session/cancel`.
7. **Math: a native `MathView` in v1** on swiftui-math, the Core Text engine that research R9 chose (`Docs/decisions/math-engine.md`).
8. **Selection: per-message plus copy thread in v1.** Cross-message drag-select is deferred unless research R10 shows macOS 27 `textSelection` gives it in containers.
9. **Streaming path: Textual with paragraph split and the balancer.** No fallback renderer unless research R1 fails.
10. **Long threads: `LazyVStack` with windowing.** `List` behind a flag.
11. **Design tokens: a public `AgentTheme`** that also yields an EditorKit `Theme`.
12. **Diff rendering is an EditorKit capability.** EditorKit takes unified diff text and renders it. The kit hosts it in `DiffView` and adds only the file list and the review actions. The kit does not build a stand-in.
13. **Grammars ship in the kit** until EditorKit links more.
14. **The kit verbs are EditorKit commands.** Palette, keybindings, and progress come from the command system.
15. **No subagent tree in v1.** ACP has no subagent producer. The canvas graph is post-v1.
16. **Config options replace the model picker and the mode picker.** One `ConfigOptionsView`, grouped by category.
17. **Reasoning binds to first-class data:** the `ThoughtEntry` objects of the session model, from `agent_thought_chunk`.
18. **Authorization and connections (§12):** the kit shows the auth methods of the agent and the MCP server status that the agent reports; the agent authorizes. App sign-in is the host's job.
19. **Elicitation (§13):** form mode as a schema-driven form; URL mode as a consent card. Both in v1.
20. **ACP version:** v2 only. The kit accepts only protocol version `2`. `SupportedProtocolVersions` holds the list, and `ConnectionModel.initializeCheckingProtocolVersion(_:)` refuses each other version with one error that names both versions. There is no v1 adapter, because the wire package has no v1 surface. Claude Code, Codex, Gemini CLI, Zed, and Xcode 27 speak v1 today. Research R6 records the survey and the reasons in `Docs/decisions/acp-version.md`.

## 12. Authorization and connections

Four distinct things, kept distinct:

1. **App sign-in.** Out of scope. The host's job.
2. **Agent authentication.** An ACP agent advertises `AuthMethod`s at `initialize`. `ConnectionModel.authState` tells if a sign-in is necessary. The `agent` method goes through `auth/login` with `ConnectionModel.login(_:)`. The `terminal` method must not go through `auth/login`: the client runs the configured agent program as a separate interactive process, with the extra `args` and `env` of the method. `ConnectionModel.loginWithTerminal(_:runner:)` does that with the `terminalAuthRunner` of the host. After a terminal sign-in, `authState` is `.reconnectRequired`, and the Reconnect button calls the `agentReconnect` hook of the host. `AgentAuthView` renders both methods and a sign-out control that calls `logout(_:)`. A request-scoped elicitation of `auth/login` shows through `PendingRequestsHost(connection:)`.
3. **MCP servers of a session.** The agent connects to the MCP servers and reports their status. `ConnectionsView` lists `SessionModel.mcpServers` with the transport and a `ConnectionStatusChip` for each server (`Docs/decisions/connection-states.md`). A tool call that waits for a server shows a chip inline when the host gives `toolCallConnectionState`. The kit keeps no connection store and no edge table.
4. **Per-action permission.** "Allow this tool to run?" `PermissionView` (§9 E). Separate from connecting.

**Division of labor.** The kit owns `AuthorizationPresenter`, a thin wrapper over `ASWebAuthenticationSession`. It supplies the `NSWindow` presentation anchor, opens the system browser on a user action, and returns the callback URL. URL mode elicitation uses it (§13.3). Everything else is the agent's: discovery (RFC 9728, RFC 8414, OIDC), client identity, PKCE `S256`, the RFC 8707 `resource` binding, token exchange and refresh, and Keychain storage. `prefersEphemeralWebBrowserSession` is exposed.

**No prior art to port.** None of assistant-ui, Vercel AI Elements, or CopilotKit ships a first-class connection component. This is a differentiator.

## 13. Elicitation

Elicitation is how a server asks the user for input mid-tool-call. It reaches the kit through ACP `elicitation/create` with a `scope`, and the client models keep each request as a `PendingElicitation`:

- A session elicitation is in `SessionModel.pendingElicitations`. One with a `toolCallId` is also linked to its tool call entry (`ToolCallEntry.linkedElicitationIDs`), and the tool call view shows it next to the call.
- A request-scoped elicitation (for example of `auth/login`) is in `ConnectionModel.pendingElicitations`, with its `requestId` and its `requestMethod`.

`PendingRequestsHost` shows one card for each request. The card calls the reply methods of the model that holds the request, through `PendingElicitationOwner`: `acceptElicitation(_:content:)`, `declineElicitation(_:)` or `cancelElicitation(_:)`. The model removes the request when it resolves, so the card goes away with no state of its own. `eventplan.md` in the Multitool repo names AgentViewKit as the presenting layer and lists the URL-mode obligations. They match §13.4.

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

Each choice normalizes to a `(value, title)` pair. ACP v2 carries `enum`, `oneOf`, and `anyOf`. Legacy `enumNames` is accepted from MCP sources only. `default`s pre-populate. Validation gates Submit: required, lengths, pattern, bounds, item counts, format.

**Multiple questions render tabbed.** One chip per property with required and answered marks. The threshold is a configuration point on the layout slot.

**Three actions, always available.** Submit (`.glassProminent`, disabled until valid), Decline, Cancel. Esc maps to cancel. VoiceOver focus moves to the view when it appears.

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

`ElicitationURLConsentView` shows the server, the message, and the full URL with the domain highlighted. It warns on Punycode or ambiguous hosts. On consent it opens the system browser through `AuthorizationPresenter`. It never auto-opens or pre-fetches. It answers `accept` for consent to open, then waits for `elicitation/complete` by `elicitationId`, with Retry and Cancel always present. A `-32042` error renders the same card.

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
- **R12. Visual audit.** Capture Xcode 27 and Claude Desktop screens. Set `AgentTheme` defaults. Result: `Docs/decisions/visual-audit.md`.
- **R13. Checkpoints.** Decided: no checkpoints in v1. ACP has no stable checkpoint producer (`session/fork` is unstable), and the kit keeps no rewind model of its own. `Docs/decisions/checkpoints.md` is not current.
- **R14. Subagent data.** Decided: no subagent tree in v1. ACP has no subagent producer, and the kit does not read Router events or AG-UI events. `Docs/decisions/subagent-source.md` is not current.
- **R15. Attachments.** Find what each kind of file becomes in an ACP prompt. Result: `Docs/decisions/attachment-types.md`.
- **R16. Usage model.** Decided: the kit shows `SessionModel.usage`, the last ACP `usage_update`, with its cost. `Docs/decisions/usage-model.md` is not current.
- **R17. Compaction UX.** Decided: the kit shows the `CompactionEntry` of the client model as a row at its position, with its status and its summary (`CompactionEntryView`). The transcript keeps the full history, so the kit has no rewrite marker. `Docs/decisions/compaction-ux.md` is not current.
