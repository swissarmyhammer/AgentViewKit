# AgentViewKit — a SwiftUI agent UI component library

**Target:** macOS 27+ (Apple Silicon), OS 27 SDK — so we assume the WWDC 2026 surface (the
FoundationModels `Transcript` shape, Liquid Glass 2, the long-form-reading accessibility APIs) with
no back-deployment.
**What:** the native SwiftUI counterpart to Vercel AI Elements / assistant-ui, bound to the
FoundationModels `Transcript`. A reusable, open-sourceable Swift Package — same posture as the Swift
ACP SDK.

---

## 1. What it is

A component library for building agent UIs in SwiftUI: not just a chat bubble list, but the
agent-grade surfaces — streaming responses, reasoning disclosure, tool-call activity, task/plan
progress, citations, human-in-the-loop approvals, artifacts, and token/context usage. The primary
binding is the most Apple-native one possible: **observe a FoundationModels `Transcript`** — the same
`@Observable` record a `LanguageModelSession` produces — and the whole surface renders. Because the
runtime routes every backend through `LanguageModelSession` (System/MLX/llama and the agentic CLIs),
one `Transcript` drives them all — and anything FM doesn't model first-class (reasoning, plans,
approvals, stats) rides along as a custom structured segment, so there's no parallel event channel.

The bet: the web has three good answers to this (Vercel AI Elements, assistant-ui, CopilotKit) and
SwiftUI has none that are agent-grade. We take their component taxonomy and their best
architectural idea (a runtime abstraction the views bind to) and build it native.

## 2. Landscape survey — what exists, what to take

**Vercel AI Elements** (shadcn-based, copy-to-codebase). The most complete *component taxonomy*:
Conversation, Message (+branching), Response (streaming markdown), Reasoning, Tool, Task, Sources
/ InlineCitation, Context (token usage), Actions, PromptInput (+attachments/tools), CodeBlock,
Artifact, WebPreview, Image, Confirmation/Approval, Suggestions, Loader, voice components, and a
React-Flow workflow Canvas. **Take:** the inventory — it's the most thorough enumeration of what an
agent UI needs.

**assistant-ui** (YC W25, the most-used React AI-chat lib). Composable primitives + a `Thread`
drop-in, but its key idea is the **`AssistantRuntimeProvider` runtime abstraction**: the UI binds
to a *runtime*, with adapters per backend (Vercel AI SDK, custom). **Take:** the runtime-binding
pattern — decouple views from any specific backend. This is the spine (§3).

**CopilotKit** (makers of the AG-UI protocol). Heavier full-stack agent frontend: chat components,
headless option, **human-in-the-loop** (pause for approval/edit), and shared state. **Take:** HITL as
a first-class component (→ native `ApprovalView`). Skip the framework lock-in.

