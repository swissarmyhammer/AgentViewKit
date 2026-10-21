# AgentViewKit compared with Vercel AI Elements, assistant-ui and CopilotKit

Date: 2026-10-11.

## 1. Purpose and sources

### 1.1 Purpose

This document compares the views of AgentViewKit with the components of
three web kits. It finds the gaps. It tells which views to add, which views
to change, and which cross-cutting functions to add.

The goal of the owner: AgentViewKit is a full, high-quality AI UI kit for
Swift. The kit is SwiftUI on macOS 27. It is an ACP client kit. Each view
binds to the observable models of FoundationModelsACPClient
(`ConnectionModel`, `SessionModel` and the `TranscriptEntry` objects).
EditorKit renders the code and hosts the composer. The EditorKit themes are
the kit themes.

Rules for the recommendations:

- A new view reads the ACP client models. It keeps no copy of model data
  and no turn logic (`Docs/decisions/acp-client-kit.md`).
- When ACP has no producer for a surface, the recommendation says so. The
  owner decision of 2026-10-02 removes branches, checkpoints and subagents
  until ACP gives a producer. This document does not change that decision.
  It lists these rows as "blocked by ACP".
- The kit is all-Swift and native. It uses no WebView (`plan.md` §4, §10).

### 1.2 Sources

| Package | Version | Date | Source |
|---|---|---|---|
| AgentViewKit | `main`, commit `e96684e` | 2026-10-11 | `Sources/AgentViewKit`, `README.md`, `plan.md` (revised 2026-10-08), `plan-review.md`, `Docs/decisions/*.md` |
| Vercel AI Elements (`ai-elements`) | 1.9.0 | 2026-03-12 | <https://registry.npmjs.org/ai-elements>, <https://github.com/vercel/ai-elements/releases>, <https://elements.ai-sdk.dev/> (the old URL <https://ai-sdk.dev/elements> redirects here), <https://elements.ai-sdk.dev/api/registry/registry.json> |
| assistant-ui (`@assistant-ui/react`) | 0.15.27 | 2026-10-10 | <https://registry.npmjs.org/-/v1/search?text=assistant-ui>, <https://github.com/assistant-ui/assistant-ui/releases>, <https://www.assistant-ui.com/docs/api-reference/primitives>, <https://www.assistant-ui.com/elements> |
| assistant-ui companions | `@assistant-ui/core` 0.3.26, `react-markdown` 0.14.20, `react-ai-sdk` 1.4.17, `react-ag-ui` 0.0.67, `react-mcp` 0.1.22, `react-devtools` 1.2.24 | 2026-10-06 to 2026-10-10 | the same npm search |
| assistant-ui tool-ui | archived | 2026-09-26 | <https://github.com/assistant-ui/tool-ui> (read-only now; the elements catalog holds its component types) |
| CopilotKit (`@copilotkit/react-core`, `@copilotkit/react-ui`) | 1.78.0 (v2 API at `@copilotkit/react-core/v2`) | 2026-10-09 | <https://registry.npmjs.org/@copilotkit/react-core>, <https://github.com/CopilotKit/CopilotKit/releases>, <https://docs.copilotkit.ai/reference>, <https://docs.copilotkit.ai/migrate/v2> |
| AG-UI (`@ag-ui/core`, `@ag-ui/client`) | 1.0.2 (protocol "1.0") | 2026-10-05 | <https://github.com/ag-ui-protocol/ag-ui/releases>, <https://docs.ag-ui.com/concepts/events>, <https://docs.ag-ui.com/concepts/interrupts> |

Notes on the sources:

- The Vercel docs list 48 components. `Loader` is deprecated (1.8.2).
  `Branch` is now part of `Message`. `Response` is now `MessageResponse`.
- CopilotKit marks the v1 API as deprecated. This document uses the v2 names.
  It gives a v1 name only when v2 has no replacement.
- A "?" cell means that the research could not confirm the item.

## 2. Comparison table

Legend:

- ✓: the package has a component or primitive for the capability.
- partial: the package has a part of the capability.
- ✗: the package does not have it.
- ?: not confirmed.
- "blocked by ACP": ACP v2 gives no data for it. The owner removed it until
  ACP gives a producer.

The AgentViewKit paths are relative to `Sources/AgentViewKit/`.

### 2.1 Conversation and messages

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Drop-in thread | ✓ `AgentThreadView` (`Thread/AgentThreadView.swift`) | partial: compose `Conversation` + `Message` + `PromptInput` | ✓ `Thread` element | ✓ `CopilotChat` |
| Scroll container, stick to bottom, scroll button | ✓ `ConversationView`, `ScrollToBottomPill`, `ScrollAnchorManager` | ✓ `Conversation`, `ConversationScrollButton` | ✓ `ThreadPrimitive.Viewport`, `.ScrollToBottom` | ✓ `scrollView` slot, `autoScroll` |
| Empty state / welcome | ✓ `ConversationEmptyState` with Markdown from the host, and `.conversationEmptyState(title:systemImage:markdown:)` (`Thread/ConversationEmptyState.swift`) | ✓ `ConversationEmptyState` | ✓ `AuiIf` + `s.thread.isEmpty` | ✓ `welcomeScreen` slot |
| User message | ✓ `UserMessageView` (`Items/UserMessageView.swift`) | ✓ `Message from="user"` | ✓ `MessagePrimitive` | ✓ `CopilotChatUserMessage` |
| Assistant message | ✓ `AssistantMessageView` | ✓ `Message`, `MessageResponse` | ✓ `MessagePrimitive.Parts` | ✓ `CopilotChatAssistantMessage` |
| Pending / failed send state | ✓ `UserMessageView` send state | ✗ | partial: message status | ? |
| Message actions: copy, retry, edit | ✓ `MessageActions` (`Items/MessageActions.swift`) | ✓ `MessageActions`, `MessageAction` | ✓ `ActionBarPrimitive.Copy`, `.Reload`, `.Edit` | ✓ toolbar slots |
| Hover action bar | ✗ (footer row only) | partial: `MessageToolbar` | ✓ `ActionBarPrimitive` autohide | ✓ `toolbarVisible` |
| Feedback (thumbs) | ✗ (no ACP method) | ✗ | ✓ `FeedbackPositive`, `FeedbackNegative`, `FeedbackAdapter` | ✓ `onThumbsUp`, `onThumbsDown` |
| Export thread to Markdown | ✓ `MessageActions` Export, `ThreadExporter` | ✓ `ConversationDownload` | ✓ `ActionBarPrimitive.ExportMarkdown` | ✗ |
| Error row | ✓ `ErrorView` (`Items/ErrorView.swift`) | partial: `ToolOutput errorText` | ✓ `ErrorPrimitive`, `MessagePrimitive.Error` | partial: `onError` |
| Unknown content fallback | ✓ `UnknownItemView` | ✗ | ✓ `tools.Fallback`, `data.Fallback` | ✓ `useDefaultRenderTool` |
| Agent state and stop reasons | ✓ `StateBanner` (`Status/StateBanner.swift`) | ✗ | ✗ | ✗ |
| Stream state: replay, missed updates, closed | ✓ `SessionStreamBanner` | ✗ | partial: resumable streams guide | ✗ |
| Session notices | ✓ `SessionNoticeBanner` | ✗ | ✗ | ✗ |
| Context compaction marker | ✓ `CompactionEntryView` | ✗ | ✗ | ✗ |
| Transcript minimap | ✓ `ThreadMinimapView` | ✗ | ✗ | ✗ |
| Message grouping | ✗ | ✗ | ✓ `MessagePrimitive.GroupedParts` | ✓ `groupMessages` |
| Message timing | ✓ `EntryTimingView`, a decorator: `.transcriptTiming()` on each row, `.entryTiming(_:)` on one view; the times come from the client `EntryTiming` (`Items/EntryTimingView.swift`) | ✗ | ✓ message timing element | ✗ |
| Quote a selection into the composer | partial: `DiffView` "Attach to prompt" | ✗ | ✓ `SelectionToolbarPrimitive.Quote`, `ComposerPrimitive.Quote` | ✗ |
| Popup / sidebar / modal shells | ✗ | ✗ | ✓ `AssistantModal`, `AssistantSidebar` | ✓ `CopilotPopup`, `CopilotSidebar` |
| Long-thread windowing | ✓ `ConversationView` "load earlier", `conversationPageSize` | ✗ | ✓ `ThreadPrimitive.LoadEarlier`, virtualization guide | ? |

