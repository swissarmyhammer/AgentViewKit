# AgentViewKit: a SwiftUI agent UI component library

Revised 2026-09-08.

**Target:** macOS 27 or later, Apple Silicon, the macOS 27 SDK. No back-deployment.
**What:** the native SwiftUI counterpart to Vercel AI Elements and assistant-ui. A reusable, open-source Swift package with the same posture as the Swift ACP SDK.
**Sources it renders:** a FoundationModels `LanguageModelSession`, the Router runtime, and any ACP agent.

---

## 1. What it is

A component library for agent UIs in SwiftUI. It is not only a chat bubble list. It gives the agent-grade surfaces: streaming responses, reasoning, tool-call activity, terminals, diffs, plans, citations, human-in-the-loop approvals, elicitation, artifacts, config options, and context usage.

The views bind to one observable model, `AgentThread`. Adapters fill that model from each source. This is the runtime-binding idea from assistant-ui, built native. Two consumption levels exist: the drop-in `AgentThreadView(thread)` for the whole surface, and the composable primitives for full control.

The bet: the web has three good answers (Vercel AI Elements, assistant-ui, CopilotKit). SwiftUI has none that are agent-grade. A survey on 2026-09-08 found no SwiftUI package with native tool-call and reasoning views above a few GitHub stars. The gap is real.

## 2. Landscape survey: what exists, what to take

**Vercel AI Elements** (1.9.0, 2026-03). The most complete component taxonomy. Chatbot: Attachments, Chain of Thought, Checkpoint, Confirmation, Context, Conversation, Inline Citation, Message, Model Selector, Plan, Prompt Input, Queue, Reasoning, Shimmer, Sources, Suggestion, Task, Tool. Code: Agent, Artifact, Code Block, Commit, File Tree, Sandbox, Stack Trace, Terminal, Test Results, Web Preview. Voice and Workflow sets. **Take:** the inventory.

**assistant-ui** (0.15, 2026-09). Composable primitives plus a `Thread` drop-in. The key idea is the runtime abstraction: views bind to a runtime, adapters per backend. 0.15 added a tool UI registry, approval parts, and a `ChainOfThoughtPrimitive`. **Take:** the runtime-binding pattern. This is the spine (§3).

**CopilotKit and AG-UI.** Human-in-the-loop as a first-class component. AG-UI added `REASONING_*`, `ACTIVITY_*`, and `SUBAGENT_*` events in 2026. **Take:** HITL as a component. Take the subagent events as a reference shape. Skip the framework.

**Xcode 27 Coding Intelligence** (beta 6). Plan mode with editable Markdown plan artifacts, queued messages, `@` inline annotations, a History slider with Restore, per-response Undo, an agents-and-models picker that accepts any ACP agent, permission settings for allowed commands and tools, skills and slash commands. **Take:** the visual default (§5) and the checkpoint idea.

**Claude Code, Cursor, Codex** (2026). Approval is mode-based: default, accept edits, plan, auto with a circuit breaker. All three ship queued messages, a diff review panel, a context usage meter, and a subagent tree. **Take:** these as the component bar for v1.

**SwiftUI building blocks.**
- **Textual** (gonzalezreal, 0.5.0, macOS 15). The MarkdownUI successor. Pure SwiftUI, GFM, theming, a `CodeBlockStyle` hook, and a `.math` extension. It has no streaming mode and re-parses the whole document on each update. AgentViewKit renders prose through Textual with the paragraph split in §8.
- **SwiftStreamingMarkdown** (Microsoft, 0.7.0). Streams well but does not allow a custom code-block view. It cannot host EditorKit. Not used.
- **EditorKit** (ours). A TextKit 2 code editor and a command system. Renders code, hosts the composer, and supplies commands and keymaps (§4.1).
- **SwiftMath / iosMath / swiftui-math.** Core Text math engines. One is chosen in research R9 (§14).
- **stream-chat-swift-ai** (GetStream, 0.7.0). Chat-centric. Nothing for tools or reasoning. Reuse the composer pattern only.

## 3. Architecture: one thread model, adapters per source

### 3.1 Why not "observe a Transcript"

The earlier plan bound the views to a FoundationModels `Transcript`. The macOS 27 SDK and the sibling repos do not support that:

- `Transcript` is a `struct`. It is not `Observable`. Only `LanguageModelSession` and `SessionPropertyValues` are.
- The Router runtime exposes `SessionProjection`, an `@Observable` class with its own entry model. It writes structured segments to the persisted transcript only, never to the live one.
- ACP agents (Claude Code, Codex, Gemini CLI, any Xcode 27 agent) are peers over ACP. They do not pass through a `LanguageModelSession`. The Swift ACP client exposes `ACPSessionState` and must not import FoundationModels.
- ACP v2 uses whole-record upserts with omit, clear, and replace. The transcript is not monotonic; compaction rewrites it. An append-only renderer cannot show either.
- Pending permission and elicitation are requests the user must answer. The ACP client keeps them as pending observable state. The kit does the same.

So the kit owns the model. The sources feed it.

### 3.2 `AgentThread`, the model the views bind to

`AgentThread` is `@MainActor @Observable`. Its shape follows the ACP v2 update stream, because that stream is the superset of what every source emits.

