# AgentViewKit — a SwiftUI agent UI component library

**Status:** v0.11 — draft
**Target:** macOS 27+ (Apple Silicon), OS 27 SDK — so we assume the WWDC 2026 surface (the
FoundationModels `Transcript` shape, Liquid Glass 2, the long-form-reading accessibility APIs) with
no back-deployment.
**What:** the native SwiftUI counterpart to Vercel AI Elements / assistant-ui, bound to the
FoundationModels `Transcript`. A reusable, open-sourceable Swift Package — same posture as the Swift
ACP SDK.
**Last updated:** 2026-06-17

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
  successor is **Textual** (same author). Watch Textual; use one of these for non-streaming.
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
- `.response` → assistant text, **split into paragraph blocks** so only the streaming paragraph re-renders (§8); rendered through EditorKit (§4.1).
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
segments. No call-site switch anywhere.

**Attachments are per-type too — files, not just images.** The FoundationModels docs lean on images, but
a user prompt (and a file artifact) can carry any file. AgentViewKit models an `Attachment` by its
`UTType` and renders it with a default keyed to that type — image preview, PDF/QuickLook thumbnail,
text/code via EditorKit, audio/video player, and a generic file chip (type icon + name + size, QuickLook
on tap) as the catch-all. Because UTTypes are open-ended, the renderer is overridable by a keyed modifier,
the same shape as custom structured segments:

```swift
    .attachmentView(for: .pdf)                { file in MyPDFPreview(file) }
    .attachmentView(for: .commaSeparatedText) { file in CSVTableView(file) }
```

