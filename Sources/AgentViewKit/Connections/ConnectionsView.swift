import EditorCommands
import FoundationModelsACPClient
import SwiftUI

/// The list of the MCP servers of a session (plan.md §12).
///
/// The view reads `SessionModel.mcpServers` of the
/// ``SwiftUI/EnvironmentValues/sessionModel`` environment value in its body.
/// It shows one ``ConnectionRow`` for each server, in the order of the list.
/// The kit keeps no copy of the list. When the environment has no session
/// model, or the list is empty, the view shows an empty state.
///
/// The rows are an ``AgentRowList``, not a SwiftUI `List`: the arrow keys
/// select a row through the `nav.*` commands of EditorKit, and a jump session
/// of the host labels each row. A row does not open. The list has no margin
/// around its rows (^rgsq3k4): the host gives one, such as
/// `.scrollContentMargins(\.tile.margin)`.
public struct ConnectionsView: View {
  /// The accessibility identifier of the empty state.
  public static let emptyIdentifier = "connections-empty"

  /// The segment kind of the scope of the list of MCP servers.
  static let listKind = "mcpServers"

  /// The segment kind of the scope of a row.
  static let rowKind = "mcpServer"

  @Environment(\.sessionModel) private var session

  /// Makes the list.
  public init() {}

  /// The scope of the list of the MCP servers of a session.
  ///
  /// Two sessions in one window show two lists, so each list has the id of
  /// its session in its segment.
  ///
  /// - Parameter session: The session whose servers the list shows.
  /// - Returns: The scope `mcpServers:<session id>`, with rows of kind
  ///   `mcpServer`.
  static func scope(for session: SessionModel) -> AgentRowListScope {
    AgentRowListScope(list: FocusSegment(kind: listKind, id: session.sessionId.rawValue), rowKind: rowKind)
  }

  public var body: some View {
    if let session, !session.mcpServers.isEmpty {
      AgentRowList(session.mcpServers, id: \.name, scope: Self.scope(for: session)) { server in
        ConnectionRow(server: server)
      }
    } else {
      EmptyStateView(
        String(localized: "No MCP Servers", bundle: .module),
        systemImage: SharedSymbol.connection,
        description: Text("The MCP servers of the session show here.", bundle: .module)
      )
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(Self.emptyIdentifier)
    }
  }
}

#Preview("MCP servers") {
  ConnectionsView()
    .environment(\.sessionModel, PreviewFixtures.mcpSession)
    .scrollContentMargins(\.tile.margin)
}

#Preview("No MCP servers") {
  ConnectionsView()
}
