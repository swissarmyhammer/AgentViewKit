import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// A host closure that connects to the agent again after a terminal sign-in.
///
/// After a successful `ConnectionModel.loginWithTerminal(_:runner:)`, the
/// `authState` of the model is `.reconnectRequired(methodId)`. ACP v2 tells
/// the client to connect again: the host makes a new transport, calls
/// `ConnectionModel.connect(over:)` and `initialize(_:)`, and then retries the
/// operation that needed the sign-in. Only the host can make a transport, so
/// the kit calls this closure and keeps no transport and no failed operation.
public typealias AgentReconnect = @MainActor () async -> Void

/// The card that signs the user in to an ACP agent (plan.md §9 E2, §12;
/// update.md §4.3 "Initialize and auth").
///
/// The card binds directly to a `ConnectionModel`. The body reads
/// `authMethods`, `authState`, `canLogin` and `canLogout` of the model, and
/// keeps no copy of them:
///
/// - When `canLogin` is `true`, each `agent` method of `authMethods` has a row
///   with a Sign In button. The button calls `ConnectionModel.login(_:)` with
///   the id of the method.
/// - Each `terminal` method has a row. When the
///   ``SwiftUI/EnvironmentValues/terminalAuthRunner`` environment value has a
///   runner, the row has a Run button. The button calls
///   `ConnectionModel.loginWithTerminal(_:runner:)` with that runner, and
///   never calls `login`. With no runner, the row has no button. When the
///   thread has the record with the id ``TerminalRecord/authID(for:)`` of the
///   method, the row shows the record in a ``TerminalView`` with an input
///   field. Each line that the user types goes to
///   ``AgentThreadActions/writeTerminalLine(_:to:)``.
/// - A method type that the kit does not know has no row.
/// - While `authState` is `.authenticated`, the card shows no method row.
/// - While `authState` is `.failed(AuthFailure)`, the card shows the
///   operation that failed and the text of the reason under the rows.
/// - While `authState` is `.reconnectRequired`, the card tells the user to
///   connect to the agent again. When the
///   ``SwiftUI/EnvironmentValues/agentReconnect`` environment value has a
///   closure, a Reconnect button calls it.
/// - When `canLogout` is `true`, a Sign Out button calls
///   `ConnectionModel.logout(_:)`. Otherwise the button is not shown.
///
/// While a call runs, its button is disabled and shows a `ProgressView`. This
/// flag is view state. The model records each failure of a call that it can
/// record in `authState`, and the card shows the failure from there. The card
/// keeps no failure of its own.
///
/// The host puts the card in its settings surface next to
/// ``ConnectionsView``. ``AgentThreadView`` shows the card while `authState`
/// asks for a sign-in. The card finds terminal records in the `thread`
/// argument, else in the ``SwiftUI/EnvironmentValues/agentThread`` environment
/// value. With no thread, a terminal row shows no terminal.
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
  /// The accessibility identifier of the operation of a failure in
  /// `authState`.
  public static let failureTitleIdentifier = "agent-auth-failure-title"
  /// The accessibility identifier of the text of a failure in `authState`.
  public static let failureIdentifier = "agent-auth-failure"
  /// The accessibility identifier of the text that tells the user to connect
  /// to the agent again.
  public static let reconnectMessageIdentifier = "agent-auth-reconnect-message"
  /// The accessibility identifier of the Reconnect button.
  public static let reconnectIdentifier = "agent-auth-reconnect"
  /// The accessibility identifier of the Sign Out button.
  public static let signOutIdentifier = "agent-auth-sign-out"

  /// The symbol of the title.
  static let symbol = "person.badge.key"

  /// A call that the card runs, as the key of its progress.
  enum Operation: Hashable {
    /// The Sign In or Run call of the method with this id.
    case method(AuthMethodId)
    /// The Sign Out call.
    case signOut
    /// The Reconnect call.
    case reconnect
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
  @Environment(\.terminalAuthRunner) private var runner
  @Environment(\.agentReconnect) private var reconnect
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
  /// When `canLogin` is `false`, an `agent` method has no row, because the
  /// agent serves no `auth/login`.
  ///
  /// - Parameters:
  ///   - methods: The auth methods of the model.
  ///   - canLogin: The `canLogin` flag of the model.
  /// - Returns: One row for each terminal method, and one row for each agent
  ///   method when `canLogin` is `true`.
  private static func rows(of methods: [FoundationModelsACP.AuthMethod], canLogin: Bool) -> [Row] {
    methods.compactMap { method in
      switch method {
      case .agent(let agent): canLogin ? .agent(agent) : nil
      case .terminal(let terminal): .terminal(terminal)
      case .unknown: nil
      }
    }
  }

  /// The title of a failure: the operation that failed.
  ///
  /// - Parameter operation: The operation of the failure.
  /// - Returns: The text that names the operation.
  private static func title(of operation: AuthFailure.Operation) -> String {
    switch operation {
    case .login: String(localized: "Sign-in failed")
    case .logout: String(localized: "Sign-out failed")
    case .terminalLogin: String(localized: "Terminal sign-in failed")
    }
  }

  /// The text of the reason of a failure.
  ///
  /// - Parameter reason: The reason of the failure.
  /// - Returns: The message of the JSON-RPC error, or the text of the end of
  ///   the terminal process.
  private static func text(of reason: AuthFailure.Reason) -> String {
    switch reason {
    case .request(let error): error.message
    case .terminal(let exitStatus, let message): terminalText(exitStatus: exitStatus, message: message)
    }
  }

  /// The text of a terminal process that failed.
  ///
  /// - Parameters:
  ///   - exitStatus: The exit status of the process, or `nil` when the
  ///     process did not exit normally.
  ///   - message: The message of the model, or `nil`.
  /// - Returns: The message, when there is one. Otherwise a text that gives
  ///   the exit status, or that tells that there is none.
  private static func terminalText(exitStatus: Int32?, message: String?) -> String {
    if let message { return message }
    guard let exitStatus else { return String(localized: "The sign-in process ended with no exit status.") }
    return String(localized: "The sign-in process ended with exit status \(exitStatus).")
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

  /// The failure of the last auth operation, or `nil`.
  private var failure: AuthFailure? {
    guard case .failed(let failure) = connection.authState else { return nil }
    return failure
  }

  /// Whether the host must connect to the agent again to finish a terminal
  /// sign-in: `authState` is `.reconnectRequired`.
  private var isReconnectRequired: Bool {
    guard case .reconnectRequired = connection.authState else { return false }
    return true
  }

  // MARK: Body

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      Label(String(localized: "Sign in to the agent"), systemImage: Self.symbol)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(Self.titleIdentifier)
      if !isAuthenticated {
        ForEach(Self.rows(of: connection.authMethods, canLogin: connection.canLogin)) { row in
          rowView(row)
        }
      }
      if let failure {
        failureView(failure)
      }
      if isReconnectRequired {
        reconnectView
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
  /// method. A terminal method has no button when the environment has no
  /// terminal auth runner.
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
        try await connection.login(LoginAuthRequest(methodId: method.methodId))
      }
    case .terminal(let method):
      if let runner {
        actionButton(
          String(localized: "Run"), operation: .method(method.methodId),
          accessibilityLabel: String(localized: "Run \(method.name)"),
          identifier: Self.runIdentifier(for: method.methodId)
        ) { [connection] in
          try await connection.loginWithTerminal(method.methodId, runner: runner)
        }
      }
    }
  }

  /// The operation and the reason of a failure in `authState`.
  ///
  /// - Parameter failure: The failure of the last auth operation.
  /// - Returns: The two texts.
  private func failureView(_ failure: AuthFailure) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Text(Self.title(of: failure.operation))
        .font(.callout.weight(.semibold))
        .accessibilityIdentifier(Self.failureTitleIdentifier)
      Text(Self.text(of: failure.reason))
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(Self.failureIdentifier)
    }
    .foregroundStyle(theme.statusColors.failed)
  }

  /// The text that tells the user to connect to the agent again, and the
  /// Reconnect button when the environment has a closure.
  private var reconnectView: some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      Text(String(localized: "Reconnect to the agent to finish the sign-in"))
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(Self.reconnectMessageIdentifier)
      if let reconnect {
        actionButton(
          String(localized: "Reconnect"), operation: .reconnect,
          accessibilityLabel: String(localized: "Reconnect to the agent"),
          identifier: Self.reconnectIdentifier
        ) {
          await reconnect()
        }
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

  // MARK: Actions

  /// Runs `call`, and records its progress under `operation`.
  ///
  /// A second call while the call runs does nothing. The model records each
  /// failure of a login, a logout and a terminal sign-in in `authState`, and
  /// the card shows the failure from there. Thus the card does not keep the
  /// error that `call` throws.
  ///
  /// - Parameters:
  ///   - operation: The key of the progress.
  ///   - call: The call to run.
  private func perform(_ operation: Operation, _ call: @escaping @MainActor () async throws -> Void) {
    guard !running.contains(operation) else { return }
    running.insert(operation)
    Task {
      try? await call()
      running.remove(operation)
    }
  }

  /// Sends a line of the terminal input field to the process of a method.
  ///
  /// The model has no state for this write. When the write fails and the
  /// environment has a session model, the failure adds an error entry to its
  /// transcript. A cancelled write records nothing.
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
        session?.appendError(reporting: error)
      }
    }
  }
}

