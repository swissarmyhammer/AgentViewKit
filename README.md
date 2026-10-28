# AgentViewKit

The SwiftUI view kit for the UI of an ACP client on macOS 27.

AgentViewKit gives the surfaces that an agent UI needs: streaming responses,
reasoning, tool calls, terminals, diffs, plans, citations, permissions,
elicitation, artifacts, config options, and context usage. An ACP v2 agent
streams to FoundationModelsACPClient. The client keeps the observable models
`ConnectionModel` and `SessionModel`, and each view binds directly to them: a
view shows what the model holds, and it calls the methods of the model. The
kit keeps no copy of the model data and no logic that tracks the prompts
([`Docs/decisions/acp-client-kit.md`](Docs/decisions/acp-client-kit.md)). A
FoundationModels agent and a FoundationModelsRouter agent reach the kit as an
ACP agent, through FoundationModelsACPAgent.

There are two levels of use. `AgentThreadView(session:connection:)` shows
the whole thread, and `RequestDeck` shows the requests next to it. The
primitives below them give full control. To start, use one of the two quick
starts: [an ACP agent](#an-acp-agent) program, or
[an agent in this process](#an-agent-in-this-process).

The direct dependencies are:

- FoundationModelsACPClient: the observable models `ConnectionModel` and
  `SessionModel`, and the in-process helper `InProcessAgent`.
- FoundationModelsACP: the ACP v2 schema types, `ClientSideConnection` and
  `InMemoryTransport`.
- EditorKit: code blocks, diffs, the composer editor, the commands, and the
  theme of the kit.
- Textual: Markdown.
- swiftui-math: math.

[`Docs/decisions/dependencies.md`](Docs/decisions/dependencies.md) gives the
versions and the products.

## Install

The package is pre-1.0 and has no tag. Depend on the `main` branch:

```swift
.package(url: "git@github.com:swissarmyhammer/AgentViewKit.git", branch: "main")
```

Then link the kit. The package has two library products. `AgentViewKit`
holds the views and the ACP helpers, and re-exports `AgentViewKitStyle`.
`AgentViewKitStyle` holds only the shared look and links only EditorKit. An
app links `AgentViewKit`:

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

  /// The text of the composer.
  @State private var draft = AttributedString()

  var body: some View {
    // The session views send the prompts, the cancel, and the answers to the
    // permission and elicitation cards through the two models. The host gives
    // only the work that no model does: a terminal sign-in runner with
    // `.terminalAuthRunner(_:)`, and a reconnect with `.agentReconnect(_:)`.
    // The composer slot shows in the bottom bar below the state banner and
    // the scroll-to-bottom pill, in one glass container, and the
    // conversation scrolls under the bar. The thread view gives the
    // slot its two models and its focus scope, so that the VoiceOver focus
    // goes from an answered card back to the composer. With no slot, the
    // thread view shows a default composer.
    AgentThreadView(session: session, connection: connection) {
      // The questions of the session, such as a permission request. The
      // thread view shows no card. The deck takes no space while no question
      // waits and no notice of a withdrawn question shows.
      RequestDeck(session: session)
      PromptInputView(text: $draft) {}
    }
  }
}
```

The kit speaks ACP protocol version 2 only
([`Docs/decisions/acp-version.md`](Docs/decisions/acp-version.md)). The agents
that are available today (Claude Code, Codex, and Gemini CLI) speak version 1.
The kit refuses such an agent: `initialize` throws, and no session opens.
The first agent of the kit is FoundationModelsACPAgent, which speaks version
2. The demo app runs FoundationModelsACPAgent in its process, and its UI
tests use an in-memory agent that speaks version 2.

### An agent in this process

`InProcessAgent.makeConnection(serving:)` of FoundationModelsACPClient runs an
ACP agent in the process of the app. It pairs an `InMemoryTransport`, serves
the agent on one end with an `AgentSideConnection`, and connects a new
`ConnectionModel` on the other end. The two sides speak the real ACP wire.
The helper returns the connection model and keeps no state of its own. The kit
does not import an agent: the app gives it. With FoundationModelsACPAgent, the
app composes the agent with the public `ComposedAgent`, binds it with
`ComposedAgent.agent(boundTo:)`, and calls
`ComposedAgent.waitForConnectionTeardown()` after the connection closes.
To stop the agent, call `ConnectionModel.disconnect()`: the model stops the read
of its end of the pair, the pair then ends the input of the agent side, and the
agent stops. When the agent closes its connection first,
`ConnectionModel.state` becomes `.disconnected`.

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
  /// With FoundationModelsACPAgent, its public `ComposedAgent` gives the
  /// agent in three steps:
  ///
  /// ```swift
  /// // 1. Compose the agent one time, before the connection opens.
  /// let composed = try await ComposedAgent.compose(
  ///   name: try DotfolderName("my-host"), workingDirectory: projectDirectory,
  ///   home: .makeCustom(synced: syncedFolder, local: localFolder))
  /// // 2. Bind the agent to the agent side of the connection.
  /// let (connection, session) = try await InProcessQuickStart.start(cwd: cwd) { agentConnection in
  ///   composed.agent(boundTo: agentConnection)
  /// }
  /// // 3. Close the connection. Then let the agent close its sessions.
  /// await connection.disconnect()
  /// await composed.waitForConnectionTeardown()
  /// ```
  ///
  /// The kit does not import FoundationModelsACPAgent, so this example is a
  /// comment and the snippet build does not compile it.
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

Three things belong in the host. Call `GrammarBundle.register()` at launch, so
that the first code block does not wait for the grammars to load. Put a
`RequestDeck(connection:)` at the window level, so that the questions of a
connection request, such as a sign-in form of `auth/login`, show. Add the
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
      VStack(spacing: 0) {
        // The questions of a connection request, such as a sign-in form. The
        // deck takes no space while no question waits and no notice of a
        // withdrawn question shows.
        RequestDeck(connection: connection)
        // The window shows an open session of the connection model.
        if let session = connection.openSessions.first {
          HostThread(connection: connection, session: session)
        } else {
          ContentUnavailableView("No session", systemImage: "bubble.left.and.bubble.right")
        }
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
      // Below each row: when the entry started, and how long it took.
      .transcriptTiming()
      // The Markdown that shows while the transcript has no entry.
      .conversationEmptyState(
        title: "Welcome",
        markdown: """
          Ask the agent about your **code**:

          - Explain a file
          - Fix a failed test
          """)
  }
}
```

### The empty state

While the transcript has no entry, `ConversationView` shows a
`ConversationEmptyState`. To show your own Markdown text in the drop-in
`AgentThreadView`, use `.conversationEmptyState(title:systemImage:markdown:)`,
as in the example above. The text shows the same as the text of an agent
message: headings, lists, links, and code blocks. The EditorKit theme applies.
The title and the symbol are optional. When you set no content, the empty
state shows "No Messages".

To show the text in a `ConversationView` with a custom slot, give
`ConversationEmptyState(title:systemImage:markdown:)` to the `emptyState`
closure.

### Message timing

The time of an entry is a decorator. The message views do not show a time by
themselves. `UserMessageView`, `AssistantMessageView` and `MessageHeader` take
no date. Add `.transcriptTiming()` to an `AgentThreadView` or a
`ConversationView`, as in the example above. Each row then shows an
`EntryTimingView` below the entry: when the entry started, and how long it
took when it ended. The default is no time.

To put the time below one view of your own, such as an override, use
`.entryTiming(_:)` with the transcript entry:

```swift
MyToolCallRow(call: call)
  .entryTiming(.toolCall(call))
