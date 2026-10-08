import FoundationModelsACPClient
import SwiftUI

/// One MCP server in ``ConnectionsView`` (plan.md §12).
///
/// The row shows the `name` and the `transport` of an `MCPServerItem` of
/// the client model, and a ``ConnectionStatusChip`` with its `status`. An
/// item with no `transport` has no transport text. The
/// row reads the item in its body. Thus a status change of the item shows in
/// this row with no other step.
public struct ConnectionRow: View {
  /// The start of the accessibility identifier of each row.
  public static let identifierPrefix = "connection-row-"

  /// The start of the accessibility identifier of the transport text of each
  /// row.
  public static let transportIdentifierPrefix = "connection-transport-"

  /// The server to show, from `SessionModel.mcpServers`.
  let server: MCPServerItem

  @Environment(\.agentTheme) private var theme

  /// Makes a row.
  ///
  /// - Parameter server: The server to show, from `SessionModel.mcpServers`.
  public init(server: MCPServerItem) {
    self.server = server
  }

  /// The accessibility identifier of the row of a server.
  ///
  /// - Parameter name: The name of the server.
  /// - Returns: `connection-row-<name>`.
  public static func identifier(for name: String) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: name)
  }

  /// The accessibility identifier of the transport text in the row of a
  /// server.
  ///
  /// - Parameter name: The name of the server.
  /// - Returns: `connection-transport-<name>`.
  public static func transportIdentifier(for name: String) -> String {
    AccessibilityIdentifier.make(prefix: transportIdentifierPrefix, value: name)
  }

  public var body: some View {
    HStack(spacing: theme.spacing.s) {
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        Text(server.name)
          .font(.headline)
          .lineLimit(1)
        if let transport = server.transport {
          Text(Self.label(for: transport))
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(Self.transportIdentifier(for: server.name))
        }
      }
      Spacer(minLength: theme.spacing.s)
      ConnectionStatusChip(status: server.status)
    }
    .padding(.vertical, theme.rowPadding)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(server.name)
    .accessibilityIdentifier(Self.identifier(for: server.name))
  }

  /// The name of a transport that the user sees.
  ///
  /// - Parameter transport: The transport of the server.
  /// - Returns: `stdio` or `HTTP`.
  private static func label(for transport: MCPServerTransport) -> String {
    switch transport {
    case .stdio: "stdio"
    case .http: "HTTP"
    }
  }
}
