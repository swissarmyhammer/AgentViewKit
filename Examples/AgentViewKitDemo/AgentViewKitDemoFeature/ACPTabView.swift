import AgentViewKit
import FoundationModelsACPClient
import SwiftUI

/// The ACP tab of the demo app.
///
/// The tab starts the agent of the launch options in the app process with
/// ``DemoAgent/makeInProcess(options:environment:)``:
/// FoundationModelsACPAgent with the live model, or the in-memory demo agent
/// for `--in-memory-agent`. It shows
/// the `ConnectionModel` and the selected `SessionModel` of the client with
/// the kit session views:
///
/// - a sidebar with the ``SessionListView`` of the connection model,
/// - the ``AgentThreadView`` of the selected session, the
///   ``ContextUsageView`` of the session, the ``RequestDeck`` of the
///   session, and a ``PromptInputView``, under the ``RequestDeck`` of the
///   connection model,
/// - a toolbar with the ``ConfigOptionsView`` menu, a button that stops the
///   agent, and a button that opens the settings sheet
///   (``ACPSettingsSheet``).
///
/// The tab holds the two models and nothing that they hold. Each view reads
/// the connection state, the sessions, the auth methods, the auth state and
/// the capability flags from the models directly.
///
/// When the agent answers a `session/new` request (the first session or the
/// New Session button) with `-32000`, the tab shows the ``AgentAuthView`` of
/// the connection model. A sign-in with an `agent` method sets the
/// `authState` of the connection model to `.authenticated`. The tab observes
/// that state and tells ``DemoAgent`` to retry the kept `session/new`. The
/// agent runs in the app process, so the tab gives no terminal auth runner
/// and no reconnect to the kit views.
struct ACPTabView: View, DemoStartingTab {
  /// The content of the tab after the start.
  private enum Content {
    /// The agent runs, and asks for a sign-in before it opens a session.
    case signingIn(DemoAgent)

    /// The agent runs, and the tab shows the selected session.
    case running(DemoAgent, SessionModel)
  }

  /// The accessibility identifier of the settings button.
  static let settingsButtonIdentifier = "demo-acp-settings"

  /// The accessibility identifier of the button that stops the agent.
  static let stopAgentButtonIdentifier = "demo-acp-stop-agent"

  /// The accessibility identifier of the text that shows a failed start.
  static let failureIdentifier = "demo-acp-failure"

  /// The accessibility identifier of the text that shows a failed
  /// `session/new` request of the New Session button.
  static let newSessionFailureIdentifier = "demo-acp-new-session-failure"

  /// The accessibility identifier of the progress view of the start.
  static let startingIdentifier = "demo-acp-starting"

  /// The minimum width of the sidebar column.
  static let sidebarMinimumWidth: CGFloat = 200

  /// The ideal width of the sidebar column.
  static let sidebarIdealWidth: CGFloat = 240

  /// The title of the empty state of a new session.
  static let welcomeTitle = "Welcome to the AgentViewKit demo"

  /// The Markdown text of the empty state of a new session.
  static let welcomeMarkdown = """
    Send a prompt below to start the conversation. The agent can:

    - answer with **Markdown**, math, and code blocks
    - run tool calls and ask for your permission

    See the [AgentViewKit README](https://github.com/swissarmyhammer/AgentViewKit).
    """

  /// The launch options of the app.
  let options: DemoLaunchOptions

  /// The state of the tab. The agent starts, and the first session opens.
  @State private var phase = DemoStartPhase<Content>.starting

  /// The error of the last `session/new` request of the New Session button,
  /// or `nil`. The connection model does not record this error.
  @State private var newSessionFailure: (any Error)?

  /// The text of the composer.
  @State private var draft = AttributedString()

  /// Whether the settings sheet shows.
  @State private var showsSettings = false

  /// Makes the tab.
  ///
  /// - Parameter options: The launch options of the app.
  init(options: DemoLaunchOptions) {
    self.options = options
  }

  /// The text of the progress view of the start.
  var startingText: String { "Starting \(options.agentName)" }