```

The times come from the `EntryTiming` of each entry of the client model
(`startedAt`, `endedAt`, and `duration`). The kit records no time. A replayed
entry has no time, so its row shows none. A thought shows "Thought for N
seconds" from the `duration` of the thought entry. The system formatters write
the times in the locale of the environment, and VoiceOver reads the time after
the entry. The font comes from the EditorKit theme, and the spacing comes from
the EditorKit `EditorStyle`. There is no time for the work of a prompt: the
client model does not put the entries in groups by prompt.

### The theme

The kit has one theme: the EditorKit `Theme`. Set it with `.editorTheme(_:)`.
Every color of the kit views comes from this theme. This includes the accent,
the status colors, the diff colors, the terminal palette, and the bars. The
EditorKit views draw no background of their own, so the content behind them
shows through. Each font also comes from this theme, one face for each
EditorKit font role: `uiFace` for the chrome, `displayFace` for the prose,
the composer and the text fields, and `codeFace` for the code. The chrome
draws its captions and headlines in the `uiFace` too, so a theme that names a
UI font family changes all of the chrome. When you set no
theme, EditorKit gives `SystemTheme`. `SystemTheme` follows the system
appearance and the accent color of the user. EditorKit can also import a Zed,
VS Code, or tmTheme file.

The layout tokens of the kit come from the shared style of EditorKit,
`EditorStyle`: the spacing, the corner radius scale, the symbol weight, and the
density. Each rounded shape of the kit takes its radius from that scale. The
theme gives a style (`Theme.style`), and `.editorTheme(_:)` sets it. A
`.editorStyle(_:)` closer to the content sets a different style. The floating
glass is always `.regular`. The Clear and Tinted looks are system settings, so
a theme does not select the glass.

The cards of the kit draw no fill: a thin separator stroke
(`.inlineEdge(radius:)` of `EditorStyle`) marks the edge of a card. A host that
wants a fill behind the cards sets it with `.inlineFill(_:)`.

To import the theme modules, add the EditorKit products `EditorSwiftUI`,
`EditorTheme`, and `EditorStyle` to the host target.

```swift
// readme:compile HostTheme
import AgentViewKit
import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// Gives the kit views in `content` one theme.
struct ThemedHost<Content: View>: View {
  /// The kit views to theme.
  @ViewBuilder let content: Content

