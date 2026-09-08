# Plan review: AgentViewKit against EditorKit, FoundationModels 27, and ACP v2

Date: 2026-09-08. Reviewed: `plan.md` at commit 82547cd.

Sources checked:

- EditorKit at `../EditorKit` (main, no tagged release).
- FoundationModels interface in the macOS 27 SDK (Xcode 27.0 beta, build 27A5252f).
- ACP v2 schema and Swift SDK at `../FoundationModelsACP` (schema-v2.0.0-alpha.3), the client at `../FoundationModelsACPClient`, the agent at `../FoundationModelsACPAgent`.
- The runtime at `../FoundationModelsRouter`, `../FoundationModelsAgents`, `../FoundationModelsAgentHarness`, `../FoundationModelsExtras`, `../FoundationModelsMultitool`.
- Public sources for Textual, SwiftStreamingMarkdown, math engines, Vercel AI Elements, assistant-ui, AG-UI, Xcode 27, and the WWDC 2026 sessions.

## 1. Summary

The component inventory in §9 is good. The market gap in §2 is real. No SwiftUI kit with native tool-call and reasoning views has more than a few stars.

The architecture in §3 does not hold. It has four problems:

1. `Transcript` is not observable. Only `LanguageModelSession` is.
2. The runtime does not give a live `Transcript` to a UI. It gives `SessionProjection`, an `@Observable` class with its own entry model.
3. The agentic CLIs do not go through `LanguageModelSession`. They are ACP peers. The ACP client gives `ACPSessionState`, an `@Observable` class, and it must not import FoundationModels.
4. The runtime spec that the plan cites (§3, §4.1, §4.8, §4.11) does not exist in any repo or in git history. There is no permission gate in the runtime.

The fix is the idea the plan already names in §2 and then drops: bind the views to a kit-owned runtime model, with one adapter per source. See §6 below.

EditorKit is a code editor and a command system. It is not a diff viewer and it does not stream. The plan asks it for three things it does not have. See §2 below.

## 2. EditorKit: what the plan assumes and what exists

| Plan assumption | EditorKit today | Action |
|---|---|---|
| "NSTextView-backed surface" (§4.1, §8) | TextKit 2 over a rope, with its own row grid (`EditorTextScaffold`, `RowGrid`). Not NSTextView. | Correct the text. The performance claim still holds. |
| Read-only highlight mode for code blocks | `EditorModel.isReadOnly` exists. `EditorView(model:)` hosts it. | OK. |
| Syntax highlighting for agent code | Tree-sitter, but only JSON and Markdown grammars are linked. Other languages need a host TextMate grammar (`TextMateGrammarRegistry`). Runtime grammar loading is a stated non-goal. | Agent output is mostly Swift, Python, TypeScript, Rust, Go, shell, YAML. The kit must ship a grammar bundle or EditorKit must link more grammars. Research item R2. |
| `DiffView` in "EditorKit diff mode" (§9 F, §7) | No diff view. Only `ChangeSet.unifiedDiff(against:)`, a plain-text debug output. | Build `DiffView` in the kit, or propose a diff feature to EditorKit. Research item R3. |
| Streaming code into a code block | No append API. The write path is `EditorModel.dispatch(Transaction)` with `ChangeSet(fromLength:replacements:)`. Syntax reparse is incremental with an 8 ms debounce. | Build a small append helper on `dispatch`. The balancer in §8 must feed the open code fence to this path, not to Textual. |
| Slash commands, chips, `@file` come from EditorKit (§4.1, §9 D) | The primitives exist: `TokenField`, `SmartTag`, `HashtagDetector`, `WikilinkDetector`, `CompletionEngine`, `CompletionPopup`, `PathCompletionSource`, `SingleLineField`, `CommandPalette`. No "slash command" feature exists as one unit. | True in parts. The kit must assemble them and add a completion source fed by ACP `available_commands_update`. |
| `AgentTheme` design tokens (§5, §11.6) | EditorKit has its own `Theme` protocol, `StyleKey`, and importers for Zed, VS Code, and tmTheme. Applied with `.editorTheme(_:)`. | Add a bridge. `AgentTheme` must produce an EditorKit `Theme` so code blocks match the chrome. |
| Dynamic Type for code (§6) | Line height and font come from `\.editorLineHeight` and `SendableFont`. No Dynamic Type path is documented. | Verify. Research item R11. |
| Not in the plan | `EditorCommands` and `EditorCommandsUI`: focus-scoped commands, keymaps (CUA, Vim, Emacs), a palette, and `ProgressCenter`. | Use them. The kit verbs (send, interrupt, approve, jump) should be `Command`s. `ProgressCenter` can back tool-call progress. Xcode 27 exposes the same idea as skills and slash commands. |
| Not in the plan | `EditorIntelligence.FoundationModelsSession` and `EditorServices.MCPClient` exist. | Draw the boundary. The kit must not duplicate these. |
| Version | Pre-1.0, no tag. Package pins are exact. macOS 15, iOS 18, Swift 6.2, strict concurrency, `MainActor` default isolation in UI targets. | Pin `branch: "main"`. Adopt the same isolation defaults. |

