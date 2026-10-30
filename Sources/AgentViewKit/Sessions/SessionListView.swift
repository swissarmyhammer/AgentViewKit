import EditorCommands
import EditorCommandsUI
import EditorCore
import EditorStyle
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
/// `refreshSessions(cwd:)` again. The search field filters the rows of the
/// model, and sends no request.
///
/// The view reads each capability flag of the model when it draws:
///
/// - When `canListSessions` is false, the view shows no list and no Refresh
///   button, and sends no `session/list`.
/// - When `canResumeSessions` is false, a row does not open.
/// - When `canDeleteSessions` is false, a row has no delete button.
///
/// The rows are an ``AgentRowList``, not a SwiftUI `List`: the selected row
/// is the row whose scope has the focus, the arrow keys and Esc move the
/// selection through the `nav.*` commands of EditorKit, and a jump session of
/// the host labels each row. Return or a double click on a row opens it, and
/// so does the press action of the row for VoiceOver. VoiceOver reads a row as
/// one element: the title, the time and the open questions of its session.
///
/// To open a row, the view calls `resumeSession(_:)` with the `cwd` and the full
/// `additionalDirectories` of the `SessionInfo` of the row and
/// `replayFrom: .start`, and gives the model of the session to `onOpen`. ACP
/// v2 requires the same `cwd` and the full list of additional directories
/// again on a resume. When the row has no list or an empty list, the request
/// has no `additionalDirectories`. A delete calls `deleteSession(_:)`, and the
/// row goes away when the model removes the item. When a call fails, the view
/// shows the error of the call, and the list keeps the values of the model.
public struct SessionListView: View {
  /// The accessibility identifier of the text view of the search field.
  public static let searchIdentifier = "session-list-search"

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

  /// The space between the header, the failure message, and the list, in
  /// points.
  static let sectionSpacing: CGFloat = 0

  /// The segment kind of the scope of the list of sessions.
  static let listKind = "sessionList"

  /// The segment kind of the scope of a row.
  static let rowKind = "session"

  /// The segment of the scope of the "Load More" row.
  static let loadMoreSegment = FocusSegment(kind: "sessionListLoadMore")

  /// The segment of the scope of the list of sessions of a connection model.
  ///
  /// Two pickers in one window, such as the two lists of the Gallery tab of
  /// the demo app, show two connection models, so each list has its own path.
  ///
  /// - Parameter connection: The connection model of the picker.
  /// - Returns: The segment `sessionList:<id>`, with the identity of the
  ///   connection model as its id.
  static func listSegment(for connection: ConnectionModel) -> FocusSegment {
    FocusSegment(kind: listKind, id: String(UInt(bitPattern: ObjectIdentifier(connection))))
  }

  /// The segment of the scope of the row of a session.
  ///
  /// - Parameter id: The identifier of the session.
  /// - Returns: The segment `session:<id>`.
  static func rowSegment(for id: SessionId) -> FocusSegment {
    FocusSegment(kind: rowKind, id: id.rawValue)
  }

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

  /// The style that gives the space of the header, of the failure message
  /// and of the rows (^rgsq3k4).
  @Environment(\.editorStyle) private var editorStyle

