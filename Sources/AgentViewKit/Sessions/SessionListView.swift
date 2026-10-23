import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The session picker of an agent: the session list of a `ConnectionModel`
/// (plan.md §3.3, §3.8 "Session picker", "Capabilities", §9 A).
///
/// The view shows `ConnectionModel.sessions` and calls the methods of the
/// model. It keeps no copy of the list and no page cursor. When the view
/// shows, and when `canListSessions` changes, it calls
/// `refreshSessions(cwd:)`. Each row shows the title and the relative time of
/// the last activity of one `SessionInfo`. A `session_info_update` of an open
/// session changes its item in the model, so the row changes with no other
/// step. When `hasMoreSessions` is true, the last row is a "Load More" button
/// that calls `loadMoreSessions()`. The Refresh button calls
/// `refreshSessions(cwd:)` again. The search field, a one-line EditorKit
/// field, filters the rows of the model, and sends no request.
///
/// The view reads each capability flag of the model when it draws:
///
/// - When `canListSessions` is false, the view shows no list and no Refresh
///   button, and sends no `session/list`.
/// - When `canResumeSessions` is false, a row is not a button.
/// - When `canDeleteSessions` is false, a row has no delete button.
///
/// A press on a row calls `resumeSession(_:)` with the `cwd` and the full
/// `additionalDirectories` of the `SessionInfo` of the row and
/// `replayFrom: .start`, and gives the model of the session to `onOpen`. ACP
/// v2 requires the same `cwd` and the full list of additional directories
/// again on a resume. When the row has no list or an empty list, the request
/// has no `additionalDirectories`. A delete calls `deleteSession(_:)`, and the
/// row goes away when the model removes the item. When a call fails, the view
/// shows the error of the call, and the list keeps the values of the model.
public struct SessionListView: View {
  /// The accessibility identifier of the search field.
  public static let searchIdentifier = "session-list-search"

  /// The placeholder and the accessibility label of the search field.
  static var searchPrompt: String { String(localized: "Search", bundle: .module) }

  /// The accessibility identifier of the "Load More" row.
  public static let loadMoreIdentifier = "session-list-load-more"

  /// The symbol of the "Load More" row.
  static let loadMoreSymbol = SharedSymbol.loadMore

  /// The accessibility identifier of the Refresh button.
  public static let refreshIdentifier = "session-list-refresh"

  /// The accessibility identifier of the new session button.
  public static let newSessionIdentifier = "session-list-new"

  /// The accessibility identifier of the failure message.
  public static let failureIdentifier = "session-list-failure"

  /// The accessibility identifier of the empty state.
  public static let emptyIdentifier = "session-list-empty"

  /// The accessibility identifier of the state of an agent that does not
  /// list its sessions.
  public static let unavailableIdentifier = "session-list-unavailable"

  /// The text before the session id in the identifier of a row.
  public static let rowIdentifierPrefix = "session-row-"

  /// The text before the session id in the identifier of a delete button.
  public static let deleteIdentifierPrefix = "session-delete-"

  /// The title of a session that has no title.
  public static let untitledTitle = "Untitled Session"

  /// The space between the title and the time of a row, in points.
  static let rowLineSpacing: CGFloat = 2

  /// The space between the header, the failure message, and the list, in
  /// points.
  static let sectionSpacing: CGFloat = 0

  /// The accessibility identifier of the row of a session.
  ///
  /// - Parameter id: The identifier of the session.
  /// - Returns: The identifier, such as `session-row-s1`.
  public static func rowIdentifier(for id: SessionId) -> String {
    AccessibilityIdentifier.make(prefix: rowIdentifierPrefix, value: id.rawValue)
  }

  /// The accessibility identifier of the delete button of a session.
  ///
  /// - Parameter id: The identifier of the session.
  /// - Returns: The identifier, such as `session-delete-s1`.
  public static func deleteIdentifier(for id: SessionId) -> String {
    AccessibilityIdentifier.make(prefix: deleteIdentifierPrefix, value: id.rawValue)
  }

  /// The connection model whose session list the view shows.
  let connection: ConnectionModel

