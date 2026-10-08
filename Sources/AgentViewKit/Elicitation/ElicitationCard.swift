import FoundationModelsACP
import FoundationModelsACPClient
import OSLog
import SwiftUI

/// The card of one pending elicitation of a client model (plan.md §3.2
/// "Pending requests", §13.2, §13.3).
///
/// The card is an ``ElicitationView`` for a form mode request, or an
/// ``ElicitationURLConsentView`` for a URL mode request.
/// ``PendingRequestsHost`` shows one card for each pending elicitation of a
/// client model, and ``ToolCallView`` shows one card for each elicitation
/// that is linked to its tool call. Each card sends the answer of the user
/// to the reply methods of the model that holds the elicitation.
struct ElicitationCard: View {
  /// The log of an elicitation that the kit cannot show.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "ElicitationCard")

  /// The pending elicitation to show.
  let request: PendingElicitation

  /// The model that holds the elicitation.
  let owner: any PendingElicitationOwner

  /// Tells if the kit has a card for the mode of a pending elicitation.
  ///
  /// The ACP schema tells a client not to show a mode that it does not know
  /// as a known mode. The hosts show no card for such a mode, and the log
  /// records it. The elicitation stays pending in the model.
  ///
  /// - Parameter pending: The pending elicitation.
  /// - Returns: `true` for the form mode and the URL mode.
  static func hasCard(for pending: PendingElicitation) -> Bool {
    switch pending.request.mode {
    case .form, .url:
      return true
    case .unknown(let kind, _):
      logger.error("The elicitation mode \(kind, privacy: .public) is not known. The kit shows no card.")
      return false
    }
  }

  var body: some View {
    switch request.request.mode {
    case .form:
      ElicitationView(request: request, owner: owner)
    case .url:
      ElicitationURLConsentView(request: request, owner: owner)
    case .unknown:
      EmptyView()
    }
  }
}
