# AgentViewKit

A SwiftUI component library for agent UIs on macOS 27.

AgentViewKit gives the surfaces that an agent UI needs: streaming responses,
reasoning, tool calls, terminals, diffs, plans, citations, permissions,
elicitation, artifacts, config options, and context usage. An ACP v2 agent
streams to FoundationModelsACPClient. The client keeps the observable models
`ConnectionModel` and `SessionModel`, and the views bind directly to them. The
kit keeps no copy of the model data. A FoundationModels agent and a
FoundationModelsRouter agent reach the kit as an ACP agent, through
FoundationModelsACPAgent.

There are two levels of use. `AgentThreadView(session:connection:actions:)`
shows the whole surface. The primitives below it give full control.

## Install

The package is pre-1.0 and has no tag. Depend on the `main` branch:

```swift
.package(url: "git@github.com:swissarmyhammer/AgentViewKit.git", branch: "main")
```

Then link the kit. The one product holds the views and the ACP helpers:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "AgentViewKit", package: "AgentViewKit"),
  ]
)
```

The package needs the Swift 6.2 tools, the Swift 6 language mode, and macOS 27
or later. There is no back-deployment. The in-family dependencies (EditorKit,
FoundationModelsACP, and FoundationModelsACPClient) also come from their `main`
branches, over SSH.

## Quick start

Each block below that starts with `// readme:compile <Name>` is the file
`<Name>.swift` in [`Examples/ReadmeSnippets/Snippets/`](Examples/ReadmeSnippets/Snippets).
`swift test` compiles the files against the products that you import, and a
test holds the README and the files equal. Thus the code that you copy is the
code that we build. See [The README gate](#the-readme-gate).

### An ACP agent

`ConnectionModel` of FoundationModelsACPClient connects to the agent and holds
the state of the connection. `ConnectionModel.newSession(_:)` opens a session
and gives its `SessionModel`. The session model holds the transcript, the
agent state, and the pending permission and elicitation requests. The views
of the kit bind to the two models directly. The kit keeps no copy of their
state.

For an agent program, the transport is the `transport` of an `AgentProcess`.

```swift
// readme:compile ACPQuickStart
import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// Connects a connection model to an ACP v2 agent and opens one session.
@MainActor
enum ACPQuickStart {
  /// The name and the version of the app in its `initialize` request.
  static let appInfo = Implementation(name: "MyApp", version: "1.0.0")

  /// Connects `connection` over `transport` and opens one session.
  static func connect(
    _ connection: ConnectionModel, over transport: any ACPTransport, cwd: AbsolutePath
  ) async throws -> SessionModel {
    _ = await connection.connect(over: transport)
    return try await openSession(on: connection, cwd: cwd)
  }

  /// Sends `initialize` and `session/new` on a connected model.
  static func openSession(on connection: ConnectionModel, cwd: AbsolutePath) async throws -> SessionModel {
    // The request advertises only the capabilities that the kit views show.
    // An agent that speaks ACP v1 makes this call throw. The kit speaks v2 only.
    _ = try await connection.initialize(InitializeRequest.makeAgentViewKitRequest(info: appInfo))
    return try await connection.newSession(NewSessionRequest(cwd: cwd))
  }
}

/// Shows one session. The view gets the two models and keeps nothing else.
struct ACPThread: View {
  let connection: ConnectionModel
  let session: SessionModel

  var body: some View {
    // The session views send the prompts, the cancel, and the answers to the
    // permission and elicitation cards through the two models. The logging
    // actions get only the verbs that no model has, such as a terminal
    // sign-in.
    AgentThreadView(session: session, connection: connection, actions: LoggingThreadActions())
      // The composer reads the two models from the environment.
      .environment(\.sessionModel, session)
      .environment(\.connectionModel, connection)
  }
}
```

The kit speaks ACP protocol version 2 only
([`Docs/decisions/acp-version.md`](Docs/decisions/acp-version.md)). The agents
that are available today (Claude Code, Codex, and Gemini CLI) speak version 1.
The kit refuses such an agent: `initialize` throws, and no session opens.
The first agent of the kit is FoundationModelsACPAgent, which speaks version
2. The demo app uses an in-memory agent that speaks version 2.

### An agent in this process

`InProcessAgent.makeConnection(serving:)` runs an ACP agent in the process of
the app. It pairs an `InMemoryTransport`, serves the agent on one end with an
`AgentSideConnection`, and connects a new `ConnectionModel` on the other end.
The two sides speak the real ACP wire. The helper returns the connection
model and keeps no state of its own. The kit does not import an agent: the
app gives it, for example the `RoutedACPAgent` of FoundationModelsACPAgent.
To stop the agent, call `ConnectionModel.disconnect()`: the helper then closes
the input of the agent side, and the agent stops. When the agent closes its
connection first, `ConnectionModel.state` becomes `.disconnected`.

```swift
// readme:compile InProcessQuickStart
import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPClient

/// Runs an ACP agent in this process and opens one session on it.
@MainActor
enum InProcessQuickStart {
  /// Starts the agent that `makeAgent` makes, and opens one session.
  ///
  /// With FoundationModelsACPAgent, the closure binds a `RoutedACPAgent`:
  ///
  /// ```swift
  /// let agent = try await RoutedACPAgent(name: name, router: router)
  /// let (connection, session) = try await InProcessQuickStart.start(cwd: cwd) { connection in
  ///   agent.bind(connection: connection)
  ///   return agent
  /// }
  /// ```
  ///
  /// Show the session with `ACPThread(connection:session:)` of the quick
  /// start above.
  static func start(
    cwd: AbsolutePath, serving makeAgent: @Sendable (AgentSideConnection) -> any Agent
  ) async throws -> (connection: ConnectionModel, session: SessionModel) {
    let connection = await InProcessAgent.makeConnection(serving: makeAgent)
    return (connection, try await ACPQuickStart.openSession(on: connection, cwd: cwd))
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
import FoundationModelsACPClient
import SwiftUI
import UniformTypeIdentifiers

// Add `@main` to make this the entry point of your app.
struct HostApp: App {
  /// The connection to the agent. Connect it and open a session with a quick
  /// start above.
  @State private var connection = ConnectionModel()

  init() {
    // Loads the bundled grammars now, so that the first code block does not wait.
    GrammarBundle.register()
  }

  var body: some Scene {
    WindowGroup {
      // The window shows an open session of the connection model.
      if let session = connection.openSessions.values.first {
        HostThread(connection: connection, session: session)
      } else {
        ContentUnavailableView("No session", systemImage: "bubble.left.and.bubble.right")
      }
    }
  }
}

struct HostThread: View {
  let connection: ConnectionModel
  let session: SessionModel

  var body: some View {
    ACPThread(connection: connection, session: session)
      // One typed modifier for each transcript entry case. The closure gets
      // the entry object of the session model.
      .toolCallView { call in Text(call.title ?? "") }
      .reasoningView { _ in EmptyView() }
      // The open-ended kinds take a key: a block kind or a type.
      .contentBlockView(for: .resourceLink) { block in
        if case .resourceLink(let link) = block { Text(link.name) }
      }
      .attachmentView(for: .pdf) { url in Text(url.lastPathComponent) }
      // The footer slot of each message entry.
      .messageFooter { entry in MessageActions(entry: entry) }
  }
}
```

### Override modifiers

`AgentThreadView(session:actions:)` switches over `TranscriptEntry` inside.
To replace the view of one case, chain the typed modifier of that case. The
closure gets the observable entry object of the session model, so the view
that it makes shows each change of the model. An inner modifier wins over an
outer modifier for the same case.

| Modifier | The closure gets |
|---|---|
| `.userMessageView { entry in }` | `UserMessageEntry` |
| `.assistantMessageView { entry in }` | `AgentMessageEntry` |
| `.reasoningView { entry in }` | `ThoughtEntry` |
| `.toolCallView { entry in }` | `ToolCallEntry` |
| `.terminalView { entry in }` | `TerminalEntry` |
| `.planView { entry in }` | `PlanTranscriptEntry` |
| `.errorView { entry in }` | `ErrorEntry` |
| `.unknownItemView { entry in }` | `UnknownEntry` |
| `.compactionEntryView { entry in }` | `CompactionEntry` |

The open-ended kinds take a key:

| Modifier | The closure gets |
|---|---|
| `.contentBlockView(for: .kind) { block in }` | the ACP `ContentBlock` of the entry, for one block kind |
| `.attachmentView(for: .pdf) { url in }` | `URL`, for one uniform type and its subtypes |
| `.messageFooter { entry in }` | `MessageEntry`, the user or agent message entry, for the footer slot of each message |
| `.diffRenderer { patch, file in }` | the patch and the file, in place of the EditorKit diff view |

A uniform type with no registration falls to the nearest supertype, and then
to the file chip. Nothing is dropped.

## Components

The list follows the inventory of [`plan.md`](plan.md) §9. A test holds the
two lists equal.

**Thread**

- `AgentThreadView`: the drop-in view. It binds a `SessionModel` and shows the whole surface.
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

- `PermissionView`: a pending permission request of a `SessionModel`, with its options, its subject, and a comment field.
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
one tab. The ACP tab connects to an ACP agent, shows its sessions in a
sidebar, and shows the thread after the session binds.

The launch arguments are in
[`Sources/DemoSupport/DemoLaunchOptions.swift`](Sources/DemoSupport/DemoLaunchOptions.swift):

- `--in-memory-agent`: the ACP tab binds the in-memory agent, and starts no process.
- `--agent-command <path>`: the ACP tab starts this agent program. The default is the `acp-agent` build of the sibling FoundationModelsACPAgent checkout. The app starts an `acp-agent` program with the `acp` subcommand, because the default subcommand of `acp-agent` does not speak ACP. The app starts other programs with no arguments.
- `--cwd <path>`: the working directory of each session. The default is the home directory.

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