**SwiftUI-native building blocks** (so we don't reinvent):
- **Microsoft SwiftStreamingMarkdown** — performant streaming markdown built for chat: feed it
  progressively larger snapshots, it incrementally parses/renders. Purpose-built for LLM output.
- **MarkdownUI** (gonzalezreal) — mature GFM renderer with theming, now in *maintenance mode*;
  successor is **Textual** (same author). **AgentViewKit renders prose and markdown through
  Textual** — message bodies, plain text, and streaming responses (§4.2); EditorKit is reserved for
  source code, diffs, and the input editor.
- **Splash** (Sundell) / **Highlightr** — Swift code highlighters. We use neither: code rendering is
  **EditorKit** (ours, §4.1), so highlighting stays consistent between code blocks and the editor.
- **GetStream stream-chat-swift-ai** — closest existing SwiftUI kit: StreamingMessageView,
  ComposerView (attachments/suggestions/speech), SpeechToTextButton, AITypingIndicatorView. But
  chat-centric — nothing for tools/reasoning/approvals/tasks. **Take:** reuse the streaming-render
  and composer patterns; build the agent surfaces ourselves.

Net: the gap is real. No open-source SwiftUI library does agent-grade activity. AgentViewKit is
that library.

## 3. Architecture — observe a FoundationModels `Transcript`

Because we're Apple-native and the runtime routes **every** backend through a `LanguageModelSession`
(runtime-spec §3, §4.1), the canonical record of a conversation is already a FoundationModels
**`Transcript`** — an `@Observable` collection of `Transcript.Entry`. So the primary binding is the
simplest one possible: **hand AgentViewKit a `Transcript` and it renders.** No bespoke session protocol
is needed for the common case.

```swift
// The drop-in. Observes a FoundationModels Transcript and renders every entry natively.
AgentTranscriptView(session.transcript)          // or AgentTranscriptView(session:)
```

**Entry → block mapping.** AgentViewKit derives its render block model (§9) straight from the Transcript:
- `.instructions` → hidden by default (system prompt), inspectable.
- `.prompt` → a user message; `.text` segments are the user's words, `.structure` segments are attached context.
- `.response` → assistant text, **split into paragraph blocks** so only the streaming paragraph re-renders (§8).
- `.toolCalls` + the following `.toolOutput` → a **tool-call group**, paired by call id/name, with args, result, and duration.
- `@unknown default` → skipped safely (forward-compat for new entry kinds).

**Structured segments are the native rich-content hook.** A `.structure(StructuredSegment)` carries a
`source` (e.g. the tool name) and a decodable `GeneratedContent`. AgentViewKit maps `source` → a native
renderer and decodes the typed payload (`segment.content.value(ChartData.self)`), so a tool that emits a
`@Generable` chart, diff, or card lands as a native SwiftUI view — the typed-content catalog expressed in
Apple's own type system, no extra protocol. This is the FM-native form of the specialized blocks a mature
agent UI needs (charts, file diffs, result cards).

**A view per entry type, each replaceable — by typed modifier, not a switch.** AgentViewKit ships a
dedicated SwiftUI view for every `Transcript.Entry` and `Transcript.Segment` kind — `InstructionsView`,
`PromptView`, `ResponseView`, `ToolCallGroupView`, `ToolOutputView`, and the segment renderers
`TextSegmentView` / `StructuredSegmentView`. `AgentTranscriptView` switches over the entry to pick one
*internally*; you never see that switch. To override, you chain a typed modifier named for the type,
exactly like `.navigationTitle` or `.toolbar` — its closure receives the **concrete** payload, not the
enum, so there's nothing to unwrap and nothing to fall through:

```swift
AgentTranscriptView(transcript)
    .toolCallGroupView { group in MyToolCalls(group) }     // group: the paired calls + output
    .responseView      { response in MyResponse(response) } // response: Transcript.Response
    .instructionsView  { _ in EmptyView() }                // e.g. keep the system prompt hidden
```

You override only the types you name; everything else keeps its shipped default, and the no-arg
`AgentTranscriptView(transcript)` is the drop-in. Each modifier writes its builder into an
`EnvironmentValue` that the internal renderer reads — so overrides compose, propagate down the view
tree, and read as ordinary SwiftUI.

The fixed entry/segment kinds get a modifier each (a finite, known set). The *open-ended* case — custom
`.structure` segments, whose `source` is an arbitrary string — gets one keyed registration modifier
instead of a switch:

```swift
    .structuredSegment("chart") { content in
        NativeChart(try? content.value(ChartData.self))    // decode the @Generable payload
    }
```

So: typed modifiers for the closed set of FM types, a `source`-keyed modifier for the open set of custom
segments. No call-site switch anywhere. Registrations resolve **last-writer-wins** — the innermost
`.structuredSegment(source:)` for a given `source` wins, like any environment override — and an
unregistered `source` falls back to a generic **collapsible structured-content view** (a labeled
disclosure + pretty-printed `GeneratedContent`), so a new segment kind is always inspectable, never
dropped (§11.2).

**Attachments are per-type too — files, not just images.** The FoundationModels docs lean on images, but
a user prompt (and a file artifact) can carry any file. AgentViewKit models an `Attachment` by its
`UTType` and renders it with a default keyed to that type — image preview, PDF/QuickLook thumbnail,
plain text/markdown via Textual, source code via EditorKit, audio/video player, and a generic file chip (type icon + name + size, QuickLook
on tap) as the catch-all. Because UTTypes are open-ended, the renderer is overridable by a keyed modifier,
the same shape as custom structured segments:

```swift
    .attachmentView(for: .pdf)                { file in MyPDFPreview(file) }
    .attachmentView(for: .commaSeparatedText) { file in CSVTableView(file) }
```

Resolution follows the **UTType conformance hierarchy**: an exact registration wins, else the nearest
conforming supertype (a `.swift` file falls to `.sourceCode` → EditorKit, a plain `.txt` to `.text` → Textual; an unknown binary
falls to `.data` → the generic chip). Defaults lean on the platform — `UTType` for detection,
`NSWorkspace`/SF Symbol icons, and QuickLook (`QLThumbnailGenerator`, `QLPreviewView`) for previewing
arbitrary files — so an unrecognized type still gets a real native preview, never a broken-image
placeholder. One `AttachmentView` family renders in all three places it appears — the composer's
attachment chips (§9 D), a prompt's attachments, and file artifacts (§9 F) — so a type you teach the kit
to render shows up consistently everywhere.

**Click to preview — a QuickLook Inspector, Claude-style.** Tapping any attachment, artifact, or file
tool-output opens it in a trailing **`.inspector`** panel — SwiftUI's native split-view side column
(resizable on macOS, a sheet when compact) — without leaving the conversation. The panel embeds a live
**QuickLook** preview (`QLPreviewView`) so it renders virtually any file type natively, and carries the
actions you'd expect: **Open** in the default app (`NSWorkspace`), **Reveal in Finder**, **Share**
(`ShareLink`), **Save / Download** (`fileExporter`), and pop-out to the full system Quick Look
(`.quickLookPreview`). Selection is surface-level state on `AgentTranscriptView`, so one inspector serves
the whole thread. The division of labor: QuickLook does the heavy preview (and the chip thumbnail via
`QLThumbnailGenerator`), so we lean on the OS rather than building per-type viewers; the typed
`.attachmentView(for:)` overrides are only for when you want a *custom inline* representation (a CSV as a
real table, say) in place of the QuickLook thumbnail.

**In-progress state is derived, not signaled.** There is no "isStreaming" flag and no separate event
for activity — the *structure* tells you. A reasoning block with no following response yet is still
going; a `.toolCalls` entry with no paired `.toolOutput` yet is still running; a `.response` whose last
text segment is still growing is mid-stream. So the shimmer (§5) is a function of the tail entry being
*unpaired*, computed from the transcript — not a thing the runtime has to announce.

**Custom structured segments are the only extension mechanism — there is no parallel channel.**
Everything an agent surface renders lives in the transcript: a standard entry, a tool output, or a
`.structure` segment keyed by `source`. Things FM doesn't model first-class — reasoning, plans/todos,
citations, artifacts, per-turn stats, even a permission **approval request** — are custom segments that
`StructuredSegmentView` dispatches to the right native view. Nothing needs an out-of-band event stream.

**The only non-transcript things are interaction verbs.** Acting on the conversation — sending,
interrupting, answering an approval — isn't data to render, it's a few methods. So `AgentViewSession`
is just the transcript plus those verbs:

```swift
protocol AgentViewSession: Observable {
    var transcript: Transcript { get }                               // the whole renderable record
    var connections: ConnectionStore { get }                         // ambient connect-state, not transcript (§12)
    func send(_ input: UserInput) async                              // text + attachments
    func interrupt()                                                  // stop the current turn
    func respond(to: ApprovalRequest, _ decision: ApprovalDecision)  // unblock the paused per-action gate
    func connect(_ request: AuthorizationRequest) async throws       // run the OAuth handoff for a server (§12)
    func respond(to: ElicitationRequest, _ result: ElicitationResult) async  // answer a server's form/URL elicitation (§13)
}
```

The approval flow is the proof: the runtime's permission gate (§4.11) injects an `approval` custom
segment when it blocks; `AgentTranscriptView` renders it as `ApprovalView`; the user's choice flows back
through `respond(to:_:)` and the gate resumes — request in the transcript, decision via a callback, no
channel. **OAuth authorization is the second proof of the same shape** (§12): when a tool's MCP server
needs the user to connect, the runtime injects an `authorization` custom segment; `AuthorizationView`
renders the "Connect" card; the browser handoff runs through `connect(_:)`; the runtime exchanges the
token and retries, and the now-authorized tool output lands in the transcript — request in the
transcript, no channel. **MCP elicitation is the third proof of the same shape** (§13): when a server
asks the user for structured input mid-tool-call, the runtime injects an `elicitation` custom segment;
`AgentTranscriptView` renders it as `ElicitationView` (a schema-driven form); the user's answer flows back
through `respond(to:_:)` and the tool resumes — request in the transcript, result via a callback, no
channel. Two genuine pieces of runtime state are *not* transcript content and are bound
directly as ambient `@Observable`s: a live token/context gauge (`ContextUsageView`) and the per-server
**connection state** (`ConnectionStore` → `ConnectionsView`, §12).

Every runtime backend is a `LanguageModelSession`, so the `Transcript` already covers System / MLX /
llama / Claude Code / Codex uniformly; a non-FM source driven directly (e.g. a remote ACP agent) maps its
stream into the same `Transcript` (and custom segments) through a thin adapter — same render path.

Two consumption levels: the drop-in **`AgentTranscriptView(transcript)`** for the whole surface, and the
composable primitives below for full control.

## 4. Building blocks — reuse, don't reinvent

All-Swift, native — **no WebView or JSCore anywhere**. Links don't render as embedded web tiles (a live
page in a tile is worse than the real thing); they open in the user's browser via `openURL` /
`NSWorkspace`, optionally shown as a native rich-link card (LinkPresentation `LPLinkView`) that still
launches the browser on click. **Prose and markdown render through Textual** (§4.2); **source code,
diffs, and the input editor render through EditorKit** (§4.1) — our high-power drop-in for SwiftUI
`Text`.

| Concern | Use | Why |
|---|---|---|
| Prose / markdown rendering | **Textual** (gonzalezreal) | mature GFM + theming; renders message bodies, plain text, and streaming responses (§4.2) |
| Streaming balance | **a streaming balancer** (§8); optionally SwiftStreamingMarkdown for incremental parse | rebalances the trailing in-progress paragraph before it reaches Textual |
| Code rendering + text input | **EditorKit (ours)** — drop-in for `Text` | one engine for code blocks, editable diffs, and the rich composer: selection, syntax highlighting, slash/chip/@file affordances (§4.1) |
| Math typesetting | **`MathView`** + a math engine | inline `$…$` / block `$$…$$` LaTeX, detected by Textual and typeset natively (§11.7) |
| Layout / scroll | native `ScrollView` + `ScrollViewReader` + `LazyVStack`/`List` | scroll anchoring; lazy row creation, windowed for long threads (§8) |
| Chrome / styling | native **Liquid Glass** (`glassEffect`/`GlassEffectContainer`) + design tokens | Xcode-assistant look by default (§5); no web theming to port |
| Activity / progress | **shimmer** for streaming/thinking · native `ProgressView` for discrete tool calls · **SF Symbols** w/ effects | native affordances, not facsimiles (§5) |
| Speech in/out | native `Speech` + our `whisper-rs`/`cpal` path | voice composer + transcription |

