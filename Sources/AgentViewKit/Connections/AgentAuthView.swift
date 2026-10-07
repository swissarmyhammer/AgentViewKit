import FoundationModelsACP
import FoundationModelsACPClient
import OSLog
import SwiftUI

/// The card that signs the user in to an ACP agent (plan.md §9 E2, §12;
/// update.md §4.3 "Initialize and auth").
///
/// The card binds directly to a `ConnectionModel`. The body reads
/// `authMethods`, `authState` and `canLogout` of the model, and keeps no copy
/// of them:
///
/// - Each `agent` method of `authMethods` has a row with a Sign In button.
///   The button calls `ConnectionModel.login(_:)` with the id of the method.
/// - Each `terminal` method has a row with a Run button. The model has no
///   terminal auth runner, so the button calls
///   ``AgentThreadActions/runTerminalAuth(_:)`` of the `threadActions`
///   environment value, and never calls `login`. When the thread has the
///   record with the id ``TerminalRecord/authID(for:)`` of the method, the row
///   shows the record in a ``TerminalView`` with an input field. Each line
///   that the user types goes to
///   ``AgentThreadActions/writeTerminalLine(_:to:)``.
/// - A method type that the kit does not know has no row.
/// - While `authState` is `.authenticated`, the card shows no method row.
/// - While `authState` is `.failed` for an `auth/login` request that the
///   agent refused, the card shows the message of the error of the agent
///   under the rows.
/// - When `canLogout` is `true`, a Sign Out button calls
///   `ConnectionModel.logout(_:)`. Otherwise the button is not shown.
///
/// While a call runs, its button is disabled and shows a `ProgressView`. This
/// flag is view state. A failure that the model does not record, for example
/// a failed logout or a closed connection, goes to the log, and adds an error
/// entry to the transcript of the ``SwiftUI/EnvironmentValues/sessionModel``
/// environment value when the environment has one. A cancelled call records
/// nothing.
///
/// The host puts the card in its settings surface next to
/// ``ConnectionsView``. ``AgentThreadView`` shows the card when a request of
/// the session fails with the code `-32000` (authentication required). The
/// card finds terminal records in the `thread` argument, else in the
/// ``SwiftUI/EnvironmentValues/agentThread`` environment value. With no
/// thread, a terminal row shows no terminal.
public struct AgentAuthView: View {
  /// The accessibility identifier of the card.
  public static let identifier = "agent-auth"
  /// The accessibility identifier of the title.
  public static let titleIdentifier = "agent-auth-title"
  /// The start of the accessibility identifier of each method row.
  public static let rowIdentifierPrefix = "agent-auth-row-"
  /// The start of the accessibility identifier of each Sign In button.
  public static let signInIdentifierPrefix = "agent-auth-sign-in-"
  /// The start of the accessibility identifier of each Run button.
  public static let runIdentifierPrefix = "agent-auth-run-"
  /// The accessibility identifier of the text of a login that the agent
  /// refused.
  public static let loginErrorIdentifier = "agent-auth-login-error"
  /// The accessibility identifier of the Sign Out button.
  public static let signOutIdentifier = "agent-auth-sign-out"

  /// The symbol of the title.
  static let symbol = "person.badge.key"

  /// The log of the auth calls that fail.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "AgentAuthView")

  /// A call that the card runs, as the key of its progress.
  enum Operation: Hashable {
    /// The Sign In or Run call of the method with this id.
    case method(AuthMethodId)
    /// The Sign Out call.
    case signOut
  }

  /// A method that the card shows.
  enum Row: Identifiable {
    /// A method that the agent runs through `auth/login`.
    case agent(AuthMethodAgent)
    /// A method that the client runs as a separate process.
    case terminal(AuthMethodTerminal)

    /// The identifier of the method.
    var id: AuthMethodId {
      switch self {
      case .agent(let method): method.methodId
      case .terminal(let method): method.methodId
      }
    }

    /// The label of the method.
    var name: String {
      switch self {
      case .agent(let method): method.name
      case .terminal(let method): method.name
      }
    }

    /// The text that tells the user about the method, or `nil`.
    var description: String? {
      switch self {
      case .agent(let method): method.description
      case .terminal(let method): method.description
      }
    }
  }

  /// The connection model whose auth state the card shows.
  let connection: ConnectionModel
  /// The thread that the host gives, or `nil` to use the environment thread.
  let suppliedThread: AgentThread?

  /// The calls that run.
  @State private var running: Set<Operation> = []