### 2.2 Streaming and Markdown

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Streaming Markdown | ✓ `ResponseView` + `StreamingMarkdownBalancer` (`Content/ResponseView.swift`) | ✓ `MessageResponse` (Streamdown, `parseIncompleteMarkdown`) | ✓ `MarkdownText`, `react-streamdown` | ✓ `markdownRenderer` slot |
| Per-paragraph re-render | ✓ `ParagraphSplitter`, `ParagraphView` | ? | ? | ? |
| Smooth text animation | ✗ | ✗ | ✓ `MessagePartPrimitive.Text` smooth streaming | ? |
| Streaming cursor | ✗ | ✗ | partial: `data-status` | ✓ `cursor` slot |
| Math | ✓ `MathView` (`Content/MathView.swift`) | ✓ KaTeX in `MessageResponse` | ✓ math element, LaTeX guide | ? |
| Mermaid diagrams | ✗ | ✗ | ✓ mermaid-diagram element | ? |
| Charts / data tables in prose | ✗ | ✗ | ✓ chart, data table elements | ? |
| Shimmer / loading text | ✓ `ShimmerView`, `ActivityIndicator` (`Activity/`) | ✓ `Shimmer` | ✓ `MessagePartPrimitive.InProgress` | ✓ "Thinking…" |

### 2.3 Reasoning and chain of thought

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Collapsible reasoning | ✓ `ReasoningView` (`Items/ReasoningView.swift`) | ✓ `Reasoning` | ✓ reasoning element | ✓ `CopilotChatReasoningMessage` |
| Auto-open while it streams, auto-close after | ✗ (closed by default; no in-progress signal read) | ✓ `isStreaming`, auto-open | ? | ✓ "Thinking…" then collapse |
| "Thought for N seconds" | ✓ `ReasoningView`, `ActivityTimeline`: the `duration` of the thought entry (`Items/ReasoningView.swift`) | ✓ `duration`, `getThinkingMessage` | ? | ✓ |
| Step list (chain of thought) | partial: `ActivityTimeline` (`Activity/ActivityTimeline.swift`) | ✓ `ChainOfThought`, `ChainOfThoughtStep` | ✓ `ChainOfThoughtPrimitive` | ✗ |
| Reasoning effort control | ✓ `ConfigOptionsView` category `thought_level` | ✗ | ✓ reasoning-effort element | ✗ |

### 2.4 Tools and generative UI

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Default tool call row | ✓ `ToolCallView` (`Items/ToolCallView.swift`) | ✓ `Tool`, `ToolHeader`, `ToolInput`, `ToolOutput` | ✓ `ToolFallback`, tool call element | ✓ `CopilotChatToolCallsView` |
| Tool status states | ✓ `ToolStatusSymbol`, `WorkStatusLabel` | ✓ 7 states incl. `approval-requested` | ✓ running, requires-action, incomplete, complete | ✓ inProgress, executing, complete |
| Tool UI registry by name | ✓ `.toolCallView(named:)` (`Thread/Registries.swift`) | ✗ (switch on `part.type`) | ✓ `defineToolkit`, `Tools({ toolkit })` | ✓ `useRenderTool` |
| Wildcard tool renderer | ✓ `.toolCallView { }` (`Thread/ItemViewOverrides.swift`) | ✗ | ✓ `tools.Fallback`, `Override` | ✓ `useRenderTool("*")` |
| Tool group (consecutive calls) | ✗ | ✗ | ✓ tool group, tool timeline elements | ✗ |
| Frontend tools (client executes) | ✗ (ACP v2: agent-owned tools) | ✗ | ✓ frontend tool with `execute` | ✓ `useFrontendTool` |
| Components as tools | ✗ | ✗ | ✓ `MessagePrimitive.GenerativeUI` | ✓ `useComponent` |
| Declarative generative UI (A2UI) | ✗ | ✗ | ✓ A2UI over AG-UI guide | ✓ A2UI middleware |
| MCP Apps (sandboxed UI) | ✗ (no WebView, by design) | ✗ | ✓ `McpAppRenderer` | ✓ `MCPAppsMiddleware` |
| Agent state rendering | partial: `StateBanner` (state only; ACP has no shared state) | ✗ | ✓ `makeAssistantDataUI` | ✓ `useAgent` state |
| Tool toggles | ✓ `ToolToggles` (`Input/ToolToggles.swift`) | ✗ | ✗ | ✓ `toolsMenu` |

### 2.5 Human in the loop, approvals, elicitation

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Tool approval card | ✓ `PermissionView` (`HumanInTheLoop/PermissionView.swift`) | ✓ `Confirmation` | ✓ approval card, `respondToApproval` | ✓ `useHumanInTheLoop` |
| Allow once / always, reject once / always | ✓ `PermissionView` + `PermissionPresentation` | partial: approve / reject | ✓ approval options | partial: render-defined |
| Reject with comment | ✓ `PermissionView` comment field | ✗ | ? | partial: render-defined |
| Command subject with cwd and terminal link | ✓ `PermissionView` | ✗ | partial: permission grant element | ✗ |
| Permission mode picker | ✓ `PermissionModePicker` (`Config/PermissionModePicker.swift`) | ✗ | partial: permission grant element | ✗ |
| Pending request host | ✓ `PendingRequestsHost` | ✗ | ✗ | partial: `useInterrupt renderInChat` |
| Schema form (elicitation) | ✓ `ElicitationView` + `ElicitationFieldView` family (`Elicitation/`) | ✗ | ✓ elicitation form, question flow | partial: `useInterrupt` `responseSchema` |
| URL-mode consent | ✓ `ElicitationURLConsentView` | ✗ | ✗ | ✗ |
| Option list / choice question | ✓ `ElicitationSingleChoiceField`, `ElicitationMultiChoiceField` | ✗ | ✓ option list element | ✗ |
| Elicitation linked to its tool call | ✓ `ToolCallView` (`linkedElicitationIDs`) | ✗ | ? | ✓ interrupt `toolCallId` |

### 2.6 Plan, tasks, queue

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Plan checklist | ✓ `TaskListView` (`Status/TaskListView.swift`) | ✓ `Plan` | ✓ agent plan, todo list elements | ✗ |
| Task card with files | partial: `TaskListView` (no files) | ✓ `Task`, `TaskItemFile` | ✓ task card element | ✗ |
| Activity timeline | ✓ `ActivityTimeline` | partial: `ChainOfThought` | ✓ run activity, trace waterfall | ✗ |
| Message queue | ✗ (composer sends at once, by design) | ✓ `Queue` | ✓ `ComposerPrimitive.Queue`, `QueueItemPrimitive` (Steer, Remove) | ✗ |
| Agent status | ✓ `StateBanner` | ✗ | ✓ agent status element | partial: `isRunning` |

### 2.7 Code, diff, terminal, artifacts, file tree, test results, stack trace

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Code block with copy, filename, language | ✓ `CodeBlockView` on EditorKit (`Code/CodeBlockView.swift`) | ✓ `CodeBlock` (Shiki) | ✓ syntax highlighter, Shiki highlighter | partial: copy-code label |
| Streaming code into a block | ✓ `EditorModel+Append.swift`, `CodeBlockModelCache` | ✗ | ? | ? |
| Diff with per-hunk accept / reject | ✓ `DiffView` (`Diff/DiffView.swift`) | ✗ | partial: code diff element | ✗ |
| Terminal output | ✓ `TerminalView` (`Terminal/TerminalView.swift`), `CommandOutputView` | ✓ `Terminal` (ANSI colors) | ✓ terminal block element | ✗ |
| ANSI colors shown | ✓ `ANSIText` maps SGR colors through the EditorKit `terminalPalette`; the editor paints them as color runs (`TerminalView`, `CommandOutputView`) | ✓ | ? | ✗ |
| Artifact panel | partial: `ArtifactView` (no ACP producer) | ✓ `Artifact` | ? | ✗ |
| File tree | ✗ | ✓ `FileTree` | ✗ | ✗ |
| Test results | ✗ | ✓ `TestResults` | ✗ | ✗ |
| Stack trace | ✗ | ✓ `StackTrace` | ✗ | ✗ |
| Commit | ✗ | ✓ `Commit` | ✗ | ✗ |
| Command snippet with copy | ✗ | ✓ `Snippet` | ✗ | ✗ |
| Sandbox (code + output tabs) | ✗ | ✓ `Sandbox` | ✗ | ✗ |
| Web preview | ✗ (opens the browser, by design) | ✓ `WebPreview` | ✓ web preview element | ✗ |
| Package, env vars, schema, JSX | ✗ | ✓ `PackageInfo`, `EnvironmentVariables`, `SchemaDisplay`, `JSXPreview` | ✗ | ✗ |
| Agent configuration card | partial: `AgentInfoHeader` (name, version) | ✓ `Agent` (model, tools, instructions) | ✗ | ✗ |
| Computer use | ✗ | ✗ | ✓ computer use element | ✗ |

