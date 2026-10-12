import AgentViewKit
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The Gallery tab of the demo app: the kit views over recorded sessions of
/// FoundationModelsACPAgent and over scripted sessions, to judge how the
/// views look with session data.
///
/// The app bundle holds the recorded sessions in the `RecordedSessions`
/// directory. The tab copies them to a temporary ``RecordedSessionsStage``,
/// and starts the agent program of the launch options over that copy with
/// ``DemoAgent/makeConnected(recordedSessions:agentCommand:)``. The tab
/// replays no session itself: FoundationModelsACPAgent restores each
/// session, and the views bind to its `ConnectionModel` and `SessionModel`.
///
/// The recorded sessions do not have each entry kind and each state of the
/// kit views. The tab also starts ``InMemoryDemoACPAgent`` with the
/// ``InMemoryDemoScript/gallery`` script, which serves the sessions of
/// ``DemoGallery``, and shows the states of ``DemoConnectionState``.
///
/// - The sidebar has three sections. The first two are the
///   ``SessionListView`` of each connection model: the recorded sessions and
///   the scripted sessions. Each list opens a session with `session/resume`
///   and `replayFrom: .start`. The third section lists the connection and
///   sign-in states. A state starts its own agent, and the tab stops that
///   agent when the detail shows another session.
/// - The detail is the ``AgentThreadView`` of the open session, in a
///   ``SessionThreadColumn`` with no composer.
/// - The inspector holds the ``GalleryLookControls``: the EditorKit theme,
///   the appearance, the increased contrast, the density, and the text size.
struct GalleryTabView: View, DemoStartingTab {
  /// The agents of the tab after the start.
  private struct Sources {
    /// The agent of the recorded sessions.
    let recorded: DemoAgent

    /// The agent of the scripted sessions.
    let scripted: DemoAgent
  }

  /// A session that the detail shows.
  private struct OpenedSession {
    /// The session model.
    let session: SessionModel

    /// The connection model of the session.
    let connection: ConnectionModel

    /// The agent that the tab started for a connection state, or `nil` for a
    /// session of a list. The tab stops it when the detail shows another
    /// session.
    let stateAgent: DemoAgent?
  }

  /// The content of the detail after the start.
  private enum Detail {
    /// No session is open.
    case empty

    /// A session is open.
    case opened(OpenedSession)

    /// A connection state did not open.
    case failed(any Error)
  }

  /// The accessibility identifier of the text that shows a failed start.
  static let failureIdentifier = "demo-gallery-failure"

  /// The accessibility identifier of the progress view of the start.
  static let startingIdentifier = "demo-gallery-starting"

  /// The accessibility identifier of the text that shows a connection state
  /// that did not open.
  static let stateFailureIdentifier = "demo-gallery-state-failure"

  /// The start of the accessibility identifier of each row of the
  /// connection states.
  static let stateRowIdentifierPrefix = "demo-gallery-state-"

  /// The accessibility identifier of the button that shows the look
  /// controls.
  static let lookButtonIdentifier = "demo-gallery-look"

  /// The symbol of the button that shows the look controls.
  static let lookSymbol = "paintpalette"

  /// The symbol of the state with no open session.
  static let noSessionSymbol = "text.bubble"

  /// The title of the tab.
  static let title = "Gallery"

  /// The title of the section of the recorded sessions.
  static let recordedTitle = "Recorded Sessions"

  /// The title of the section of the scripted sessions.
  static let scriptedTitle = "Scripted Sessions"

  /// The title of the section of the connection states.
  static let statesTitle = "Connection States"

  /// The minimum width of the inspector column.
  static let inspectorMinimumWidth: CGFloat = 260

  /// The ideal width of the inspector column.
  static let inspectorIdealWidth: CGFloat = 300

  /// The launch options of the app. The tab starts their agent program.
  let options: DemoLaunchOptions

  /// The state of the tab. The tab copies the recordings and starts the two
  /// agents. The started tab holds the agents.
  @State private var phase = DemoStartPhase<Sources>.starting

  /// The content of the detail.
  @State private var detailContent = Detail.empty

  /// The look of the kit views.
  @State private var look = GalleryLook()

  /// Whether the inspector with the look controls shows.
  @State private var showsLookControls = true

  /// Makes the tab.
  ///
  /// - Parameter options: The launch options of the app.
  init(options: DemoLaunchOptions) {
    self.options = options
  }

  /// The text of the progress view of the start.
  var startingText: String { "Starting the agent of the recorded sessions" }

