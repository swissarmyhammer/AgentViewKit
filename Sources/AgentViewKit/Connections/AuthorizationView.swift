import SwiftUI

/// The in-thread card that asks the user to connect to an MCP server
/// (plan.md §12).
///
/// The card is a glass card with the title "Connect to <server>", one chip for
/// each requested scope, a ``ConnectionStatusChip``, and a Connect button. The
/// Connect button calls ``AgentThreadActions/connect(_:)`` of the
/// `threadActions` environment value with the request.
///
/// - While `connect` runs, the button is disabled and shows a `ProgressView`,
///   and the chip shows ``ConnectionState/authenticating``.
/// - When `connect` throws, the card shows the text of the error and a Retry
///   button in place of the Connect button.
/// - At all other times, the chip shows the state of the server in the
///   ``ConnectionStore`` of the environment. The card finds the server by the
///   connection identifier that is equal to
///   ``AuthorizationRequest/serverName``, then by the display name. When the
///   store has no such server, the chip shows ``ConnectionState/needsAuth``,
///   because a request exists only for a server that needs authorization.
///
/// The card does not change the store. The host reports each state change
/// with ``ConnectionStore/transition(_:to:)``.
///
/// The view keeps the progress and the error in state. Give each request its
/// own view identity, for example with `.id(request.id)`.
public struct AuthorizationView: View {
  /// The start of the accessibility identifier of each card.
  public static let identifierPrefix = "authorization-card-"
  /// The start of the accessibility identifier of each title.
  public static let titleIdentifierPrefix = "authorization-title-"
  /// The start of the accessibility identifier of each scope chip.
  public static let scopeIdentifierPrefix = "authorization-scope-"
  /// The start of the accessibility identifier of each Connect button.
  public static let connectIdentifierPrefix = "authorization-connect-"
  /// The start of the accessibility identifier of each Retry button.
  public static let retryIdentifierPrefix = "authorization-retry-"
  /// The start of the accessibility identifier of each error text.
  public static let errorIdentifierPrefix = "authorization-error-"

  /// The symbol of the title.
  static let symbol = "key.horizontal"

  /// The step of the Connect action.
  enum Phase: Equatable {
    /// No `connect` call runs, and the last call did not fail.
    case idle
    /// A `connect` call runs.
    case connecting
    /// The last `connect` call failed with this text.
    case failed(String)
  }

  /// The request to show.
  let request: AuthorizationRequest

  /// The step of the Connect action.
  @State private var phase: Phase = .idle

  @Environment(\.threadActions) private var actions
  @Environment(\.connectionStore) private var store
  @Environment(\.agentTheme) private var theme

  /// Makes the card of `request`.
  ///
  /// - Parameter request: The request to show.
  public init(request: AuthorizationRequest) {
    self.request = request
  }

  // MARK: Identifiers

  /// The accessibility identifier of the card of `id`.
  ///
  /// - Parameter id: The identifier of the request.
  /// - Returns: `authorization-card-<id>`.
  public static func identifier(for id: AuthorizationRequestID) -> String {
    makeIdentifier(identifierPrefix, id)
  }

  /// The accessibility identifier of the title of the card of `id`.
  ///
  /// - Parameter id: The identifier of the request.
  /// - Returns: `authorization-title-<id>`.
  public static func titleIdentifier(for id: AuthorizationRequestID) -> String {
    makeIdentifier(titleIdentifierPrefix, id)
  }

  /// The accessibility identifier of the chip of `scope` in the card of `id`.
  ///
  /// - Parameters:
  ///   - id: The identifier of the request.
  ///   - scope: The OAuth scope.
  /// - Returns: `authorization-scope-<id>-<scope>`.
  public static func scopeIdentifier(for id: AuthorizationRequestID, scope: String) -> String {
    makeIdentifier(scopeIdentifierPrefix, id) + "-" + scope
  }

  /// The accessibility identifier of the Connect button of the card of `id`.
  ///
  /// - Parameter id: The identifier of the request.
  /// - Returns: `authorization-connect-<id>`.
  public static func connectIdentifier(for id: AuthorizationRequestID) -> String {
    makeIdentifier(connectIdentifierPrefix, id)
  }

  /// The accessibility identifier of the Retry button of the card of `id`.
  ///
  /// - Parameter id: The identifier of the request.
  /// - Returns: `authorization-retry-<id>`.
  public static func retryIdentifier(for id: AuthorizationRequestID) -> String {
    makeIdentifier(retryIdentifierPrefix, id)
  }