## 3. FoundationModels: what the macOS 27 SDK gives

Wrong in the plan:

1. `Transcript` is a `struct`. It is `Sendable`, `Equatable`, `Codable`, `RandomAccessCollection`, and on 27 also `MutableCollection` and `RangeReplaceableCollection`. It is not `Observable`. `AgentTranscriptView(transcript)` can render a snapshot only. Observation comes from `LanguageModelSession.transcript` read in a view body, or from `SessionPropertyValues.history`, which is `Observable`.
2. `StructuredSegment.source` is deprecated in 27. The name is `schemaName`. The runtime keys segments by full Swift type name, for example `FoundationModelsRouter.OperationEventSegment`, not by short tokens like `chart`.
3. `interrupt()` has no SDK backing. There is no cancel API. The host cancels the `Task` and sets `transcriptErrorHandlingPolicy` to `.revertTranscript` or `.preserveTranscript`.
4. `Transcript.Entry` and `Transcript.Segment` are not `@frozen`. Every switch needs `@unknown default`.
5. `ToolOutput` has `id`, `toolName`, `segments` only. No status, no error, no duration, no metadata. A failed tool surfaces as a thrown `ToolCallError`, not as an entry.
6. No type in `Transcript` carries a `Date`. Durations and timelines must be measured by the host.
7. `GeneratedContent` has no `properties()` or `elements()`. Walk `kind` (`.structure(properties:orderedKeys:)`, `.array`) or use `value(_:forProperty:)`. It is not `Codable`; use `jsonString` and `init(json:)`.

New in 27 that the plan must use:

1. `Transcript.Entry.reasoning(Reasoning)` with `segments`, `signature`, `metadata`. Reasoning is first-class. It is not a custom segment. `ReasoningView` binds to it.
2. `Transcript.Segment.attachment(AttachmentSegment)` with `Attachment.image(ImageAttachment)` and a `label`. Images only. No audio, video, or files.
3. `LanguageModelSession.usage` and `Response.usage` and `Snapshot.usage`: `input.totalTokenCount`, `input.cachedTokenCount`, `output.totalTokenCount`, `output.reasoningTokenCount`. `contextSize` and `tokenCount(for:)` are 26.4. `PrivateCloudComputeLanguageModel.quotaUsage` adds a quota state.
4. `LanguageModelError` cases: `contextSizeExceeded(contextSize:tokenCount:)`, `rateLimited`, `guardrailViolation`, `refusal`, `timeout`, and others. The kit needs an error block for each.
5. `DynamicProfile` hooks `.onPrompt`, `.onResponse`, `.onReasoning`, `.onToolCall`, `.onToolOutput`. This is the event stream an activity timeline needs, with host timestamps.
6. `LanguageModel` and `LanguageModelExecutor` protocols. Third-party models drive the same `Transcript`. The "thin adapter" in §3 is now a supported path.
7. `ToolCall.metadata` and `Prompt.metadata` exist. `ToolOutput.metadata` does not.
8. `SystemLanguageModel.Adapter` is obsoleted in 27. Remove adapter mentions.
9. `ResponseStream.Snapshot.transcriptEntries` is 27-only. On 26 the snapshot has no entries.