extension EnvironmentValues {
  /// The runner that runs a `terminal` auth method of the agent in an
  /// interactive terminal (plan.md §12).
  ///
  /// ``AgentAuthView`` shows the Run button of a `terminal` method only when
  /// this value has a runner, and gives the runner to
  /// `ConnectionModel.loginWithTerminal(_:runner:)`. The default is `nil`:
  /// only a host can run the agent program in a terminal. A host that sets a
  /// runner also sends `auth.terminal` in its `initialize` request, with
  /// ``FoundationModelsACP/InitializeRequest/makeAgentViewKitRequest(info:terminalAuthRunner:)``.
  @Entry public var terminalAuthRunner: (any TerminalAuthRunner)? = nil

  /// The host closure that connects to the agent again after a terminal
  /// sign-in.
  ///
  /// ``AgentAuthView`` shows a Reconnect button that calls this closure while
  /// `authState` is `.reconnectRequired`. The default is `nil`: the card then
  /// shows only the text that tells the user to connect again.
  @Entry public var agentReconnect: AgentReconnect? = nil
}

extension View {
  /// Sets the runner that runs the `terminal` auth methods of the agent in
  /// this subtree.
  ///
  /// - Parameter runner: The runner of the host, or `nil` for no Run button.
  /// - Returns: A view that gives the runner to its subtree.
  public func terminalAuthRunner(_ runner: (any TerminalAuthRunner)?) -> some View {
    environment(\.terminalAuthRunner, runner)
  }

  /// Sets the host closure that the Reconnect button of the auth card calls
  /// in this subtree.
  ///
  /// - Parameter reconnect: The closure of the host, or `nil` for no
  ///   Reconnect button.
  /// - Returns: A view that gives the closure to its subtree.
  public func agentReconnect(_ reconnect: AgentReconnect?) -> some View {
    environment(\.agentReconnect, reconnect)
  }
}
