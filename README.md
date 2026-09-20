# AgentViewKit

A SwiftUI component library for agent UIs on macOS 27.

AgentViewKit gives the surfaces that an agent UI needs: streaming responses,
reasoning, tool calls, terminals, diffs, plans, citations, permissions,
elicitation, artifacts, config options, and context usage. The views bind to
one observable model, `AgentThread`. A source adapter fills the model from a
runtime. The kit has three sources: an ACP v2 agent, a FoundationModels
`LanguageModelSession`, and a FoundationModelsRouter session.

There are two levels of use. `AgentThreadView(thread:actions:)` shows the
whole surface. The primitives below it give full control.

## Install

The package is pre-1.0 and has no tag. Depend on the `main` branch:

```swift
.package(url: "git@github.com:swissarmyhammer/AgentViewKit.git", branch: "main")
```

Then link the kit, and the product of each source that your app uses:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "AgentViewKit", package: "AgentViewKit"),
    .product(name: "AgentViewKitACP", package: "AgentViewKit"),
    .product(name: "AgentViewKitFoundationModels", package: "AgentViewKit"),
    .product(name: "AgentViewKitRouter", package: "AgentViewKit"),
  ]
)
```

The package needs the Swift 6.2 tools, the Swift 6 language mode, and macOS 27
or later. There is no back-deployment. The in-family dependencies (EditorKit,
FoundationModelsACP, FoundationModelsACPClient, FoundationModelsRouter, and
FoundationModelsExtras) also come from their `main` branches, over SSH.

## Three quick starts

Each block below that starts with `// readme:compile <Name>` is the file
`<Name>.swift` in [`Examples/ReadmeSnippets/Snippets/`](Examples/ReadmeSnippets/Snippets).
`swift test` compiles the files against the products that you import, and a
test holds the README and the files equal. Thus the code that you copy is the
code that we build. See [The README gate](#the-readme-gate).

### 1. An ACP agent

`ACPThreadSource` reads the `session/update` stream of one session and fills
the thread. `ACPThreadActions` sends the prompts, the cancel, and the answers
to the agent.

```swift
// readme:compile ACPQuickStart
import AgentViewKit
import AgentViewKitACP
import FoundationModelsACP
import FoundationModelsACPClient
import Observation
import SwiftUI

/// Connects to an ACP v2 agent, opens a session, and binds it to a thread.
@Observable
@MainActor
final class ACPQuickStart {
  let thread = AgentThread()
  private(set) var actions: ACPThreadActions?

  @ObservationIgnored private let client = SwiftUIACPClient()
  @ObservationIgnored private var tasks: [Task<Void, Never>] = []

  func connect(over transport: any ACPTransport, cwd: String) async throws {
    let connection = await client.connect(over: transport)
    let request = InitializeRequest(
      info: Implementation(name: "MyApp", version: "1.0.0"),
      protocolVersion: ACPClient.supportedProtocolVersion,
      capabilities: ACPClient.advertisedCapabilities)
    // An agent that speaks ACP v1 makes this call throw. The kit speaks v2 only.
    let response = try await connection.initialize(request)
    let session = try await connection.newSession(NewSessionRequest(cwd: AbsolutePath(rawValue: cwd)))
    let sessionId = session.sessionId

    let source = ACPThreadSource(
      thread: thread, updates: connection.updates(for: sessionId), agentName: "Agent")
    source.acceptProtocolVersion(response.protocolVersion, requested: request.protocolVersion)
    tasks = [
      Task { await source.run() },
      Task {
        await source.mirrorPendingRequests(
          of: client.session(for: sessionId), client: client, sessionId: sessionId)
      },
    ]
    actions = ACPThreadActions(thread: thread, client: client, connection: connection, sessionId: sessionId)
  }
}

struct ACPThread: View {
  let model: ACPQuickStart

  var body: some View {
    if let actions = model.actions {
      AgentThreadView(thread: model.thread, actions: actions)
    } else {
      ProgressView("Connecting")
    }
  }
}
```

The kit speaks ACP protocol version 2 only
([`Docs/decisions/acp-version.md`](Docs/decisions/acp-version.md)). The agents
that are available today (Claude Code, Codex, and Gemini CLI) speak version 1.
The kit refuses such an agent: `initialize` throws, or `ACPThreadSource` adds
one error record that names the two versions, and the thread gets no update.
The first agent of the kit is FoundationModelsACPAgent, which speaks version
2. The demo app uses an in-memory agent that speaks version 2.

### 2. A FoundationModels session

`SessionThreadSource` observes a live `LanguageModelSession` and fills the
thread. `SessionThreadActions` starts and cancels each turn.

```swift
// readme:compile FoundationModelsQuickStart
import AgentViewKit
import AgentViewKitFoundationModels
import FoundationModels
import SwiftUI

/// Binds a live `LanguageModelSession` to a thread.
@MainActor
final class FoundationModelsQuickStart {
  let source: SessionThreadSource
  let actions: SessionThreadActions

  init() {
    let session = LanguageModelSession(instructions: "You are the assistant of MyApp.")
    source = SessionThreadSource(session: session)
    actions = SessionThreadActions(source: source)
    source.start()
  }
}

struct FoundationModelsThread: View {
  let model: FoundationModelsQuickStart

  var body: some View {
    AgentThreadView(thread: model.source.thread, actions: model.actions)
  }
}
```

The source maps the transcript of the session: the instructions, the prompts,
the responses, the reasoning, and the tool calls. A response streams into the
thread one paragraph at a time. `AgentTranscriptView(transcript:)` shows a
persisted `Transcript` value one time, and does not update.

### 3. A Router session

`RouterThreadSource` reads the session events of a FoundationModelsRouter
`RoutedSession` and fills the thread. `RouterThreadActions` starts each turn,
cancels it, and answers the elicitations.

```swift
// readme:compile RouterQuickStart
import AgentViewKit
import AgentViewKitRouter
import FoundationModelsRouter
import SwiftUI

/// Binds a Router session to a thread.
@MainActor
final class RouterQuickStart {
  let source: RouterThreadSource
  let actions: RouterThreadActions
  private let run: Task<Void, Never>

  init(session: any RoutedSession) {
    let source = RouterThreadSource(session: session)
    self.source = source
    actions = RouterThreadActions(source: source)
    run = Task { await source.run() }
  }
}

struct RouterThread: View {
  let model: RouterQuickStart

  var body: some View {
    AgentThreadView(thread: model.source.thread, actions: model.actions)
  }
}
```

## The host app

Two things belong in the host. Call `GrammarBundle.register()` at launch, so
that the first code block does not wait for the grammars to load. Add the
typed modifiers for the item kinds that your app shows in its own way.

```swift
// readme:compile HostApp
import AgentViewKit
import SwiftUI
import UniformTypeIdentifiers

// Add `@main` to make this the entry point of your app.
struct HostApp: App {
  init() {
    // Loads the bundled grammars now, so that the first code block does not wait.
    GrammarBundle.register()
  }

  var body: some Scene {
    WindowGroup {
      // A thread that no source drives takes the logging actions.
      HostThread(thread: AgentThread(), actions: LoggingThreadActions())
    }
  }
}

struct HostThread: View {
  let thread: AgentThread
  let actions: any AgentThreadActions

  var body: some View {
    AgentThreadView(thread: thread, actions: actions)
      // One typed modifier for each item kind. The closure gets the record.
      .toolCallView { call in Text(call.title) }
      .reasoningView { _ in EmptyView() }
      // The open-ended kinds take a key: a schema name, a block kind, or a type.
      .structuredItem("MyApp.Chart") { content in Text(content.schemaName) }
      .contentBlockView(for: .resourceLink) { block in
        if case .resourceLink(let link) = block.content { Text(link.name) }
      }
      .attachmentView(for: .pdf) { url in Text(url.lastPathComponent) }
      // The footer slot of each message.
      .messageFooter { message in BranchNavigator(messageID: message.id) }
  }
}
```

### Override modifiers

`AgentThreadView` switches over `ThreadItem` inside. To replace the view of
one kind, chain the typed modifier of that kind. The closure gets the concrete
record. An inner modifier wins over an outer modifier for the same kind.

| Modifier | The closure gets |
|---|---|
| `.systemPromptView { prompt in }` | `SystemPrompt` |
| `.userMessageView { message in }` | `Message` |
| `.assistantMessageView { message in }` | `Message` |
| `.reasoningView { reasoning in }` | `Reasoning` |
| `.toolCallView { call in }` | `ToolCallRecord` |
| `.structuredItemView { record in }` | `StructuredRecord`, for each structured item |
| `.compactionView { marker in }` | `CompactionMarker` |
| `.errorView { error in }` | `ThreadError` |
| `.unknownItemView { record in }` | `UnknownRecord` |

The open-ended kinds take a key:

| Modifier | The closure gets |
|---|---|
| `.structuredItem("Name") { content in }` | `StructuredItemContent`, for one schema name, as a thread item and as a block in a message |
| `.contentBlockView(for: .kind) { block in }` | `ContentBlock`, for one block kind |
| `.attachmentView(for: .pdf) { url in }` | `URL`, for one uniform type and its subtypes |
| `.messageFooter { message in }` | `Message`, for the footer slot of each message |
| `.diffRenderer { patch, file in }` | the patch and the file, in place of the EditorKit diff view |

A schema name with no registration shows a collapsible pretty-printed
`JSONValue`. A uniform type with no registration falls to the nearest
supertype, and then to the file chip. Nothing is dropped.

## Components

The list follows the inventory of [`plan.md`](plan.md) §9. A test holds the
two lists equal.

**Thread**

- `AgentThreadView`: the drop-in view. It binds an `AgentThread` and shows the whole surface.
- `AgentTranscriptView`: the snapshot view of a FoundationModels `Transcript` value. It does not update.
- `ConversationView`: the container with auto-scroll, the scroll-to-bottom pill, and the empty state.
- `MessageActions`: copy, copy thread, export, retry, and edit, in the message footer.
- `BranchNavigator`: regenerate, and the paging of the branches of a message.
- `ThreadMinimapView`: the rail of turns, tool calls, and errors. A drag moves the thread.
- `StateBanner`: shows `requiresAction` and a stop reason that needs attention.
- `SessionListView`: the sessions of `session/list`, with cursor paging.

**Item views**

- `SystemPromptView`: the instructions, collapsed by default.
- `UserMessageView` and `AssistantMessageView`: the content blocks of a message, with the footer slot.
- `StructuredItemView`: the fallback of the schema name registry, a collapsible pretty-printed `JSONValue`.
- `CompactionMarkerView`: marks a transcript rewrite and shows its summary.
- `UnknownItemView`: the collapsible raw view of an unknown record or block.
- `ErrorView`: one block for each error kind, each with an action such as Retry or Compact.
- `ContentBlockView`: the block family: text, image, audio, resource link, resource, attachment, structured, and unknown.

**Streaming content**

- `ResponseView`: the paragraph-split Markdown view on Textual, with the balancer and the code block hook.
- `CodeBlockView`: a read-only EditorKit editor with copy, filename, and language.
- `MathView`: inline and block LaTeX.
- `ReasoningView`: collapsible, with a shimmering title while it runs, and auto-collapse when it stops.
- `ActivityIndicator` and `ShimmerView`: the in-progress effects.

**Agent activity**

- `ToolCallView`: title, kind icon, status, locations, raw input and output, and collapsible content.
- `TerminalView`: an agent-owned terminal with command, cwd, exit status, and ANSI output.
- `DiffView`: the per-file list with counts, accept or reject per hunk, and attach lines to the prompt, over the EditorKit diff view.
- `TaskListView`: the plans, keyed by id, with priority and status.
- `ActivityTimeline`: tool calls, reasoning, and terminals in time order, with host timestamps.
- `SubagentTreeView`: the tree of child runs, with status and drill-in.
- `SourcesView` and `InlineCitation`: the sources of a message and the citation pills in the text.
- `ContextUsageView`: the context usage meter. It merges FoundationModels usage and ACP `usage_update`.
- `AgentGraphView`: the multi-agent canvas. This view is not in v1.

**Infrastructure**

- `AgentThread`, `ThreadItem`, `ThreadChange`: the model, its records, and the changes that a source applies.
- `StreamingMarkdownBalancer`, `ScrollAnchorManager`, `ExpandedBlocksStore`: the balancer of open Markdown, the scroll anchors, and the expanded state of the blocks.
- `AgentCommands`: the kit verbs as EditorKit commands (`AgentCommandVerb`) with the default keymap (`AgentKeymap`).
- `GrammarBundle`: the TextMate grammars of the languages that agents write most.

**Input**

- `PromptInputView`: the composer on EditorKit, with slash commands, `@file`, attachments, tool toggles, and the mic.
- `ConfigOptionsView`: the picker of `configOptions`, grouped by category.
- `PromptQueueView`: the queued messages while a turn runs, with reorder, edit, drop, and send now.
- `SuggestionsView` and `SpeechInputButton`: the suggestion chips and the speech input.

**Human in the loop**

- `PermissionView`: a `PermissionRequest` with its options, its subject, and a comment field.
- `PermissionModePicker`: the `mode` config option as a segmented control.
- `CheckpointView`: the history slider with Restore code, Restore conversation, or both.

**Connections and authorization**

- `AuthorizationView`: the in-thread card that connects an MCP server.
- `AgentAuthView`: the auth methods of an ACP agent, with sign-out.
- `ConnectionsView`, `ConnectionRow`, `ConnectionStatusChip`: the list of connections, one row, and one status chip.
- `AuthorizationPresenter`: opens an authorization URL in `ASWebAuthenticationSession`.

**Elicitation**

- `ElicitationView`: the form of an elicitation request, with the `ElicitationFieldView` family and `ElicitationURLConsentView` for URL mode.

**Artifacts and attachments**

- `AttachmentView`, `AttachmentInspector`, `ArtifactView`, `CommandOutputView`, `LinkView`, `ImageView`, `AudioPlayerView`: the attachment chip, the Quick Look inspector, the artifact card, the command output, and the link, image, and audio blocks.

## The demo app

[`Examples/AgentViewKitDemo`](Examples/AgentViewKitDemo) is a macOS app with
two tabs. The ACP tab connects to an ACP agent, shows its sessions in a
sidebar, and shows the thread after the session binds. The FoundationModels
tab binds a `LanguageModelSession` on the system model, with two demo tools.

The launch arguments are in
[`Sources/DemoSupport/DemoLaunchOptions.swift`](Sources/DemoSupport/DemoLaunchOptions.swift):

- `--in-memory-agent`: the ACP tab binds the in-memory agent, and starts no process.
- `--agent-command <path>`: the ACP tab starts this agent program. The default is the `acp-agent` build of the sibling FoundationModelsACPAgent checkout.
- `--cwd <path>`: the working directory of each session. The default is the home directory.
- `--fake-language-model`: the FoundationModels tab binds a fake model with a scripted reply, and the app opens on that tab.
- `--force-model-unavailable`: the FoundationModels tab shows the model as not available, and the app opens on that tab.

The demo UI tests are in
[`Examples/AgentViewKitDemo/Tests/`](Examples/AgentViewKitDemo/Tests). Run
them with `Scripts/test-examples.sh`. The script makes the Xcode project,
builds the app, and runs the UI tests. It needs Xcode, the `xcodeproj` gem,
and macOS UI Automation Mode. Without automation mode, the test runner waits
and gives no output.

## Tests and gates

```bash
swift test                  # the unit tests, the hosted view tests, and the README snippets
Scripts/check-readme.sh     # the README gate
Scripts/check-benchmarks.sh # the benchmark gate
Scripts/test-examples.sh    # the demo UI tests
```

### The README gate

`Scripts/extract-readme-snippets.sh` writes each `// readme:compile` block of
this file to `Examples/ReadmeSnippets/Snippets/<Name>.swift`. The
`ReadmeSnippetsTests` target compiles that directory on each `swift test`.
`Scripts/check-readme.sh` extracts the blocks again, fails when the result
differs from the committed files, and builds the target. When you change a
block, run the extraction script and commit the result.

### The benchmark gate

The benchmarks are a separate package in [`Benchmarks/`](Benchmarks). They
measure the streaming paths and compare each run with the committed baseline.
`Scripts/check-benchmarks.sh` fails when a change makes a path slower than
the baseline permits. [`Benchmarks/README.md`](Benchmarks/README.md) names
the scenarios and the commands.

## Design documents

- [`plan.md`](plan.md): the architecture, the component inventory, and the decisions.
- [`Docs/decisions/`](Docs/decisions): one file for each decision, such as the ACP version, the diff renderer, the branches, and the required thread actions.