Resolution follows the **UTType conformance hierarchy**: an exact registration wins, else the nearest
conforming supertype (a `.swift` file falls to `.sourceCode` → `.text` → EditorKit; an unknown binary
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
    func send(_ input: UserInput) async                              // text + attachments
    func interrupt()                                                  // stop the current turn
    func respond(to: ApprovalRequest, _ decision: ApprovalDecision)  // unblock the paused gate
}
```

The approval flow is the proof: the runtime's permission gate (§4.11) injects an `approval` custom
segment when it blocks; `AgentTranscriptView` renders it as `ApprovalView`; the user's choice flows back
through `respond(to:_:)` and the gate resumes — request in the transcript, decision via a callback, no
channel. A live token/context gauge is the one genuine piece of runtime state, and it isn't transcript
content either: the host binds a plain `@Observable` usage value to `ContextUsageView` directly.

Every runtime backend is a `LanguageModelSession`, so the `Transcript` already covers System / MLX /
llama / Claude Code / Codex uniformly; a non-FM source driven directly (e.g. a remote ACP agent) maps its
stream into the same `Transcript` (and custom segments) through a thin adapter — same render path.

Two consumption levels: the drop-in **`AgentTranscriptView(transcript)`** for the whole surface, and the
composable primitives below for full control.

## 4. Building blocks — reuse, don't reinvent

All-Swift, native — **no WebView or JSCore anywhere**. Links don't render as embedded web tiles (a live
page in a tile is worse than the real thing); they open in the user's browser via `openURL` /
`NSWorkspace`, optionally shown as a native rich-link card (LinkPresentation `LPLinkView`) that still
launches the browser on click. Both
prose **and** code render through **EditorKit** (below), our high-power drop-in for SwiftUI `Text`.

| Concern | Use | Why |
|---|---|---|
| Markdown parse + streaming balance | **SwiftStreamingMarkdown** (+ a streaming balancer, §8) | structure only — produces blocks/attributed runs; rendering is EditorKit's job |
| Text + code rendering | **EditorKit (ours)** — drop-in for `Text` | one engine for prose, streaming text, code blocks, and editable diffs: selection, rich runs, performance |
| Static / rich markdown | MarkdownUI (→ Textual) as the parser where needed | mature GFM; still renders through EditorKit |
| Layout / scroll | native `ScrollView` + `ScrollViewReader` + `LazyVStack`/`List` | scroll anchoring; lazy row creation, windowed for long threads (§8) |
| Chrome / styling | native **Liquid Glass** (`glassEffect`/`GlassEffectContainer`) + design tokens | Xcode-assistant look by default (§5); no web theming to port |
| Activity / progress | **shimmer** for streaming/thinking · native `ProgressView` for discrete tool calls · **SF Symbols** w/ effects | native affordances, not facsimiles (§5) |
| Speech in/out | native `Speech` + our `whisper-rs`/`cpal` path | voice composer + transcription |

### 4.1 Dependency: EditorKit — the universal text renderer

AgentViewKit **depends on EditorKit** and uses it as a **high-power drop-in for SwiftUI `Text`**: the
native counterpart to CM6 in the web app, the "one universal editor everywhere" principle. Anywhere
the kit would otherwise use `Text`, it uses EditorKit instead, so the heavy lifting (glyph layout,
text selection across the transcript, rich attributed runs, syntax highlighting, large-document
performance) lives in one NSTextView-backed surface that still presents as an ordinary SwiftUI view.
Three roles:
- **Prose render** — message body text and streaming text render through EditorKit, giving real
  transcript-wide selection (the thing plain SwiftUI `Text` does poorly) for free.
- **Code render** — fenced code blocks render in EditorKit's read-only highlight mode (Splash/
  Highlightr dropped). The markdown layer produces blocks; EditorKit renders both the prose runs and
  the code blocks, so styling is uniform.
- **Full editor** — editable artifacts and diffs use the same EditorKit, so "code the agent showed
  me" and "code I'm editing" are identical in highlighting, theme, and language support.
- **Rich input** — as the composer's editor, EditorKit also owns the in-line input affordances:
  **slash commands**, **chips/tokens**, and **`@file` references** (with their popups/autocomplete)
  are EditorKit features, the native analog of how CM6 handles them in the web app. The composer
  inherits all of this by hosting EditorKit; AgentViewKit doesn't reimplement them.

This is what keeps the transcript pure SwiftUI at scale (§8): the SwiftUI list stays light because the
expensive text work is inside EditorKit, not in per-cell SwiftUI view trees. The highlighting/layout
engine choice (tree-sitter, NSTextView internals) lives in EditorKit's own spec — out of scope here;
AgentViewKit just treats it as a `Text` that can do far more.

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
material levels, symbol weights) so the kit restyles coherently and a consumer can re-tint without
touching component internals. Builders (§7) override structure; tokens tune the default look.

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
- **Heavy text lives in EditorKit, not the cells.** The reason pure SwiftUI holds up here is that the
  expensive text work — glyph layout, selection, highlighting — is inside EditorKit's NSTextView-backed
  surface (§4.1), so the SwiftUI cells stay thin wrappers. This is how we get native-grade transcript
  performance without dropping the list itself to AppKit.
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
- `MessageView` — user/assistant, parts-based render; body text via EditorKit (§4.1). *native*
- `MessageActions` — copy / retry / edit, in a **footer** block (not hover-revealed). *native*
- `BranchNavigator` — regenerate / branch paging. *native*
- `ThreadMinimapView` — condensed overview of the whole thread (turns, tool calls, errors) as a scrubbable rail for navigating long conversations; click to jump, highlights current viewport. *net-new*

**A2. Transcript entry views (one per `Transcript.Entry`/`Segment`, each overridable §3/§7)**
- `InstructionsView` — system prompt; hidden by default, inspectable. *net-new*
- `PromptView` — a `.prompt` entry (user turn) + its segments; attachments render via the `AttachmentView` family (§3, §9 F). *net-new*
- `ResponseView` — a `.response` entry, paragraph-split, via EditorKit. *net-new (see B)*
- `ToolCallGroupView` — `.toolCalls` + paired `.toolOutput`, grouped with per-call duration. *net-new (see C)*
- `ToolOutputView` — a standalone `.toolOutput`. *net-new*
- `TextSegmentView` / `StructuredSegmentView` — the two `Transcript.Segment` kinds; the structured one dispatches on `source` to a native renderer (chart/diff/card). *net-new*

**B. Streaming content**
- `ResponseView` — streaming-safe message text; rendered via **EditorKit** (text drop-in, §4.1), fed by the SwiftStreamingMarkdown parser + balancer (§8). *EditorKit + parser*
- `CodeBlockView` — copy + filename; renders via **EditorKit** (read-only highlight). *EditorKit*
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

**F. Artifacts / attachments / rich output**
- `AttachmentView` — **per-attachment, any file** (§3): keyed by `UTType` with conformance-based fallback; defaults to image preview, PDF/QuickLook thumbnail, text/code (EditorKit), audio/video player, or a generic file chip (icon + name + size, QuickLook on tap). Overridable via `.attachmentView(for:)`. Shared by composer chips, prompt attachments, and file artifacts. *net-new (native QuickLook/UTType)*
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

## 11. Open questions

*Resolved:* **Primary binding = a FoundationModels `Transcript`** — `AgentTranscriptView(transcript)`
renders the whole surface. Everything renderable lives in the transcript (entry, tool output, or a
custom `.structure` segment); in-progress state is *derived* from unpaired tail entries, not signaled;
`AgentViewSession` adds only the interaction verbs (send/interrupt/respond) — no parallel channel (§3). **SwiftUI throughout** — the transcript stays SwiftUI (`LazyVStack`/`List`); heavy text work lives
in EditorKit so the cells stay light (§8). **EditorKit is the universal text renderer** — a drop-in for
`Text` covering prose, streaming text, code, and diffs (§4.1); SwiftStreamingMarkdown (+balancer)
parses, EditorKit renders. Composability via `@ViewBuilder` slots with default overloads (§7). Default
look = Liquid Glass + Xcode-assistant cues; **shimmer** for streaming/thinking, native `ProgressView`
for discrete steps (§5); fully accessible by default (§6).

1. Distribution: standalone open-source SPM package (like the Swift ACP SDK) vs in-app target. Lean standalone + open primitives; depends on EditorKit.
2. Custom-segment registration: fixed entry/segment types get typed override modifiers (§3); the open-ended `.structure` `source` gets a `.structuredSegment(source:)` modifier. Open part: collision/precedence when two registrations claim a `source`, and the default view for an unknown `source`.
3. `AgentGraphView`: v1 or later? (Later — single-agent activity first.)
4. EditorKit ↔ markdown integration: the parser produces blocks/attributed runs; confirm the cleanest hand-off so streaming prose and fenced code both render through EditorKit without a per-token re-layout storm.
5. Long-thread strategy (all SwiftUI): `LazyVStack` for custom layout vs `List` (recycling) for very long threads — and whether windowing/pagination is needed on top, given EditorKit already carries the per-cell text cost.
6. Design tokens (§5): ship a public, themeable token set consumers can re-tint, or keep tokens internal and rely on builder overrides + the system Liquid Glass tint/opacity?
7. Math rendering: agent output contains LaTeX/math — add a native `MathView` (and which engine), since EditorKit is text/code, not math typesetting?
