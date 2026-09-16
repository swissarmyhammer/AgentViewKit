import SwiftUI

/// One server in ``ConnectionsView`` (plan.md §12).
///
/// The row shows the name of the server, a ``ConnectionStatusChip``, a
/// Connect or a Disconnect button, and a toggle for each tool. The buttons
/// and the toggles act on the ``ConnectionStore`` of the environment.
///
/// A tool identifier is unique only in its connection, so the accessibility
/// identifier of a toggle holds the connection identifier and the tool
/// identifier.
public struct ConnectionRow: View {
  /// The start of the accessibility identifier of each row.
  public static let identifierPrefix = "connection-row-"

  /// The start of the accessibility identifier of each tool toggle.
  public static let toolIdentifierPrefix = "connection-tool-"

  /// The start of the accessibility identifier of each Connect button.
  public static let connectIdentifierPrefix = "connection-connect-"

  /// The start of the accessibility identifier of each Disconnect button.
  public static let disconnectIdentifierPrefix = "connection-disconnect-"

  /// The state kinds that show the Connect button. The other kinds show the
  /// Disconnect button.
  static let connectKinds: Set<ConnectionState.Kind> = [
    .disconnected, .needsAuth, .expired, .error,
  ]

  /// The connection to show.
  let connection: Connection

  @Environment(\.connectionStore) private var store
  @Environment(\.agentTheme) private var theme

  /// Makes a row.
  ///
  /// - Parameter connection: The connection to show.
  public init(connection: Connection) {
    self.connection = connection
  }

  /// The accessibility identifier of the row of `id`.
  ///
  /// - Parameter id: The identifier of the connection.
  /// - Returns: `connection-row-<id>`.
  public static func identifier(for id: ConnectionID) -> String {
    identifierPrefix + id.rawValue
  }

  /// The accessibility identifier of the toggle of `tool` in the row of `id`.
  ///
  /// - Parameters:
  ///   - id: The identifier of the connection.
  ///   - tool: The identifier of the tool.
  /// - Returns: `connection-tool-<id>-<tool>`.
  public static func toolIdentifier(for id: ConnectionID, tool: ToolToggleID) -> String {
    "\(toolIdentifierPrefix)\(id.rawValue)-\(tool.rawValue)"
  }

  /// The accessibility identifier of the Connect button in the row of `id`.
  ///
  /// - Parameter id: The identifier of the connection.
  /// - Returns: `connection-connect-<id>`.
  public static func connectIdentifier(for id: ConnectionID) -> String {
    connectIdentifierPrefix + id.rawValue
  }

  /// The accessibility identifier of the Disconnect button in the row of
  /// `id`.
  ///
  /// - Parameter id: The identifier of the connection.
  /// - Returns: `connection-disconnect-<id>`.
  public static func disconnectIdentifier(for id: ConnectionID) -> String {
    disconnectIdentifierPrefix + id.rawValue
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      header
      ForEach(connection.tools) { tool in
        // The stock style is a check box. On macOS 27 a switch style has no
        // accessibility label of its own, so the row uses the stock style.
        Toggle(tool.name, isOn: binding(for: tool))
          .accessibilityIdentifier(Self.toolIdentifier(for: connection.id, tool: tool.id))
      }
    }
    .padding(.vertical, theme.rowPadding)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(connection.name)
    .accessibilityIdentifier(Self.identifier(for: connection.id))
  }

  /// The row with the name, the chip, and the button.
  private var header: some View {
    HStack(spacing: theme.spacing.s) {
      Text(connection.name)
        .font(.headline)
        .lineLimit(1)
      Spacer(minLength: theme.spacing.s)
      ConnectionStatusChip(state: connection.state)
      actionButton
    }
  }

  /// The Connect or the Disconnect button for the state of the connection.
  @ViewBuilder
  private var actionButton: some View {
    let id = connection.id
    if Self.connectKinds.contains(connection.state.kind) {
      Button("Connect") {
        Task { await store?.connect(id) }
      }
      .buttonStyle(.glassProminent)
      .accessibilityLabel("Connect \(connection.name)")
      .accessibilityIdentifier(Self.connectIdentifier(for: id))
    } else {
      Button("Disconnect") {
        Task { await store?.disconnect(id) }
      }
      .buttonStyle(.glass)
      .accessibilityLabel("Disconnect \(connection.name)")
      .accessibilityIdentifier(Self.disconnectIdentifier(for: id))
    }
  }

  /// A binding that reads `tool` and writes to the store.
  ///
  /// - Parameter tool: The tool of the toggle.
  /// - Returns: The binding of the toggle.
  private func binding(for tool: ToolToggle) -> Binding<Bool> {
    let id = connection.id
    return Binding(
      get: { tool.isEnabled },
      set: { store?.setToolEnabled(id, tool.id, $0) }
    )
  }
}
