import FoundationModelsACPClient
import SwiftUI

/// The list of the MCP servers of a session (plan.md §12).
///
/// The view reads `SessionModel.mcpServers` of the
/// ``SwiftUI/EnvironmentValues/sessionModel`` environment value in its body.
/// It shows one ``ConnectionRow`` for each server, in the order of the list.
/// The kit keeps no copy of the list. When the environment has no session
/// model, or the list is empty, the view shows an empty state.
public struct ConnectionsView: View {
  /// The accessibility identifier of the empty state.
  public static let emptyIdentifier = "connections-empty"

  @Environment(\.sessionModel) private var session

  /// Makes the list.
  public init() {}

  public var body: some View {
    if let session, !session.mcpServers.isEmpty {
      List(session.mcpServers) { server in
        ConnectionRow(server: server)
      }
    } else {
      ContentUnavailableView(
        "No MCP Servers",
        systemImage: "point.3.connected.trianglepath.dotted",
        description: Text("The MCP servers of the session show here.")
      )
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(Self.emptyIdentifier)
    }
  }
}