## 4. The runtime: what really exists

1. The Router plan was deleted on 2026-08-25. Recover it with `git show 10b8f6a^:plan.md` in `../FoundationModelsRouter`. Its headings are not numbered. The §-numbers in `plan.md` resolve to nothing.
2. The Router exposes `SessionProjection` (`@MainActor @Observable`). Its `TranscriptEntry.Kind` has four cases: `text`, `reasoning`, `toolCall`, `compaction`. It is fed by `SessionEvent`. `RoutedSession.transcript` is `async` on an actor. It is not bindable.
3. Structured segments exist in the Router. The protocol is `PersistableStructuredSegment` with a `Codable` content, not `@Generable`. The catalog has two names: `CompactionSegment` and `OperationEventSegment`. The Router appends them to the persisted transcript only, never to the live session transcript.
4. There is no approval, plan, citation, artifact, or authorization segment anywhere. The kit would define these, not consume them. The `schemaName` catalog must be agreed with `RouterSegmentSchemaNames`.
5. The transcript is not monotonic. Compaction rewrites it. Entries a view has shown can disappear. A pure append renderer cannot show this.
6. Elicitation exists as `FoundationModelsExtras.ElicitationRequest` inside `OperationEvent`. `../FoundationModelsMultitool/eventplan.md` names AgentViewKit as the presenting layer and lists its URL-mode obligations. Those match §13.4.
7. The ACP client (`ACPSessionState`, `SwiftUIACPClient`) treats permission and elicitation as pending observable state, not as transcript entries. This is the opposite of the "no parallel channel" rule in §3.

## 5. ACP v2: what the schema gives and what the plan lacks

The SDK targets `schema-v2.0.0-alpha.3`. Upstream marks v2 as draft and not production-ready. The stable line is v1 (schema-v1.21.0). Research item R6 covers this.

v2 facts that shape the kit:

1. There is no `tool_call` variant and no `ToolCall` type. Only `ToolCallUpdate` with `PatchField` upserts. First sight creates, later sights patch. Every field can be omitted, cleared, or replaced.
2. Tool kinds: `read`, `edit`, `delete`, `move`, `search`, `execute`, `think`, `fetch`, `switch_mode`, `other`, plus unknown. Status: `pending`, `in_progress`, `completed`, `failed`, `cancelled`, plus unknown. The agent emits custom `_lost` and `_unknown` statuses.
3. Tool content: `content(ContentBlock)`, `diff`, `terminal`. A diff is a list of path changes plus one `git_patch` text. Per-file old and new text is gone.
4. Terminals are agent-owned. The client renders `terminal_update` and `terminal_output_chunk` (base64). No `terminal/*` client methods.
5. Plans are keyed by `planId`. Each update replaces that plan. Entries have `priority` and `status` with `cancelled`.
6. `state_update`: `running`, `idle(stopReason)`, `requires_action`. `StopReason` arrives here, not on the prompt response: `end_turn`, `max_tokens`, `max_turn_requests`, `refusal`, `cancelled`.
7. Modes are gone. `config_option_update` carries `select` and `boolean` options with categories `mode`, `model`, `model_config`, `thought_level`. This is the model picker, the permission-mode picker, and the reasoning-level picker in one.
8. `usage_update`: `used`, `size`, optional `cost(amount, currency)`.
9. `session_info_update`: `title`, `updatedAt`. `session/list` returns `SessionInfo` with cursors.
10. Permission: `title` is required. `subject` is `tool_call(ToolCallUpdate)` or `command(command, cwd, terminalId?)`. Options are `allow_once`, `allow_always`, `reject_once`, `reject_always`. Outcome is `selected(optionId)` or `cancelled`.
11. Agent auth: `AuthMethod` is `terminal` (run an interactive command) or `agent`. This is not OAuth and not MCP. §12 has no view for it.
12. Content blocks: `text`, `image`, `audio`, `resource_link` (with `icons`), `resource` (text or blob). `Annotations` carry `audience` and `priority`.
13. Elicitation passthrough exists with a `scope` (session and toolCallId, or requestId). The schema matches §13 except that legacy `enumNames` is not in v2.
14. Every union has an `unknown` case that must render. Every type has `_meta`.
15. No subagent update exists. `session/fork` is unstable. Compaction updates are unstable.