  @Environment(\.threadActions) private var actions
  @Environment(\.agentThread) private var environmentThread
  @Environment(\.sessionModel) private var session
  @Environment(\.agentTheme) private var theme

  /// Makes the card.
  ///
  /// - Parameters:
  ///   - connection: The connection model of the agent. The card reads its
  ///     auth methods and its auth state, and calls its login and logout.
  ///   - thread: The thread that has the terminal records of the terminal
  ///     methods, or `nil` to use the environment thread.
  public init(connection: ConnectionModel, thread: AgentThread? = nil) {
    self.connection = connection
    self.suppliedThread = thread
  }

  // MARK: Identifiers

  /// The accessibility identifier of the row of `id`.
  ///
  /// - Parameter id: The identifier of the method.
  /// - Returns: `agent-auth-row-<id>`.
  public static func rowIdentifier(for id: AuthMethodId) -> String {
    AccessibilityIdentifier.make(prefix: rowIdentifierPrefix, value: id.rawValue)
  }

  /// The accessibility identifier of the Sign In button of `id`.
  ///
  /// - Parameter id: The identifier of the agent method.
  /// - Returns: `agent-auth-sign-in-<id>`.
  public static func signInIdentifier(for id: AuthMethodId) -> String {
    AccessibilityIdentifier.make(prefix: signInIdentifierPrefix, value: id.rawValue)
  }

  /// The accessibility identifier of the Run button of `id`.
  ///
  /// - Parameter id: The identifier of the terminal method.
  /// - Returns: `agent-auth-run-<id>`.
  public static func runIdentifier(for id: AuthMethodId) -> String {
    AccessibilityIdentifier.make(prefix: runIdentifierPrefix, value: id.rawValue)
  }

  // MARK: Model

  /// The rows of `methods`, in order, with no row for an unknown method.
  ///
  /// - Parameter methods: The auth methods of the model.
  /// - Returns: One row for each agent and terminal method.
  static func rows(of methods: [FoundationModelsACP.AuthMethod]) -> [Row] {
    methods.compactMap { method in
      switch method {
      case .agent(let agent): .agent(agent)
      case .terminal(let terminal): .terminal(terminal)
      case .unknown: nil
      }
    }
  }

  /// The thread that has the terminal records.
  private var thread: AgentThread? {
    suppliedThread ?? environmentThread
  }

  /// Whether the last login succeeded: `authState` is `.authenticated`.
  private var isAuthenticated: Bool {
    guard case .authenticated = connection.authState else { return false }
    return true
  }

  /// The error of the last login that the agent refused, or `nil`.
  ///
  /// The value reads the `AuthFailure` of `authState` only for a failed
  /// `auth/login` request. Other failures have no view here yet.
  private var loginRefusal: RequestError? {
    guard case .failed(let failure) = connection.authState,
      case .login = failure.operation,
      case .request(let refusal) = failure.reason
    else { return nil }
    return refusal
  }