```swift
@MainActor @Observable
public final class AgentThread {
    public private(set) var items: [ThreadItem]           // ordered, stable ids
    public private(set) var state: ThreadState            // .idle(StopReason?) / .running / .requiresAction
    public private(set) var plans: [PlanID: Plan]
    public private(set) var terminals: [TerminalID: TerminalRecord]
    public private(set) var configOptions: [ConfigOption] // mode, model, thought level, booleans
    public private(set) var availableCommands: [SlashCommand]
    public private(set) var usage: ContextUsage?
    public private(set) var info: ThreadInfo               // title, updatedAt
    public private(set) var pendingPermissions: [PermissionRequest]
    public private(set) var pendingElicitations: [ElicitationRequest]
    public private(set) var pendingAuthorizations: [AuthorizationRequest]

    public func apply(_ change: ThreadChange)              // insert / patch / replace / remove / clear
}
```

The durable `ConnectionStore` (§12) is not on the thread. It is ambient in the environment, because a grant to a server outlives any one thread.

`ThreadItem` is the closed set of things a thread shows. Each case carries a record. Every record is an `@Observable` class that conforms to `ThreadRecord`:

```swift
public protocol ThreadRecord: AnyObject, Identifiable, Observable {
    var id: String { get }              // stable across patches
    var revision: Int { get }           // increments on every patch; row equality is id plus revision
    var meta: JSONValue? { get }        // the source `_meta`, kept unchanged
}
```

A patch mutates the record in place and bumps `revision`. Only the row that reads that record invalidates (§8). The `_meta` field lets an adapter or a host read extension data later (see R14). The cases:

- `.system(SystemPrompt)`. The instructions. Hidden by default, inspectable.
- `.userMessage(Message)` and `.assistantMessage(Message)`. A `Message` holds `[ContentBlock]`: `text`, `image`, `audio`, `resourceLink` (with `icons`), `resource`, `attachment(URL)`, `structured(schemaName, GeneratedContent)`, `unknown`. Each block carries optional `annotations` with `audience` and `priority`. The renderer hides a block whose audience excludes the user, and orders by priority when it must truncate.
- `.reasoning(Reasoning)`. Segments plus an optional signature.
- `.toolCall(ToolCallRecord)`. `title`, `kind` (`read`, `edit`, `delete`, `move`, `search`, `execute`, `think`, `fetch`, `switchMode`, `other`, `unknown`), `status` (`pending`, `inProgress`, `completed`, `failed`, `cancelled`, `lost`, `unknown`), `content` (`[ToolContent]`: `block`, `diff`, `terminal`), `locations`, `rawInput`, `rawOutput`, and host-measured `startedAt` and `endedAt`. The ACP agent emits a custom `_lost` status when a result was lost. It maps to `lost` and renders as its own state. Other custom statuses fall to `unknown`.
- `.structured(StructuredRecord)`. A FoundationModels `.structure` segment that no mapping claimed. Keyed by `schemaName`.
- `.compaction(CompactionMarker)`. The point where a rewrite happened, with the summary.
- `.error(ThreadError)`. A surfaced `LanguageModelError`, an ACP error, or a stop reason that needs attention.
- `.unknown(UnknownRecord)`. Anything the adapter did not recognize. Rendered, never dropped.

Every enum in the model has an `unknown` case. Every switch in the kit handles it.

`ThreadChange` supports insert, patch by id, replace by id, remove by id, and clear. Patches use three-state fields: unchanged, cleared, or a value. This is the ACP `PatchField` rule. It also covers a compaction rewrite.

### 3.3 Sources: adapters that feed the model

A `ThreadSource` fills an `AgentThread`. The kit ships three.

**`SessionThreadSource`** wraps a FoundationModels `LanguageModelSession`. It reads `session.transcript` and `session.isResponding` through observation. It maps:

- `.instructions` to `.system`, hidden by default, inspectable.
- `.prompt` to `.userMessage`. `.text` segments become text blocks. `.attachment` segments become image blocks. `.structure` segments become structured blocks.
- `.response` to `.assistantMessage`, split into paragraph blocks so only the streaming paragraph re-renders (§8).
- `.reasoning` to `.reasoning`. Reasoning is a first-class entry in the macOS 27 SDK.
- `.toolCalls` plus the paired `.toolOutput` to one `.toolCall` per call. Status is derived: a call with no output is `inProgress`. A thrown `ToolCallError` sets `failed`. The SDK gives no status field and no timestamps. The source stamps host times from the `DynamicProfile` hooks `.onPrompt`, `.onResponse`, `.onReasoning`, `.onToolCall`, and `.onToolOutput`. The same hooks feed `ActivityTimeline` (§9 C). When the host does not own the profile, the source falls back to observation of `session.transcript` and stamps the time it sees each entry.
- `@unknown default` to `.unknown`.

During `streamResponse`, the tail comes from `ResponseStream.Snapshot` and goes to a separate `StreamingMessage` observable (§8). Research R4 measures which tail source invalidates least. `session.usage` fills `ContextUsage` (R16). `LanguageModelError` cases become `.error` items (§9 A2). There is no cancel API in the SDK. The host cancels the `Task` and sets `transcriptErrorHandlingPolicy`.

**`RouterThreadSource`** subscribes to `RoutedSession.streamSessionEvents()`, or seeds from `SessionProjection`. It maps `text`, `reasoning`, `toolCall`, and `compaction`. It handles `SessionEvent.elicitationRequested(OperationEvent)` itself, because `SessionProjection` drops that event on purpose. The answer path is `RoutedSession.respond(elicitationId:response:)` for form mode and `RoutedSession.complete(elicitationId:)` for URL mode. Structured segments use `schemaName`, the macOS 27 name. The old `source` name is deprecated.

**`ACPThreadSource`** folds ACP v2 `SessionUpdate`s into the model with `PatchField` rules. The rules already exist in `SessionUpdateAggregator` in the ACP wire package and in `ACPSessionState` in the ACP client package. The mapping is direct:

| ACP message (a `session/update` variant, or a request the client receives) | Thread change |
|---|---|
| `user_message_chunk`, `user_message` | patch `.userMessage` by `messageId` |
| `agent_message_chunk`, `agent_message` | patch `.assistantMessage` |
| `agent_thought_chunk`, `agent_thought` | patch `.reasoning` |
| `tool_call_update`, `tool_call_content_chunk` | upsert `.toolCall` by `toolCallId` |
| `terminal_update`, `terminal_output_chunk` | upsert `terminals` |
| `plan_update` | replace `plans[planId]` |
| `state_update` | set `state`; `idle` carries the `StopReason` |
| `config_option_update` | replace `configOptions` |
| `available_commands_update` | replace `availableCommands` |
| `usage_update` | set `usage` with `used`, `size`, optional `cost` |
| `session_info_update` | patch `info` |
| `session/request_permission` | append to `pendingPermissions` |
| `elicitation/create`, `elicitation/complete` | append to or resolve `pendingElicitations` |
| unknown | append `.unknown` |

The SDK in `../FoundationModelsACP` targets ACP v2 alpha. Upstream stable is v1. Research R6 decides whether a v1 adapter ships too.

**Custom content from FoundationModels sources** rides in `.structure` segments keyed by `schemaName`. The kit defines a catalog for what the SDK does not model: approval, plan, citation, artifact, authorization, usage. Each payload is `Codable` and conforms to the Router's `PersistableStructuredSegment` shape. The names are agreed with `RouterSegmentSchemaNames` so that persisted transcripts round-trip. This catalog is the only extension mechanism for transcript-backed sources. Research R5 (§14) settles who injects each.

### 3.4 Verbs: the only non-model surface

Acting on the thread is a small protocol. The views call it. A source implements it.

```swift
public protocol AgentThreadActions: AnyObject {
    func send(_ input: UserInput) async                                  // text + attachments
    func cancel() async                                                  // stop the current turn
    func respond(to request: PermissionRequest, _ decision: PermissionDecision) async
    func respond(to request: ElicitationRequest, _ result: ElicitationResult) async
    func setConfigOption(_ id: ConfigOptionID, _ value: ConfigValue) async
    func connect(_ request: AuthorizationRequest) async throws           // OAuth handoff, §12
    func login(_ methodId: AuthMethodID) async throws                    // ACP `auth/login`, agent method only, §12
    func runTerminalAuth(_ method: AuthMethod.Terminal) async throws     // relaunch the agent with extra args and env, §12
    func logout() async throws                                           // ACP `auth/logout`, §12
}
```

`cancel` is not derivable. Each source implements it: `Task` cancellation for FoundationModels, `session/cancel` for ACP.

```swift
public struct PermissionDecision {
    public var outcome: Outcome            // .selected(optionId) or .cancelled, the ACP shape
    public var comment: String?            // optional reason, mostly on a rejection
}
```

The wire has no field for a comment. When a comment exists, the source sends it as the next user message after the decision. Claude Code does the same with a deny reason. This works on every source.

### 3.5 In-progress state is derived

There is no `isStreaming` flag on a view. `state` says if the thread runs. A `.toolCall` with `inProgress` still runs. A `.reasoning` item with no following message still thinks. The shimmer (§5) is a function of these, computed from the model.

### 3.6 Views per item kind, each replaceable by a typed modifier

`AgentThreadView` switches over `ThreadItem` internally. You never see the switch. To override, chain a typed modifier named for the kind. Its closure receives the concrete record:

```swift
AgentThreadView(thread)
    .toolCallView       { call in MyToolCall(call) }
    .assistantMessageView { message in MyMessage(message) }
    .reasoningView      { _ in EmptyView() }
```

The open-ended cases get keyed modifiers:

```swift
    .structuredItem("AgentViewKit.Chart") { content in NativeChart(content) }   // by schemaName
    .contentBlockView(for: .resourceLink) { link in MyLinkCard(link) }
    .attachmentView(for: .pdf)            { file in MyPDFPreview(file) }         // by UTType
```

`.structuredItem(schemaName)` matches both a `.structured` thread item and a `structured` content block inside a message, so one registration covers a chart wherever it arrives. Registrations resolve last-writer-wins through the environment. An unregistered `schemaName` falls back to a collapsible pretty-printed `GeneratedContent` view. An unregistered `UTType` falls to the nearest conforming supertype, then to the generic file chip. Nothing is dropped.

**Attachments are per-type.** An `Attachment` is keyed by `UTType`. Defaults: image preview, PDF and QuickLook thumbnail, plain text and markdown via Textual, source code via EditorKit, audio and video player, and a generic file chip. One `AttachmentView` family renders in the composer, in prompts, and in artifacts. What a source accepts differs: FoundationModels takes images only, ACP takes audio, resources, and links. Research R15 finds what the runtime does with other files.

**Click to preview.** Tapping an attachment, artifact, or file output opens it in a trailing `.inspector` with a live `QLPreviewView` and the actions Open, Reveal in Finder, Share, Save, and pop-out Quick Look.

**Snapshot rendering.** `AgentTranscriptView(transcript)` still exists. It builds an `AgentThread` from a `Transcript` value once and renders it. Use it for persisted transcripts. It does not update.

## 4. Building blocks: reuse, do not reinvent

All-Swift, native. No WebView or JSCore anywhere. Links open in the user's browser, optionally shown as an `LPLinkView` card.