### 2.8 Attachments and media

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Composer attachment chips | ✓ `AttachmentChips` (`Input/AttachmentChips.swift`) | ✓ `Attachments`, `PromptInputActionAddAttachments` | ✓ `ComposerPrimitive.Attachments` | ✓ `attachments` prop |
| Drag and drop, paste | ✓ `attachmentDropDestination` | ✓ `globalDrop` | ✓ `AttachmentDropzone` | ✓ |
| Per-type attachment views | ✓ `AttachmentView` + `.attachmentView(for:)` | partial: `getMediaCategory` | ✓ attachment adapters | partial: image, audio, video |
| Preview inspector (Quick Look) | ✓ `AttachmentInspector` | partial: `AttachmentHoverCard` | ✗ | partial: image lightbox |
| Capability check before send | ✓ `PromptInputView` reads `promptCapabilities` | ✓ `accept`, `maxFileSize` | ✓ adapter `accept` | ✓ `accept`, `maxSize` |
| Upload progress | ✗ (no upload; local files) | ✗ | ✓ adapter `add` progress | ✓ `onUpload` |
| Screenshot attach | ✗ | ✓ `PromptInputActionAddScreenshot` | ✗ | ✗ |
| Image block | ✓ `ImageView` (`Content/Blocks/ImageView.swift`) | ✓ `Image` | ✓ `MessagePartPrimitive.Image` | ✓ |
| Audio block | ✓ `AudioPlayerView` | ✓ `AudioPlayer` | ? | ✓ audio player |
| Resource link card | ✓ `LinkView` (`LPLinkView`) | ✗ | ✗ | ✗ |
| Embedded resource | ✓ `ResourceBlockView` | ✗ | ✗ | partial: `document` part |

### 2.9 Citations and sources

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Sources list | partial: `SourcesView` (`Citations/SourcesView.swift`; no ACP producer) | ✓ `Sources` | ✓ sources element | ✗ |
| Inline citation pill | partial: `InlineCitation` (no ACP producer) | ✓ `InlineCitation` with card and carousel | ✓ inline citation element | ✗ |

### 2.10 Context and usage

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Context meter | ✓ `ContextUsageView`, `UsageRingView` (`Status/`) | ✓ `Context` | ✓ context display | ✗ |
| Cost | ✓ `ContextUsageView` (when the agent sends it) | ✓ `modelId` + tokenlens | ✓ cost meter | ✗ |
| Token breakdown (input, output, reasoning, cache) | ✗ (ACP `usage_update` has `used`, `size`, `cost` only) | ✓ `ContextInputUsage` and others | ✓ context breakdown | ✗ |
| Quota banner | ✗ | ✗ | ✓ quota banner | ✗ |

### 2.11 Model and mode selection

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Model picker | ✓ `ConfigOptionsView` category `model` (`Config/ConfigOptionsView.swift`) | ✓ `ModelSelector`, `PromptInputSelect` | ✓ model selector, composer model picker | ✗ |
| Searchable model list | ✗ (plain `Picker`) | ✓ cmdk search | ? | ✗ |
| Mode picker | ✓ `PermissionModePicker`, `ConfigOptionsView` category `mode` | ✗ | partial | ✗ |
| Boolean options | ✓ `ConfigOptionsView` `Toggle` | ✗ | ✗ | ✗ |

### 2.12 Sessions, threads, branches, checkpoints

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Session list with paging | ✓ `SessionListView` (`Sessions/SessionListView.swift`) | ✗ | ✓ `ThreadListPrimitive`, `LoadMore` | ✓ `useThreads`, `CopilotThreadsDrawer` |
| Delete session | ✓ `SessionListView` | ✗ | ✓ `ThreadListItemPrimitive.Delete` | ✓ `deleteThread` |
| Rename / archive | ✗ (no ACP method) | ✗ | ✓ `Archive`, `Unarchive`, generated titles | ✓ `renameThread`, `archiveThread` |
| Session title header | ✗ (`sessionInfo` is not read) | ✗ | ✓ `ThreadListItemPrimitive.Title` | ? |
| Branch picker | ✗ blocked by ACP (`Docs/decisions/acp-client-kit.md`) | ✓ `MessageBranch` | ✓ `BranchPickerPrimitive` | ✓ `branchNavigation` |
| Checkpoint / restore | ✗ blocked by ACP (`session/fork` unstable) | ✓ `Checkpoint` | partial: LangGraph checkpoint id | ✗ |

### 2.13 Voice

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Dictation button | ✓ `SpeechInputButton`, `SystemSpeechTranscriber` (`Input/`) | ✓ `SpeechInput` | ✓ `ComposerPrimitive.Dictate` | ✓ `startTranscribeButton` |
| Live transcript in composer | ? (not confirmed in `SpeechInputButton`) | ✓ `onTranscriptionChange` | ✓ `DictationTranscript` | ✓ `mode="transcribe"` |
| Waveform / level meter | ✗ | ✗ | ✓ `useVoiceVolume` | ✓ `CopilotChatAudioRecorder` |
| Read aloud (TTS) | ✗ | ✗ | ✓ `ActionBarPrimitive.Speak`, `SpeechSynthesisAdapter` | partial: `onReadAloud` callback |
| Mic selector | ✗ | ✓ `MicSelector` | ✗ | ✗ |
| Voice selector | ✗ | ✓ `VoiceSelector` | ✗ | ✗ |
| Transcript segments with seek | ✗ | ✓ `Transcription` | ✗ | ✗ |
| Realtime voice session | ✗ | ✗ | ✓ `RealtimeVoiceAdapter`, voice conversation, orb | ✗ |
| Persona / avatar | ✗ | ✓ `Persona` | ✓ orb element | ✗ |

### 2.14 Suggestions and composer

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Suggestion chips | ✓ `SuggestionsView` (`Input/SuggestionsView.swift`; host list) | ✓ `Suggestions` | ✓ `ThreadPrimitive.Suggestions`, suggestions adapter | ✓ `useConfigureSuggestions` |
| Follow-up suggestions after a turn | partial: `DefaultPromptAccessory` (host list) | ✗ | ✓ follow-up suggestions | ✓ `available: after-first-message` |
| Composer with slots | ✓ `PromptInputView` (`editor`, `accessory` slots) | ✓ `PromptInput` parts | ✓ `ComposerPrimitive` | ✓ `CopilotChatInput` slots |
| Slash commands | ✓ `SlashCommandSource` from `availableCommands` | partial: `PromptInputCommand` parts | ✓ `TriggerPopover` | ? |
| `@file` mentions | ✓ `FileReferenceSource` | ✗ | ✓ mentions element | ✗ |
| Input history | ✗ | ✗ | ✓ input history guide | ✗ |
| Stop button | ✓ `PromptInputView` | ✓ `PromptInputSubmit status` | ✓ `ComposerPrimitive.Cancel` | ✓ `onStop` |

### 2.15 Connections and auth

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Connection state banner | ✓ `AgentConnectionBanner` (`Connections/`) | ✗ | ✗ | ✗ |
| Agent sign-in / sign-out | ✓ `AgentAuthView` | ✗ | partial: Assistant Cloud auth | ✗ |
| MCP server status | ✓ `ConnectionsView`, `ConnectionRow`, `ConnectionStatusChip` | ✗ | partial: user-managed MCP servers page | ✗ |
| Web authorization session | ✓ `AuthorizationPresenter` | ✗ | ✗ | ✗ |
| Agent identity | ✓ `AgentInfoHeader` | partial: `Agent` | ✗ | ✗ |

### 2.16 Subagents

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Subagent list or tree | ✗ blocked by ACP (`AgentGraphView` post-v1) | ✗ | ✓ subagent list, handoff elements | partial: `useAgent` state + `useRenderTool` |
| Multi-agent canvas | ✗ post-v1 | ✓ `Canvas`, `Node`, `Edge`, `Connection`, `Controls`, `Panel`, `Toolbar` | ✗ | ✗ |

### 2.17 Theming, accessibility, i18n

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Theme tokens | ✓ `AgentTheme`, `.agentTheme(_:)` (`Theme/`) | ✓ shadcn CSS variables | ✓ shadcn / Tailwind (core theming page ?) | ✓ shadcn oklch tokens on `[data-copilotkit]` |
| One theme for code and chrome | ✓ `AgentTheme+EditorKit.swift` | partial: Shiki theme apart | ? | ✗ |
| Dark mode | ✓ system appearance | ✓ `data-theme` | ✓ | ✓ `.dark` |
| Material / glass | ✓ `agentFloatingGlass()`, always `.regular` (`Theme/AgentSurfaces.swift`) | ✗ | ✗ | ✗ |
| Screen reader labels | ✓ `ThreadAccessibility` | partial: `label` props | ? | partial: labels |
| Boundary announcements | ✓ `VoiceOverAnnouncer` (`Platform/Announcer.swift`) | ✗ | ? | ? |
| Focus to new request card | ✓ `AccessibilityFocusMover` | ✗ | ? | ? |
| Linked reading groups | ✓ `accessibilityReadingScope()` | ✗ | ✗ | ✗ |
| Reduce Motion | partial: `ShimmerView`, `ToolCallView` only | ? | ? | ? |
| Dynamic Type | ✓ (`Docs/decisions/dynamic-type.md`) | ✗ | ✗ | ✗ |
| Keyboard commands and keymap | ✓ `AgentCommands`, `AgentKeymap` (`Commands/`) | partial: `PromptInputButton` shortcut tooltip | partial: composer submit modes | ? |
| Localized strings | partial: some `String(localized:)`; no string catalog; no `defaultLocalization` in `Package.swift` | ✗ (English in source) | ? | partial: 20 `labels` keys |