### 4.1 Dependency: EditorKit — code, diffs, and rich input

AgentViewKit **depends on EditorKit** as its **code and editing engine** — the native counterpart to
CM6 in the web app. EditorKit is an NSTextView-backed surface that presents as an ordinary SwiftUI
view; the kit reaches for it wherever content is *code* or *editable*, so glyph layout, syntax
highlighting, code selection, and large-document performance live in one place. (Prose and markdown
go to Textual instead — §4.2.) Three roles:
- **Code render** — fenced code blocks render in EditorKit's read-only highlight mode (Splash/
  Highlightr dropped). EditorKit is plugged into Textual *as its code-block renderer* — Textual
  parses the markdown and, wherever it hits a fenced block, hands the code + language to EditorKit
  via its code-block customization hook (§4.2), so a code block in prose looks identical to the
  standalone editor.
- **Full editor** — editable artifacts and diffs use the same EditorKit, so "code the agent showed
  me" and "code I'm editing" are identical in highlighting, theme, and language support.
- **Rich input** — as the composer's editor, EditorKit also owns the in-line input affordances:
  **slash commands**, **chips/tokens**, and **`@file` references** (with their popups/autocomplete)
  are EditorKit features, the native analog of how CM6 handles them in the web app. The composer
  inherits all of this by hosting EditorKit; AgentViewKit doesn't reimplement them.

The highlighting/layout engine choice (tree-sitter, NSTextView internals) lives in EditorKit's own
spec — out of scope here; AgentViewKit just treats it as a `Text` that can do far more.

### 4.2 Dependency: Textual — prose and markdown

AgentViewKit **depends on Textual** (gonzalezreal, the MarkdownUI successor) as its **prose and
markdown renderer**: message bodies, plain text, and streaming assistant responses render through
Textual, themed to match the Xcode-assistant look (§5). It is a pure-SwiftUI GFM renderer, so it
slots straight into the `LazyVStack` rows and inherits SwiftUI accessibility and Dynamic Type for
free. On the streaming path it is fed progressively larger snapshots, with the trailing paragraph
rebalanced by the `StreamingMarkdownBalancer` (§8) so half-typed delimiters don't flash. **Textual's
code-block renderer is overridden to host EditorKit** — Textual handles every prose construct (lists,
tables, emphasis, links, blockquotes), but a fenced code block is routed out to EditorKit (§4.1) so
code inside a message looks identical to a standalone code block and the editor. That hook is the one
seam between the two engines.

Textual also owns **math detection**: it spots inline `$…$` and block `$$…$$` spans and routes them to
`MathView` (§9 B) — the typeset third engine alongside prose-in-Textual and code-in-EditorKit (§11.7).

The one thing this split gives up relative to the old EditorKit-for-prose plan is **transcript-wide
text selection** — NSTextView gave cross-message selection for free, whereas SwiftUI text selection is
per-view. The v1 bar (§11.8): per-message selection plus a **Copy thread** action in `MessageActions`;
a contiguous cross-message drag-select is deferred.

## 5. Default styling — make it look like Apple shipped it

The defaults are the product: out of the box, AgentViewKit should read as a native macOS 27 surface —
specifically like the **Coding Assistant in Xcode 27** (chat with plan mode, queued messages, inline
annotations) — not a ported web chat. Every default uses the system's own materials, components,
symbols, and motion; the builder slots (§7) let you replace any of it.

**Liquid Glass, used correctly.** Glass is for the *navigation layer*, never content — so the
transcript, code, and message text sit on the content plane and glass is reserved for chrome: the
composer bar, floating action clusters, the model/agent picker, toolbars, the inspector. Use
`GlassEffectContainer` to group chrome (it blends/morphs and is the performant path),
`.glassEffect(.regular, in:)` for surfaces, `.buttonStyle(.glass)` for secondary actions and
`.buttonStyle(.glassProminent)` (tinted, primary only) for send/confirm, and `.glassEffectID(_:in:)`
with a `@Namespace` for morphing transitions (the composer expanding into a tool tray, an approval
sheet emerging). Never stack glass on glass; tint selectively. The system opacity slider and
second-iteration tokens (WWDC 2026) are picked up automatically; use `appearsActive` to dim chrome
when the window is inactive.

**Native components, not facsimiles.** In-progress *reasoning and streaming text* use a **shimmer**
(a shimmering title/label) rather than a spinner — it reads more native and signals "thinking" without
a spinning gear. *Discrete tool calls* use a real `ProgressView()` — spinner (indeterminate) or bar
(determinate). Status, kinds, and affordances are **SF Symbols** with symbol effects:
`.symbolEffect(.variableColor)` for live activity, `.contentTransition(.symbolEffect(.replace))` when
a tool goes running → done, `.bounce` on completion. Buttons, toggles, menus, sheets, and the
inspector are stock SwiftUI controls so they inherit platform behavior — and accessibility — for free.

**Match Xcode's restraint.** Prose is system text (SF Pro); code and tool I/O are **SF Mono**. Spacing,
list insets, and selection styling follow the Xcode assistant; color stays mostly neutral with tint
reserved for primary actions and status. Reasoning is a quiet collapsible block, tool calls are
compact rows that expand, and a plan renders as a checklist — the Xcode "plan mode" idiom.

**Tokens, not hard-coded values.** Defaults read from a small design-token set (spacing, radii,
material levels, symbol weights, accent, density) — exposed publicly as **`AgentTheme`**, applied with
`.agentTheme(_:)` and read from the environment (§11.6) — so the kit restyles coherently and a consumer
can re-tint without touching component internals. Builders (§7) override structure; tokens tune the
default look.

## 6. Accessibility

Accessibility is a default, not a setting — the kit ships fully accessible, and the burden is on a
*builder override* to preserve it, not on the consumer to add it.

**Lean on the styling system.** SwiftUI emits accessibility elements from built-in views and preserves
labels, traits, and actions across restyling, so defaults built on stock controls are accessible
automatically. This is the accessibility corollary to §7: when you swap a subcomponent via a builder,
you inherit responsibility for its accessibility — the default slot carries correct labels/traits, and
the kit documents what an override must re-expose (label, value, actions). Prefer restyling stock
controls over fully custom views for exactly this reason.

**Streaming, made VoiceOver-sane.** A token-by-token transcript must not spam VoiceOver. Stream
silently into the view and announce only at meaningful boundaries (turn complete, tool result,
approval needed) with appropriate priority, rather than per-delta; expose the settled message as the
accessible value. Respect **Reduce Motion** — disable glass morphing and streaming-text animation, snap
to final state. Honor **Dynamic Type** throughout (the transcript reflows; code uses a scalable mono).

**WWDC 2026 surfaces we adopt.** The new long-form reading APIs — seamless paragraph navigation across
separate views, the `causesPageTurn` trait, custom VoiceOver rotor actions for text selection — fit a
multi-message transcript directly: a VoiceOver user moves through the conversation by paragraph and
message, not swipe-by-swipe. For net-new controls (`ApprovalView`, the `ReasoningView` toggle, tool
rows) follow the WWDC 2026 custom-control accessibility guidance — declare purpose, value, actions,
feedback. The system's richer VoiceOver image descriptions and Accessibility Reader
(summaries/translation) come for free when content is well-labeled.