  var body: some View {
    content
      // The layout tokens of the kit: spacing, radii, symbol weight, density.
      // The theme gives a style too. This one is closer to the content, so it
      // wins.
      .editorStyle(.default)
      // Every color and each font of the kit views come from this
      // EditorKit theme. `.system` follows the system appearance.
      .editorTheme(.system)
  }
}
```

### The attachment inspector

A tap on an attachment or an image in `AgentThreadView` shows the file in an
inspector. By default (`.builtIn`), the thread view shows the file in its own
trailing `.inspector`. Do not use the default in a window that has its own
inspector, such as a `NavigationSplitView` with an inspector: two inspectors in
one window can make AppKit stop the app.

Such a window applies `.agentAttachmentInspector(.host($selection))` one time
at its root. Then the thread views apply no inspector. A tap writes an
`AgentAttachmentSelection` to the binding: the file and the `sessionId` of the
thread that the user pressed. Thus more than one thread view can share one
binding. Show the file in your inspector, for example with
`AttachmentInspector`, whose actions Open, Reveal in Finder, Share, Save and
Quick Look work in each mode. Each action is an EditorKit command of the scope
of the attachment, so the context menu and the command palette run it too. A
write of `nil` closes the inspector.

```swift
// readme:compile HostInspector
import AgentViewKit
import FoundationModelsACPClient
import SwiftUI

/// A window with a sidebar, a thread, and its own inspector.
struct InspectorWindow: View {
  let connection: ConnectionModel
  let session: SessionModel

  /// The file that the inspector of the window shows, or `nil`.
  @State private var selection: AgentAttachmentSelection?

  var body: some View {
    NavigationSplitView {
      Text("Threads")
    } detail: {
      AgentThreadView(session: session, connection: connection)
    }
    .inspector(isPresented: isInspectorPresented) {
      if let selection {
        AttachmentInspector(selection.attachment)
      }
    }
    // One time at the root of the window: the thread views apply no
    // inspector, and a tap writes the file and its session to `selection`.
    .agentAttachmentInspector(.host($selection))
  }