### 2.18 Composability and runtime binding

| Capability | AgentViewKit | Vercel AI Elements | assistant-ui | CopilotKit |
|---|---|---|---|---|
| Replace one entry kind | ✓ typed modifiers (`Thread/ItemViewOverrides.swift`) | ✓ (you own the copied source) | ✓ `components` keys | ✓ slots |
| Keyed registries | ✓ `.contentBlockView(for:)`, `.attachmentView(for:)`, `.toolCallView(named:)` | ✗ | ✓ `tools.by_name`, `data.by_name` | ✓ `useRenderTool` name |
| Builder slots with defaults | ✓ `PromptInputView`, `ElicitationView`, `.messageFooter` | ✓ compound parts | ✓ primitives with `asChild`, `render` | ✓ slot = component, class or props |
| Style protocols (`ButtonStyle` pattern) | not planned: the look follows the EditorKit theme (section 5.12) | ✗ | ✗ | ✗ |
| Headless primitives | partial: infrastructure types (`ScrollAnchorManager`, `ExpandedBlocksStore`) | ✗ | ✓ 19 primitive groups | ✓ `useAgent` headless |
| Data binding | ✓ ACP `SessionModel` / `ConnectionModel` | ✓ AI SDK `useChat` parts | ✓ runtimes: Local, ExternalStore, AI SDK, LangGraph, AG-UI, A2A, others | ✓ AG-UI agent via `useAgent` |
| Raw protocol inspector / devtools | ✗ | ✗ | ✓ `react-devtools` `DevToolsModal` | ✓ `inspectorTools` |
| Observability hooks | ✗ | ✗ | ✓ `react-o11y`, Cloud traces | partial: `onError`, `agent.subscribe` |
| Preview fixtures | ✗ (no `#Preview` in `Sources/`) | ✓ docs examples | ✓ docs examples | ✓ docs examples |

Row count: 147 capability rows in 18 groups.

### 2.19 Summary of the table

- AgentViewKit leads on the ACP surfaces that the web kits do not have:
  agent state, stop reasons, stream state, notices, compaction, connections,
  agent auth, MCP server status, elicitation in URL mode, permission modes,
  diff review, and accessibility.
- AgentViewKit is behind on these surfaces: hover action bars, reasoning
  auto-open, tool groups, file tree, test results, stack trace, read aloud,
  searchable model picker, session title, message queue, Mermaid, devtools
  and preview fixtures.
- Branches, checkpoints, subagents and feedback stay blocked until ACP gives
  a producer.

## 3. Additional views we should create

Each view reads the ACP client models. It keeps no copy of model data. Each
new view gets a typed override or a slot, the same as the current views.

### 3.1 `SessionHeader`

- **What:** A header that shows the session title and the last update time
  from `SessionModel.sessionInfo`. It shows the `cwd` and the
  `additionalDirectories`. It can hold the `ContextUsageView` and the
  `ConfigOptionsView` menu as trailing items.
- **Why:** assistant-ui shows the thread title (`ThreadListItemPrimitive.Title`).
  CopilotKit has `CopilotModalHeader`. The kit does not read
  `sessionInfo` at this time.
- **ACP data:** `session_info_update` (`title`, `updatedAt`), `cwd`.
- **File:** new `Sources/AgentViewKit/Sessions/SessionHeader.swift`.
- **Priority:** P1.

### 3.2 `ToolCallGroup`

- **What:** One collapsible row for a run of consecutive tool calls and
  terminals. The row shows the count, the kinds, and the worst status. It
  expands to the `ToolCallView` rows.
- **Why:** assistant-ui has the tool group and tool timeline elements. A
  coding agent sends many reads and searches in sequence. Without a group,
  these rows push the answer out of view.
- **ACP data:** adjacent `.toolCall` and `.terminal` entries of
  `SessionModel.transcript`, and `ToolCallEntry.status`. The group is a
  view function of the transcript order. It keeps no list.
- **File:** new `Sources/AgentViewKit/Items/ToolCallGroup.swift`. Change
  `Sources/AgentViewKit/Thread/ConversationView.swift` to use it.
- **Priority:** P1.

### 3.3 `ChangedFilesView` (file tree)

- **What:** A tree of the files that the session touched. Each row shows the
  operation (read, edit, delete, move) and the added and removed line
  counts. A click opens the file diff in `DiffView` or shows the file in
  `AttachmentInspector`.
- **Why:** Vercel has `FileTree` and `Commit` (file list with counts).
  Claude Code, Cursor and Codex show a changed-files panel (`plan.md` §2).
- **ACP data:** `ToolCallEntry.locations`, the `kind` of each tool call, and
  the `diff` content (`Diff.changes`, `git_patch`).
- **File:** new `Sources/AgentViewKit/Diff/ChangedFilesView.swift`. Use
  `Sources/AgentViewKit/Diff/DiffSummary.swift` for the counts.
- **Priority:** P1.

### 3.4 `MessageActionBar` (hover action bar)

- **What:** A floating glass bar that shows on hover or focus of a message.
  It holds the `MessageActions` buttons. It stays visible for the last
  message.
- **Why:** assistant-ui `ActionBarPrimitive` (autohide), CopilotKit
  `toolbarVisible`, Vercel `MessageToolbar`. A footer row on each message
  adds height to each row.
- **ACP data:** the `MessageEntry` of the row. The verbs call
  `SessionModel.prompt(_:meta:)`.
- **File:** new `Sources/AgentViewKit/Items/MessageActionBar.swift`. Use the
  hover modifier of section 5.5.
- **Priority:** P1.

### 3.5 `ReadAloudButton`

- **What:** A button that reads a message aloud with `AVSpeechSynthesizer`.
  A second press stops it. It highlights nothing in v1.
- **Why:** assistant-ui `ActionBarPrimitive.Speak` and `StopSpeaking`,
  CopilotKit `readAloudButton`.
- **ACP data:** the text blocks of `AgentMessageEntry.content`. A host
  speech service goes through an environment value, the same as
  `speechTranscriber`.
- **File:** new `Sources/AgentViewKit/Input/ReadAloudButton.swift` and a
  `SpeechSynthesizer` protocol next to `Input/SpeechTranscriber.swift`.
- **Priority:** P2.

### 3.6 `ModelPicker` (searchable)

- **What:** A searchable popover for a `select` config option of category
  `model`. It shows the groups of the option and a search field. It sets
  the value with `SessionModel.setConfigOption(_:)`.
- **Why:** Vercel `ModelSelector` (cmdk search), assistant-ui composer
  model picker. A plain `Picker` does not scale to many models.
- **ACP data:** `SessionModel.configOptions`, category `model`.
- **File:** new `Sources/AgentViewKit/Config/ModelPicker.swift`.
- **Priority:** P2.

### 3.7 `StackTraceView`

- **What:** A view of a stack trace with the error type, the message and the
  frames. Each frame with a file path and a line is a button that opens the
  file. Internal frames collapse.
- **Why:** Vercel `StackTrace`. Agents often show build and test failures.
- **ACP data:** the `data` of an `ErrorEntry`, and the text of a
  `TerminalEntry` or of a tool call content block. The view parses the text
  at render time and keeps no copy. A host can turn the detection off.
- **File:** new `Sources/AgentViewKit/Terminal/StackTraceView.swift`.
- **Priority:** P2.

### 3.8 `TestResultsView`

- **What:** A summary of a test run (passed, failed, skipped, duration) with
  suites and the failed tests expanded.
- **Why:** Vercel `TestResults`. A coding agent runs tests in most turns.
- **ACP data:** the text of a `TerminalEntry` from an `execute` tool call.
  The view parses the output of `swift test`, XCTest, and Swift Testing at
  render time. It falls back to `TerminalView` when the parse fails.
- **File:** new `Sources/AgentViewKit/Terminal/TestResultsView.swift`.
- **Priority:** P2.