**Focus & semantics.** Move VoiceOver focus to an approval prompt when it appears (it's a decision
gate) and back to the composer when a turn ends. Label tool calls by effect and status ("Edit
file.swift, running" → "…completed"), reasoning as a collapsible region, and the diff/code views by
language + change summary. Every interactive element gets an `accessibilityLabel`, and where it acts,
an `accessibilityAction`.

## 7. Composability — sensible defaults + overridable subcomponents

Principle: every composite view ships a working default *and* lets you swap its constituent
subcomponents through **builder slots**. `AgentTranscriptView(transcript)` renders fully out of the box; any piece
— the prompt editor, the code renderer, a message header — is a `@ViewBuilder` parameter you can
override, with a sensible default when you don't.

The mechanism is a generic slot per swappable subcomponent, plus a **constrained-extension overload**
that supplies the default so the short init still compiles. `PromptInputView`'s editor is the worked
example: pass an `EditorKit` view to use it, pass nothing to get the stock SwiftUI editor.

```swift
public struct PromptInputView<Editor: View, Accessory: View>: View {
    @Binding var text: AttributedString
    let onSubmit: () -> Void
    @ViewBuilder var editor: (PromptEditorContext) -> Editor   // swap the actual editor component
    @ViewBuilder var accessory: () -> Accessory                // tools row, model picker, mic…
}
public struct PromptEditorContext {           // what the kit hands whatever editor you pass
    public let text: Binding<AttributedString>
    public let placeholder: String
    public let onSubmit: () -> Void
}

// Default: stock SwiftUI editor + default accessory, so the short init works with no closures.
extension PromptInputView where Editor == StockPromptEditor, Accessory == DefaultPromptAccessory {
    public init(text: Binding<AttributedString>, onSubmit: @escaping () -> Void) {
        self.init(text: text, onSubmit: onSubmit,
                  editor: { StockPromptEditor($0) },
                  accessory: { DefaultPromptAccessory() })
    }
}
```

And an editor-override init that keeps the default accessory:

```swift
extension PromptInputView where Accessory == DefaultPromptAccessory {
    public init(text: Binding<AttributedString>, onSubmit: @escaping () -> Void,
                @ViewBuilder editor: @escaping (PromptEditorContext) -> Editor) { /* … */ }
}
```

Use site:

```swift
PromptInputView(text: $text, onSubmit: send)                                // stock editor
PromptInputView(text: $text, onSubmit: send, editor: { EditorKitView($0) }) // EditorKit
```

Use the explicit `editor:` label — a bare trailing closure binds to the *last* slot (`accessory`).
Each slot you want independently omittable needs its own default overload, so keep the defaulted
slots few.

`CodeBlockView` and `DiffView` work the same way but default the *other* direction: AgentViewKit
already depends on EditorKit, so code rendering and diffs **default to EditorKit**, with the `code:`
slot there to drop in a stock or custom renderer. (Prompt input defaults to stock because a plain
editor is fine for typing; code is where highlighting earns the dependency.) Higher-level composites
(`MessageView`, `AgentThreadView`) expose the same slots and forward them down, so a substitution is
chosen once where you construct the thread.

Use **constrained-extension overloads, not Swift default arguments** — generics and default params
don't mix cleanly. The same principle drives the transcript renderer, expressed as **typed override
modifiers**: `.responseView { … }`, `.toolCallGroupView { … }`, and friends — one per `Transcript`
type, each closure receiving the concrete payload, chained like `.toolbar`/`.navigationTitle` (§3). No
call-site switch; the internal renderer reads the overrides from the environment. Rule of thumb: a
builder slot per swappable subcomponent, a default via the extension, so the drop-in path stays
`AgentTranscriptView(transcript)` and any piece is overridable at the use site.

## 8. Rendering in a loop — LazyVStack at scale

The thread is a long, append-heavy transcript in `ScrollView { LazyVStack { ForEach … } }`. The
failure mode during streaming is re-diffing the whole list on every token. Discipline:

- **Stable identity, always.** Rows key off a stable `id` (the message/event ULID) — never the array
  index, never a fresh `UUID()` per render, never `.id(UUID())`. Base `Equatable`/`Hashable` on the
  id, not mutable fields, so editing a row doesn't change its identity.
- **Isolate the streaming tail.** Only the last message mutates while tokens arrive. Keep that
  fast-changing text in its own `@Observable`, read only by the tail view — *not* in the object that
  drives the list — so a token doesn't invalidate the other rows. (Observation recomputes only views
  that read the changed property, and only when read in `body`.)
- **Equatable rows.** Conform rows to `Equatable` + apply `.equatable()`, with a *small, specific*
  equality input (id + a content revision counter), not the whole model, so unchanged rows skip
  re-render.
- **Precompute, never in body.** Parse markdown, highlight code (EditorKit), format timestamps when
  the event arrives and cache on the model; throttle the tail's re-parse. Row bodies stay cheap.
- **List vs LazyVStack.** `LazyVStack` gives the custom layout the agent surface needs (tool cards,
  diffs, plans). It's lazy both directions on current OSes but cells persist, so a very long thread
  grows memory — **paginate/window** older turns (load before the last row, dedupe by id). `List`
  (UICollectionView-backed, true recycling) is the fallback for pathologically long, regular threads.
- **Scoped state.** No single global observable driving the whole screen; split list data from
  screen-level UI state so unrelated updates don't invalidate the list.
- **Heavy text work is delegated, not in the cells.** Code and diffs render inside EditorKit's
  NSTextView-backed surface (§4.1) — its glyph layout, selection, and highlighting cost stays out of
  the SwiftUI view tree. Prose renders through Textual (§4.2), kept cheap by parsing the markdown when
  the event arrives and caching it on the model (above), never re-parsing in `body`. Either way the
  SwiftUI cells stay thin wrappers, so the list holds up without dropping itself to AppKit.