  /// The working directory that filters the sessions, or `nil` for each
  /// session of the agent.
  let cwd: AbsolutePath?

  /// The session that shows on screen, or `nil`. Its row has no
  /// ``PendingRequestCountBadge`` and no open question text in its label.
  let currentSession: SessionId?

  /// The action that gets the model of a resumed session.
  let onOpen: (SessionModel) -> Void

  /// The new session action, or `nil` for no button.
  let onNewSession: (() -> Void)?

  /// The EditorKit theme that gives the error color of the failure message.
  @Environment(\.editorTheme) private var editorTheme

  /// The search text that filters the rows.
  @State private var query = ""

  /// The error message of the last call of the view, or `nil`.
  @State private var failureMessage: String?

  /// The report that gets the result of each call of the view, or `nil`.
  @Environment(\.sessionListCallReport) private var reportCall

  /// The report that gets the identifier of each button whose call the view
  /// starts, or `nil`.
  @Environment(\.sessionListPressReport) private var reportPress

  /// Makes the session picker of a connection model.
  ///
  /// - Parameters:
  ///   - connection: The connection model whose session list the view
  ///     shows.
  ///   - cwd: The absolute path of the working directory that filters the
  ///     sessions, or `nil` for each session of the agent.
  ///   - currentSession: The session that shows on screen, or `nil`. Its
  ///     row has no count of open questions.
  ///   - onOpen: The action that gets the model of a resumed session.
  ///   - onNewSession: The new session action, or `nil` for no button.
  public init(
    connection: ConnectionModel,
    cwd: AbsolutePath? = nil,
    currentSession: SessionId? = nil,
    onOpen: @escaping (SessionModel) -> Void,
    onNewSession: (() -> Void)? = nil
  ) {
    self.connection = connection
    self.cwd = cwd
    self.currentSession = currentSession
    self.onOpen = onOpen
    self.onNewSession = onNewSession
  }

  public var body: some View {
    VStack(spacing: Self.sectionSpacing) {
      header
      if let failureMessage {
        failure(failureMessage)
      }
      content
    }
    .task(id: connection.canListSessions) { await refresh() }
  }

  /// The search field, the Refresh button and the new session button.
  private var header: some View {
    HStack {
      OneLineTextField(text: $query, prompt: Self.searchPrompt, identifier: Self.searchIdentifier)
      if connection.canListSessions {
        Button {
          start(Self.refreshIdentifier) { await refresh() }
        } label: {
          Label(String(localized: "Refresh", bundle: .module), systemImage: SharedSymbol.reload)
            .labelStyle(.iconOnly)
        }
        .help(String(localized: "Refresh", bundle: .module))
        .accessibilityIdentifier(Self.refreshIdentifier)
      }
      if let onNewSession {
        Button(action: onNewSession) {
          Label(
            String(localized: "New Session", bundle: .module), systemImage: SharedSymbol.newSession
          )
            .labelStyle(.iconOnly)
        }
        .help(String(localized: "New Session", bundle: .module))
        .accessibilityIdentifier(Self.newSessionIdentifier)
      }
    }
    .padding()
  }

  /// The list, the empty state, or the state of an agent that does not list
  /// its sessions.
  @ViewBuilder private var content: some View {
    if !connection.canListSessions {
      ContentUnavailableView(
        String(localized: "Session List Not Available", bundle: .module),
        systemImage: SharedSymbol.sessionList,
        description: Text("The agent does not list its sessions.", bundle: .module)
      )
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(Self.unavailableIdentifier)
    } else if connection.sessions.isEmpty {
      ContentUnavailableView(
        String(localized: "No Sessions", bundle: .module),
        systemImage: SharedSymbol.conversation,
        description: Text("The sessions of the agent show here.", bundle: .module)
      )
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(Self.emptyIdentifier)
    } else {
      list
    }
  }