  /// `true` while the window has a selection. The close of the inspector
  /// writes `false`, and that removes the selection.
  private var isInspectorPresented: Binding<Bool> {
    Binding(get: { selection != nil }, set: { if !$0 { selection = nil } })
  }
}
```

### Override modifiers

`AgentThreadView(session:connection:)` switches over `TranscriptEntry` inside.
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

- `AgentThreadView`: the drop-in view. It binds a `SessionModel`, and the `ConnectionModel` when the host gives it, and shows the whole surface except the request cards. Its top bar (`.safeAreaBar(edge: .top)`) holds, from the top, the `AgentInfoHeader` and the `AgentConnectionBanner` when the host gives the connection model, the `SessionNoticeBanner` and the `SessionStreamBanner`, with no background. The `AgentInfoHeader` floats on `.regular` glass, the same as the conversation header in Messages; the banners are content with no glass. Give `sessionTitle:` to show an "Agent › Session" breadcrumb in the header, and `headerContextMenuPath:` (a `FocusPath` of a host command scope) to show the EditorKit context menu of that path on a right click on the header, with no command that is not available there. The conversation scrolls under the bar and the toolbar, with the system scroll edge effect. AppKit makes that effect as tall as the whole stack of bars above the list, so the rows under the stack are washed out, and the fade is gradual only near the top of the list. Its bottom bar (`.safeAreaBar(edge: .bottom)`) holds, from the top, the `StateBanner`, the sign-in card when the agent asks for a sign-in and the composer slot, in one glass container with the scroll-to-bottom pill; the conversation scrolls under the bar. The pill floats over the list above the bar and takes no space in it, so the bottom inset of the list does not change when the pill shows. The banner and the sign-in card have no glass surface, and the conversation scrolls under them, so their buttons keep the glass styles. The default slot is a `DefaultThreadComposer`. Put a `RequestDeck` in the slot above the composer, or next to the view.
- `ConversationView`: the container with auto-scroll, the scroll-to-bottom pill, the empty state with Markdown text from the host, and the `StateBanner` in its own bottom bar, which the list scrolls under.
- `MessageActions`: copy, copy thread, export, retry, and edit, in the message footer.
- `ThreadMinimapView`: the rail of the transcript entries, with the tool call status. A drag moves the thread.
- `StateBanner`: shows `requiresAction`, an idle session with a pending request, and a stop reason that needs attention, also the extension stop reasons.
- `SessionStreamBanner`: the replay marker, the partial-history note, the missed-updates banner with Reload, and the closed state.
- `SessionNoticeBanner`: one banner for each notice of the session model.
- `SessionListView`: the sessions of `ConnectionModel.sessions`, with cursor paging. When an open session that is not the `currentSession` has open requests, its row shows a `PendingRequestCountBadge` with the number of the requests, and the row label adds the count text, such as "2 open questions". The badge is visual only and is hidden from VoiceOver, so VoiceOver reads the count one time.

**Entry views**

- `UserMessageView` and `AssistantMessageView`: the content blocks of a message, with the footer slot.
- `CompactionEntryView`: marks a context compaction at its position, with its status and its summary.
- `UnknownItemView`: the collapsible raw view of an unknown entry or block.
- `ErrorView`: the card of an error entry, with its JSON-RPC code, its message, and its data.
- `ContentBlockView`: the block family: text, image, audio, resource link, resource, and unknown.

**Streaming content**

- `ResponseView`: the paragraph-split Markdown view on Textual, with the code block hook.
- `CodeBlockView`: a read-only EditorKit editor with copy, filename, and language.
- `MathView`: inline and block LaTeX.
- `ReasoningView`: the collapsible view of a thought entry.
- `ActivityIndicator` and `ShimmerView`: the in-progress effects.

**Agent activity**

- `ToolCallView`: title, kind icon, status, locations, raw input and output, and collapsible content.
- `TerminalView`: an agent-owned terminal with command, cwd, exit status, and ANSI output.
- `DiffView`: the per-file list with counts, accept or reject per hunk, and attach lines to the prompt, over the EditorKit diff view.
- `TaskListView`: the checklist of a plan entry, with priority and status.
- `ActivityTimeline`: thoughts, tool calls, terminals, and errors in transcript order.
- `SourcesView` and `InlineCitation`: the sources of a message and the citation pills in the text.
- `ContextUsageView`: the context usage meter from `SessionModel.usage`, with the cost.
- `AgentGraphView`: the multi-agent canvas. This view is not in v1.

**Infrastructure**

- `StreamingMarkdownBalancer`, `ScrollAnchorManager`, `ExpandedBlocksStore`: the balancer of open Markdown, the scroll anchors, and the expanded state of the blocks.
- `AgentCommands`: the kit verbs as EditorKit commands (`AgentCommandVerb`) with the default keymap (`AgentKeymap`). Each attachment chip, image, artifact file and attachment inspector is a scope (`agentAttachment:<id>`) with the attachment verbs Open, Reveal in Finder, Share, Save and Quick Look (`AgentAttachmentVerb`); the buttons of the inspector, the context menu and the palette run the same commands. The verbs are in five groups (`AgentCommandGroup`: `agent.compose`, `agent.control`, `agent.navigate`, `agent.clipboard`, `agent.attachment`). A host turns off a group with `.agentCommandGroups(off:)`, and then its verbs are not in the menus, the context menus or the palette, and their keys do nothing.
- `GrammarBundle`: the TextMate grammars of the languages that agents write most.

**Input**

- `PromptInputView`: the composer on EditorKit, with slash commands, `@file`, attachments, tool toggles, and the mic. Give the composer the prefix-completion routes of the host with one modifier, `.composerCompletions([PrefixCompletionRoute])` from EditorKit `EditorComplete`, on the thread view or on the composer: for example `@` to files, `^` to tasks, `#` to tags and `/` to commands. Typing a sigil lists the rows of its route in a popup at the caret, above the field. Return and Tab accept the selected row, as one entry of the window undo stack. A `/` route replaces the slash commands of the agent, and an `@` route replaces the `@file` references.
- `ConfigOptionsView`: the picker of `configOptions`, grouped by category.
- `SuggestionsView` and `SpeechInputButton`: the suggestion chips and the speech input.

