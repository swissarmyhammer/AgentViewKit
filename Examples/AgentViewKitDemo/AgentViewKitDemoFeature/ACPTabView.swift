import AgentViewKit
import AgentViewKitACP
import SwiftUI

/// The ACP tab of the demo app.
///
/// The tab starts the agent of the launch options (``ACPDemoSession``) and
/// shows:
///
/// - a sidebar with the ``SessionListView`` of the agent,
/// - the ``StateBanner``, the ``AgentThreadView``, the ``TaskListView``, and
///   the ``ContextUsageView`` of the bound thread,
/// - a ``PromptInputView``, whose default accessory row has the
///   ``PermissionModePicker``,
/// - a toolbar with the ``ConfigOptionsView`` menu and a button that opens
///   the settings sheet (``ACPSettingsSheet``).
struct ACPTabView: View {
  /// The accessibility identifier of the settings button.
  static let settingsButtonIdentifier = "demo-acp-settings"

  /// The accessibility identifier of the text that shows a failed
  /// connection.
  static let failureIdentifier = "demo-acp-failure"

  /// The accessibility identifier of the progress view of a connection.
  static let connectingIdentifier = "demo-acp-connecting"

  /// The launch options of the app.
  let options: DemoLaunchOptions

  /// The ACP session of the tab.
  @State private var session: ACPDemoSession

  /// The text of the composer.
  @State private var draft = AttributedString()

  /// Whether the settings sheet shows.
  @State private var showsSettings = false

  /// Makes the tab.
  ///
  /// - Parameter options: The launch options of the app.
  init(options: DemoLaunchOptions) {
    self.options = options
    _session = State(initialValue: ACPDemoSession(options: options))
  }

  var body: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(min: 200, ideal: 240)
    } detail: {
      detail
    }
    .toolbar {
      ToolbarItemGroup {
        ConfigOptionsView(options: session.thread.configOptions)
        Button("Settings", systemImage: "gearshape") {
          showsSettings = true
        }
        .accessibilityIdentifier(Self.settingsButtonIdentifier)
      }
    }
    .sheet(isPresented: $showsSettings) {
      ACPSettingsSheet(session: session, agentCommand: options.agentCommand)
        .environment(\.agentThread, session.thread)
        .environment(\.threadActions, session.actions)
        .connectionStore(session.connectionStore)
    }
    .environment(\.agentThread, session.thread)
    // The actions are `nil` before the first session binds. A view that
    // reads no actions does nothing (Docs/decisions/required-thread-actions.md).
    .environment(\.threadActions, session.actions)
    .connectionStore(session.connectionStore)
    .task {
      await session.start(options: options)
    }
  }

  // MARK: - Sidebar

  /// The session list of the agent, or the connection state.
  @ViewBuilder private var sidebar: some View {
    if let list = session.sessionList {
      sessionList(list)
    } else {
      phaseView
    }
  }

  /// The session list of `list`.
  ///
  /// A selection resumes the session, and the New Session button opens a
  /// session. The list offers a delete only when the agent sends the
  /// `session/delete` capability.
  ///
  /// - Parameter list: The session pages of the agent.
  /// - Returns: The list view.
  private func sessionList(_ list: ACPSessionList) -> some View {
    let session = session
    var onDelete: ((SessionID) async throws -> Void)?
    if session.canDeleteSessions {
      onDelete = { id in try await list.delete(id) }
    }
    return SessionListView(
      provider: list,
      onSelect: { id in
        Task { await session.selectSession(id) }
      },
      onNewSession: {
        Task { await session.newSession() }
      },
      onDelete: onDelete
    )
    .id(ObjectIdentifier(list))
  }

  // MARK: - Detail

  /// The bound thread with its status views and the composer, or the
  /// connection state before the first session binds.
  @ViewBuilder private var detail: some View {
    if let actions = session.actions {
      boundThread(actions: actions)
        .navigationTitle(session.agentName)
    } else {
      phaseView
        .navigationTitle(session.agentName)
    }
  }

  /// The bound thread with its status views and the composer.
  ///
  /// - Parameter actions: The actions of the bound session.
  /// - Returns: The detail view of the thread.
  private func boundThread(actions: ACPThreadActions) -> some View {
    let thread = session.thread
    return VStack(spacing: 0) {
      if case .failed = session.phase {
        phaseView
      }
      StateBanner(state: thread.state)
      AgentThreadView(thread: thread, actions: actions)
      TaskListView(plans: thread.plans)
      ContextUsageView(usage: thread.usage)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal)
      PromptInputView(text: $draft) {}
        .padding()
    }
    .id(ObjectIdentifier(thread))
  }

  /// The view of a connection that is not ready.
  @ViewBuilder private var phaseView: some View {
    switch session.phase {
    case .idle, .connecting:
      ProgressView("Connecting to \(session.agentName)")
        .accessibilityIdentifier(Self.connectingIdentifier)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let message):
      Label(message, systemImage: "exclamationmark.triangle")
        .foregroundStyle(.red)
        .padding()
        .accessibilityIdentifier(Self.failureIdentifier)
    case .ready:
      EmptyView()
    }
  }
}