### 3.9 `ProtocolInspector` (devtools)

- **What:** A debug panel that lists the raw ACP `SessionUpdate` values in
  arrival order, the requests and the responses. It shows the JSON of each
  item with `JSONDisclosure`.
- **Why:** assistant-ui `react-devtools` (`DevToolsModal`), CopilotKit
  `inspectorTools`. It makes agent bugs easy to find.
- **ACP data:** `SessionModel.updateTap()`. The view keeps a ring buffer of
  view state only, because the model keeps no update log. Record this in
  the view state table of `Docs/decisions/acp-client-kit.md`.
- **File:** new `Sources/AgentViewKit/Diagnostics/ProtocolInspector.swift`.
- **Priority:** P2.

### 3.10 `PendingPromptsView` (queue)

- **What:** A list above the composer of the user messages with the send
  state `pending`. Each item has a Remove action when the agent supports a
  cancel of one prompt.
- **Why:** Vercel `Queue`, assistant-ui `ComposerPrimitive.Queue`, Xcode 27
  queued messages. The composer sends at once (`plan.md` §3.8), so the
  queue is the set of pending entries of the model, not a kit queue.
- **ACP data:** `UserMessageEntry.sendState` in `SessionModel.transcript`.
- **File:** new `Sources/AgentViewKit/Input/PendingPromptsView.swift`.
- **Priority:** P3. ACP has no "remove one queued prompt" method. Show the
  list without Remove until ACP gives one.

### 3.11 `CommandSnippet`

- **What:** One line of a shell command in the code font, with a copy
  button.
- **Why:** Vercel `Snippet`. Use it in the command subject of
  `PermissionView`, in the header of `TerminalView`, and in Markdown inline
  code that starts with `$`.
- **ACP data:** the `command` of a permission subject and of a terminal.
- **File:** new `Sources/AgentViewKit/Content/CommandSnippet.swift`.
- **Priority:** P3.

### 3.12 `DiagramView` (Mermaid)

- **What:** A native render of Mermaid flowcharts and sequence diagrams in a
  fenced `mermaid` block. Other diagram kinds show as a code block.
- **Why:** assistant-ui mermaid-diagram element. Agents use Mermaid for
  plans and architecture.
- **ACP data:** fenced blocks in the text of `AgentMessageEntry.content`,
  through the `EditorKitCodeBlockStyle` hook.
- **File:** new `Sources/AgentViewKit/Content/DiagramView.swift`.
- **Priority:** P3. No WebView, so the kit needs a native layout engine.
  Find a Swift Mermaid parser first.

### 3.13 `AssistantPanel` (popup and sidebar shells)

- **What:** Two shells for a host app: a floating panel (`NSPanel`) and a
  trailing inspector column. Each holds `AgentThreadView` and
  `PromptInputView`.
- **Why:** assistant-ui `AssistantModal` and `AssistantSidebar`, CopilotKit
  `CopilotPopup` and `CopilotSidebar`. They make the kit easy to add to an
  existing app.
- **ACP data:** the same models as `AgentThreadView`.
- **File:** new `Sources/AgentViewKit/Thread/AssistantPanel.swift`.
- **Priority:** P3.

### 3.14 Blocked by ACP (no work now)

These views need an ACP producer. The owner decision of 2026-10-02 removes
them until ACP gives one. Keep them on the watch list:

- `BranchPicker`: Vercel `MessageBranch`, assistant-ui
  `BranchPickerPrimitive`, CopilotKit `branchNavigation`.
- `CheckpointView`: Vercel `Checkpoint`. It needs a stable `session/fork`
  with a message id (`Docs/decisions/checkpoints.md`).
- `SubagentTreeView`: assistant-ui subagent list. It needs a `_meta` spawn
  key or an ACP subagent update (`Docs/decisions/subagent-source.md`).
- `FeedbackButtons`: assistant-ui and CopilotKit thumbs. ACP has no feedback
  method. A host can add them through the `.messageFooter` slot now.

## 4. Updates to our views

### 4.1 `ReasoningView`

- **File:** `Sources/AgentViewKit/Items/ReasoningView.swift`,
  `Sources/AgentViewKit/Items/ThoughtEntryBlock.swift`.
- **Change:** Open the block while the thought is the last entry of the
  transcript and `agentState` is `.running`. Close it when a later entry
  arrives, unless the user opened it. Show a shimmer title ("Thinking")
  during that time.
- **Why:** Vercel `Reasoning` auto-opens and auto-closes. CopilotKit shows
  "Thinking…" then collapses. `plan.md` §9 B asks for "shimmering title
  while in progress; auto-collapse on done". The model has no in-progress
  flag on a thought, but the position and `agentState` are model values.
- **Note:** The title shows "Thought for N seconds" from the `duration` of
  the thought entry. The client model writes the times (`EntryTiming`). The
  kit records no time. A thought with no end time or a replayed thought shows
  "Thought".

### 4.2 `ToolCallView`

- **File:** `Sources/AgentViewKit/Items/ToolCallView.swift`,
  `Sources/AgentViewKit/Items/ToolCallPart.swift`.
- **Change:** Show "Awaiting approval" in the row when a pending permission
  request has this tool call as its subject. Show the inline
  `PermissionView` under the row, the same as the linked elicitation.
- **Why:** Vercel `Tool` has the `approval-requested` state and
  `Confirmation` in the tool. assistant-ui puts the approval in the tool
  part.
- **Look:** The colors and fonts come from the EditorKit theme (section 5.12).

### 4.3 `ConversationView` and `ConversationEmptyState`

- **File:** `Sources/AgentViewKit/Thread/ConversationView.swift` and
  `Sources/AgentViewKit/Thread/ConversationEmptyState.swift`.
- **Done:** `ConversationEmptyState` is in its own file. It shows Markdown
  text that the host gives, with an optional title and an optional SF Symbol.
  The text renders through `ResponseView`, the same as the text of an agent
  message (Textual and `EditorKitCodeBlockStyle`), so headings, lists, links
  and code blocks show, and the EditorKit theme applies. The host sets the
  content with `ConversationEmptyState(title:systemImage:markdown:)` in the
  `emptyState` slot, or with `.conversationEmptyState(title:systemImage:markdown:)`
  for the drop-in `AgentThreadView`. With no host content, the empty state
  shows the standard text "No Messages".
- **Change:** Give the empty state a slot for the agent name (from
  `AgentInfoHeader` data), the suggestions, and the commands of
  `availableCommands`. Use `ToolCallGroup` (section 3.2) for runs of tool
  calls.
- **Why:** CopilotKit `welcomeScreen`, Vercel `ConversationEmptyState`
  (title, description, icon).

### 4.4 `MessageActions`

- **File:** `Sources/AgentViewKit/Items/MessageActions.swift`.
- **Change:** Make each button a separate public view (`CopyMessageButton`,
  `RetryButton`, `EditMessageButton`, `ExportThreadButton`), so a host can
  build its own bar. Add an "additional items" slot. Show the bar in
  `MessageActionBar` (section 3.4).
- **Why:** assistant-ui `ActionBarPrimitive` parts, CopilotKit
  `additionalToolbarItems`.

### 4.5 `ContextUsageView`

- **File:** `Sources/AgentViewKit/Status/ContextUsageView.swift`,
  `Sources/AgentViewKit/Status/UsageRingView.swift`.
- **Change:** Add a popover with the used tokens, the window size, the
  percent, and the cost. Add a warning tint at a threshold token of
  `AgentTheme`. Do not show a breakdown that ACP does not send.
- **Why:** Vercel `Context` hover card, assistant-ui context display.

### 4.6 `ConfigOptionsView`

- **File:** `Sources/AgentViewKit/Config/ConfigOptionsView.swift`.
- **Change:** Use `ModelPicker` (section 3.6) for the `model` category when
  the option has more than a threshold number of choices. Add a compact
  composer style that shows the current model and the thought level as
  chips.
- **Why:** Vercel `PromptInputSelect`, assistant-ui composer model picker.

### 4.7 `SourcesView`, `InlineCitation` and `CitationPayload`

- **File:** `Sources/AgentViewKit/Citations/SourcesView.swift`,
  `Sources/AgentViewKit/Citations/InlineCitation.swift`,
  `Sources/AgentViewKit/Citations/CitationPayload.swift`.
- **Change:** `CitationPayload` is a kit type with no ACP producer. Add an
  initializer that reads an `AgentMessageEntry`: each `resource_link` block
  and each `resource` block is a source, in block order. Show
  `SourcesView` in `AssistantMessageView` when the entry has sources.
  Record this mapping in a decision file.
- **Why:** Vercel `Sources` binds to `source-url` parts. Without a
  producer, the two views never show in a session.
- **Rule:** The initializer reads the entry in the view body. It is not a
  stored copy.

