import FoundationModelsACPClient
import SwiftUI

/// The card of one elicitation request (plan.md §13.2, §13.3).
///
/// The card is an ``ElicitationView`` for a form mode request, or an
/// ``ElicitationURLConsentView`` for a URL mode request.
/// ``PendingRequestsHost`` shows one card for each pending elicitation of a
/// client model, and ``ToolCallView`` shows one card for each elicitation
/// that is linked to its tool call. Each card sends the answer of the user
/// to the model in ``SwiftUI/EnvironmentValues/elicitationReplies``.
struct ElicitationCard: View {
  /// The server name that each card shows. An elicitation over ACP comes
  /// from the agent.
  static let agentServer = String(localized: "The agent")

  /// The request to show.
  let request: ElicitationRequest

  /// The kit request of a pending elicitation of a client model.
  ///
  /// - Parameter pending: The pending elicitation.
  /// - Returns: The request with the local id of the elicitation and the
  ///   server name ``agentServer``, or `nil` for a mode that the kit does
  ///   not know.
  static func makeRequest(for pending: PendingElicitation) -> ElicitationRequest? {
    SessionUpdateMapping.elicitationRequest(pending, server: agentServer)
  }

  var body: some View {
    switch request.mode {
    case .form:
      ElicitationView(request: request)
    case .url:
      ElicitationURLConsentView(request: request)
    }
  }
}