  // MARK: Body

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      Label(String(localized: "Sign in to the agent"), systemImage: Self.symbol)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(Self.titleIdentifier)
      if !isAuthenticated {
        ForEach(Self.rows(of: connection.authMethods)) { row in
          rowView(row)
        }
      }
      if let loginRefusal {
        errorText(loginRefusal.message, identifier: Self.loginErrorIdentifier)
      }
      if connection.canLogout {
        signOutRow
      }
    }
    .padding(theme.spacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(String(localized: "Sign in to the agent"))
    .accessibilityIdentifier(Self.identifier)
  }

  /// The row of one method: the name, the description, the button, and the
  /// terminal of a terminal method.
  ///
  /// - Parameter row: The method to show.
  /// - Returns: The row.
  private func rowView(_ row: Row) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          Text(row.name)
            .font(.body.weight(.medium))
          if let description = row.description {
            Text(description)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: theme.spacing.s)
        methodButton(row)
      }
      if case .terminal(let method) = row,
        let record = thread?.terminals[TerminalRecord.authID(for: method.methodId)]
      {
        TerminalView(record: record, stdin: { line in write(line, to: record.id) })
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(row.name)
    .accessibilityIdentifier(Self.rowIdentifier(for: row.id))
  }

  /// The Sign In button of an agent method, or the Run button of a terminal
  /// method.
  ///
  /// - Parameter row: The method of the button.
  /// - Returns: The button.
  @ViewBuilder
  private func methodButton(_ row: Row) -> some View {
    switch row {
    case .agent(let method):
      actionButton(
        String(localized: "Sign In"), operation: .method(method.methodId),
        accessibilityLabel: String(localized: "Sign in with \(method.name)"),
        identifier: Self.signInIdentifier(for: method.methodId)
      ) { [connection] in
        try await Self.login(method.methodId, on: connection)
      }
    case .terminal(let method):
      actionButton(
        String(localized: "Run"), operation: .method(method.methodId),
        accessibilityLabel: String(localized: "Run \(method.name)"),
        identifier: Self.runIdentifier(for: method.methodId)
      ) { [actions] in
        try await actions?.runTerminalAuth(method)
      }
    }
  }

  /// The row with the Sign Out button.
  private var signOutRow: some View {
    VStack(alignment: .trailing, spacing: theme.spacing.s) {
      Divider()
      actionButton(
        String(localized: "Sign Out"), operation: .signOut,
        accessibilityLabel: String(localized: "Sign out of the agent"),
        identifier: Self.signOutIdentifier
      ) { [connection] in
        try await connection.logout(LogoutAuthRequest())
      }
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
  }

  /// A button that runs a call, with a `ProgressView` while the call runs.
  ///
  /// - Parameters:
  ///   - title: The text of the button.
  ///   - operation: The key of the progress of the call.
  ///   - accessibilityLabel: The label that VoiceOver reads.
  ///   - identifier: The accessibility identifier of the button.
  ///   - call: The call to run.
  /// - Returns: The button.
  private func actionButton(
    _ title: String,
    operation: Operation,
    accessibilityLabel: String,
    identifier: String,
    call: @escaping @MainActor () async throws -> Void
  ) -> some View {
    let isRunning = running.contains(operation)
    return Button {
      perform(operation, call)
    } label: {
      if isRunning {
        ProgressView()
          .controlSize(.small)
      } else {
        Text(title)
      }
    }
    .buttonStyle(.glass)
    .disabled(isRunning)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier(identifier)
  }

  /// The text of a login that the agent refused.
  ///
  /// - Parameters:
  ///   - message: The text of the error.
  ///   - identifier: The accessibility identifier of the text.
  /// - Returns: The text view.
  private func errorText(_ message: String, identifier: String) -> some View {
    Text(message)
      .font(.callout)
      .foregroundStyle(theme.statusColors.failed)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityIdentifier(identifier)
  }

  // MARK: Actions

  /// Sends `auth/login` with the id of an agent method.
  ///
  /// When the agent refuses the login, the model records the error in
  /// `authState`, and the card shows it from there. Thus the refusal does not
  /// go to ``report(_:)``.
  ///
  /// - Parameters:
  ///   - methodID: The id of the agent method.
  ///   - connection: The connection model that sends the request.
  /// - Throws: Each error that the model does not record in `authState`.
  private static func login(_ methodID: AuthMethodId, on connection: ConnectionModel) async throws {
    do {
      try await connection.login(LoginAuthRequest(methodId: methodID))
    } catch is RequestError {
      // `authState` holds the refusal, and the card shows it.
    }
  }

  /// Runs `call`, and records its progress under `operation`.
  ///
  /// A second call while the call runs does nothing. A cancelled call
  /// records nothing. Each other thrown error goes to ``report(_:)``.
  ///
  /// - Parameters:
  ///   - operation: The key of the progress.
  ///   - call: The call to run.
  private func perform(_ operation: Operation, _ call: @escaping @MainActor () async throws -> Void) {
    guard !running.contains(operation) else { return }
    running.insert(operation)
    Task {
      do {
        try await call()
      } catch is CancellationError {
        // A cancelled call is not a failure.
      } catch {
        report(error)
      }
      running.remove(operation)
    }
  }

  /// Sends a line of the terminal input field to the process of a method.
  ///
  /// A failed write goes to ``report(_:)``.
  ///
  /// - Parameters:
  ///   - line: The line that the user typed.
  ///   - terminal: The identifier of the terminal record.
  private func write(_ line: String, to terminal: TerminalID) {
    guard let actions else { return }
    Task {
      do {
        try await actions.writeTerminalLine(line, to: terminal)
      } catch is CancellationError {
        // A cancelled write is not a failure.
      } catch {
        report(error)
      }
    }
  }

  /// Records a failure that the model does not record.
  ///
  /// The failure goes to the log. When the environment has a session model,
  /// the failure also adds an error entry to its transcript.
  ///
  /// - Parameter error: The error of the call.
  private func report(_ error: any Error) {
    Self.logger.error("An auth call failed: \(String(describing: error), privacy: .public)")
    session?.appendError(reporting: error)
  }
}