### 4.8 `ArtifactView` and `ArtifactPayload`

- **File:** `Sources/AgentViewKit/Attachments/ArtifactView.swift`,
  `Sources/AgentViewKit/Attachments/ArtifactPayload.swift`.
- **Change:** Add an initializer from an ACP `resource` or `resource_link`
  block, and from a file location of an `edit` tool call. Add an action
  slot (Vercel `ArtifactAction`) and a close action.
- **Why:** The view has no ACP producer at this time. Vercel `Artifact` has
  header actions.

### 4.9 `TerminalView`

- **File:** `Sources/AgentViewKit/Terminal/TerminalView.swift`,
  `Sources/AgentViewKit/Terminal/ANSIText.swift`.
- **Change:** Add a copy action and a "follow output" toggle. The SGR colors
  show: `ANSIText` maps them through the EditorKit `terminalPalette`, and the
  editor paints them as EditorKit color runs (`EditorModel.setColorRuns(_:)`
  and `addColorRuns(_:)`).
- **Why:** Vercel `Terminal` has `autoScroll` and a copy button.

### 4.10 `TaskListView`

- **File:** `Sources/AgentViewKit/Status/TaskListView.swift`.
- **Change:** Show a progress summary in the header ("3 of 7 done"). Show a
  shimmer on the header while an entry is in progress. Add a collapsed
  style for an old plan when a newer plan with the same `planId` exists.
- **Why:** Vercel `Plan` (`isStreaming` shimmer) and `Task`
  (collapsible). assistant-ui agent plan.

### 4.11 `SuggestionsView`

- **File:** `Sources/AgentViewKit/Input/SuggestionsView.swift`,
  `Sources/AgentViewKit/Input/DefaultPromptAccessory.swift`.
- **Change:** Add a default source that makes chips from
  `availableCommands` when the host gives no list. Keep the host list
  first.
- **Why:** CopilotKit and assistant-ui have suggestion sources. ACP has no
  suggestion update, but it has the commands.

### 4.12 `SpeechInputButton`

- **File:** `Sources/AgentViewKit/Input/SpeechInputButton.swift`,
  `Sources/AgentViewKit/Input/SystemSpeechTranscriber.swift`.
- **Change:** Show the live transcript in the composer while the user
  speaks. Add a level meter. Add a microphone menu that reads the audio
  input devices.
- **Why:** assistant-ui `DictationTranscript` and `useVoiceVolume`,
  CopilotKit `CopilotChatAudioRecorder`, Vercel `MicSelector`.

### 4.13 `PromptInputView`

- **File:** `Sources/AgentViewKit/Input/PromptInputView.swift`,
  `Sources/AgentViewKit/Input/EditorKitPromptEditor.swift`.
- **Change:** Add input history (Up arrow in an empty composer recalls the
  last prompts of the user messages in the transcript). Add a screenshot
  attach action (ScreenCaptureKit) to the accessory.
- **Why:** assistant-ui input history guide, Vercel
  `PromptInputActionAddScreenshot`.
- **Rule:** The history reads `SessionModel.transcript`. It keeps no list.

### 4.14 `AgentInfoHeader`

- **File:** `Sources/AgentViewKit/Connections/AgentInfoHeader.swift`.
- **Change:** Add a detail popover with the agent capabilities, the auth
  methods, and the prompt capabilities from the `initialize` answer.
- **Why:** Vercel `Agent` shows the model, the tools and the instructions.

### 4.15 `SessionListView`

- **File:** `Sources/AgentViewKit/Sessions/SessionListView.swift`.
- **Change:** Group the rows by date (Today, Yesterday, Earlier). Add a
  swipe and a context menu for delete. Mark the open sessions of
  `openSessions`.
- **Why:** assistant-ui thread list sidebar, CopilotKit
  `CopilotThreadsDrawer`.

### 4.16 `ErrorView`

- **File:** `Sources/AgentViewKit/Items/ErrorView.swift`.
- **Change:** Add a Retry action for a failed prompt (the user message with
  the send state `failed`). Show a `StackTraceView` (section 3.7) when the
  `data` holds a trace. Add a Copy action for the JSON.
- **Why:** assistant-ui `ErrorPrimitive`, Vercel `StackTrace`.

## 5. Cross-cutting concerns

Each item is a view modifier, an environment value, or a
shared base view. Each item applies to many views. Each item keeps the
binding rule: no copy of model data.

### 5.1 Loading and shimmer state

- **Pattern:** A modifier `.agentWorking(_ isWorking: Bool)` that applies
  `ShimmerView` to a title, and a `.redacted(reason: .placeholder)` skeleton
  for a row that waits for its first content.
- **Where:** `ReasoningView`, `TaskListView`, `ToolCallView`,
  `AssistantMessageView` (before the first chunk), `SessionListView` (while
  it refreshes), `ConfigOptionsView` (while `configOptions` is nil).
- **Why:** The kit has `ShimmerView` and `ActivityIndicator`, but each view
  decides alone. One modifier gives one look and one Reduce Motion rule.
- **File:** `Sources/AgentViewKit/Activity/ShimmerView.swift`.

### 5.2 Error boundaries

- **Pattern:** A shared `FailureCard` base view and a modifier
  `.renderFailure { error in }` for a host override. A view that cannot
  decode its content (bad JSON, bad patch, bad image data) shows the card
  with a "Show raw" disclosure, not an empty view.
- **Where:** `DiffView` (bad `git_patch`), `ImageView`, `AudioPlayerView`,
  `MathView` (bad LaTeX), `ElicitationView` (bad schema), `TerminalView`.
- **Why:** The kit rule is "nothing is dropped" (`plan.md` §3.6). SwiftUI
  has no error boundary, so each view must catch its own failure.
- **File:** new `Sources/AgentViewKit/Content/FailureCard.swift`.

### 5.3 Empty states

- **Pattern:** One `AgentEmptyState` base view on `ContentUnavailableView`,
  and a modifier `.emptyState { }` for each list view.
- **Where:** `ConversationView`, `SessionListView`, `ConnectionsView`,
  `ActivityTimeline`, `ConfigOptionsView`, `AttachmentInspector`.
- **Why:** Some list views show nothing when the list is empty. Vercel has
  `ConversationEmptyState` and `AttachmentEmpty`. A blank area looks broken.
- **File:** `Sources/AgentViewKit/Thread/ConversationEmptyState.swift`
  (`ConversationEmptyState` is now in its own file, see section 4.3).

### 5.4 Copy and export actions

- **Pattern:** A modifier `.copyable(_ text: () -> String)` that adds the
  Copy context menu item, the Command-C command in focus, and a hover copy
  button. It writes through the `pasteboard` environment value.
- **Where:** `CodeBlockView`, `TerminalView`, `CommandOutputView`,
  `ErrorView`, `UnknownItemView`, `JSONDisclosure`, `DiffView`,
  `CommandSnippet`, each message.
- **Why:** Each web kit has a copy button on code, terminal, stack trace and
  messages. The kit has copy in some views only.
- **File:** `Sources/AgentViewKit/Platform/Pasteboard.swift`.

### 5.5 Hover action bars

- **Pattern:** A modifier `.hoverActions { }` that shows a glass toolbar on
  `onHover` or keyboard focus, and keeps it visible for VoiceOver as custom
  actions (`accessibilityActions`).
- **Where:** messages (`MessageActionBar`), `CodeBlockView`, `ToolCallView`,
  `AttachmentChip`, `SessionListView` rows.
- **Why:** assistant-ui and CopilotKit show actions on hover. Pointer-only
  actions fail VoiceOver users, so the modifier must also add the custom
  actions.
- **File:** new `Sources/AgentViewKit/Platform/HoverActions.swift`.

### 5.6 Keyboard shortcuts

- **Pattern:** Each new verb is an `AgentCommandVerb` with a chord in
  `AgentKeymap`. Views show the chord in the help tag
  (`.help("Copy  ⇧⌘C")`).
- **Where:** new verbs: read aloud, open changed files, toggle reasoning,
  approve with comment, open the model picker, next and previous session.
- **Why:** `plan.md` decision 14: the kit verbs are EditorKit commands.
  Vercel shows shortcuts in tooltips (`PromptInputButton`).
- **File:** `Sources/AgentViewKit/Commands/AgentCommands.swift`,
  `Sources/AgentViewKit/Commands/AgentKeymap.swift`.

### 5.7 Focus

- **Pattern:** Extend `AccessibilityFocusMover` to keyboard focus with
  `@FocusState` and `.focusable()`. A new permission or elicitation card
  takes the keyboard focus. When it resolves, the composer takes the focus.
  `focusComposer` already exists.
- **Where:** `PendingRequestsHost`, `PermissionView`, `ElicitationView`,
  `PromptInputView`, `ThreadMinimapView`.
