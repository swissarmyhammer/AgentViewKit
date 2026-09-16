import SwiftUI

/// The list of server connections (plan.md §12).
///
/// The view shows the ``ConnectionStore`` of the environment. Set the store
/// with ``SwiftUI/View/connectionStore(_:)``. Each connection is a
/// ``ConnectionRow``. When the environment has no store, or the store has no
/// connection, the view shows an empty state.
public struct ConnectionsView: View {
  /// The accessibility identifier of the empty state.
  public static let emptyIdentifier = "connections-empty"

  @Environment(\.connectionStore) private var store

  /// Makes the list.
  public init() {}

  public var body: some View {
    if let store, !store.connections.isEmpty {
      List(store.connections) { connection in
        ConnectionRow(connection: connection)
      }
    } else {
      ContentUnavailableView(
        "No Connections",
        systemImage: "point.3.connected.trianglepath.dotted",
        description: Text("Servers that the agent can use show here.")
      )
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(Self.emptyIdentifier)
    }
  }
}