| Concern | Use | Why |
|---|---|---|
| Prose and markdown | **Textual** | mature GFM plus theming; a `CodeBlockStyle` hook for EditorKit |
| Streaming balance | `StreamingMarkdownBalancer` (§8) | closes dangling delimiters in the trailing paragraph |
| Code render, diffs, text input | **EditorKit** | one engine for code blocks, diffs, and the composer |
| Commands and keymaps | **EditorKit** `EditorCommands` and `EditorCommandsUI` | the kit verbs are commands; palette and keybindings come free |
| Math | `MathView` on a Core Text engine | inline and block LaTeX (§11, decision 7) |
| Layout and scroll | `ScrollView`, `LazyVStack`, `ScrollViewReader` | scroll anchoring; lazy rows |
| Chrome | Liquid Glass, design tokens | Xcode-assistant look (§5) |
| Activity | shimmer, `ProgressView`, SF Symbols | native affordances (§5) |
| Speech | native `Speech`, the whisper path | voice composer |

### 4.1 Dependency: EditorKit

EditorKit is a TextKit 2 editor over a rope, with a CodeMirror-shaped state algebra, tree-sitter highlighting, and a focus-scoped command system. It is pre-1.0. Pin `branch: "main"`. It targets macOS 15 and Swift 6.2 with strict concurrency and `MainActor` default isolation in UI targets. The kit adopts the same isolation defaults.

What the kit takes from it:

- **Code render.** Fenced code blocks render in an `EditorView` with `isReadOnly`. Textual's `CodeBlockStyle` hands the code and the language hint to the kit, which hosts EditorKit. A code block in prose looks identical to the editor.
- **Grammars.** EditorKit links JSON and Markdown only. Other languages need a host TextMate grammar through `TextMateGrammarRegistry`. The kit ships a grammar bundle for the languages agents emit most (research R2).
- **Diffs.** A unified-diff view is an EditorKit capability. EditorKit takes unified diff text and renders it, inline or side-by-side, with its own gutter marks, line colors, and hunk folding. EditorKit has no diff view today, so this is the first feature the kit asks of EditorKit (research R3). The kit's `DiffView` hosts that view and adds the per-file list with counts and the review actions. Input is `git_patch` text from ACP. When the runtime gives old and new text, the kit computes a unified diff first. The kit does not build its own diff renderer.
- **Streaming code.** EditorKit has no append API. The kit adds a small append helper on `EditorModel.dispatch` with a tail replacement. The balancer (§8) routes an open code fence to this path.
- **Rich input.** The composer hosts EditorKit. Slash commands, chips, and `@file` references are assembled from `TokenField`, `SmartTag`, `CompletionEngine`, `CompletionPopup`, `PathCompletionSource`, and `SingleLineField`. A `SlashCommandSource` completion source is fed by `availableCommands`.
- **Commands.** The kit verbs (send, cancel, approve, jump to item, copy thread) register as EditorKit `Command`s with a default keymap. The host's palette and keybindings editor pick them up. `ProgressCenter` backs tool-call progress.
- **Theme bridge.** `AgentTheme` (§5) produces an EditorKit `Theme`, so code colors match the chrome. EditorKit can also import Zed, VS Code, and tmTheme files.

Boundary: EditorKit's `EditorIntelligence` and `EditorServices.MCPClient` are editor features. The kit does not duplicate them.

### 4.2 Dependency: Textual

Textual renders message bodies, plain text, and streaming responses. It is pure SwiftUI, so it sits in the `LazyVStack` rows and inherits Dynamic Type and accessibility. Its `CodeBlockStyle` is the one seam to EditorKit. Its `.math` extension detects `$…$` and `$$…$$` spans and routes them to `MathView`.

Textual has no streaming mode. Each update re-parses the whole input. So the kit never feeds a whole message during streaming. It feeds settled paragraphs once, and the streaming paragraph alone (§8). Research R1 measures this.

The cost of pure SwiftUI prose is transcript-wide selection. See decision 8.

## 5. Default styling: make it look like Apple shipped it

Out of the box, the kit reads as the Coding Intelligence assistant in Xcode 27: chat with plan artifacts, queued messages, compact tool rows, a history slider, and a usage ring.

**Liquid Glass, used correctly.** Glass is for chrome, never content. The composer bar, floating action clusters, the picker, toolbars, and the inspector use `GlassEffectContainer`, `.glassEffect(.regular, in:)`, `.buttonStyle(.glass)`, and `.buttonStyle(.glassProminent)` for primary actions. `.glassEffectID(_:in:)` with a `@Namespace` morphs the composer into a tool tray. macOS 27 adds no new glass API. Use the existing `appearsActive` environment value to dim chrome when the window is inactive. Never stack glass on glass. Research R12 sets the default token values from Xcode 27 and Claude Desktop captures.

**Native components, not facsimiles.** Streaming text and reasoning use a shimmer. Discrete tool calls use `ProgressView`. Status uses SF Symbols with `.symbolEffect(.variableColor)` while live, `.contentTransition(.symbolEffect(.replace))` on running-to-done, and `.bounce` on completion. Buttons, toggles, menus, sheets, and the inspector are stock controls.

**Match Xcode's restraint.** Prose is SF Pro. Code, tool I/O, and terminals are SF Mono. Color stays neutral. Tint is for primary actions and status. Reasoning is a quiet collapsible block. Tool calls are compact rows that expand. A plan is a checklist.

**Tokens, not hard-coded values.** A public `AgentTheme` holds spacing, radii, material levels, symbol weights, accent, and density. Apply it with `.agentTheme(_:)`. It also yields an EditorKit `Theme`.

## 6. Accessibility