  /// The rows and the "Load More" row.
  private var list: some View {
    List {
      ForEach(Self.sessions(in: connection.sessions, matching: query), id: \.sessionId) { info in
        row(for: info)
      }
      if connection.hasMoreSessions {
        Button(String(localized: "Load More", bundle: .module), systemImage: Self.loadMoreSymbol) {
          start(Self.loadMoreIdentifier) { await perform { try await connection.loadMoreSessions() } }
        }
        .accessibilityIdentifier(Self.loadMoreIdentifier)
      }
    }
  }

  /// The failure message of the last call.
  ///
  /// - Parameter message: The error message.
  /// - Returns: The message text.
  private func failure(_ message: String) -> some View {
    Text(message)
      .font(.caption)
      .foregroundStyle(editorTheme.severityError)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal)
      .accessibilityIdentifier(Self.failureIdentifier)
  }

  /// The row of one session.
  ///
  /// The resume control is the one accessibility element of the row that
  /// tells the session. For an open session that is not ``currentSession``
  /// and has pending requests, its label is the label of the session and the
  /// open question text, such as "Second, 2 open questions". The
  /// ``PendingRequestCountBadge`` is visual only and is hidden from
  /// accessibility, so VoiceOver reads the count one time.
  ///
  /// - Parameter info: The session to show.
  /// - Returns: The resume control, the ``PendingRequestCountBadge`` of an
  ///   open session that is not ``currentSession``, and, when the agent
  ///   serves `session/delete`, the delete button.
  private func row(for info: SessionInfo) -> some View {
    let otherSession = otherOpenSession(for: info.sessionId)
    let openQuestions = Self.openQuestionsLabel(of: otherSession)
    return HStack {
      resumeControl(for: info)
        .accessibilityLabel { label in
          label
          if let openQuestions {
            Text(openQuestions)
          }
        }
        .accessibilityIdentifier(Self.rowIdentifier(for: info.sessionId))
      if let otherSession {
        PendingRequestCountBadge(session: otherSession)
      }
      if connection.canDeleteSessions {
        Button(role: .destructive) {
          start(Self.deleteIdentifier(for: info.sessionId)) {
            await perform { try await connection.deleteSession(info.sessionId) }
          }
        } label: {
          Label(String(localized: "Delete", bundle: .module), systemImage: SharedSymbol.delete)
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .help(String(localized: "Delete", bundle: .module))
        .accessibilityIdentifier(Self.deleteIdentifier(for: info.sessionId))
      }
    }
  }

  /// The title and time of a session: a resume button when the agent serves
  /// `session/resume`, else plain text.
  ///
  /// - Parameter info: The session to show.
  /// - Returns: The control.
  @ViewBuilder private func resumeControl(for info: SessionInfo) -> some View {
    if connection.canResumeSessions {
      Button {
        start(Self.rowIdentifier(for: info.sessionId)) { await resume(info) }
      } label: {
        summary(of: info)
      }
      .buttonStyle(.plain)
    } else {
      summary(of: info)
        .accessibilityElement(children: .combine)
    }
  }

  /// The title and the relative time of the last activity of a session.
  ///
  /// - Parameter info: The session to show.
  /// - Returns: The two lines of text.
  private func summary(of info: SessionInfo) -> some View {
    VStack(alignment: .leading, spacing: Self.rowLineSpacing) {
      Text(Self.title(of: info))
        .lineLimit(1)
      if let updatedAt = info.updatedAt.flatMap(ISO8601Time.date(from:)) {
        Text(updatedAt, format: .relative(presentation: .named))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }

  /// Calls `refreshSessions(cwd:)` when the agent lists its sessions.
  ///
  /// When the agent does not list its sessions, the view sends nothing, and
  /// it gives `nil` to the ``SwiftUI/EnvironmentValues/sessionListCallReport``
  /// value in the same step.
  private func refresh() async {
    guard connection.canListSessions else {
      reportCall?(nil)
      return
    }
    await perform { try await connection.refreshSessions(cwd: cwd) }
  }

  /// Resumes a session with all its retained history, and gives its model
  /// to ``onOpen``.
  ///
  /// - Parameter info: The session to resume.
  private func resume(_ info: SessionInfo) async {
    let request = ResumeSessionRequest.makeAgentViewKitRequest(
      sessionId: info.sessionId,
      cwd: info.cwd,
      additionalDirectories: info.additionalDirectories ?? [],
      replayFrom: .start(ReplayFromStart()))
    await perform { onOpen(try await connection.resumeSession(request)) }
  }

  /// Starts the call of a button in a task.
  ///
  /// The view gives `identifier` to the
  /// ``SwiftUI/EnvironmentValues/sessionListPressReport`` value in the same
  /// step, before it starts the task.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the pressed button.
  ///   - call: The call that the task runs.
  private func start(_ identifier: String, _ call: @escaping @MainActor () async -> Void) {
    reportPress?(identifier)
    Task { await call() }
  }

  /// Runs one call of the model, and keeps its error message for the view.
  ///
  /// A call that succeeds removes the last message. The view gives the
  /// result of the call to the
  /// ``SwiftUI/EnvironmentValues/sessionListCallReport`` value in the same
  /// step as it keeps the message.
  ///
  /// - Parameter call: The call of the model.
  private func perform(_ call: () async throws -> Void) async {
    let message: String?
    do {
      try await call()
      message = nil
    } catch {
      message = error.localizedDescription
    }
    failureMessage = message
    reportCall?(message)
  }

  /// The open model of a session that is not ``currentSession``.
  ///
  /// The call reads `ConnectionModel.session(for:)`. A session that is not
  /// open has no model.
  ///
  /// - Parameter id: The id of the session.
  /// - Returns: The model, or `nil` for the current session and for a
  ///   session that is not open.
  private func otherOpenSession(for id: SessionId) -> SessionModel? {
    guard id != currentSession else { return nil }
    return connection.session(for: id)
  }

  /// The text that the label of a row adds for the open questions of its
  /// session.
  ///
  /// - Parameter session: The open model of the session, or `nil`.
  /// - Returns: ``PendingRequestCountBadge/openQuestionsLabel(count:)``, or
  ///   `nil` when there is no model or the model has no pending request.
  private static func openQuestionsLabel(of session: SessionModel?) -> String? {
    guard let count = session?.pendingRequests.count, count > 0 else { return nil }
    return PendingRequestCountBadge.openQuestionsLabel(count: count)
  }

  /// The title of a session, or ``untitledTitle``.
  ///
  /// - Parameter info: The session.
  /// - Returns: The title. A title of only white space gives
  ///   ``untitledTitle``.
  private static func title(of info: SessionInfo) -> String {
    guard let title = info.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return untitledTitle
    }
    return title
  }

  /// The sessions whose title or working directory contains `query`.
  ///
  /// The comparison ignores case and diacritics. An empty query, or a query
  /// of only white space, keeps each session.
  ///
  /// - Parameters:
  ///   - sessions: The session list of the model.
  ///   - query: The search text.
  /// - Returns: The sessions that match, in list order.
  private static func sessions(in sessions: [SessionInfo], matching query: String) -> [SessionInfo] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return sessions }
    return sessions.filter { info in
      [info.title ?? "", info.cwd.rawValue].contains { $0.localizedStandardContains(needle) }
    }
  }
}

extension EnvironmentValues {
  /// The ``ObservationReport`` that gets the result of each call of the
  /// nearest ``SessionListView``, or `nil`.
  ///
  /// The view calls the report when a call of the connection model ends, in
  /// the same step as it keeps the error message: `nil` for a call that
  /// succeeds, the error message for a call that fails. A refresh that the
  /// view skips, because the agent does not list its sessions, also gives
  /// `nil`. The view keeps the message in its own state, so a test waits for
  /// the report before it reads the failure message.
  @Entry var sessionListCallReport: ObservationReport<String?>? = nil

  /// The ``ObservationReport`` that gets the accessibility identifier of each
  /// button of the nearest ``SessionListView`` whose call the view starts, or
  /// `nil`.
  ///
  /// The view calls the report in the same step as the press, before it
  /// starts the task of the call: the Refresh button, the "Load More" row, a
  /// resume row, and a delete button.
  @Entry var sessionListPressReport: ObservationReport<String>? = nil
}

#Preview("Sessions") {
  SessionListView(connection: .previewSample) { _ in }
}