Missing from §9 as a result: a terminal view, a config-options surface, a session list, a requires-action banner, a stop-reason line, a cost field in usage, a command-permission subject with `cwd`, agent-auth views, resource and audio content views, a compaction marker, and a generic unknown-item view.

## 6. Recommended architecture change

Keep §9. Replace §3 with a runtime model, which is what assistant-ui does and what the plan praises in §2.

1. Define `AgentThread`, an `@Observable` model the views bind to. Shape it after the ACP v2 update stream, because that stream is the superset: messages with ids, tool calls as patchable records, plans by id, terminals by id, config options, usage, session info, and a state machine. `ACPSessionState` is a working draft of this model.
2. Define two adapters. `FoundationModelsThreadAdapter` observes a `LanguageModelSession`, or consumes Router `SessionEvent`, and maps `prompt`, `response`, `reasoning`, `toolCalls`, `toolOutput`, and `.structure` segments by `schemaName`. `ACPThreadAdapter` folds `SessionUpdate` into the model with `PatchField` rules. `SessionUpdateAggregator` already has those rules.
3. Keep the verbs on a protocol. Add `setConfigOption`, `respond(to: PermissionRequest)`, `login(AuthMethod)`, `cancel`. Drop the claim that `interrupt` is derivable.
4. Model in-progress state from the model's state machine and from unpaired records, as §3 says. Both sources supply it.
5. Support replace and clear, not append only. Compaction and v2 whole-message upserts need it.
6. Keep pending permission and elicitation as observable pending state on the model, with an in-thread card that reads it. This keeps the transcript honest and matches the client library.
7. Keep the `.structure` `schemaName` registry for FoundationModels sources. Agree the catalog with the Router.

Everything else in the plan survives this change. The typed override modifiers in §3 and the slots in §7 apply to the model's records instead of to `Transcript.Entry`.

## 7. Other corrections

1. Textual exists (0.5.0, 2026-06-15, macOS 15). It has `CodeBlockStyle` with `makeBody(configuration:)`. The configuration gives `languageHint` and the raw code, so EditorKit can replace the whole block. It has no streaming mode. Issue 47 reports a full re-parse on each update. The paragraph split in §8 is required, not optional. Research item R1.
2. Textual has a `.math` syntax extension backed by `swiftui-math` 0.1.0, which has had no activity since January. SwiftMath and iosMath are the maintained Core Text engines. Decision 7 must pick one. Research item R9.
3. SwiftStreamingMarkdown (0.7.0) streams well but refuses custom code-block views. It cannot host EditorKit. Drop it from decision 4 as a fallback.
4. Long-form reading: the SwiftUI API is `accessibilityLinkedGroup(id:in:)`. `causesPageTurn` is old. Rewrite §6 around the linked group.
5. Liquid Glass: no new `glassEffect` or `GlassEffectContainer` API in 27. `appearsActive` is confirmed. Remove "second-iteration tokens".
6. `textSelection(_:)` on 27 gives range selection inside containers. Decision 8 may be too cautious. Research item R10.
7. Xcode 27 confirmed: plan mode with editable Markdown artifacts, queued messages, `@` inline annotations, a History slider with Restore, per-response Undo, an agents and models picker that includes any ACP agent, permissions settings with allowed commands and tools. Add a checkpoint or rewind surface to §9 (Vercel has `Checkpoint`, Claude Code has `/rewind`).
8. Vercel AI Elements 1.9 added `Queue`, `Plan`, `Checkpoint`, `Chain of Thought`, `Model Selector`, `Terminal`, `Commit`, `File Tree`, `Stack Trace`, `Test Results`, and voice parts. AG-UI added `REASONING_*`, `ACTIVITY_*`, and `SUBAGENT_*` events. assistant-ui 0.15 added a tool UI registry and approval parts. Update §2 and §10.
9. Subagents: no ACP update carries them. Claude Code, Cursor, and Codex all ship a tree panel. Move `AgentGraphView` from "canvas, later" to "tree, v1" and find a data source. Research item R14.
10. Permission UX in 2026 is mode-based: Claude Code `default`, `acceptEdits`, `plan`, `auto`; Cursor auto-review; Codex guardian with a circuit breaker. `ApprovalView` needs a "switch to auto" option and a deny-with-comment field. The mode picker is an ACP config option of category `mode`.

