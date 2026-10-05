import SwiftUI

/// The card of one elicitation request (plan.md §13.2, §13.3).
///
/// The card is an ``ElicitationView`` for a form mode request, or an
/// ``ElicitationURLConsentView`` for a URL mode request.
/// ``PendingRequestsHost`` shows one card for each pending request of a
/// thread, and ``ToolCallView`` shows one card for each elicitation that is
/// linked to its tool call.
struct ElicitationCard: View {
  /// The request to show.
  let request: ElicitationRequest

  var body: some View {
    switch request.mode {
    case .form:
      ElicitationView(request: request)
    case .url:
      ElicitationURLConsentView(request: request)
    }
  }
}
