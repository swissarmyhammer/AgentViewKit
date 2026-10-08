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
public struct AgentConnectionBanner: View {
  /// The accessibility identifier of the text of the disconnected banner.
  public static let disconnectedIdentifier = "agent-connection-disconnected"

  /// The accessibility identifier of the text of the failed banner.
  public static let failedIdentifier = "agent-connection-failed"

  /// The connection model whose state the banner shows.
  let connection: ConnectionModel

  @Environment(\.agentTheme) private var theme

  /// Makes the banner of the connection state of a connection model.
  ///
  /// - Parameter connection: The connection model of the agent.
  public init(connection: ConnectionModel) {
    self.connection = connection
  }

  public var body: some View {
    if let message = Self.makeMessage(for: connection.state) {
      StatusBar(message: message, action: nil)
        .padding(theme.spacing.m)
    }
  }

  /// Makes the text of the banner of a connection state.
  ///
  /// - Parameter state: The connection state of the model.
  /// - Returns: The text, or `nil` when the state shows no banner.
  private static func makeMessage(for state: ConnectionState) -> StateBanner.Message? {
    switch state {
    case .disconnected:
      disconnectedMessage
    case .failed(let error):
      StateBanner.Message(
        title: String(localized: "The connection to the agent failed"),
        explanation: error.localizedDescription,
        symbolName: "exclamationmark.triangle.fill",
        identifier: failedIdentifier)
    case .connecting, .connected:
      nil
    }
  }

  /// The text of the disconnected banner.
  private static let disconnectedMessage = StateBanner.Message(
    title: String(localized: "The agent is not connected"),
    explanation: String(localized: "No connection to the agent is open. The agent receives no messages."),
    symbolName: "bolt.horizontal.circle",
    identifier: disconnectedIdentifier)
}
