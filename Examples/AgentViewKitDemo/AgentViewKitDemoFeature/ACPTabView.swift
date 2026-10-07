import AgentViewKit
import FoundationModelsACPClient
import SwiftUI

/// The ACP tab of the demo app.
///
/// The tab starts the agent of the launch options with ``DemoAgent``, and
/// shows the `ConnectionModel` and the selected `SessionModel` of the client
/// with the kit session views:
///
/// - a sidebar with the ``SessionListView`` of the connection model,
/// - the ``AgentThreadView`` of the selected session, the
///   ``ContextUsageView`` of the session, and a ``PromptInputView``,
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
/// the connection model. The tab gives the `terminalAuthRunner` and the
/// `agentReconnect` environment values of ``DemoAgent`` to the kit views, so
/// that a terminal sign-in can run, and the Reconnect button connects again
/// and opens that session. A Reconnect from the thread of an open session
/// (after a prompt failed with `-32000`) opens a new session, because the
/// reconnect closed the old one.
///
/// A sign-in with an `agent` method sets the `authState` of the connection
/// model to `.authenticated`. The tab observes that state and tells
/// ``DemoAgent`` to retry the kept `session/new`.
struct ACPTabView: View {
  /// The state of the tab.
  private enum Phase {
    /// The agent starts, and the first session opens.
    case starting

    /// The start failed with the error.
    case failed(any Error)

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

  /// The launch options of the app.
  let options: DemoLaunchOptions