- **Streaming markdown needs a balancer.** Feeding raw growing markdown to a renderer makes half-typed
  delimiters flash as broken markup. A `StreamingMarkdownBalancer` rebalances only the *trailing
  in-progress paragraph* (closing a dangling `**`/`[`), detects an open code fence (odd/even split on
  ```` ``` ````) and leaves code-in-progress untouched, and never touches already-settled paragraphs.
  Required on the streaming path.
- **Scroll anchoring is its own component.** A `ScrollAnchorManager` tracks whether the user is pinned
  to the bottom (with a small tolerance to avoid jitter), saves/restores an item-anchored read
  position across list updates so appends don't yank the view, drives the scroll-to-bottom affordance,
  and *coalesces* auto-scrolls during streaming so many token updates collapse to one scroll per tick.

## 9. Component inventory

Grouped; "source" = native (build), reuse (existing lib), or net-new (agent-grade, build native).

**A. Conversation / thread**
- `AgentTranscriptView` — **the drop-in**: observe a FoundationModels `Transcript` (or a `LanguageModelSession`) and render the whole surface (§3). *net-new (the easy path)*
- `AgentThreadView` — same surface driven by an `AgentViewSession` (the `Transcript` + the interaction verbs send/interrupt/respond) when you need to act on it, not just render. *net-new (composes the rest)*
- `ConversationView` — container: auto-scroll, scroll-to-bottom, empty state. *native*
- `MessageView` — user/assistant, parts-based render; body text via Textual (§4.2), code blocks via EditorKit (§4.1). *native*
- `MessageActions` — copy / **copy thread** / retry / edit, in a **footer** block (not hover-revealed); per-message selection, no cross-message drag-select in v1 (§11.8). *native*
- `BranchNavigator` — regenerate / branch paging. *native*
- `ThreadMinimapView` — condensed overview of the whole thread (turns, tool calls, errors) as a scrubbable rail for navigating long conversations; click to jump, highlights current viewport. *net-new*

**A2. Transcript entry views (one per `Transcript.Entry`/`Segment`, each overridable §3/§7)**
- `InstructionsView` — system prompt; hidden by default, inspectable. *net-new*
- `PromptView` — a `.prompt` entry (user turn) + its segments; attachments render via the `AttachmentView` family (§3, §9 F). *net-new*
- `ResponseView` — a `.response` entry, paragraph-split, via Textual. *net-new (see B)*
- `ToolCallGroupView` — `.toolCalls` + paired `.toolOutput`, grouped with per-call duration. *net-new (see C)*
- `ToolOutputView` — a standalone `.toolOutput`. *net-new*
- `TextSegmentView` / `StructuredSegmentView` — the two `Transcript.Segment` kinds; the structured one dispatches on `source` to a native renderer (chart/diff/card). *net-new*

**B. Streaming content**
- `ResponseView` — streaming-safe message text; rendered via **Textual** (§4.2) with fenced code routed to EditorKit, fed progressively and rebalanced at the trailing paragraph (§8). *Textual + balancer*
- `CodeBlockView` — copy + filename; renders via **EditorKit** (read-only highlight). *EditorKit*
- `MathView` — typeset LaTeX: inline `$…$` and block `$$…$$`, detected by Textual and routed here (§4.2, §11.7); honors Reduce Motion / Dynamic Type. *net-new (math engine)*
- `ReasoningView` — collapsible streaming thinking; **shimmering** title while in progress, auto-collapse on done. *net-new (§5)*
- `ActivityIndicator` — "Thinking / Running tool…" states; **shimmer** for streaming, native `ProgressView` for discrete steps. *native (§5)*
- `ShimmerView` — reusable shimmer for any in-progress label/text. *net-new (§5)*

**C. Agent activity — the agent-grade core (mostly net-new for SwiftUI)**
- `ToolCallView` — name, args, status (shimmer while running, SF Symbol running→done via `.symbolEffect`), result; collapsible. *net-new (§5)*
- `TaskListView` — plan / todo progress. *net-new*
- `ActivityTimeline` — interleaved tool calls, reasoning, sub-agent dispatch (the observability/trace surface). *net-new*
- `SourcesView` / `InlineCitation` — citations. *net-new*
- `ContextUsageView` — token / context-window meter. *net-new*
- `AgentGraphView` — multi-agent / subagent dispatch graph (the React-Flow analog). *net-new, advanced/later — SwiftUI `Canvas`*

**C2. Infrastructure (non-visual)**
- `StreamingMarkdownBalancer` — rebalances the trailing in-progress paragraph; leaves open code fences alone (§8). *net-new*
- `ScrollAnchorManager` — pinned-to-bottom tracking, anchor save/restore across updates, coalesced auto-scroll (§8). *net-new*
- `ExpandedBlocksStore` — central collapse/expand state for tool calls & reasoning, kept out of the cells. *net-new*

**D. Input**
- `PromptInputView` — hosts EditorKit as the editor, so **slash commands, chips, and `@file` references come from EditorKit** (§4.1); AgentViewKit adds submit/stop with status, **attachments** (chips via the `AttachmentView` family, §9 F), **model/agent picker** (ties to runtime-spec §4.8), tool toggles, and web-search/mic. Editor is a `@ViewBuilder` slot (stock SwiftUI default / pass EditorKit), accessory regions are slots too (§7). *net-new*
- `PromptQueueView` — **queued messages**: while a turn is running (`session/prompt` is long-lived), typed messages queue client-side and send in order as the agent frees up; reorder, edit, or drop before they go. *net-new*
- `SuggestionsView` — suggested prompts / follow-ups. *native*
- `SpeechInputButton` — record → transcript. *reuse pattern*

**E. Human-in-the-loop**
- `ApprovalView` — approve / deny / **edit** a tool call or permission request; renders the consequence-language prompt + Once/Session/Always/Deny. *net-new — the GUI for the permission gate (runtime-spec §4.11)*
- `PermissionPromptView` — scoped grant (once / session / always for this dir). *net-new*

**E3. Elicitation (MCP `elicitation/create`, §13)** — a *server's* request for structured input mid-tool-call; distinct from the per-action *approval* (E) and the per-server *connect* (E2). A compound, schema-driven form with swappable parts (§13).
- `ElicitationView` — **the compound form** (form mode): rendered from an `elicitation` custom segment, it shows the requesting server + `message`, generates one field per `requestedSchema` property, validates against the schema, and submits via `respond(to:_:)`. Multi-field requests render **tabbed** (Claude-style, §13); single-field renders inline. Three actions: **Submit** (accept) / **Decline** / **Cancel**. Every constituent is a builder slot. *net-new*
- `ElicitationFieldView` family — one renderer per derived field kind, each an overridable slot (§13): `ElicitationTextField` (string; **defaults to EditorKit** as the input engine, swappable), `ElicitationNumberField` (number/integer + min/max → stepper/slider), `ElicitationToggleField` (boolean → `Toggle`), `ElicitationDateField` (`format: date`/`date-time` → `DatePicker`), `ElicitationSingleChoiceField` (enum / titled `oneOf` → **radio**/menu), `ElicitationMultiChoiceField` (array-of-enum / titled `anyOf` → **checkboxes** with min/max-items). *net-new*
- `ElicitationURLConsentView` — **URL mode**: a consent card showing the full `url` with the **domain highlighted**, gated on explicit user consent, that opens the link in the **safe system browser** (never a webview) by reusing the `AuthorizationPresenter` infra (§9 E2 / §12). Resolves on `notifications/elicitation/complete` or manual retry; also the renderer for a `-32042 URLElicitationRequiredError`. *net-new (shares §12's browser-handoff infra)*

**E2. Connections / authorization (OAuth, §12)** — the per-server *connect* gate, kept distinct from the per-action *approval* gate above.
- `AuthorizationView` — the in-thread just-in-time "Connect to *X*" card, rendered from an `authorization` custom segment: server name, requested scopes, a `.glassProminent` **Connect** button that drives the browser handoff via `connect(_:)`. Shares `ApprovalView`'s consequence-language + glass styling; it is the in-thread twin of `ApprovalView` but grants a *connection*, not a single action. *net-new*
- `ConnectionsView` — the durable settings surface (the dominant pattern across ChatGPT / Claude / VS Code / Cursor): a `List`/`Form` of MCP servers & services, each a `ConnectionRow`, bound to the ambient `ConnectionStore` (not the transcript). Connect / Disconnect, per-tool toggles, step-up scope re-consent. *net-new*
- `ConnectionRow` / `ConnectionStatusChip` — name + `ConnectionStatusChip` (green/yellow/red dot + label: *Connected / Needs authentication / Authenticating / Expired / Error*) + Connect/Disconnect. The chip also surfaces inline on a `ToolCallView` blocked on auth. *net-new*
- `AuthorizationPresenter` — **infrastructure** (sibling of `ScrollAnchorManager`, §C2): wraps `ASWebAuthenticationSession` against the kit's `NSWindow` presentation anchor. Given an authorization URL + callback config from the runtime, it runs the system-browser handoff and returns the callback `URL`. **Touches zero OAuth protocol** — PKCE, discovery, CIMD/DCR, token exchange/refresh, and Keychain storage all live in the runtime beneath the kit (§12). *net-new (native AuthenticationServices)*

**F. Artifacts / attachments / rich output**
- `AttachmentView` — **per-attachment, any file** (§3): keyed by `UTType` with conformance-based fallback; defaults to image preview, PDF/QuickLook thumbnail, plain text/markdown (Textual), source code (EditorKit), audio/video player, or a generic file chip (icon + name + size, QuickLook on tap). Overridable via `.attachmentView(for:)`. Shared by composer chips, prompt attachments, and file artifacts. *net-new (native QuickLook/UTType)*
- `AttachmentInspector` — trailing **`.inspector`** split-view (Claude-style) with an embedded `QLPreviewView` of the selected attachment/artifact/file output + actions: Open, Reveal in Finder, Share, Save/Download, pop-out Quick Look (§3). *net-new (native Inspector + QuickLook)*
- `ArtifactView` — generated document / file panel; file body via `AttachmentView`. *net-new*
- `DiffView` — code diffs from agent edits; **EditorKit** diff mode. *EditorKit (important for coding agents)*
- `CommandOutputView` — shell/command output (tools, scheduler jobs). *net-new*
- `LinkView` — a URL the agent surfaced: a native rich-link card (LinkPresentation `LPLinkView` — title, favicon, thumbnail) that **opens in the user's browser** on click (`openURL`). No embedded web. *native (LinkPresentation)*
- `ImageView` / `AudioPlayerView` — media leaf views used by `AttachmentView` for their types. *native / reuse*

## 10. What we port / adapt / skip

- **Port:** the component taxonomy (Vercel Elements) and the runtime-binding spine (assistant-ui).
- **Adapt:** HITL (CopilotKit) → native `ApprovalView`; composability via `@ViewBuilder` slots with
  default overloads (§7) rather than copy-to-codebase.
- **Skip:** React-Flow canvas (use SwiftUI `Canvas`), shadcn/Tailwind theming (use Liquid Glass +
  design tokens), copy-to-codebase distribution (ship a real SPM library with open, overridable
  primitives), web-only voice stacks (use native Speech + our whisper path), third-party code
  highlighters (use our EditorKit), **embedded web preview** (Vercel's `WebPreview` / any `WKWebView` —
  open the user's browser instead, with a native `LPLinkView` card; no live web in a tile).

## 11. Decisions

*Resolved:* **Primary binding = a FoundationModels `Transcript`** — `AgentTranscriptView(transcript)`
renders the whole surface. Everything renderable lives in the transcript (entry, tool output, or a
custom `.structure` segment); in-progress state is *derived* from unpaired tail entries, not signaled;
`AgentViewSession` adds only the interaction verbs (send/interrupt/respond) — no parallel channel (§3). **SwiftUI throughout** — the transcript stays SwiftUI (`LazyVStack`/`List`); heavy text work is
delegated — code/diffs to EditorKit, prose to Textual — so the cells stay light (§8). **Two text
renderers, split by content** — **Textual** renders prose and markdown (message bodies, streaming
responses, §4.2); **EditorKit** renders source code, diffs, and the rich input editor (§4.1), and is
plugged into Textual *as its code-block renderer* so fenced code matches the standalone editor; a
balancer rebalances the streaming tail before Textual. Composability via `@ViewBuilder` slots with default overloads (§7). Default
look = Liquid Glass + Xcode-assistant cues; **shimmer** for streaming/thinking, native `ProgressView`
for discrete steps (§5); fully accessible by default (§6).

The remaining questions are now resolved:

1. **Distribution — standalone open-source SPM package.** Shipped like the Swift ACP SDK: a real SPM library of open, overridable primitives — not an in-app target, not copy-to-codebase. Depends on **EditorKit** (code/diffs/input), **Textual** (prose/markdown), and a math-typesetting engine (decision 7).
2. **Custom-segment registration — last writer wins; unknown `source` is shown, never dropped.** Fixed entry/segment types keep their typed override modifiers (§3); the open-ended `.structure` `source` uses `.structuredSegment(source:)`, which writes into the environment, so the *innermost* registration for a `source` wins (ordinary override semantics). An unrecognized `source` falls back to a generic **collapsible structured-content view** — a labeled disclosure showing the `source` + pretty-printed `GeneratedContent` — so a new segment kind is always inspectable, never blank or a crash.
3. **`AgentGraphView` — later, not v1.** Single-agent activity (tool calls, reasoning, plans, approvals) ships first; the multi-agent `Canvas` graph is a post-v1 addition.
4. **Textual ↔ streaming/code — Textual-only on the streaming path.** Textual is fed balanced snapshots (the `StreamingMarkdownBalancer`, §8) directly; we do **not** add SwiftStreamingMarkdown unless a perf spike shows Textual can't keep up with token-rate snapshots. The EditorKit code-block hook caches the EditorKit view per fenced-block id, so a streaming tail re-render never relayouts settled code blocks.
5. **Long threads — LazyVStack + windowing is the default path.** `LazyVStack` carries the custom agent layout; `ScrollAnchorManager` + windowing/pagination of older turns (§8) sit on top for memory. `List` (true recycling) stays a documented escape hatch for pathologically long, regular threads, behind a flag — not the default.
6. **Design tokens — a small public, themeable set.** A public **`AgentTheme`** (spacing, radii, material levels, symbol weights, accent, density), applied with `.agentTheme(_:)` and read from the environment, so consumers re-tint coherently without touching internals (§5). Builder overrides (§7) remain for structure; tokens tune the look.
7. **Math — a native `MathView` in v1.** AgentViewKit takes a math-typesetting dependency; Textual gets a hook that detects inline `$…$` and block `$$…$$` spans and routes them to `MathView` — the third content engine alongside Textual (prose) and EditorKit (code), §4. Honors Reduce Motion / Dynamic Type like the rest.
8. **Transcript-wide selection — per-message + Copy thread, no cross-message drag-select in v1.** Each message is individually selectable/copyable; `MessageActions` adds a **Copy thread** action for the whole log (§9 A). A transcript-level selectable mode (true cross-message drag-select) is deferred — revisit if users ask. This is the accepted cost of moving prose to SwiftUI/Textual (§4.2).
9. **OAuth / connections — in-thread gate + settings surface; the kit presents, the runtime authorizes; app sign-in is out of scope (§12).** The just-in-time *connect* gate is transcript-native (an `authorization` custom segment + the `connect(_:)` verb), and a durable `ConnectionsView` bound to an ambient `ConnectionStore` is the management home — both ship in v1. The kit owns only a thin `AuthorizationPresenter` over `ASWebAuthenticationSession` (it supplies the `NSWindow` anchor and returns the callback URL); all OAuth protocol — discovery, PKCE, CIMD/DCR, token exchange/refresh, Keychain — lives in the runtime beneath. App-level user identity (signing into the app/provider itself) is the **host's** responsibility, not the kit's.
10. **Elicitation — a transcript-native, schema-driven form (form mode) + a URL-mode consent card; both ship in v1 (§13).** MCP `elicitation/create` is the *third proof* of the §3 seam: the request is an `elicitation` custom segment, the answer is the new `respond(to:ElicitationRequest,_:)` verb, no parallel channel. **Form mode** renders `ElicitationView` — a compound form that normalizes all four enum encodings (plain `enum`, legacy `enumNames`, titled `oneOf`, multi-select `anyOf`/array) into one field model, maps each field to a native control (radio for single-choice, checkboxes for multi-choice with min/max-items, `Toggle`/`DatePicker`/stepper for the rest), pre-populates `default`s, validates against the schema before enabling **Submit**, and lays out **tabbed** when there's more than one field. Every part is a **builder slot** (§7 pattern): the whole view, the per-kind field renderers, header, and footer are overridable — and **free-text fields default to EditorKit** (the kit's input engine, §4.1) with a slot to swap. Actions are the spec's three: **accept** (with `content`), **decline**, **cancel**. **URL mode** never passes data through the client: `ElicitationURLConsentView` shows the full URL with the domain highlighted, gets explicit consent, and opens the **safe system browser** by reusing §12's `AuthorizationPresenter` — resolving on `notifications/elicitation/complete` (or manual retry), and also rendering the `-32042 URLElicitationRequiredError`. Servers **MUST NOT** request secrets via form mode (that's what URL mode is for); the kit always offers decline/cancel and always names the requesting server (§13).

## 12. Authorization & connections (OAuth)

MCP tools — and third-party services generally — increasingly require the user to authorize before the agent can act. This is genuinely *out-of-band, browser-based, stateful* work that fights the transcript spine; the resolution is to split it exactly along the seam §3 already draws, so OAuth costs the architecture **one verb, one ambient `@Observable`, one in-thread segment type** — nothing more.

**Four distinct things, kept distinct (the consistent lesson from every shipping agent).** Products visually collapse these, but they are logically separate and the kit keeps them so:
1. **App sign-in** — the user logging into the app/provider itself. **Out of scope** — the host's job, pre-conversation (Sign in with Apple, provider login). The kit documents the boundary and does not ship a component for it.
2. **Per-server connect / account link** — "Connect to GitHub." A one-time *durable* grant. This is what the kit owns (below).
3. **Per-action approval** — "Allow this tool to run?" Fires at execution time *even after* the server is connected. Already in the plan as **`ApprovalView`** (§9 E) — kept separate from connecting.
4. **Step-up scope consent** — a 403 `insufficient_scope` mid-session; same machinery as #2, different trigger. Handled as a re-consent on the existing connection.

**The split along the §3 seam.** Per-server connect has two faces, each landing on the side of the architecture it belongs to:
- **In-thread, just-in-time → transcript-native.** When a tool's MCP server needs authorization, the runtime injects an `authorization` custom segment (exactly as the permission gate injects `approval`). `AuthorizationView` renders a "Connect to *X*" card with the requested scopes; the user taps **Connect**; the handoff runs via `connect(_:)`; the runtime exchanges the token and retries; the now-authorized tool output lands in the transcript. *Request in the transcript, result in the transcript, no parallel channel* — the second proof of §3's claim. And "this tool is blocked on auth" stays **derived**, not signaled: a `.toolCall` followed by an `authorization` segment *is* a blocked tool, surfaced inline on `ToolCallView` via a `ConnectionStatusChip`.
- **Durable management → ambient state, not transcript.** The settings home (`ConnectionsView`) is the dominant pattern across ChatGPT / Claude / VS Code / Cursor — a list of servers/services with status, Connect/Disconnect, and per-tool toggles. This is *not* conversation content; it's the **second occupant of §3's "ambient runtime state" category**, the sibling of `ContextUsageView`'s usage gauge: the host binds an `@Observable` `ConnectionStore` and `ConnectionsView` renders it.

**The state machine is event-driven from the protocol** (MCP 2025-11-25). A server is `connected`; it transitions to `needs-auth` precisely on a `401` + `WWW-Authenticate`; to `authenticating` while the browser session is open; back to `connected` after a successful Bearer retry; and to `expired` / `needs-auth` on refresh failure. `ConnectionStatusChip` renders this five-state machine (green / yellow / red + label); nothing else needs to *announce* connection state.

**Division of labor — the kit presents, the runtime authorizes.** This mirrors how the kit treats EditorKit/Textual as engines beneath it. The kit owns a thin **`AuthorizationPresenter`** (§9 E2) that wraps **`ASWebAuthenticationSession`**: it supplies the required **`NSWindow` presentation anchor**, opens the system browser on a user action (never an embedded webview — RFC 8252 §4/§8.12), and returns the callback `URL` to the runtime. **Everything else is the runtime's**, beneath the kit and out of its spec: PRM/AS-metadata discovery (RFC 9728 / 8414 + OIDC), client identity (**CIMD preferred, DCR fallback** — the live 2025→2026 change), PKCE `S256` (verified before proceeding), the RFC 8707 `resource` audience binding, token exchange/refresh rotation, and **Keychain** storage (`kSecClassGenericPassword`, `kSecUseDataProtectionKeychain` on macOS). The redirect strategy (loopback `127.0.0.1:ephemeral`, the RFC 8252-preferred desktop form Claude Code / VS Code / Cursor use, vs. a custom/HTTPS callback scheme `ASWebAuthenticationSession` intercepts directly) is a **runtime** choice; the presenter accepts whatever callback config the runtime hands it. `prefersEphemeralWebBrowserSession` is exposed so the host can opt into a fresh, no-shared-cookies login.

**No prior art to port.** None of assistant-ui, Vercel AI Elements, CopilotKit, or AG-UI ships a first-class auth/connection component — each leaves it to an out-of-band Bearer token or a hand-built tool-UI/HITL card. So this surface is net-new and a genuine differentiator: AgentViewKit is the agent UI kit that makes *connecting* a first-class, transcript-native moment rather than a settings-only afterthought.

## 13. Elicitation (MCP `elicitation/create`)

Elicitation is MCP's standard mechanism for a **server** to ask the **user** for input in the middle of a
tool call — "what's your GitHub username?", "pick the branches to deploy", "set your reminder time" —
without baking those answers into the tool's up-front parameters. It's the third MCP interaction primitive
the kit makes first-class, after per-action **approval** (§9 E) and per-server **connect** (§12). It lands
on the exact §3 seam those two already use, so it costs the architecture **one verb, one in-thread segment
type, one compound view** — and is the *third proof* of §3's "everything renderable lives in the
transcript, only interaction verbs sit outside it" claim.

**The spec, precisely (MCP `2025-11-25`, with `2025-06-18` back-compat).** A server sends
`elicitation/create` with a human-readable `message` and a `mode`. There are two modes, and the kit
renders each on the side of the §3 seam it belongs to:

- **`form`** (default; `mode` omitted ⇒ form) — in-band structured collection. Carries a `requestedSchema`:
  a **flat object of primitive properties only** (no nesting, no arrays-of-objects). The response is the
  three-action model — `accept` (+ `content` matching the schema), `decline`, `cancel`.
- **`url`** — out-of-band interaction (auth, payment, anything sensitive) that **must not pass through the
  client**. Carries a `url` + an `elicitationId`. The client's *only* job is to get consent and open the
  URL safely; the result arrives later via `notifications/elicitation/complete` (or the request was
  triggered by a `-32042 URLElicitationRequiredError`, which the client may retry after completion).

The kit answers both through the same verb:

```swift
func respond(to request: ElicitationRequest, _ result: ElicitationResult) async
enum ElicitationResult {
    case accept(GeneratedContent)   // form mode: the validated field values
    case decline                    // user explicitly said no
    case cancel                     // user dismissed (Esc, clicked away, browser failed to load)
}
```

### 13.1 Form mode — `ElicitationView`, a compound schema-driven form

The runtime injects an `elicitation` custom segment (exactly as it injects `approval`/`authorization`);
`AgentTranscriptView` dispatches it to `ElicitationView`. The view does four things: **name the requesting
server** (a security MUST — always show *who* is asking and *why*, from `message`), **generate a field per
schema property**, **validate** locally against the schema, and **return** via `respond(to:_:)`.

**Schema → field-kind, normalized once.** The wire format for choices is a mess of four encodings across
spec versions; `ElicitationView` collapses them into a single internal field model so no renderer ever
branches on wire shape:

| `requestedSchema` property | Field kind | Default control |
|---|---|---|
| `string` (+ `minLength`/`maxLength`/`pattern`) | text | **EditorKit** input (single-line, or multi-line for long/large-max) |
| `string` + `format: email`/`uri` | text, validated | EditorKit input + format validation |
| `string` + `format: date`/`date-time` | date | `DatePicker` |
| `number`/`integer` (+ `minimum`/`maximum`) | number | stepper, or **slider** when both bounds present |
| `boolean` | boolean | `Toggle` (one switch, not two radios) |
| `enum: [...]` *or* `oneOf: [{const,title}]` *or* legacy `enumNames` | single-choice | **radio group** (≲5 options) / menu (more) |
| `type: array, items: {enum}` *or* `items: {anyOf: [{const,title}]}` (+ `minItems`/`maxItems`) | multi-choice | **checkbox group**, enforcing min/max-items |

Each choice normalizes to a `(value, title)` pair — for untitled encodings `title == value`; for titled
`oneOf`/`anyOf`, `value == const`. `default`s pre-populate every field (a `2025-11-25` addition, supported
across all primitive types). **Validation is the gate**: required properties, `min/maxLength`, `pattern`,
`min/maximum`, `min/maxItems`, and `format` are checked live; **Submit** (accept) is disabled with inline
field errors until the whole object validates — the client-side half of the spec's "validate before
sending."

**Multiple questions → tabbed, Claude-style.** A single-property request renders inline. A multi-property
request renders **tabbed** — one chip per property across the top, each marked required/optional and
showing an answered/valid checkmark, with the body showing the active field — so a request with several
multiple-choice questions is a clean step-through, not a long scroll. (This is the kit's read of Claude's
multi-question UX, which the user called out as the nice pattern.) The threshold (inline vs. tabbed vs. a
plain scrolling `Form`) is itself a configuration point on the layout slot below; tabbed is the default
above one field.

**Three actions, always available.** The footer carries **Submit** (accept; `.buttonStyle(.glassProminent)`,
disabled until valid), **Decline**, and **Cancel**; `Esc` / dismiss maps to `cancel`, never a silent
accept. Per §6, VoiceOver focus moves to the elicitation when it appears (it's a decision gate) and back to
the composer when it resolves.

### 13.2 Composability — a builder slot for every part (the explicit ask)

`ElicitationView` follows §7 exactly: a working default out of the box, and **every constituent is an
overridable slot**, so a consumer can restyle one field kind, the chrome, or the whole layout without
forking the view. The closed set of field kinds gets **typed override modifiers** (like §3's
`.responseView`/`.toolCallGroupView`), each closure receiving the concrete field context — not a switch:

```swift
ElicitationView(request)
    .elicitationTextField        { ctx in EditorKitInput(ctx) }   // DEFAULT — swap for stock or custom
    .elicitationSingleChoiceField { ctx in MyRadioGroup(ctx) }
    .elicitationMultiChoiceField  { ctx in MyCheckboxes(ctx) }
    .elicitationHeader  { req in MyServerBanner(req) }            // who's asking
    .elicitationLayout  { fields in MyTabStrip(fields) }          // tabbed / form / wizard
    .elicitationFooter  { actions in MyActionBar(actions) }       // Submit / Decline / Cancel

public struct ElicitationFieldContext {     // what the kit hands each field renderer
    public let schema: ElicitationFieldSchema   // title, description, constraints, format, choices
    public let value: Binding<GeneratedContent> // the field's current answer
    public let validation: FieldValidationState // live errors, required, satisfied
}
```

**Free text defaults to EditorKit, by design.** The kit already depends on EditorKit as its input engine
(§4.1, the "rich input" role), so the default `elicitationTextField` *is* EditorKit — single-line for short
strings, multi-line for long/large-`maxLength` ones — giving elicitation the same selection, theming, and
affordances as the composer. This defaults the **opposite direction from `PromptInputView`** (which defaults
to a stock editor, §7) — a deliberate choice the user asked for: one input engine for in-thread text, with
the slot there to drop in a stock SwiftUI field or any custom editor later. The constrained-extension
overload pattern (§7) supplies the EditorKit default so the no-closure `ElicitationView(request)` still
compiles as the drop-in.

### 13.3 URL mode — reuse the §12 browser handoff, don't rebuild it

URL-mode elicitation is structurally the OAuth-connect card again: out-of-band, browser-based, must not
leak data through the client. So it **reuses §12's machinery** rather than adding a parallel path.
`ElicitationURLConsentView` (the form-mode twin's sibling) renders a consent card — server name, the
`message`, and the **full `url` with its domain highlighted** — and on consent runs the open through the
same `AuthorizationPresenter` (§9 E2). The spec's safe-handling MUSTs map directly onto what that presenter
already does and onto the kit's no-WebView rule (§4): **never auto-open or pre-fetch**, **show the full URL
for examination**, **highlight the domain** (warn on Punycode/ambiguous hosts), and **open only in the safe
system browser** (`ASWebAuthenticationSession` / `SFSafariViewController`-class, *never* a `WKWebView` the
client or LLM could inspect). The kit returns `accept` to signal consent-to-open (not completion); the
interaction finishes out of band and resolves when `notifications/elicitation/complete` (matched by
`elicitationId`) arrives, with a manual **Retry**/**Cancel** always present in case the notification never
does. A `-32042 URLElicitationRequiredError` returned from a `tools/call` renders the same card and lets the
runtime retry the call after completion. The kit touches **zero** of the OAuth/token protocol — same
division of labor as §12: *the kit presents and gets consent; the runtime and server own everything else.*

### 13.4 Security posture (the spec's client MUSTs, mapped to the kit)

- **Form mode never carries secrets.** Servers MUST NOT request passwords/API keys/tokens via form mode —
  that's precisely what URL mode exists for. The kit surfaces the mode distinction in the UI and routes
  sensitive collection out-of-band.
- **Always identifiable, always refusable.** Every elicitation names the requesting server and offers
  **Decline** and **Cancel** at all times (§13.1) — the client's "make it clear who's asking" and "allow
  decline at any time" obligations.
- **Validate before sending** (§13.1) and **no clickable URLs in form fields** — only the `url` field of a
  URL-mode request is ever rendered as openable, and only through the consent flow (§13.3).
- **Rate-limiting / flood control** is a runtime concern beneath the kit; the kit renders whatever the
  runtime admits, the same as every other segment.

**Prior art.** As with §12, none of assistant-ui, Vercel AI Elements, or CopilotKit ships a first-class,
schema-driven elicitation form with the four-encoding enum normalization, tabbed multi-question layout, and
a swappable EditorKit text engine — so this, too, is net-new and a differentiator: AgentViewKit makes a
server *asking the user a question* a native, transcript-grounded moment.
