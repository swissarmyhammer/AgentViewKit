import SwiftUI

/// The card that signs the user in to an ACP agent (plan.md §9 E2, §12).
///
/// The card shows one row for each ``AuthMethod`` that the agent gave at
/// `initialize`. The card calls the verbs of the `threadActions` environment
/// value:
///
/// - An ``AuthMethod/agent(_:)`` row has a Sign In button. The button calls
///   ``AgentThreadActions/login(_:)`` with the id of the method.
/// - An ``AuthMethod/terminal(_:)`` row has a Run button. The button calls
///   ``AgentThreadActions/runTerminalAuth(_:)``, and never calls `login`.
///   When the thread has the record with the id
///   ``TerminalRecord/authID(for:)`` of the method, the row shows the record
///   in a ``TerminalView`` with an input field. Each line that the user
///   types goes to ``AgentThreadActions/writeTerminalLine(_:to:)``.
/// - An ``AuthMethod/unknown(_:)`` method has no row.
/// - When `isAuthenticated` is `true`, a Sign Out button calls
///   ``AgentThreadActions/logout()``. Otherwise the button is not shown.
///
/// While a verb runs, its button is disabled and shows a `ProgressView`. When
/// a verb throws, the card shows the text of the error under the row. A
/// cancelled verb shows no error.
///
/// The host puts the card in the thread when the ACP source reports the
/// `authenticationRequired` error (code -32000), and in its settings surface
/// next to ``ConnectionsView``. The card finds terminal records in the
/// `thread` argument, else in the ``SwiftUI/EnvironmentValues/agentThread``
/// environment value. With no thread, a terminal row shows no terminal.
///
/// The view keeps the progress and the errors in state. Give each agent its
/// own view identity, for example with `.id(agentID)`.
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
  /// The start of the accessibility identifier of each row error text.
  public static let errorIdentifierPrefix = "agent-auth-error-"
  /// The accessibility identifier of the Sign Out button.
  public static let signOutIdentifier = "agent-auth-sign-out"
  /// The accessibility identifier of the Sign Out error text.
  public static let signOutErrorIdentifier = "agent-auth-sign-out-error"

  /// The symbol of the title.
  static let symbol = "person.badge.key"

  /// A verb that the card runs, as the key of its progress and its error.
  enum Operation: Hashable {
    /// The Sign In or Run verb of the method with this id.
    case method(AuthMethodID)
    /// The Sign Out verb.
    case signOut
  }

  /// A method that the card shows.
  enum Row: Identifiable {
    /// A method that the agent runs through `auth/login`.
    case agent(AuthMethod.Agent)
    /// A method that the client runs as a separate process.
    case terminal(AuthMethod.Terminal)

    /// The identifier of the method.
    var id: AuthMethodID {
      switch self {
      case .agent(let method): method.id
      case .terminal(let method): method.id
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

  /// The methods that the agent gave.
  let methods: [AuthMethod]
  /// Whether the user is signed in to the agent.
  let isAuthenticated: Bool
  /// The thread that the host gives, or `nil` to use the environment thread.
  let suppliedThread: AgentThread?

  /// The verbs that run.
  @State private var running: Set<Operation> = []
  /// The error text of each verb whose last call failed.
  @State private var errors: [Operation: String] = [:]

  @Environment(\.threadActions) private var actions
  @Environment(\.agentThread) private var environmentThread
  @Environment(\.agentTheme) private var theme

  /// Makes the card.
  ///
  /// - Parameters:
  ///   - methods: The methods that the agent gave at `initialize`, in order.
  ///   - isAuthenticated: Whether the user is signed in. When it is `true`,
  ///     the card shows the Sign Out button.
  ///   - thread: The thread that has the terminal records of the terminal
  ///     methods, or `nil` to use the environment thread.
  public init(methods: [AuthMethod], isAuthenticated: Bool, thread: AgentThread? = nil) {
    self.methods = methods
    self.isAuthenticated = isAuthenticated
    self.suppliedThread = thread
  }

  // MARK: Identifiers

  /// The accessibility identifier of the row of `id`.
  ///
  /// - Parameter id: The identifier of the method.
  /// - Returns: `agent-auth-row-<id>`.
  public static func rowIdentifier(for id: AuthMethodID) -> String {
    rowIdentifierPrefix + id.rawValue
  }

  /// The accessibility identifier of the Sign In button of `id`.
  ///
  /// - Parameter id: The identifier of the agent method.
  /// - Returns: `agent-auth-sign-in-<id>`.
  public static func signInIdentifier(for id: AuthMethodID) -> String {
    signInIdentifierPrefix + id.rawValue
  }

  /// The accessibility identifier of the Run button of `id`.
  ///
  /// - Parameter id: The identifier of the terminal method.
  /// - Returns: `agent-auth-run-<id>`.
  public static func runIdentifier(for id: AuthMethodID) -> String {
    runIdentifierPrefix + id.rawValue
  }

  /// The accessibility identifier of the error text of the row of `id`.
  ///
  /// - Parameter id: The identifier of the method.
  /// - Returns: `agent-auth-error-<id>`.
  public static func errorIdentifier(for id: AuthMethodID) -> String {
    errorIdentifierPrefix + id.rawValue
  }

  // MARK: Model

  /// The rows of `methods`, in order, with no row for an unknown method.
  ///
  /// - Parameter methods: The methods that the agent gave.
  /// - Returns: One row for each agent and terminal method.
  static func rows(of methods: [AuthMethod]) -> [Row] {
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

  // MARK: Body

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      Label(String(localized: "Sign in to the agent"), systemImage: Self.symbol)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(Self.titleIdentifier)
      ForEach(Self.rows(of: methods)) { row in
        rowView(row)
      }
      if isAuthenticated {
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

  /// The row of one method: the name, the description, the button, the
  /// error text, and the terminal of a terminal method.
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
      if let message = errors[.method(row.id)] {
        errorText(message, identifier: Self.errorIdentifier(for: row.id))
      }
      if case .terminal(let method) = row,
        let record = thread?.terminals[TerminalRecord.authID(for: method.id)]
      {
        TerminalView(record: record, stdin: { line in write(line, to: record.id, for: method.id) })
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
        String(localized: "Sign In"), operation: .method(method.id),
        accessibilityLabel: String(localized: "Sign in with \(method.name)"),
        identifier: Self.signInIdentifier(for: method.id)
      ) { actions in
        try await actions.login(method.id)
      }
    case .terminal(let method):
      actionButton(
        String(localized: "Run"), operation: .method(method.id),
        accessibilityLabel: String(localized: "Run \(method.name)"),
        identifier: Self.runIdentifier(for: method.id)
      ) { actions in
        try await actions.runTerminalAuth(method)
      }
    }
  }

  /// The row with the Sign Out button and its error text.
  private var signOutRow: some View {
    VStack(alignment: .trailing, spacing: theme.spacing.s) {
      Divider()
      if let message = errors[.signOut] {
        errorText(message, identifier: Self.signOutErrorIdentifier)
      }
      actionButton(
        String(localized: "Sign Out"), operation: .signOut,
        accessibilityLabel: String(localized: "Sign out of the agent"),
        identifier: Self.signOutIdentifier
      ) { actions in
        try await actions.logout()
      }
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
  }

  /// A button that runs a verb, with a `ProgressView` while the verb runs.
  ///
  /// - Parameters:
  ///   - title: The text of the button.
  ///   - operation: The key of the progress and the error of the verb.
  ///   - accessibilityLabel: The label that VoiceOver reads.
  ///   - identifier: The accessibility identifier of the button.
  ///   - verb: The verb to run with the actions of the environment.
  /// - Returns: The button.
  private func actionButton(
    _ title: String,
    operation: Operation,
    accessibilityLabel: String,
    identifier: String,
    verb: @escaping @MainActor (any AgentThreadActions) async throws -> Void
  ) -> some View {
    let isRunning = running.contains(operation)
    return Button {
      perform(operation, verb)
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

  /// The text of a failed verb.
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

  /// Runs `verb`, and records its progress and its error under `operation`.
  ///
  /// A second call while the verb runs does nothing. A cancelled verb
  /// records no error. Each other thrown error records the text of the
  /// error.
  ///
  /// - Parameters:
  ///   - operation: The key of the progress and the error.
  ///   - verb: The verb to run with the actions of the environment.
  private func perform(
    _ operation: Operation,
    _ verb: @escaping @MainActor (any AgentThreadActions) async throws -> Void
  ) {
    guard !running.contains(operation) else { return }
    running.insert(operation)
    errors[operation] = nil
    let actions = actions
    Task {
      do {
        try await verb(actions)
      } catch is CancellationError {
        // A cancelled verb is not a failure.
      } catch {
        errors[operation] = error.localizedDescription
      }
      running.remove(operation)
    }
  }

  /// Sends a line of the terminal input field to the process of a method.
  ///
  /// A failed write shows the text of the error under the row of the
  /// method.
  ///
  /// - Parameters:
  ///   - line: The line that the user typed.
  ///   - terminal: The identifier of the terminal record.
  ///   - methodID: The identifier of the terminal method.
  private func write(_ line: String, to terminal: TerminalID, for methodID: AuthMethodID) {
    let actions = actions
    Task {
      do {
        try await actions.writeTerminalLine(line, to: terminal)
      } catch is CancellationError {
        // A cancelled write is not a failure.
      } catch {
        errors[.method(methodID)] = error.localizedDescription
      }
    }
  }
}