  /// The accessibility identifier of the error text of the card of `id`.
  ///
  /// - Parameter id: The identifier of the request.
  /// - Returns: `authorization-error-<id>`.
  public static func errorIdentifier(for id: AuthorizationRequestID) -> String {
    makeIdentifier(errorIdentifierPrefix, id)
  }

  /// The accessibility identifier that starts with `prefix` and ends with the
  /// identifier of the request.
  ///
  /// - Parameters:
  ///   - prefix: The start of the identifier.
  ///   - id: The identifier of the request.
  /// - Returns: `<prefix><id>`.
  private static func makeIdentifier(_ prefix: String, _ id: AuthorizationRequestID) -> String {
    AccessibilityIdentifier.make(prefix: prefix, value: id.rawValue)
  }

  // MARK: State

  /// The connection state of `serverName` in `store`.
  ///
  /// - Parameters:
  ///   - serverName: The display name of the server in the request.
  ///   - store: The store of the environment, or `nil`.
  /// - Returns: The state of the connection whose identifier is equal to
  ///   `serverName`, else the state of the first connection whose name is
  ///   equal to `serverName`, else ``ConnectionState/needsAuth``.
  static func storeState(of serverName: String, in store: ConnectionStore?) -> ConnectionState {
    guard let store else { return .needsAuth }
    let connection =
      store.connection(ConnectionID(serverName))
      ?? store.connections.first { $0.name == serverName }
    return connection?.state ?? .needsAuth
  }

  /// The state that the chip shows.
  private var chipState: ConnectionState {
    phase == .connecting ? .authenticating : Self.storeState(of: request.serverName, in: store)
  }

  // MARK: Body

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      header
      if !request.scopes.isEmpty {
        scopes
      }
      if case .failed(let message) = phase {
        Text(message)
          .font(.callout)
          .foregroundStyle(theme.statusColors.failed)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier(Self.errorIdentifier(for: request.id))
      }
      HStack {
        Spacer(minLength: 0)
        actionButton
      }
    }
    .padding(theme.spacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Connect to \(request.serverName)")
    .accessibilityIdentifier(Self.identifier(for: request.id))
  }

  /// The title and the status chip.
  private var header: some View {
    HStack(spacing: theme.spacing.s) {
      Label("Connect to \(request.serverName)", systemImage: Self.symbol)
        .font(.headline)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Connect to \(request.serverName)")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(Self.titleIdentifier(for: request.id))
      Spacer(minLength: theme.spacing.s)
      ConnectionStatusChip(state: chipState)
    }
  }

  /// One chip for each requested scope, in request order.
  private var scopes: some View {
    ScrollView(.horizontal) {
      HStack(spacing: theme.spacing.xs) {
        ForEach(Array(request.scopes.enumerated()), id: \.offset) { _, scope in
          Text(scope)
            .font(.caption.monospaced())
            .padding(.horizontal, theme.spacing.s)
            .padding(.vertical, theme.spacing.xs)
            .background(
              .quaternary, in: RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous)
            )
            .accessibilityIdentifier(Self.scopeIdentifier(for: request.id, scope: scope))
        }
      }
    }
    .scrollIndicators(.hidden)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Scopes")
  }

  /// The Connect button, or the Retry button after a failure.
  @ViewBuilder
  private var actionButton: some View {
    switch phase {
    case .idle, .connecting:
      Button(action: connect) {
        if phase == .connecting {
          ProgressView()
            .controlSize(.small)
        } else {
          Text("Connect")
        }
      }
      .buttonStyle(.glassProminent)
      .disabled(phase == .connecting)
      .accessibilityLabel("Connect to \(request.serverName)")
      .accessibilityIdentifier(Self.connectIdentifier(for: request.id))
    case .failed:
      Button("Retry", action: connect)
        .buttonStyle(.glassProminent)
        .accessibilityLabel("Retry the connection to \(request.serverName)")
        .accessibilityIdentifier(Self.retryIdentifier(for: request.id))
    }
  }

  // MARK: Actions

  /// Calls `connect` with the request, and records the step in ``phase``.
  ///
  /// A cancelled call goes back to ``Phase/idle``. Each other thrown error
  /// goes to ``Phase/failed(_:)`` with the text of the error.
  private func connect() {
    guard phase != .connecting, let actions else { return }
    phase = .connecting
    let request = request
    Task {
      do {
        try await actions.connect(request)
        phase = .idle
      } catch is CancellationError {
        phase = .idle
      } catch {
        phase = .failed(error.localizedDescription)
      }
    }
  }
}