  var body: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(min: Self.sidebarMinimumWidth, ideal: Self.sidebarIdealWidth)
    } detail: {
      detail
        .navigationTitle(options.agentName)
    }
    .toolbar {
      ToolbarItemGroup {
        toolbarItems
      }
    }
    .sheet(isPresented: $showsSettings) {
      settingsSheet
    }
    .task {
      await start()
    }
    .task(id: agent?.connection.authState) {
      await authStateDidChange()
    }
  }

  /// The agent of the phase, or `nil` before the start or after a failed
  /// start.
  private var agent: DemoAgent? {
    switch phase {
    case .starting, .failed: nil
    case .started(.signingIn(let agent)), .started(.running(let agent, _)): agent
    }
  }

  // MARK: - Start

  /// Starts the agent and opens the first session. The tab starts the agent
  /// one time only.
  private func start() async {
    await DemoStartPhase.start($phase) {
      let agent = try await DemoAgent.makeInProcess(options: options)
      await openFirstSession(on: agent)
    }
  }

  /// Opens the first session of a connected agent. Each failure shows through
  /// ``show(_:of:)``.
  ///
  /// - Parameter agent: The connected agent.
  private func openFirstSession(on agent: DemoAgent) async {
    await openSession(on: agent) { error in await show(error, of: agent) }
  }

  /// Opens a session with ``DemoAgent/openSession(onOpen:)`` and selects it.
  ///
  /// The agent keeps a request that fails with `-32000`, so that the retry
  /// after a sign-in opens and selects the session.
  ///
  /// - Parameters:
  ///   - agent: The connected agent.
  ///   - failure: Shows the error of a failed request.
  private func openSession(on agent: DemoAgent, failure: (any Error) async -> Void) async {
    do {
      try await agent.openSession { session in select(session, on: agent) }
    } catch {
      await failure(error)
    }
  }

  /// Shows a session that the agent opened, and clears the failure of the
  /// New Session button.
  ///
  /// - Parameters:
  ///   - session: The open session model.
  ///   - agent: The agent that opened it.
  private func select(_ session: SessionModel, on agent: DemoAgent) {
    phase = .started(.running(agent, session))
    newSessionFailure = nil
  }

  /// Retries the operation that failed with `-32000` when the `authState`
  /// of the connection model becomes `.authenticated`.
  ///
  /// A sign-in with an `agent` method on the sign-in card sets that state.
  /// The agent runs its kept operation, for example the first `session/new`,
  /// and the tab selects the session. When the agent kept no operation, the
  /// call does nothing.
  private func authStateDidChange() async {
    guard let agent, case .authenticated = agent.connection.authState else { return }
    do {
      try await agent.retryFailedOperation()
    } catch {
      await show(error, of: agent)
    }
  }

  /// Shows the failure of the first session, of a retry after a sign-in, or
  /// the `-32000` answer of the New Session button.
  ///
  /// A `-32000` answer shows the sign-in card. Each other failure stops the
  /// agent, because the tab then has no session to show.
  ///
  /// - Parameters:
  ///   - error: The error of the operation.
  ///   - agent: The agent.
  private func show(_ error: any Error, of agent: DemoAgent) async {
    guard !DemoAgent.isAuthenticationRequired(error) else {
      phase = .started(.signingIn(agent))
      return
    }
    await agent.stop()
    phase = .failed(error)
  }

  /// Opens a new session and selects it.
  ///
  /// A `-32000` answer shows the sign-in card through ``show(_:of:)``, and
  /// the retry after a sign-in opens the session. Each other failure keeps
  /// the selected session, and the sidebar shows the error.
  ///
  /// - Parameter agent: The running agent.
  private func openNewSession(on agent: DemoAgent) async {
    await openSession(on: agent) { error in
      guard !DemoAgent.isAuthenticationRequired(error) else {
        await show(error, of: agent)
        return
      }
      newSessionFailure = error
    }
  }

  // MARK: - Sidebar

  /// The session list of the connection model, or the state of the start.
  @ViewBuilder private var sidebar: some View {
    if case .started(.running(let agent, let session)) = phase {
      sessionList(of: agent, showing: session)
    } else {
      DemoStartView(phase: phase, tab: self)
    }
  }

  /// The session list of the connection model of an agent.
  ///
  /// The list resumes a selected session with `replayFrom: .start`, and the
  /// tab selects the session model that the resume gives. The New Session
  /// button opens a session. The list shows each action only when the agent
  /// sends its capability.
  ///
  /// The list gets the id of the selected session as its current session.
  /// Thus the row of the session on screen shows no count of open requests.
  /// When the tab selects a different session, the phase changes, and the
  /// list gets the id of that session.
  ///
  /// - Parameters:
  ///   - agent: The running agent.
  ///   - session: The selected session, which the detail shows.
  /// - Returns: The sidebar.
  private func sessionList(of agent: DemoAgent, showing session: SessionModel) -> some View {
    VStack(spacing: 0) {
      SessionListView(
        connection: agent.connection,
        cwd: agent.workingDirectory,
        currentSession: session.sessionId,
        onOpen: { resumed in phase = .started(.running(agent, resumed)) },
        onNewSession: {
          Task { await openNewSession(on: agent) }
        }
      )
      if let newSessionFailure {
        DemoFailureLabel(error: newSessionFailure, identifier: Self.newSessionFailureIdentifier)
      }
    }
  }

  // MARK: - Detail

  /// The request deck of the connection model over the content of the detail.
  ///
  /// The deck shows the request-scoped elicitations of the connection model,
  /// such as a sign-in form of `auth/login`. It takes no space while no
  /// question waits.
  private var detail: some View {
    VStack(spacing: 0) {
      if let agent {
        RequestDeck(connection: agent.connection)
      }
      detailContent
    }
  }

  /// The selected session, the sign-in card, or the state of the start.
  @ViewBuilder private var detailContent: some View {
    switch phase {
    case .started(.running(let agent, let session)):
      thread(of: session, on: agent)
    case .started(.signingIn(let agent)):
      AgentAuthView(connection: agent.connection)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    case .starting, .failed:
      DemoStartView(phase: phase, tab: self)
    }
  }

  /// The transcript of a session with its usage and the composer.
  ///
  /// ``SessionThreadColumn`` shows the transcript and the usage, and gives
  /// the two models to the composer. A new session shows the welcome text.
  ///
  /// - Parameters:
  ///   - session: The selected session model.
  ///   - agent: The running agent.
  /// - Returns: The detail view.
  private func thread(of session: SessionModel, on agent: DemoAgent) -> some View {
    SessionThreadColumn(session: session, connection: agent.connection) {
      PromptInputView(text: $draft) {}
        .padding()
    }
    .conversationEmptyState(title: Self.welcomeTitle, markdown: Self.welcomeMarkdown)
  }

  // MARK: - Toolbar

  /// The configuration menu of the selected session, the button that stops
  /// the agent, and the settings button, while the agent runs.
  ///
  /// The stop calls `ConnectionModel.disconnect()` through
  /// `DemoAgent.stop()`: the state of the connection model becomes
  /// `.disconnected`, and the thread view shows the connection banner.
  @ViewBuilder private var toolbarItems: some View {
    if case .started(.running(let agent, let session)) = phase {
      ConfigOptionsView(session: session)
      Button("Stop Agent", systemImage: "stop.circle") {
        Task { await agent.stop() }
      }
      .accessibilityIdentifier(Self.stopAgentButtonIdentifier)
      Button("Settings", systemImage: "gearshape") {
        showsSettings = true
      }
      .accessibilityIdentifier(Self.settingsButtonIdentifier)
    }
  }

  /// The settings sheet, with the models of the running agent.
  @ViewBuilder private var settingsSheet: some View {
    if case .started(.running(let agent, let session)) = phase {
      ACPSettingsSheet(connection: agent.connection, session: session)
    }
  }
}