**Human in the loop**

- `PermissionView`: a pending permission request of a `SessionModel`, with its options, its subject, and a comment field.
- `PermissionModePicker`: the `mode` config option as a segmented control.
- `RequestDeck`: the deck of the pending requests of a `SessionModel`, or of the request-scoped elicitations of a `ConnectionModel`. It is a component of its own, next to the thread view and the composer. When an elicitation request has an agent path or a source, its card shows who asks: the root label, the agent path and the source, for example "root › reviewer · runCode". A permission card shows no such line. Set the root label with the `elicitationRootAgentLabel` environment value. The default is "root". When the agent withdraws a request, the deck shows a notice above the cards, for example "Your name? was withdrawn: The run ended.", and VoiceOver reads the notice one time. The notice stays until the user presses its Dismiss button.

**Connections and authorization**

- `AgentConnectionBanner`: the banner of `ConnectionModel.state`.
- `AgentInfoHeader`: the name and the version of the agent from its `initialize` answer, and the session title from the host after a chevron. VoiceOver reads it as one header element, "Agent, Session".
- `AgentAuthView`: the auth methods of an ACP agent, with sign-out.
- `ConnectionsView`, `ConnectionRow`, `ConnectionStatusChip`: the MCP servers of a session, one row, and one status chip.
- `AuthorizationPresenter`: opens an authorization URL in `ASWebAuthenticationSession`.

**Elicitation**

- `ElicitationView`: the form of an elicitation request, with the `ElicitationFieldView` family and `ElicitationURLConsentView` for URL mode.

**Artifacts and attachments**

- `AttachmentView`, `AttachmentInspector`, `ArtifactView`, `CommandOutputView`, `LinkView`, `ImageView`, `AudioPlayerView`: the attachment chip, the Quick Look inspector, the artifact card, the command output, and the link, image, and audio blocks.

## The demo app

[`Examples/AgentViewKitDemo`](Examples/AgentViewKitDemo) is a macOS app with
two tabs:

- The ACP tab runs FoundationModelsACPAgent in the process of the app,
  through the package and with its live model
  (`ComposedAgent.compose(modelSource: .live)`). It shows the sessions of the
  agent in a sidebar, and shows the thread after the session binds. It starts
  no agent program and needs no sibling checkout. The live model downloads
  and loads the model of the agent profile at the first start.
- The Gallery tab shows recorded sessions of FoundationModelsACPAgent, so that
  you can see how the views look with real session data. It runs
  FoundationModelsACPAgent in the process of the app, through the package and
  with its stub model, over a temporary copy of
  [`Examples/AgentViewKitDemo/RecordedSessions/`](Examples/AgentViewKitDemo/RecordedSessions).
  It starts no agent program and needs no sibling checkout. It lists the
  sessions with `session/list`, and opens one with `session/resume`.
  The agent restores the session, and the views bind to its models. The
  recorded sessions do not have each entry kind and each state of the views,
  so the sidebar also lists the scripted sessions of the in-memory agent
  (`DemoGallery`) and the connection and sign-in states
  (`DemoConnectionState`). They show permission requests, form and URL
  elicitations, plans, compactions, notices, errors, attachments, the other
  stop reasons, and the sign-in and connection states. The popover of the
  Look button sets the EditorKit theme (`SystemTheme`, `DefaultTheme.light`,
  `DefaultTheme.dark`), the appearance, the increased contrast, the density,
  and the text size.

The launch arguments are in
[`Sources/DemoSupport/DemoLaunchOptions.swift`](Sources/DemoSupport/DemoLaunchOptions.swift):

- `--in-memory-agent`: the ACP tab runs the scripted in-memory agent in place of FoundationModelsACPAgent, so that no model loads. The UI tests use this argument.
- `--cwd <path>`: the working directory of each session of the ACP tab. The default is the home directory.
- `--tab <name>`: the tab that the window opens on, `acp` or `gallery`. The default is `acp`.