  /// The state of the tab.
  @State private var phase = Phase.starting

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
    .terminalAuthRunner(agent?.terminalAuthRunner)
    .agentReconnect(reconnectAction)
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
    case .signingIn(let agent), .running(let agent, _): agent
    }
  }

  /// The Reconnect closure of the sign-in card, or `nil` when the agent cannot
  /// make a new transport.
  private var reconnectAction: AgentReconnect? {
    guard let agent, agent.canReconnect else { return nil }
    return { await reconnect(agent) }
  }

  // MARK: - Start

  /// Starts the agent and opens the first session. The tab starts the agent
  /// one time only.
  private func start() async {
    guard case .starting = phase else { return }
    do {
      let agent = try await DemoAgent.makeConnected(options: options)
      await openFirstSession(on: agent)
    } catch {
      phase = .failed(error)
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
  /// The agent keeps a request that fails with `-32000`, so that a reconnect
  /// after a terminal sign-in opens and selects the session.
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
    phase = .running(agent, session)
    newSessionFailure = nil
  }

  /// Connects to the agent again after a terminal sign-in.
  ///
  /// The agent then retries the operation that failed with `-32000`. When it
  /// kept no operation, for example after a prompt of the open session
  /// failed with `-32000`, the agent opens a new session, because the
  /// reconnect closed the old one. The tab selects that session.
  ///
  /// - Parameter agent: The agent.
  private func reconnect(_ agent: DemoAgent) async {
    do {
      try await agent.reconnect { session in select(session, on: agent) }
    } catch {
      await show(error, of: agent)
    }
  }

  /// Retries the operation that failed with `-32000` when the `authState`
  /// of the connection model becomes `.authenticated`.
  ///
  /// A sign-in with an `agent` method on the sign-in card sets that state.
  /// The agent runs its kept operation, for example the first `session/new`,
  /// and the tab selects the session. After a reconnect, the agent kept no
  /// operation, so the call does nothing.
  private func authStateDidChange() async {
    guard let agent, case .authenticated = agent.connection.authState else { return }
    do {
      try await agent.retryFailedOperation()
    } catch {
      await show(error, of: agent)
    }
  }

  /// Shows the failure of the first session, of a reconnect, or the `-32000`
  /// answer of the New Session button.
  ///
  /// A `-32000` answer shows the sign-in card. Each other failure stops the
  /// agent, because the tab then has no session to show.
  ///
  /// - Parameters:
  ///   - error: The error of the operation.
  ///   - agent: The agent.
  private func show(_ error: any Error, of agent: DemoAgent) async {
    guard !DemoAgent.isAuthenticationRequired(error) else {
      phase = .signingIn(agent)
      return
    }
    await agent.stop()
    phase = .failed(error)
  }

  /// Opens a new session and selects it.
  ///
  /// A `-32000` answer shows the sign-in card through ``show(_:of:)``, and a
  /// reconnect after a terminal sign-in opens the session. Each other failure
  /// keeps the selected session, and the sidebar shows the error.
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
    if case .running(let agent, _) = phase {
      sessionList(of: agent)
    } else {
      phaseView
    }
  }

  /// The session list of the connection model of an agent.
  ///
  /// The list resumes a selected session with `replayFrom: .start`, and the
  /// tab selects the session model that the resume gives. The New Session
  /// button opens a session. The list shows each action only when the agent
  /// sends its capability.
  ///
  /// - Parameter agent: The running agent.
  /// - Returns: The sidebar.
  private func sessionList(of agent: DemoAgent) -> some View {
    VStack(spacing: 0) {
      SessionListView(
        connection: agent.connection,
        cwd: agent.workingDirectory,
        onOpen: { session in phase = .running(agent, session) },
        onNewSession: {
          Task { await openNewSession(on: agent) }
        }
      )
      if let newSessionFailure {
        failureLabel(newSessionFailure, identifier: Self.newSessionFailureIdentifier)
      }
    }
  }

  // MARK: - Detail

  /// The selected session, the sign-in card, or the state of the start.
  @ViewBuilder private var detail: some View {
    switch phase {
    case .running(let agent, let session):
      thread(of: session, on: agent)
    case .signingIn(let agent):
      AgentAuthView(connection: agent.connection)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    case .starting, .failed:
      phaseView
    }
  }

  /// The transcript of a session with its usage and the composer.
  ///
  /// The thread view shows the connection banner and the agent header of
  /// the connection model, and closes the session when it goes away. The
  /// composer reads the two models from the environment.
  ///
  /// - Parameters:
  ///   - session: The selected session model.
  ///   - agent: The running agent.
  /// - Returns: The detail view.
  private func thread(of session: SessionModel, on agent: DemoAgent) -> some View {
    VStack(spacing: 0) {
      AgentThreadView(session: session, connection: agent.connection)
      .messageFooter { entry in MessageActions(entry: entry) }
      ContextUsageView(session: session)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal)
      PromptInputView(text: $draft) {}
        .padding()
    }
    .environment(\.sessionModel, session)
    .environment(\.connectionModel, agent.connection)
    .id(ObjectIdentifier(session))
  }

  /// The view of a start that has not given a session.
  @ViewBuilder private var phaseView: some View {
    switch phase {
    case .starting:
      ProgressView("Starting \(options.agentName)")
        .accessibilityIdentifier(Self.startingIdentifier)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let error):
      failureLabel(error, identifier: Self.failureIdentifier)
    case .signingIn, .running:
      EmptyView()
    }
  }

  /// The text of a failed request.
  ///
  /// - Parameters:
  ///   - error: The error of the request.
  ///   - identifier: The accessibility identifier of the text.
  /// - Returns: The label.
  private func failureLabel(_ error: any Error, identifier: String) -> some View {
    Label(String(describing: error), systemImage: "exclamationmark.triangle")
      .foregroundStyle(.red)
      .padding()
      .accessibilityIdentifier(identifier)
  }

  // MARK: - Toolbar

  /// The configuration menu of the selected session, the button that stops
  /// the agent, and the settings button, while the agent runs.
  ///
  /// The stop calls `ConnectionModel.disconnect()` through
  /// `DemoAgent.stop()`: the state of the connection model becomes
  /// `.disconnected`, and the thread view shows the connection banner.
  @ViewBuilder private var toolbarItems: some View {
    if case .running(let agent, let session) = phase {
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
    if case .running(let agent, let session) = phase {
      ACPSettingsSheet(connection: agent.connection, session: session, agentCommand: options.agentCommand)
    }
  }
}
