import FoundationModelsACP
import FoundationModelsACPClient

/// A client model that holds pending elicitations and takes the answer of the
/// user to each one (update.md §3 D7, §4.2 "Pending requests", §4.3
/// "Request-scoped elicitations").
///
/// `SessionModel` holds the elicitations of a session, and `ConnectionModel`
/// holds the request-scoped elicitations. ``ElicitationView`` and
/// ``ElicitationURLConsentView`` call these methods of the model that holds
/// the `PendingElicitation` they show. The model removes the elicitation when
/// it resolves, so the card goes away with no state of its own.
@MainActor
public protocol PendingElicitationOwner: AnyObject {
  /// Accepts one pending elicitation.
  ///
  /// - Parameters:
  ///   - id: The local id of the pending elicitation.
  ///   - content: The form values as ACP JSON, or `nil` for no content.
  func acceptElicitation(_ id: PendingElicitation.ID, content: FoundationModelsACP.JSONValue?)

  /// Declines one pending elicitation.
  ///
  /// - Parameter id: The local id of the pending elicitation.
  func declineElicitation(_ id: PendingElicitation.ID)

  /// Cancels one pending elicitation.
  ///
  /// - Parameter id: The local id of the pending elicitation.
  func cancelElicitation(_ id: PendingElicitation.ID)
}

extension SessionModel: PendingElicitationOwner {}

extension ConnectionModel: PendingElicitationOwner {}
