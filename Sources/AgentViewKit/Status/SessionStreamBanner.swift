import EditorCommandsUI
import EditorStyle
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The banners of the stream state of a `SessionModel` (plan.md §3.2
/// "Stream state", §3.8 "Resume", "Missed updates", "Closed thread").
///
/// The body reads the stream state of the model directly, and keeps no copy
/// of it. The connection model changes that state, and the banners follow:
///
/// - While `isClosed` is true, one banner tells that the session is closed,
///   and no other banner shows.
/// - While `isReplaying` is true, a marker tells that the agent replays the
///   history.
/// - While `hasMissedUpdates` is true, a banner tells that the transcript can
///   lack updates. Its Reload button calls `ConnectionModel.resumeSession(_:)`
///   with `replayFrom: .start`. The button is disabled while the resume or
///   the replay runs. The banner goes away only when the model clears
///   `hasMissedUpdates`. A failed resume adds an error entry to the
///   transcript, and the banner then tells that the reload failed, with the
///   localized description of the error, as a failure. The Reload button
///   stays, so the user can reload again, and a new press shows the
///   missed-updates text again while the resume runs.
/// - When `history` is `.retained` and no replay runs, a note tells that the
///   history can be partial. The agent replays only the history that it
///   keeps, so the note never tells that the history is complete.
///
/// The Reload button shows only when the host gives the connection model and
/// the agent can resume sessions (`ConnectionModel.canResumeSessions`). The
/// `session/resume` request of the button sends the `cwd` and the full list
/// of `additionalDirectories` of the session model, because ACP v2 requires
/// the same values again on a resume. When the list is empty, the request
/// has no `additionalDirectories`. A model with no `cwd` is a model that no
/// `session/new` or `session/resume` request opened, and it shows no
/// Reload button.
///
/// The text of each banner has its own accessibility identifier, such as
/// ``missedUpdatesIdentifier``.
public struct SessionStreamBanner: View {
  /// The accessibility identifier of the text of the closed banner.
  public static let closedIdentifier = "session-stream-closed"

  /// The accessibility identifier of the text of the replay marker.
  public static let replayingIdentifier = "session-stream-replaying"

  /// The accessibility identifier of the text of the missed-updates banner.
  public static let missedUpdatesIdentifier = "session-stream-missed-updates"

  /// The accessibility identifier of the text of the reload-failed banner.
  public static let reloadFailedIdentifier = "session-stream-reload-failed"

  /// The accessibility identifier of the Reload button.
  public static let reloadIdentifier = "session-stream-reload"

  /// The symbol of the Reload button.
  static let reloadSymbol = SharedSymbol.reload

  /// The accessibility identifier of the text of the partial-history note.
  public static let partialHistoryIdentifier = "session-stream-partial-history"

  /// The session model whose stream state the banners show.
  let session: SessionModel

  /// The connection model that resumes the session, or `nil` for no Reload
  /// button.
  let connection: ConnectionModel?

  @Environment(\.editorStyle) private var editorStyle

  /// The report that gets the method of the resume that Reload starts, or
  /// `nil`.
  @Environment(\.requestStartReport) private var reportRequestStart

  /// The state of the reload that the Reload button starts.
  @State private var reloadPhase = ReloadPhase.idle

  /// Makes the banners of the stream state of a session model.
  ///
  /// - Parameters:
  ///   - session: The session model whose stream state the banners show.
  ///   - connection: The connection model that opened the session, or `nil`
  ///     when the host does not let the user reload the session.
  public init(session: SessionModel, connection: ConnectionModel?) {
    self.session = session
    self.connection = connection
  }

  /// One banner of the view.
  private struct Bar {
    /// The text of the banner.
    let message: StatusBar.Message

    /// The button of the banner, or `nil` for no button.
    let action: StatusBar.Action?
  }

  /// The state of the reload that the Reload button starts.
  private enum ReloadPhase: Equatable {
    /// No reload runs, and the last reload did not fail.
    case idle

    /// A reload runs.
    case reloading

    /// The last reload failed.
    ///
    /// - Parameter errorDescription: The localized description of its error.
    case failed(errorDescription: String)
  }

  public var body: some View {
    let bars = shownBars
    if !bars.isEmpty {
      VStack(spacing: editorStyle.tile.margin) {
        ForEach(bars, id: \.message.identifier) { bar in
          StatusBar(message: bar.message, action: bar.action)
        }
      }
      .statusBarActionStyle(AgentStatusBarActionStyle())
      .padding(editorStyle.tile.margin)
    }
  }

  /// The banners that the stream state of the model shows now, in order.
  private var shownBars: [Bar] {
    guard !session.isClosed else { return [Bar(message: Self.closedMessage, action: nil)] }
    let replaying = session.isReplaying
    let canReload = !replaying && reloadPhase != .reloading
    let rows: [(isShown: Bool, bar: Bar)] = [
      (replaying, Bar(message: Self.replayingMessage, action: nil)),
      (session.hasMissedUpdates, Bar(message: missedUpdatesBarMessage, action: makeReloadAction(isEnabled: canReload))),
      (isHistoryRetained && !replaying, Bar(message: Self.partialHistoryMessage, action: nil)),
    ]
    return rows.filter(\.isShown).map(\.bar)
  }

  /// The text of the banner of the missed updates: the reload-failed text
  /// after a failed reload, and otherwise the missed-updates text.
  private var missedUpdatesBarMessage: StatusBar.Message {
    guard case .failed(let errorDescription) = reloadPhase else { return Self.missedUpdatesMessage }
    return Self.makeReloadFailedMessage(errorDescription: errorDescription)
  }

  /// Whether the transcript of the model holds a replay of the retained
  /// history of the agent: `history` is `.retained`.
  private var isHistoryRetained: Bool {
    guard case .retained = session.history else { return false }
    return true
  }

  /// Makes the Reload button of the missed-updates banner.
  ///
  /// - Parameter isEnabled: Whether the button takes a press.
  /// - Returns: The button, or `nil` when the host gave no connection model,
  ///   the agent cannot resume sessions, or the session model has no `cwd`.
  private func makeReloadAction(isEnabled: Bool) -> StatusBar.Action? {
    guard let connection, connection.canResumeSessions, let cwd = session.cwd else { return nil }
    return StatusBar.Action(
      title: String(localized: "Reload", bundle: .module), systemImage: Self.reloadSymbol,
      identifier: Self.reloadIdentifier,
      isEnabled: isEnabled
    ) { [session, reportRequestStart, phase = $reloadPhase] in
      let request = ResumeSessionRequest.makeAgentViewKitRequest(
        sessionId: session.sessionId,
        cwd: cwd,
        additionalDirectories: session.additionalDirectories,
        replayFrom: .start(ReplayFromStart()))
      phase.wrappedValue = .reloading
      session.startRequest("session/resume", reporting: reportRequestStart) {
        try await Self.resume(request, on: connection, recordingIn: phase)
      }
    }
  }

  /// Sends the `session/resume` request of the Reload button, and records
  /// its outcome in `phase`.
  ///
  /// A success sets ``ReloadPhase/idle``. A failure sets
  /// ``ReloadPhase/failed(errorDescription:)`` with the localized
  /// description of the error, and throws the error again, so that the
  /// session model also adds an error entry to the transcript.
  ///
  /// - Parameters:
  ///   - request: The `session/resume` request.
  ///   - connection: The connection model that sends the request.
  ///   - phase: The state of the reload of the banner.
  /// - Throws: The error of the request.
  private static func resume(
    _ request: ResumeSessionRequest, on connection: ConnectionModel, recordingIn phase: Binding<ReloadPhase>
  ) async throws {
    do {
      _ = try await connection.resumeSession(request)
      phase.wrappedValue = .idle
    } catch {
      phase.wrappedValue = .failed(errorDescription: error.localizedDescription)
      throw error
    }
  }
}

extension SessionStreamBanner {
  /// The text of the closed banner.
  static let closedMessage = StatusBar.Message(
    title: String(localized: "The session is closed", bundle: .module),
    explanation: String(
      localized: "The agent sends no more updates. You can read the transcript.", bundle: .module),
    symbolName: SharedSymbol.closed,
    identifier: closedIdentifier)

  /// The text of the replay marker: work that goes on, so its symbol moves.
  static let replayingMessage = StatusBar.Message(
    title: String(localized: "Loading the history", bundle: .module),
    explanation: String(
      localized: "The agent sends the history of the session again.", bundle: .module),
    symbolName: SharedSymbol.replaying,
    identifier: replayingIdentifier, isOngoing: true)

  /// The text of the missed-updates banner: a state that needs care, so a
  /// warning, as on the stream banner of KanbanViewKit.
  static let missedUpdatesMessage = StatusBar.Message(
    title: String(localized: "Updates are missing", bundle: .module),
    explanation: String(
      localized: "The connection did not keep all updates of this session. Reload the history from the agent.",
      bundle: .module),
    symbolName: SharedSymbol.warning,
    identifier: missedUpdatesIdentifier, severity: .warning)

  /// Makes the text of the reload-failed banner: the transcript still lacks
  /// updates, because the last reload failed.
  ///
  /// - Parameter errorDescription: The localized description of the error of
  ///   the reload.
  /// - Returns: The text, a failure whose explanation tells the error.
  static func makeReloadFailedMessage(errorDescription: String) -> StatusBar.Message {
    StatusBar.Message(
      title: String(localized: "Updates are still missing", bundle: .module),
      explanation: String(localized: "The reload failed: \(errorDescription)", bundle: .module),
      symbolName: SharedSymbol.error,
      identifier: reloadFailedIdentifier, severity: .failure)
  }

  /// The text of the partial-history note.
  static let partialHistoryMessage = StatusBar.Message(
    title: String(localized: "The history can be partial", bundle: .module),
    explanation: String(
      localized: "The agent replayed only the history that it keeps. Older messages can be missing.",
      bundle: .module),
    symbolName: SharedSymbol.partialHistory,
    identifier: partialHistoryIdentifier)
}

#Preview("Stream state") {
  let connection = ConnectionModel.previewSample
  if let session = connection.openSessions.first {
    SessionStreamBanner(session: session, connection: connection)
  }
}