- **Why:** `plan.md` §6 asks for this for VoiceOver. Keyboard users need the
  same.
- **File:** `Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift`.

### 5.8 Accessibility labels and announcements

- **Pattern:** A shared `AccessibilityText` namespace with one function for
  each entry kind (label, value, hint). An override view applies
  `.accessibilityEntry(_ entry:)` to get the same text. Add announcements
  for: compaction done, notice added, connection lost, session closed.
- **Where:** all entry views, all banners, all overrides through
  `ItemViewOverrides.swift`.
- **Why:** `plan.md` §6: "A builder override inherits the duty to keep it."
  A modifier makes that duty easy.
- **File:** `Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift`.

### 5.9 Motion and Reduce Motion

- **Pattern:** One modifier `.agentAnimation(_:value:)` that reads
  `accessibilityReduceMotion` and returns `nil` animation when it is on. One
  `.agentSymbolEffect(_:)` that does the same for SF Symbol effects.
- **Where:** all views that animate. At this time only `ShimmerView` and
  `ToolCallView` read `accessibilityReduceMotion`. `ThreadMinimapView`,
  `ScrollToBottomPill`, `StatusBar`, `ConnectionStatusChip`, `ReasoningView`
  and the glass morph in `PromptInputView` must use it.
- **Why:** `plan.md` §6: "Respect Reduce Motion: no glass morphing, no
  streaming animation."
- **File:** new `Sources/AgentViewKit/Theme/AgentMotion.swift`.

### 5.10 Theming hooks

- **Pattern:** Add motion tokens, typography tokens (prose, code, caption),
  and per-status colors to `AgentTheme`. Keep one source: the theme makes
  the EditorKit `Theme`. Add `.agentTheme(from editorTheme:)` so a host can
  start from an EditorKit theme (Zed, VS Code, tmTheme import) and get the
  chrome colors.
- **Where:** all views.
- **Why:** The owner goal: the EditorKit themes are the kit themes. Today
  the bridge goes one way (`AgentTheme` to EditorKit). The web kits use one
  token set for code and chrome.
- **File:** `Sources/AgentViewKit/Theme/AgentTheme.swift`,
  `Sources/AgentViewKit/Theme/AgentTheme+EditorKit.swift`.

### 5.11 Telemetry and analytics hooks

- **Pattern:** An environment value `agentEvents` with a closure
  `(AgentUIEvent) -> Void`. The views send UI events: permission answered,
  elicitation answered, message copied, retry, edit, export, config option
  changed, session opened. The kit sends nothing by default.
- **Where:** each verb of each view.
- **Why:** assistant-ui has `react-o11y` and feedback adapters. CopilotKit
  has `observabilityHooks` (v1) and `onError` (v2). A host needs the UI
  events, and the model does not give them.
- **Rule:** The closure gets the event. The kit keeps no event log.
- **File:** new `Sources/AgentViewKit/Platform/AgentEvents.swift`.

### 5.12 The look follows the theme (no style protocols)

- **Decision of the owner (2026-10-11):** The kit has no style protocols in
  the `ButtonStyle` pattern, and no style overrides. The look of each view
  follows the theme. The EditorKit `Theme` in `\.editorTheme` gives the
  colors and the fonts (`Docs/decisions/visual-audit.md`, card ^3c1k7g8).
  `AgentTheme` gives only the layout tokens.
- **Pattern:** A host changes the look with a theme: `SystemTheme`, the
  `DefaultTheme` presets, or a Zed, VS Code or tmTheme file. A host that
  needs a different view for one entry kind uses the typed override of that
  kind (`Thread/ItemViewOverrides.swift`).
- **Where:** all views. A view reads each color and font from the theme. It
  adds no style parameter.
- **Why:** One theme gives one look across the kit and the code views. Style
  protocols would give a second way to change the look, next to the theme.

### 5.13 Slots and headless parts

- **Pattern:** Make the inner parts of each composite public:
  `ToolCallHeader`, `ToolCallBody`, `PermissionOptionButtons`,
  `ReasoningHeader`, `MessageContentView`. Each part reads the entry
  object. A host can then build its own view from kit parts.
- **Where:** `ToolCallView`, `PermissionView`, `ReasoningView`,
  `UserMessageView`, `AssistantMessageView`, `DiffView`.
- **Why:** assistant-ui has 19 primitive groups. Vercel has compound parts.
  The kit has slots on the composer and elicitation only.

### 5.14 Localization

- **Pattern:** Put each user string in `String(localized:bundle:.module)` or
  `LocalizedStringResource`. Add a `Localizable.xcstrings` catalog under
  `Sources/AgentViewKit/Resources/`. Add `defaultLocalization: "en"` to
  `Package.swift`. Use `Text(_:format:)` for numbers, dates and token
  counts.
- **Where:** all views. Some files use `String(localized:)`
  (`Elicitation/ElicitationView.swift`, `Status/ContextUsageView.swift`,
  `Connections/AgentAuthView.swift` and others). Most literals are bare
  `Text("…")` with no bundle, so they look up the host bundle.
- **Why:** CopilotKit has 20 label keys. The kit has none. A bare literal in
  a package does not localize.
- **File:** `Package.swift`, new `Sources/AgentViewKit/Resources/Localizable.xcstrings`.

### 5.15 Preview fixtures

- **Pattern:** A `Previews` folder with fixture builders that make a
  `SessionModel` from a recorded ACP update stream through
  `InProcessAgent` and a scripted agent. Add `#Preview` blocks for each
  public view, in light and dark, at the large Dynamic Type sizes.
- **Where:** all public views. `Sources/AgentViewKit` has no `#Preview` at
  this time.
- **Why:** The web kits show a live example for each component. Previews
  speed up design work and catch layout bugs. The fixtures use the real
  models, so they keep the binding rule.
- **File:** new `Sources/DemoSupport/Fixtures/` (or a new
  `AgentViewKitPreviews` target), and `#Preview` blocks in each view file.

### 5.16 Hit-area and density

- **Pattern:** One `AgentTheme.Density` value drives row height, padding and
  control size in all views through a modifier `.agentDensity()`.
- **Where:** `ToolCallView`, `TaskListView`, `SessionListView`,
  `ActivityTimeline`, `ConnectionRow`.
- **Why:** `AgentTheme` has `Density`, but each view must read it the same
  way. Xcode 27 uses compact rows (`plan.md` §5).
- **File:** `Sources/AgentViewKit/Theme/AgentTheme.swift`.

### 5.17 Entry times (a decorator)

- **Decision of the owner (2026-10-11):** The time is a decorator. A view
  modifier wraps a row with a view that tells when. The message views do not
  show a time by themselves. The default is no time.
- **Decision of the owner (2026-10-12):** The decorator is the one way to
  show a time. `UserMessageView`, `AssistantMessageView` and `MessageHeader`
  take no host `date:` parameter, and the header shows only the name of the
  sender.
- **Pattern:** `.transcriptTiming()` sets the environment value
  `showsTranscriptTiming`. `ItemRow` reads it, so each row of
  `ConversationView` and `AgentThreadView` shows an `EntryTimingView` below
  the entry. `.entryTiming(_:)` wraps one view of a host, such as an
  override. The view shows the start time and, when the entry ended, its
  duration, with the system formatters (`Date.FormatStyle`,
  `Duration.UnitsFormatStyle`). VoiceOver reads the time as one element after
  the entry.
- **Where:** user messages, agent messages, thoughts, tool calls and the
  other entries. The `ReasoningView` title and the `ActivityTimeline` thought
  row read the `duration` of the thought entry.
- **Rule:** The times come from the `EntryTiming` of each entry of the client
  model (`startedAt`, `endedAt`, `duration`). The kit records no time and
  keeps no copy. A replayed entry has no time and shows none. There are no
  turn times: the client model has no turns. The view has no style parameter.
  Its font comes from the EditorKit theme and its spacing from `AgentTheme`
  (section 5.12).
- **File:** `Sources/AgentViewKit/Items/EntryTimingView.swift`,
  `Sources/AgentViewKit/Thread/ItemRow.swift`.

## 6. Data binding: ACP client model and transcript entries

This section records how the views get their data (review of 2026-10-11). Paths are below `Sources/AgentViewKit/` unless stated.

### Result

- No view reads a FoundationModels `Transcript`. `Package.swift` and `ImportBoundaryTests` forbid FoundationModels imports. `ThreadExporter` reads `[TranscriptEntry]` of the ACP client. `DemoSupport` holds ACP agents only. There is one source of truth: the FoundationModelsACPClient models.
- The legacy designs are gone: the Router, the structured items, the `schemaName` catalog, `AgentViewKitACP` and the kit copies of the ACP value types. `RemovedVocabularyTests` prevents their return.
- The problems are smaller. Different views read the same concept in different ways. Some helpers calculate again the state that the client already has. Some APIs are not used or are only partly connected.