Accessibility is a default. The kit ships fully accessible. A builder override inherits the duty to keep it.

**Lean on the styling system.** Stock controls emit correct elements. Restyle stock controls before you build custom ones. The kit documents what an override must re-expose: label, value, actions.

**Streaming, made VoiceOver-sane.** Stream silently. Announce at boundaries only: turn complete, tool result, action required. Expose the settled message as the accessible value. Respect Reduce Motion: no glass morphing, no streaming animation. Honor Dynamic Type throughout. Research R11 checks EditorKit font scaling.

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
    public let onSubmit: () -> Void
    public let commands: [SlashCommand]       // for the slash completion source
}

extension PromptInputView where Editor == StockPromptEditor, Accessory == DefaultPromptAccessory {
    public init(text: Binding<AttributedString>, onSubmit: @escaping () -> Void) { /* defaults */ }
}
extension PromptInputView where Accessory == DefaultPromptAccessory {
    public init(text: Binding<AttributedString>, onSubmit: @escaping () -> Void,
                @ViewBuilder editor: @escaping (PromptEditorContext) -> Editor) { /* … */ }
}
```

Use the explicit `editor:` label. A bare trailing closure binds to the last slot. Keep defaulted slots few.

`CodeBlockView` and `DiffView` default the other direction: they default to EditorKit, with a `code:` slot for a custom renderer. Higher-level composites forward their slots down, so a substitution is chosen once. Use constrained-extension overloads, not default arguments. The typed override modifiers in §3.6 are the same principle at the thread level.

## 8. Rendering in a loop: LazyVStack at scale

The thread is a long, append-heavy list in `ScrollView { LazyVStack { ForEach … } }`. The failure mode is re-diffing the whole list on every token.

- **Stable identity.** Rows key off the record `id`. Never the index. Never a fresh `UUID()` per render. Equality is the id plus a revision counter.
- **Isolate the streaming tail.** The in-flight message lives in a `StreamingMessage` observable read only by the tail row. Sources coalesce chunks at about 33 ms before they touch it. The `ACPSessionState` cadence is the reference.
- **Equatable rows.** Rows conform to `Equatable` with a small equality input and apply `.equatable()`.
- **Precompute, never in body.** Parse settled markdown, highlight code, and format times when the change arrives. Cache on the record.
- **Paragraph split for Textual.** Settled paragraphs render once. Only the streaming paragraph re-parses. Without this, Textual re-parses the whole message per token.
- **Streaming balancer.** `StreamingMarkdownBalancer` closes a dangling `**` or `[` in the trailing paragraph, detects an open code fence, and routes the fence body to the EditorKit append path. Settled paragraphs are never touched.
- **Replace and clear.** A compaction or a whole-message upsert can replace or remove rows. The list handles removal with the same stable ids.
- **Scoped state.** No single property drives the whole screen. `AgentThread` keeps list data and screen-level state in separate observed properties, and Observation tracks per property, so a `usage_update` or a `config_option_update` does not invalidate the list. Each record is its own `@Observable` object, so a patch to one tool call invalidates that row alone. The list body reads only `items` ids and the row reads its record.
- **Cache the code block per fence.** The EditorKit code-block hook caches one `EditorModel` per fenced-block id. A streaming tail re-render never relayouts a settled code block.
- **Windowing.** `LazyVStack` cells persist, so a long thread grows memory. Window older turns behind a "load earlier" row. `List` stays a documented escape hatch behind a flag.
- **Scroll anchoring.** `ScrollAnchorManager` tracks pinned-to-bottom with a tolerance, restores an item anchor across updates, drives the scroll-to-bottom pill with a new-message count, and coalesces auto-scrolls during streaming. Use `onScrollTargetVisibilityChange`, not absolute offsets.
- **Heavy text out of the cells.** Code, diffs, and terminals render inside EditorKit. Prose is cached. Cells stay thin.

## 9. Component inventory

Source: native (build on stock), reuse (existing library), net-new (agent-grade, build).

**A. Thread**
- `AgentThreadView`: the drop-in. Binds an `AgentThread` and renders the whole surface. *net-new*
- `AgentTranscriptView`: snapshot renderer for a FoundationModels `Transcript` value. *net-new*
- `ConversationView`: container with auto-scroll, scroll-to-bottom, empty state. *native*
- `MessageActions`: copy, copy thread, retry, edit, in a footer. *native*
- `BranchNavigator`: regenerate and branch paging. *native*
- `ThreadMinimapView`: scrubbable rail of turns, tool calls, and errors. *net-new*
- `StateBanner`: shows `requiresAction` and a stop reason that needs attention (`max_tokens`, `refusal`, `max_turn_requests`). *net-new*
- `SessionListView`: sessions from `session/list` with title and updated time, cursor paging. *net-new*

**A2. Item views (one per `ThreadItem` kind, each overridable). Each component has one entry in this inventory. Groups B and C give detail for two of these.**
- `SystemPromptView`: the instructions, collapsed by default. *net-new*
- `UserMessageView` and `AssistantMessageView`: content-block based, share `MessageActions`. *net-new*
- `ReasoningView`: see group B. `ToolCallView`: see group C.
- `StructuredItemView`: the `schemaName` registry fallback, a collapsible pretty-printed `GeneratedContent`. *net-new*
- `CompactionMarkerView`: marks a transcript rewrite with its summary. Research R17 sets the design. *net-new*
- `UnknownItemView`: collapsible raw view for any unknown record or content block. *net-new*
- `ErrorView` renders one block per error kind, each with an action. `contextSizeExceeded(contextSize:tokenCount:)`: show the counts and offer Compact. `rateLimited`: show the reset time and offer Retry. `guardrailViolation` and `refusal`: show the explanation and offer Rephrase. `timeout`: offer Retry. ACP errors: show the code and message. A stop reason from `StateBanner` links here when the user needs to act.
- `ContentBlockView` family: text (Textual), image, audio, resource link (`LPLinkView` card), embedded resource, attachment, structured, unknown. *native and net-new*

**B. Streaming content**
- `ResponseView`: paragraph-split Textual with the balancer and the EditorKit code-block hook. *reuse plus balancer*
- `CodeBlockView`: copy, filename, language; EditorKit read-only. *EditorKit*
- `MathView`: inline and block LaTeX. *net-new on a math engine*
- `ReasoningView`: collapsible; shimmering title while in progress; auto-collapse on done. *net-new*
- `ActivityIndicator` and `ShimmerView`. *native, net-new*

**C. Agent activity**
- `ToolCallView`: title, kind icon, status, locations, raw input and output, collapsible content. Status uses symbol effects. *net-new*
- `TerminalView`: agent-owned terminal from `terminal_update` and `terminal_output_chunk`; command, cwd, exit status; ANSI handling per research R7. *net-new*
- `DiffView`: hosts EditorKit's unified-diff view (§4.1); adds the per-file list with counts, accept or reject per hunk, and attach selected lines to the prompt; `git_patch` input. *EditorKit for the render, net-new for the chrome*
- `TaskListView`: plans keyed by id; priority and status including cancelled. *net-new*
- `ActivityTimeline`: interleaved tool calls, reasoning, terminals, with host timestamps. *net-new*
- `SubagentTreeView`: a tree of child runs with status and drill-in. Data source per research R14. *net-new, v1 as a tree*
- `SourcesView` and `InlineCitation`. *net-new*
- `ContextUsageView`: `ContextUsage` merges FoundationModels `Usage`, Private Cloud Compute quota, and ACP `usage_update` with cost. *net-new*
- `AgentGraphView`: multi-agent canvas. *post-v1*

**C2. Infrastructure (non-visual)**
- `AgentThread`, `ThreadItem`, `ThreadChange`, the three `ThreadSource`s (§3). *net-new*
- `StreamingMarkdownBalancer`, `ScrollAnchorManager`, `ExpandedBlocksStore`. *net-new*
- `AgentCommands`: the kit verbs as EditorKit commands with a default keymap. *EditorKit*
- `GrammarBundle`: TextMate grammars for the top agent languages. *net-new*

**D. Input**
- `PromptInputView`: hosts EditorKit; slash commands from `availableCommands`; chips; `@file`; attachments; submit or cancel with status; tool toggles; mic. Editor and accessory are slots. *net-new*
- `ConfigOptionsView`: the picker for `configOptions`, grouped by category: mode (permission mode), model, model config, thought level, and booleans. Replaces a bespoke model picker. *net-new*
- `PromptQueueView`: queued messages while a turn runs; reorder, edit, drop; "send now" injects into the current turn. Esc stops the running turn and holds the queue. *net-new*
- `SuggestionsView`, `SpeechInputButton`. *native, reuse*

**E. Human-in-the-loop**
- `PermissionView`: renders a `PermissionRequest`. Shows the required title, the description, and the subject: a tool call, or a command with its cwd. Options come from the request. The four ACP kinds (allow once, allow always, reject once, reject always) are the v1 bar. A directory-scoped grant ("always for this folder") is not on the ACP wire. A source that supports it adds it as a fifth option. Research R5 and R8 decide which source supplies it. The subject for a command carries `command`, `cwd`, `toolCallId`, and `terminalId`. When `terminalId` is present the card links to the related `TerminalView`. Adds a deny-with-comment field (§3.4). Offers "switch to auto" when the mode config option exists. Research R8 sets the option set. *net-new*
- `PermissionModePicker`: the `mode` config option as a segmented control. *net-new*
- `CheckpointView`: history slider per turn with Restore code, Restore conversation, or both. Data model per research R13. *net-new*

**E2. Connections and authorization (§12)**
- `AuthorizationView`: in-thread "Connect to X" card for an MCP server. *net-new*
- `AgentAuthView`: an ACP agent's `AuthMethod`s: `agent` calls `login`; `terminal` calls `runTerminalAuth` and shows the process in a `TerminalView`; a sign-out control calls `logout`. *net-new*
- `ConnectionsView`, `ConnectionRow`, `ConnectionStatusChip`. *net-new*
- `AuthorizationPresenter`: wraps `ASWebAuthenticationSession`. *net-new*

**E3. Elicitation (§13)**
- `ElicitationView`, the `ElicitationFieldView` family, `ElicitationURLConsentView`. *net-new*

**F. Artifacts and attachments**
- `AttachmentView`, `AttachmentInspector`, `ArtifactView`, `CommandOutputView`, `LinkView`, `ImageView`, `AudioPlayerView`. *native and net-new*

## 10. What we port, adapt, and skip

- **Port:** the component taxonomy (Vercel AI Elements) and the runtime-binding spine (assistant-ui).
- **Adapt:** HITL (CopilotKit) to `PermissionView`; composability via slots with default overloads.
- **Skip:** React-Flow canvas (use SwiftUI `Canvas`, later); shadcn theming (use Liquid Glass and tokens); copy-to-codebase (ship a real package); web voice stacks; third-party highlighters (use EditorKit); embedded web preview (open the browser); SwiftStreamingMarkdown (cannot host EditorKit).

## 11. Decisions

1. **Distribution: a standalone open-source SPM package with one target per source.** `AgentViewKit` holds the model and the views. It depends on EditorKit (branch `main` until it tags), Textual, and a math engine. `AgentViewKitFoundationModels` holds `SessionThreadSource` and imports FoundationModels. `AgentViewKitRouter` holds `RouterThreadSource` and imports FoundationModelsRouter and FoundationModelsExtras. `AgentViewKitACP` holds `ACPThreadSource` and imports FoundationModelsACP and FoundationModelsACPClient. The ACP target must not import FoundationModels, which matches the rule in the ACP client repo. A test enforces the import boundary.
2. **Binding: `AgentThread` plus `ThreadSource` adapters (§3).** Not a bare `Transcript`. `AgentTranscriptView` remains as a snapshot renderer.
3. **Model shape follows ACP v2.** Upserts with three-state patches, replace, and clear. Every enum has an `unknown` case that renders.
4. **Pending requests are model state, not items.** Permission, elicitation, and authorization live in pending lists. In-thread cards read them.
5. **Custom transcript content is a `schemaName` catalog.** `Codable` payloads compatible with the Router's `PersistableStructuredSegment`. Names agreed with the Router. Unknown names render as a collapsible raw view.
6. **Cancel is a verb per source.** Not derived. `Task` cancellation for FoundationModels; `session/cancel` for ACP.
7. **Math: a native `MathView` in v1** on a Core Text engine chosen in research R9. Candidates: Textual's `.math` on swiftui-math, SwiftMath, iosMath.
8. **Selection: per-message plus copy thread in v1.** Cross-message drag-select is deferred unless research R10 shows macOS 27 `textSelection` gives it in containers.
9. **Streaming path: Textual with paragraph split and the balancer.** No fallback renderer unless research R1 fails.
10. **Long threads: `LazyVStack` with windowing.** `List` behind a flag.
11. **Design tokens: a public `AgentTheme`** that also yields an EditorKit `Theme`.
12. **Diff rendering is an EditorKit capability.** EditorKit takes unified diff text and renders it. The kit hosts it in `DiffView` and adds only the file list and the review actions. EditorKit has no diff view today; the kit does not build a stand-in.
13. **Grammars ship in the kit** until EditorKit links more.
14. **The kit verbs are EditorKit commands.** Palette, keybindings, and progress come from the command system.
15. **Subagents render as a tree in v1.** The canvas graph is post-v1.
16. **Config options replace the model picker and the mode picker.** One `ConfigOptionsView`, grouped by category.
17. **Reasoning binds to first-class data.** `Transcript.Entry.reasoning` for FoundationModels; `agent_thought` for ACP.
18. **OAuth and connections (§12):** in-thread gate plus settings surface; the kit presents, the runtime authorizes. App sign-in is the host's job. ACP agent auth is a separate view.
19. **Elicitation (§13):** form mode as a schema-driven form; URL mode as a consent card. Both in v1.
20. **ACP version:** the adapter targets the v2 SDK in `../FoundationModelsACP`. Research R6 decides on a v1 adapter.

## 12. Authorization and connections

Four distinct things, kept distinct:

1. **App sign-in.** Out of scope. The host's job.
2. **Per-server connect.** "Connect to GitHub." A durable grant. The kit owns this.
3. **Per-action permission.** "Allow this tool to run?" `PermissionView` (§9 E). Separate from connecting.
4. **Step-up scope consent.** A `403 insufficient_scope` mid-session. Same machinery as 2.

Plus one that ACP adds:

5. **Agent authentication.** An ACP agent advertises `AuthMethod`s at `initialize`. The `agent` method goes through `auth/login` with its `methodId`; the `login(_:)` verb drives it. The `terminal` method must not go through `auth/login`. The schema says the client runs the configured agent program as a separate interactive process, with the method's extra `args` and `env`. The `runTerminalAuth(_:)` verb does that and shows the process in a `TerminalView`. `AgentAuthView` renders both methods and a sign-out control that calls `logout()`, which maps to `auth/logout`.

**Per-server connect has two faces.**
- **In-thread, just-in-time.** When a tool's MCP server needs authorization, the source appends an `AuthorizationRequest` to `pendingAuthorizations`. `AuthorizationView` renders a "Connect to X" card with the requested scopes. The user taps Connect. The handoff runs through `connect(_:)`. The runtime exchanges the token and retries. A tool call blocked on auth shows a `ConnectionStatusChip` inline.
- **Durable management.** `ConnectionsView` lists servers with status, Connect and Disconnect, and per-tool toggles. It binds to the ambient `ConnectionStore`.

**The state machine follows the protocol** (MCP 2025-11-25). `disconnected` is the initial state and the state after the Disconnect action; `connected`; `needs-auth` on a `401` with `WWW-Authenticate`; `authenticating` while the browser session is open; back to `connected` after a successful retry; `expired` on refresh failure; `error` on a non-401 failure. `ConnectionStatusChip` renders these six states.

**Division of labor.** The kit owns `AuthorizationPresenter`, a thin wrapper over `ASWebAuthenticationSession`. It supplies the `NSWindow` presentation anchor, opens the system browser on a user action, and returns the callback URL. Everything else is the runtime's: discovery (RFC 9728, RFC 8414, OIDC), client identity (CIMD preferred, DCR fallback), PKCE `S256`, the RFC 8707 `resource` binding, token exchange and refresh, and Keychain storage. The redirect strategy is a runtime choice. `prefersEphemeralWebBrowserSession` is exposed.

**No prior art to port.** None of assistant-ui, Vercel AI Elements, or CopilotKit ships a first-class connection component. This is a differentiator.

## 13. Elicitation

Elicitation is how a server asks the user for input mid-tool-call. It reaches the kit two ways: `FoundationModelsExtras.ElicitationRequest` inside a Router `OperationEvent`, and ACP `elicitation/create` with a `scope`. Both land in `pendingElicitations`. `eventplan.md` in the Multitool repo names AgentViewKit as the presenting layer and lists the URL-mode obligations. They match §13.4.

**The spec** (MCP 2025-11-25). A server sends a `message` and a `mode`.

- **`form`** (default). Carries a `requestedSchema`: a flat object of primitive properties. The response is `accept` with `content`, `decline`, or `cancel`.
- **`url`**. Carries a `url` and an `elicitationId`. The client gets consent and opens the URL safely. The result arrives later via `elicitation/complete`, or the request came from a `-32042 URLElicitationRequiredError`.

```swift
func respond(to request: ElicitationRequest, _ result: ElicitationResult) async
enum ElicitationResult {
    case accept(GeneratedContent?)  // form: validated values; url: nil, consent to open only
    case decline
    case cancel
}
```

### 13.1 Form mode: `ElicitationView`

The view names the requesting server, generates a field per property, validates locally, and returns through `respond(to:_:)`.

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
ElicitationView(request)
    .elicitationTextField         { ctx in EditorKitInput(ctx) }   // default
    .elicitationSingleChoiceField { ctx in MyRadioGroup(ctx) }
    .elicitationMultiChoiceField  { ctx in MyCheckboxes(ctx) }
    .elicitationHeader            { req in MyServerBanner(req) }
    .elicitationLayout            { fields in MyTabStrip(fields) }
    .elicitationFooter            { actions in MyActionBar(actions) }

public struct ElicitationFieldContext {       // what the kit hands each field renderer
    public let schema: ElicitationFieldSchema   // title, description, constraints, format, choices
    public let value: Binding<GeneratedContent> // the field's current answer
    public let validation: FieldValidationState // live errors, required, satisfied
}
```

Free text defaults to EditorKit. This is the opposite default from `PromptInputView`, on purpose: one input engine for in-thread text.

### 13.3 URL mode

`ElicitationURLConsentView` shows the server, the message, and the full URL with the domain highlighted. It warns on Punycode or ambiguous hosts. On consent it opens the system browser through `AuthorizationPresenter`. It never auto-opens or pre-fetches. It returns `accept` for consent to open, then waits for `elicitation/complete` by `elicitationId`, with Retry and Cancel always present. A `-32042` error renders the same card.

### 13.4 Security posture

- Form mode never carries secrets. Sensitive collection goes to URL mode.
- Every elicitation names the server and offers Decline and Cancel.
- Validate before sending. No clickable URLs in form fields.
- Open only in the safe system browser, never a `WKWebView`.
- Rate limiting is a runtime concern.

## 14. Research before build

Ordered by design impact. Each item names the question and the method.

- **R1. Textual streaming cost.** Bench at 50 tokens per second on a 2,000-line message with the paragraph split and the balancer. Decide if the tail needs a lighter renderer.
- **R2. Grammar bundle.** List the languages agents emit most. Find MIT TextMate or tree-sitter grammars. Measure size. Decide kit bundle or EditorKit link.
- **R3. EditorKit unified-diff feature.** Write the feature spec for EditorKit: input is unified diff text; output is inline and side-by-side, with gutter marks, line colors, and hunk folding, on EditorKit decorations. Prototype it on the EditorKit decoration and gutter APIs. This work lands in EditorKit's plan, and the kit consumes it.
- **R4. Observation granularity.** Measure invalidation when a view reads `session.transcript` during `streamResponse`. Test `SessionPropertyValues.history` and `Snapshot.transcriptEntries` as the tail source.
- **R5. Runtime contract.** Write the runtime contract, or point at `SessionProjection` and `SessionEvent`. Agree the `schemaName` catalog with the Router. Decide who injects approval, plan, citation, artifact, and authorization.
- **R6. ACP version.** List which agents speak v1 and which speak v2 today. Decide on a v1 adapter.
- **R7. Terminal output.** Pick an ANSI and VT parser, or strip escapes. Check licenses.
- **R8. Permission and mode UX.** Map Claude Code, Cursor, and Codex option sets onto ACP options and config options.
- **R9. Math engine.** Test Textual `.math`, SwiftMath, and iosMath on inline and block spans in a streaming paragraph.
- **R10. Text selection.** Test `textSelection` on a `LazyVStack` of Textual views on macOS 27.
- **R11. Dynamic Type and accessibility.** Prototype `accessibilityLinkedGroup` across lazy rows. Set the VoiceOver cadence. Check EditorKit font scaling.
- **R12. Visual audit.** Capture Xcode 27 and Claude Desktop screens. Set `AgentTheme` defaults.
- **R13. Checkpoints.** Find what the Router gives (`makeFork`, transcript rewrite) and what ACP gives (`session/fork`, unstable). Design the rewind model.
- **R14. Subagent data.** Find a data source for the tree: Router `SessionEvent`, ACP `_meta`, or AG-UI subagent events.
- **R15. Attachments.** FoundationModels accepts images only. ACP accepts audio, resources, and links. Find what the Router does with other files.
- **R16. Usage model.** Merge FoundationModels `Usage`, Private Cloud Compute quota, and ACP `usage_update` into `ContextUsage`.
- **R17. Compaction UX.** Design how a rewrite shows. Inputs: Router `CompactionSegment`, ACP unstable `compaction_update`, Claude Code `/compact`.