  /// The model of the search text that filters the rows.
  @State private var search = OwnModelSlot(editable: true)

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
  ///
  /// The search field is a kit one-line field (``AgentOneLineField``). The
  /// search sends no request, so Return in the field submits nothing.
  private var header: some View {
    HStack {
      AgentOneLineField(
        model: searchModel, identifier: Self.searchIdentifier,
        placeholder: String(localized: "Search", bundle: .module))
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
    .padding(editorStyle.spacing.l)
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

  /// The rows and the "Load More" row, in an ``AgentRowList``. A row opens
  /// only when the agent serves `session/resume`.
  private var list: some View {
    AgentRowList(
      Self.sessions(in: connection.sessions, matching: searchModel.text), id: \.sessionId.rawValue,
      scope: AgentRowListScope(list: Self.listSegment(for: connection), rowKind: Self.rowKind),
      onOpen: openAction
    ) { info in
      row(for: info)
    } footer: {
      if connection.hasMoreSessions {
        loadMoreButton
      }
    }
    .scrollContentMargins(\.tile.margin)
  }

  /// The action that opens the session of a row, or `nil` when the agent
  /// does not serve `session/resume`.
  private var openAction: ((SessionInfo) -> Void)? {
    guard connection.canResumeSessions else { return nil }
    return { open($0) }
  }

  /// The "Load More" row: a button in a scope of its own, so a `nav.*` move
  /// and a jump reach it, and a landed jump presses it. It is in the list,
  /// which routes its keys as it routes the keys of a row, so the Up Arrow
  /// goes back to the rows.
  private var loadMoreButton: some View {
    Button(String(localized: "Load More", bundle: .module), systemImage: Self.loadMoreSymbol) {
      start(Self.loadMoreIdentifier) { await perform { try await connection.loadMoreSessions() } }
    }
    .accessibilityIdentifier(Self.loadMoreIdentifier)
    .commandScope(segment: Self.loadMoreSegment)
    .targetable(true)
  }

  /// The failure message of the last call.
  ///
  /// - Parameter message: The error message.
  /// - Returns: The message text.
  private func failure(_ message: String) -> some View {
    Text(message)
      .font(editorTheme.font(for: .ui, style: .caption))
      .foregroundStyle(editorTheme.severityError)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, editorStyle.spacing.l)
      .accessibilityIdentifier(Self.failureIdentifier)
  }

  /// The row of one session.
  ///
  /// The summary is the one accessibility element of the row that tells the
  /// session. For an open session that is not ``currentSession`` and has
  /// pending requests, its label is the label of the session and the open
  /// question text, such as "Second, 2 open questions". The
  /// ``PendingRequestCountBadge`` is visual only and is hidden from
  /// accessibility, so VoiceOver reads the count one time. When the agent
  /// serves `session/resume`, the summary is a button whose press action
  /// opens the session, as Return and a double click on the row do.
  ///
  /// - Parameter info: The session to show.
  /// - Returns: The summary, the ``PendingRequestCountBadge`` of an open
  ///   session that is not ``currentSession``, and, when the agent serves
  ///   `session/delete`, the delete button.
  private func row(for info: SessionInfo) -> some View {
    let otherSession = otherOpenSession(for: info.sessionId)
    let openQuestions = Self.openQuestionsLabel(of: otherSession)
    return HStack {
      summary(of: info)
        .accessibilityElement(children: .combine)
        .accessibilityLabel { label in
          label
          if let openQuestions {
            Text(openQuestions)
          }
        }
        .modifier(SessionRowOpenAction(open: connection.canResumeSessions ? { open(info) } : nil))
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

  /// The title and the relative time of the last activity of a session.
  ///
  /// - Parameter info: The session to show.
  /// - Returns: The two lines of text.
  private func summary(of info: SessionInfo) -> some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.xs) {
      Text(Self.title(of: info))
        .lineLimit(1)
      if let updatedAt = info.updatedAt.flatMap(ISO8601Time.date(from:)) {
        Text(updatedAt, format: .relative(presentation: .named))
          .font(editorTheme.font(for: .ui, style: .caption))
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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

  /// Opens the session of a row: starts its resume, and reports the press of
  /// the row.
  ///
  /// - Parameter info: The session to open.
  private func open(_ info: SessionInfo) {
    start(Self.rowIdentifier(for: info.sessionId)) { await resume(info) }
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

  /// The model of the search text. The first read makes an empty model.
  private var searchModel: EditorModel {
    search.model(text: "")
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

/// The press action of the summary of a session row, when the row opens.
///
/// A row that opens is a button for VoiceOver: its press action opens the
/// session, as Return and a double click on the row do. A row of an agent
/// that does not serve `session/resume` is plain text.
private struct SessionRowOpenAction: ViewModifier {
  /// The action that opens the session of the row, or `nil` for a row that
  /// does not open.
  let open: (() -> Void)?

  @ViewBuilder func body(content: Self.Content) -> some View {
    if let open {
      content
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open() }
    } else {
      content
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