### Binding map

| Data surface | Client source | How the kit reads it |
|---|---|---|
| Transcript entries | `session.transcript` | `ConversationView` → `ItemRow`, with an override slot for each case |
| Messages | user and agent message entries | kit enum `MessageEntry` (`MessageItemView.swift:12`), `TranscriptMessageView` |
| Thoughts | thought entry | `ThoughtEntryBlock`, `ReasoningView` |
| Entry times | `EntryTiming` of each entry (`startedAt`, `endedAt`, `duration`) | `EntryTimingView` through `ItemRow` when `showsTranscriptTiming` is on; the thought title |
| Tool calls | tool call entry | direct, with the kit helpers `shownTitle`, `shownKind`, `shownStatus` (`ToolCallPart.swift:22-35`); `ToolCallRegistry` slot |
| Plan, terminal, compaction, errors, unknown | entry objects | direct |
| Permissions | `session.pendingPermissions` | `PendingRequestsHost` |
| Elicitations | session and connection `pendingElicitations`, `linkedElicitationIDs` | `PendingRequestsHost`, `ToolCallView` |
| Usage | `session.usage` | `ContextUsageView` |
| Config and modes | `session.configOptions` | `ConfigOptionsView`, `PermissionModePicker` |
| Commands | `session.availableCommands` | `PromptInputView` → `SlashCommandSource` |
| Sessions list | `connection.sessions` and capability flags | `SessionListView` |
| Connection and auth | `connection.state`, `authState`, `initializeResponse` | `AgentConnectionBanner`, `AgentLoginPrompt`, `AgentInfoHeader` |
| Notices and replay | `session.notices`, `history`, `hasMissedUpdates`, `isClosed` | `SessionNoticeBanner`, `SessionStreamBanner` |
| MCP servers | `session.mcpServers` | `ConnectionsView` |
| Attachments | none (composer only) | kit type `Attachment`; `PromptContent.swift:68-136` makes ACP blocks |

Most views get `session:` and `connection:` as init parameters. `PromptInputView`, `ConnectionsView`, `MessageActions`, `DefaultPromptAccessory` and `ToolCallView` read environment values (`SessionTranscriptEnvironment.swift:13`, `:23`) that `ConversationView` and `ActivityTimeline` set.

### Redundancy

- `PermissionView.swift` (about lines 250-283) searches `session.transcript` for the tool call. The client already has `toolCallEntry(for:)` (`SessionModel+Pending.swift:319`).
- `ThreadAccessibility.hasResult` (`ThreadAccessibility.swift:103-109`) and `ToolKindSymbol.isLive` (`ToolKindSymbol.swift:84-88`) give different results for unknown statuses.
- Two code paths find the mode option: `PermissionModePicker.swift:50-55` and `PermissionPresentation.swift:134-143`.
- `ConfigSelectChoices.swift:44-61` encodes and decodes the select options again. `ElicitationFieldSchema` and `ElicitationValidator` are kit projections of the ACP schema.
- The kit holds copies of agent extension values: `StateBanner+StopReasons.swift:16-59` (`_truncated`, `_stalled` and others) and `ToolKindSymbol.swift:41` (`"_lost"`). FoundationModelsACP and the client do not define these values.
- Turn logic is in the kit: `answerPermission` sends the reject comment as a new prompt (`SessionModel+Requests.swift:110-116`); `switchToAuto` sends two requests (`PermissionView.swift:388-392`); Retry sends the earlier user content again (`MessageActions.swift:235-239`).

### Divergent paths

- "Running" has two meanings. `SessionModel.isRunning` (`SessionTranscriptEnvironment.swift:32`) checks `.running` only; the Stop button and `ActivityIndicator` use it. `AgentCommandTarget.isActive` (`AgentCommandTarget.swift:188-192`) also counts `.requiresAction`; the cancel command and the turn announcements use it. During `requiresAction`, the cancel command works but the Stop button is hidden.
- A linked elicitation can show two times: inline in `ToolCallView`, and again in `PendingRequestsHost.swift:111`, which lists each session elicitation. The test `aLinkedElicitationShowsInTheRowOfItsToolCallOnly` does not count the cards.
- The drop-in view does not show connection-scoped elicitations: `AgentThreadView.swift:129` uses `PendingRequestsHost(session:)` only. But `ThreadAccessibility.swift:168` includes both scopes, so VoiceOver announces requests that have no card.
- `ActivityTimeline` does not use the override slots (`ActivityTimeline.swift:257-268`). `ActivityState` reads the raw `status == .inProgress` (`ActivityIndicator.swift:30`), not `shownStatus`.
- There are three send paths: the composer sends the prompt capabilities and the attachments (`PromptInputView.swift:202`); the `.send` command sends plain text only (`AgentCommandTarget.swift:246`); Retry sends the raw content (`MessageActions.swift:239`).
- The demo finds the auth state from errors (`DemoAgent.isAuthenticationRequired`, `DemoAgent.swift:108`; `ACPTabView.swift:228`, `:245`), not from `connection.authState`. Its `.signingIn` screen is a second sign-in surface next to `AgentLoginPrompt`.
- No code calls `initializeCheckingProtocolVersion` (`SupportedProtocolVersions.swift:94`). The README, the demo (`DemoAgent.swift:218`) and `ScriptedSession.swift:166` call `initialize` directly.
- The test fixtures do not diverge: `ScriptedSession` drives real `ConnectionModel` and `SessionModel` objects over the wire.

### Unused or partly connected code

- The `duration` parameter of `ReasoningView` is always `nil` (`ReasoningView.swift:91`, `:105`, `:156`, `:200`).
- `CitationPayload` and `SourcesView` have no ACP source. `TextBlockView.swift:17` gives no citations to `ResponseView`, and `ParagraphView.swift:52` sends `[]`.
- The drop-in view and the demo do not use `ArtifactPayload`, `ArtifactView`, `ToolToggles`, `ActivityTimeline`, `ActivityIndicator` or `threadMinimap`.

### Recommendations, by impact

1. Fix the elicitation surfaces: the host skips linked elicitations, and `AgentThreadView` shows the connection-scoped ones. Files: `PendingRequestsHost.swift`, `AgentThreadView.swift`, `ToolCallEntryViewHostedTests.swift`.
2. Use one "agent active" predicate everywhere. Files: `SessionTranscriptEnvironment.swift`, `AgentCommandTarget.swift`, `DefaultPromptAccessory.swift`, `PromptInputView.swift`, `ActivityIndicator.swift`.
3. Move the turn logic into the client, or behind host callbacks. Files: `SessionModel+Requests.swift`, `PermissionView.swift`, `MessageActions.swift`.
4. Use the client `toolCallEntry(for:)`. Move the select-choices decode to FoundationModelsACP. Files: `PermissionView.swift`, `ConfigSelectChoices.swift`.
5. Merge the duplicate helpers (`hasResult` and `isLive`; the two mode-option finders). Make `ActivityTimeline` use the override slots and `shownStatus`.
6. Send all prompts through one path. Give the `.send` command the prompt capabilities. File: `AgentCommandTarget.swift`.
7. Read `authState` in the demo. Files: `DemoAgent.swift`, `ACPTabView.swift`.
8. Remove or connect the unused code: the `duration` API, `initializeCheckingProtocolVersion`, the citation and artifact payloads, `ToolToggles`. Move the agent extension values to the agent that makes them.

## 7. Top 10 actions, in priority order

1. Add `ToolCallGroup` and use it in `ConversationView` (section 3.2).
2. Add `SessionHeader` that reads `sessionInfo` (section 3.1).
3. Change `ReasoningView` to open while it streams and to close after
   (section 4.1).
4. Give `SourcesView`, `InlineCitation` and `ArtifactView` an ACP producer
   from `resource_link` and `resource` blocks (sections 4.7 and 4.8).
5. Add `ChangedFilesView` from tool call locations and diffs (section 3.3).
6. Add the hover action bar modifier and `MessageActionBar` (sections 3.4
   and 5.5).
7. Make the inner parts of the composite views public (section 5.13).
   Their look follows the theme (section 5.12).
8. Add localization: string catalog, `defaultLocalization`, and bundle
   lookups (section 5.14).
9. Add preview fixtures on `InProcessAgent` and `#Preview` blocks for each
   public view (section 5.15).
10. Add the Reduce Motion modifier and use it in each animated view
    (section 5.9).

Do the data binding fixes of section 6 before these actions. Recommendations 1
and 2 of section 6 are defects that a user can see: a linked elicitation can
show two times, and the Stop button is hidden while the agent waits for an
answer.