## 8. Research to do next

Ordered by how much they change the design.

- R1. Textual streaming cost. Bench Textual at 50 tokens per second on a 2,000-line document with the paragraph split and the balancer. Decide if the tail needs its own lightweight renderer.
- R2. Grammar bundle. List the languages agents emit most. Find MIT-licensed TextMate grammars or tree-sitter grammars for each. Measure binary size. Decide if EditorKit links them or the kit ships them.
- R3. Diff rendering. Parse `git_patch` text. Prototype inline and side-by-side diffs on EditorKit with decorations and a gutter. Decide if this is a kit component or an EditorKit feature.
- R4. Observation granularity. Measure what invalidates when a view reads `session.transcript` during `streamResponse`. Test `SessionPropertyValues.history` and `Snapshot.transcriptEntries` as the tail source.
- R5. Runtime contract. Write the missing runtime spec, or point the plan at `SessionProjection` and `SessionEvent`. Agree the `schemaName` catalog with the Router for approval, plan, citation, artifact, and authorization. Decide who injects each.
- R6. ACP version. List which agents speak v1 and which speak v2 today (Claude Code, Codex, Gemini CLI, Zed, Xcode 27). Decide if the kit needs a v1 adapter or waits for v2 stable.
- R7. Terminal output. Pick an ANSI and VT parser for `terminal_output_chunk`, or strip escapes. Check licenses.
- R8. Permission and mode UX. Map the Claude Code, Cursor, and Codex option sets onto ACP permission options and config options. Design the option set for `ApprovalView`.
- R9. Math engine. Test Textual `.math` with `swiftui-math`, then SwiftMath, on inline and block spans inside a streaming paragraph.
- R10. Text selection. Test `textSelection` on a `LazyVStack` of Textual views on macOS 27. Decide if cross-message selection ships in v1.
- R11. Dynamic Type and accessibility. Prototype `accessibilityLinkedGroup` across lazy rows. Set the VoiceOver announcement cadence for streaming. Check EditorKit font scaling.
- R12. Visual audit. Capture Xcode 27 beta 6 and Claude Desktop screens for plan artifacts, queued messages, tool rows, history slider, usage ring. Set `AgentTheme` defaults from them.
- R13. Checkpoints. Find what the Router gives (`makeFork`, transcript rewrite) and what ACP gives (`session/fork`, unstable). Design the rewind data model.
- R14. Subagent data. Find a data source for a subagent tree. Candidates: Router `SessionEvent`, ACP `_meta`, AG-UI subagent events.
- R15. Attachments and context. FoundationModels accepts images only. ACP accepts audio, resources, and links. Find what the Router does with a non-image file the user attaches.
- R16. Usage model. Merge FoundationModels `Usage`, PCC `quotaUsage`, and ACP `usage_update` with cost into one `ContextUsage` type.
- R17. Compaction UX. Design how a transcript rewrite shows. Inputs: Router `CompactionSegment`, ACP unstable `compaction_update`, Claude Code `/compact`.