### Replace the recorded sessions

The recorded sessions come from the SWE-bench runs in
`../FoundationModelsACPAgent/bench/preds.<run>.transcripts/`, and from one
run of the stub model of the agent (the steps are in
[`RecordedSessions/README.md`](Examples/AgentViewKitDemo/RecordedSessions/README.md)).
They are replaced over time, and no test reads their content. To replace them:

1. Remove the directories in `Examples/AgentViewKitDemo/RecordedSessions/` that you replace.
2. Copy whole instance directories from `preds.<run>.transcripts/` into that directory, as they are. Do not trim or change a file.
3. Change the table in [`RecordedSessions/README.md`](Examples/AgentViewKitDemo/RecordedSessions/README.md).
4. Build the demo app again.

The Gallery tab copies the recordings to a temporary directory at each
start, and gives that copy to the agent in code as its transcript location
(`ComposedAgent.compose(transcriptLocation: .path(...))`). It writes no
configuration file. A restore thus never changes the files in the repository.

The demo UI tests are in
[`Examples/AgentViewKitDemo/Tests/`](Examples/AgentViewKitDemo/Tests). Run
them with `Scripts/test-examples.sh`. The script makes the Xcode project,
builds the app, and runs the UI tests. It needs Xcode, the `xcodeproj` gem,
and macOS UI Automation Mode. Without automation mode, the test runner waits
and gives no output. The UI test step holds the UI test lock that the
swissarmyhammer repositories share
(`~/Library/Caches/swissarmyhammer/ui-tests.lock`), so a UI test run of
Testudo or EditorKit and this one never bring an app to the front at the same
time. While another run holds the lock, the script waits and names the holder.

## Tests and gates

```bash
swift test                  # the unit tests, the hosted view tests, and the README snippets
Scripts/check-readme.sh     # the README gate
Scripts/test-examples.sh    # the demo UI tests
```

### The test rule

A test does not wait on a clock: no sleep, no poll, no time limit, and no
run of the run loop for a time. After a change on the main actor, a hosted
test calls `HostedViewHarness.render()` and reads the accessibility tree.
After a change that comes from asynchronous work, the test waits for its
event with `render(when:)` or `ObservationWait.until(_:)`, and then checks
the result with an expectation. A hosted test holds `HostedTestLock`, and a
wait has no time limit, so each hosted wait must be for an event that is
certain to come.

### Snapshot images

The snapshot tests make PNG images of the real views of the kit, with fixed
data and fixed dates, at two pixels for each point, in sRGB. Each view has
four images: light, dark, Reduce Transparency and Increase Contrast. The
reference images are in `Tests/AgentViewKitTests/Snapshots/__Snapshots__/`:

- `HostedSnapshotTests/`: each view in a hidden window
  (`ViewSnapshot.hostedPixels`). These images show the AppKit views, such as
  the list of the thread and the EditorKit editor. The cache of a window shows
  no glass.
- `GlassSnapshotTests/`: the glass parts in isolation, over text
  (`ViewSnapshot.renderedPixels`, with `ImageRenderer`). These images show a
  glass look. It can be different from the Liquid Glass that the system
  draws in a window.

When the look of a view changes, its test fails, and it writes
`<name>.actual.png` and `<name>.diff.png` to `.build/snapshots/<suite>/`.
The difference image shows each pixel that changed in magenta. The test also
attaches the two images.

To record the reference images again, run the tests in the record mode, and
then look at each image before the commit:

```bash
AVK_SNAPSHOT_RECORD=1 swift test --filter SnapshotTests
```

In the record mode, each snapshot test records an issue, so that a run with
the variable never passes.

### The README gate

`Scripts/extract-readme-snippets.sh` writes each `// readme:compile` block of
this file to `Examples/ReadmeSnippets/Snippets/<Name>.swift`. The
`ReadmeSnippetsTests` target compiles that directory on each `swift test`.
`Scripts/check-readme.sh` extracts the blocks again, fails when the result
differs from the committed files, and builds the target. When you change a
block, run the extraction script and commit the result.

## Design documents

- [`plan.md`](plan.md): the architecture, the component inventory, and the decisions.
- [`Docs/decisions/`](Docs/decisions): one file for each decision, such as the ACP version, the diff renderer, the connection states, and the scope and the binding rule of the ACP client kit.
