import EditorStyle
import FoundationModelsACPClient
import SwiftUI

/// The banner of the connection state of a `ConnectionModel` (plan.md §3.3
/// "The connection state", §3.8 "Connection banner").
///
/// The body reads `ConnectionModel.state` directly, and keeps no copy of it.
/// When the transport closes, the model changes its state, and the banner
/// follows with no other step:
///
/// - `.disconnected`: a banner tells that no connection to the agent is open.
/// - `.failed`: a banner tells that the connection failed, with the text of
///   the error.
/// - `.connecting` and `.connected`: no banner.
///
/// The model never connects again on its own, so the banner has no button.
/// The host connects again with `ConnectionModel.connect(over:)`.
///
/// The text of each banner has its own accessibility identifier:
/// ``disconnectedIdentifier`` and ``failedIdentifier``.
///
/// The banner has no margin around it (^rgsq3k4): the layout that holds it
/// spaces it, as the top bar of ``AgentThreadView`` does with the tile
/// margin.
public struct AgentConnectionBanner: View {
  /// The accessibility identifier of the text of the disconnected banner.
  public static let disconnectedIdentifier = "agent-connection-disconnected"

  /// The accessibility identifier of the text of the failed banner.
  public static let failedIdentifier = "agent-connection-failed"

  /// The connection model whose state the banner shows.
  let connection: ConnectionModel

  /// Makes the banner of the connection state of a connection model.
  ///
  /// - Parameter connection: The connection model of the agent.
  public init(connection: ConnectionModel) {
    self.connection = connection
  }

  public var body: some View {
    if let message = Self.makeMessage(for: connection.state) {
      StatusBar(message: message, action: nil)
        .statusBarActionStyle(AgentStatusBarActionStyle())
    }
  }

  /// Makes the text of the banner of a connection state.
  ///
  /// - Parameter state: The connection state of the model.
  /// - Returns: The text, or `nil` when the state shows no banner.
  static func makeMessage(for state: ConnectionState) -> StatusBar.Message? {
    switch state {
    case .disconnected:
      disconnectedMessage
    case .failed(let error):
      StatusBar.Message(
        title: String(localized: "The connection to the agent failed", bundle: .module),
        explanation: error.localizedDescription,
        symbolName: SharedSymbol.error,
        identifier: failedIdentifier, severity: .failure)
    case .connecting, .connected:
      nil
    }
  }

  /// The text of the disconnected banner.
  private static let disconnectedMessage = StatusBar.Message(
    title: String(localized: "The agent is not connected", bundle: .module),
    explanation: String(
      localized: "No connection to the agent is open. The agent receives no messages.",
      bundle: .module),
    symbolName: SharedSymbol.disconnected,
    identifier: disconnectedIdentifier)
}

#Preview("Disconnected") {
  AgentConnectionBanner(connection: .preview(state: .disconnected))
}