  var body: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(min: ACPTabView.sidebarMinimumWidth, ideal: ACPTabView.sidebarIdealWidth)
    } detail: {
      detail
        .navigationTitle(Self.title)
    }
    .galleryLook(look)
    .inspector(isPresented: $showsLookControls) {
      GalleryLookControls(look: $look)
        .inspectorColumnWidth(min: Self.inspectorMinimumWidth, ideal: Self.inspectorIdealWidth)
    }
    .toolbar {
      ToolbarItem {
        Button("Look", systemImage: Self.lookSymbol) {
          showsLookControls.toggle()
        }
        .accessibilityIdentifier(Self.lookButtonIdentifier)
      }
    }
    .task {
      await start()
    }
  }

  // MARK: - Start

  /// Copies the recordings of the app bundle to a new stage, and starts the
  /// two agents. The tab starts them one time only. A bundle with no
  /// recordings fails the start with
  /// ``RecordedSessionsStage/MissingRecordingsError``.
  private func start() async {
    await DemoStartPhase.start($phase) {
      phase = .started(try await makeSources())
    }
  }

  /// Starts the agent of the scripted sessions in this process, and the
  /// agent program of the launch options over a stage of the recordings.
  /// When the agent of the recordings does not start, the call stops the
  /// agent of the scripted sessions.
  ///
  /// - Returns: The two agents.
  /// - Throws: The error of the stage or of the start of an agent.
  private func makeSources() async throws -> Sources {
    let scripted = try await DemoAgent.makeInProcess(script: .gallery)
    do {
      let stage = try RecordedSessionsStage.make(copying: try RecordedSessionsStage.recordingsDirectory())
      let recorded = try await DemoAgent.makeConnected(recordedSessions: stage, agentCommand: options.agentCommand)
      return Sources(recorded: recorded, scripted: scripted)
    } catch {
      await scripted.stop()
      throw error
    }
  }

  // MARK: - Open

  /// Shows a session that a session list opened.
  ///
  /// - Parameters:
  ///   - session: The resumed session.
  ///   - agent: The agent of the list.
  private func show(_ session: SessionModel, of agent: DemoAgent) {
    Task {
      await replaceDetail(with: .opened(OpenedSession(session: session, connection: agent.connection, stateAgent: nil)))
    }
  }

  /// Starts the agent of a connection state, and shows its session.
  ///
  /// - Parameter state: The connection state.
  private func open(_ state: DemoConnectionState) async {
    do {
      let opened = try await state.open()
      await replaceDetail(
        with: .opened(OpenedSession(session: opened.session, connection: opened.agent.connection, stateAgent: opened.agent)))
    } catch {
      await replaceDetail(with: .failed(error))
    }
  }

  /// Shows new content in the detail, and stops the agent of the connection
  /// state that the detail showed before.
  ///
  /// - Parameter content: The new content of the detail.
  private func replaceDetail(with content: Detail) async {
    let previous = detailContent
    detailContent = content
    if case .opened(let opened) = previous, let agent = opened.stateAgent {
      await agent.stop()
    }
  }

  // MARK: - Columns

  /// The three sections of the started tab, or the state of the start.
  @ViewBuilder private var sidebar: some View {
    if case .started(let sources) = phase {
      VStack(alignment: .leading, spacing: 0) {
        section(Self.recordedTitle) {
          SessionListView(
            connection: sources.recorded.connection, cwd: sources.recorded.workingDirectory,
            onOpen: { show($0, of: sources.recorded) })
        }
        section(Self.scriptedTitle) {
          SessionListView(
            connection: sources.scripted.connection, cwd: sources.scripted.workingDirectory,
            onOpen: { show($0, of: sources.scripted) })
        }
        section(Self.statesTitle) {
          stateList
        }
      }
    } else {
      DemoStartView(phase: phase, tab: self)
    }
  }

  /// One section of the sidebar: a title over its content.
  ///
  /// - Parameters:
  ///   - title: The title of the section.
  ///   - content: The content of the section.
  /// - Returns: The section.
  private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(title)
        .font(.headline)
        .padding([.horizontal, .top])
        .accessibilityAddTraits(.isHeader)
      content()
    }
  }

  /// The list of the connection states. A press on a row opens the state.
  private var stateList: some View {
    List(DemoConnectionState.allCases, id: \.self) { state in
      Button(state.title) {
        Task { await open(state) }
      }
      .accessibilityIdentifier(Self.stateRowIdentifierPrefix + state.rawValue)
    }
  }

  /// The open session, the state with no open session, a state that did not
  /// open, or the state of the start.
  @ViewBuilder private var detail: some View {
    if case .started = phase {
      switch detailContent {
      case .opened(let opened):
        SessionThreadColumn(session: opened.session, connection: opened.connection) {}
      case .failed(let error):
        DemoFailureLabel(error: error, identifier: Self.stateFailureIdentifier)
      case .empty:
        ContentUnavailableView(
          "No Session Is Open",
          systemImage: Self.noSessionSymbol,
          description: Text("Select a session or a connection state in the list.")
        )
      }
    } else {
      DemoStartView(phase: phase, tab: self)
    }
  }
}
