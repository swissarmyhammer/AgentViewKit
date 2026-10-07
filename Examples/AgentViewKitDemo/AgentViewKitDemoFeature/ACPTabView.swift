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
/// the connection state, the sessions, the auth methods and the capability
/// flags from the models directly.
struct ACPTabView: View {
  /// The state of the tab.
  private enum Phase {
    /// The agent starts, and the first session opens.
    case starting

    /// The start failed with the error.
    case failed(any Error)

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
    .task {
      await start()
    }
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

  /// Opens the first session of a connected agent.
  ///
  /// A failure stops the agent, because the tab then has no session to show.
  ///
  /// - Parameter agent: The connected agent.
  private func openFirstSession(on agent: DemoAgent) async {
    do {
      phase = .running(agent, try await agent.openSession())
    } catch {
      await agent.stop()
      phase = .failed(error)
    }
  }

  /// Opens a new session and selects it. A failure keeps the selected
  /// session, and the sidebar shows the error.
  ///
  /// - Parameter agent: The running agent.
  private func openNewSession(on agent: DemoAgent) async {
    do {
      phase = .running(agent, try await agent.openSession())
      newSessionFailure = nil
    } catch {
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

  /// The selected session, or the state of the start.
  @ViewBuilder private var detail: some View {
    if case .running(let agent, let session) = phase {
      thread(of: session, on: agent)
    } else {
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
      AgentThreadView(
        session: session,
        connection: agent.connection,
        workingDirectory: agent.workingDirectory,
        // The session views send the prompts, the cancel, and the answers
        // through the two models. The logging actions get only the verbs
        // that no model has, such as a terminal sign-in.
        actions: LoggingThreadActions()
      )
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
    case .running:
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
  /// The stop is the in-process form of an agent that exits: the state of the
  /// connection model becomes `.disconnected`, and the thread view shows the
  /// connection banner.
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
