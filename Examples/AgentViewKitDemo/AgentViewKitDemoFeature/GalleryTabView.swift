import AgentViewKit
import Foundation
import FoundationModelsACPClient
import SwiftUI

/// The Gallery tab of the demo app: the kit views over recorded sessions of
/// FoundationModelsACPAgent, to judge how the views look with real session
/// data.
///
/// The app bundle holds the recorded sessions in the `RecordedSessions`
/// directory. The tab copies them to a temporary ``RecordedSessionsStage``,
/// and starts the agent program of the launch options over that copy with
/// ``DemoAgent/makeConnected(recordedSessions:agentCommand:)``. The tab
/// replays no session itself: FoundationModelsACPAgent restores each
/// session, and the views bind to its `ConnectionModel` and `SessionModel`.
///
/// - The sidebar is the ``SessionListView`` of the connection model. It
///   lists the sessions with `session/list`, and opens one with
///   `session/resume` and `replayFrom: .start`.
/// - The detail is the ``AgentThreadView`` of the open session, in a
///   ``SessionThreadColumn`` with no composer.
/// - The inspector holds the ``GalleryLookControls``: the EditorKit theme,
///   the appearance, the increased contrast, the density, and the text size.
struct GalleryTabView: View {
  /// The state of the tab.
  private enum Phase {
    /// The tab copies the recordings and starts the agent.
    case starting

    /// The start failed with the error.
    case failed(any Error)

    /// The agent runs over the copy of the recordings.
    case running(DemoAgent)
  }

  /// The error of a start that finds no recordings in the app bundle.
  enum StartError: LocalizedError {
    /// The app bundle has no `RecordedSessions` directory.
    case missingRecordings

    /// The text of the error.
    var errorDescription: String? {
      "The app bundle has no \(GalleryTabView.recordingsResourceName) directory."
    }
  }

  /// The name of the directory of the recorded sessions in the app bundle.
  /// The error text of ``StartError`` reads it outside the main actor.
  nonisolated static let recordingsResourceName = "RecordedSessions"

  /// The accessibility identifier of the text that shows a failed start.
  static let failureIdentifier = "demo-gallery-failure"

  /// The accessibility identifier of the progress view of the start.
  static let startingIdentifier = "demo-gallery-starting"

  /// The accessibility identifier of the button that shows the look
  /// controls.
  static let lookButtonIdentifier = "demo-gallery-look"

  /// The symbol of the button that shows the look controls.
  static let lookSymbol = "paintpalette"

  /// The symbol of the state with no open session.
  static let noSessionSymbol = "text.bubble"

  /// The title of the tab.
  static let title = "Gallery"

  /// The minimum width of the inspector column.
  static let inspectorMinimumWidth: CGFloat = 260

  /// The ideal width of the inspector column.
  static let inspectorIdealWidth: CGFloat = 300

  /// The launch options of the app. The tab starts their agent program.
  let options: DemoLaunchOptions

  /// The state of the tab.
  @State private var phase = Phase.starting

  /// The open session, or `nil` before the first open.
  @State private var session: SessionModel?

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

  /// Copies the recordings to a new stage, and starts the agent over it.
  /// The tab starts the agent one time only.
  private func start() async {
    guard case .starting = phase else { return }
    do {
      let stage = try RecordedSessionsStage.make(copying: try Self.recordingsDirectory())
      phase = .running(try await DemoAgent.makeConnected(recordedSessions: stage, agentCommand: options.agentCommand))
    } catch {
      phase = .failed(error)
    }
  }

  /// The directory of the recorded sessions in the app bundle.
  ///
  /// - Returns: The directory.
  /// - Throws: ``StartError/missingRecordings`` when the bundle has no such
  ///   directory.
  private static func recordingsDirectory() throws -> URL {
    guard let directory = Bundle.main.url(forResource: recordingsResourceName, withExtension: nil) else {
      throw StartError.missingRecordings
    }
    return directory
  }

  // MARK: - Columns

  /// The session list of the connection model, or the state of the start.
  @ViewBuilder private var sidebar: some View {
    if case .running(let agent) = phase {
      SessionListView(
        connection: agent.connection,
        cwd: agent.workingDirectory,
        onOpen: { opened in session = opened }
      )
    } else {
      phaseView
    }
  }

  /// The open session, the state with no open session, or the state of the
  /// start.
  @ViewBuilder private var detail: some View {
    if case .running(let agent) = phase {
      if let session {
        SessionThreadColumn(session: session, connection: agent.connection) {}
      } else {
        ContentUnavailableView(
          "No Session Is Open",
          systemImage: Self.noSessionSymbol,
          description: Text("Select a recorded session in the list.")
        )
      }
    } else {
      phaseView
    }
  }

  /// The view of a start that has not given an agent.
  @ViewBuilder private var phaseView: some View {
    switch phase {
    case .starting:
      ProgressView("Starting the agent of the recorded sessions")
        .accessibilityIdentifier(Self.startingIdentifier)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let error):
      DemoFailureLabel(error: error, identifier: Self.failureIdentifier)
    case .running:
      EmptyView()
    }
  }
}
