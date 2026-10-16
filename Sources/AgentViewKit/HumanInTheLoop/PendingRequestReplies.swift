import FoundationModelsACP
import FoundationModelsACPClient

/// A client model that holds pending elicitations and takes the answer of the
/// user to each one (plan.md §3.2 "Pending requests", §3.3
/// "Request-scoped elicitations", §11 decision 4).
///
/// `SessionModel` holds the elicitations of a session, and `ConnectionModel`
/// holds the request-scoped elicitations. ``ElicitationView`` and
/// ``ElicitationURLConsentView`` call these methods of the model that holds
/// the `PendingElicitation` they show. The model removes the elicitation when
/// it resolves, so the card goes away with no state of its own.
///
/// An accepted URL mode elicitation moves to ``awaitingURLCompletions``, with
/// the same id, until the flow in the browser ends. The model removes it when
/// the agent sends `elicitation/complete`, or when ``stopWaiting(_:)`` stops
/// the wait.
@MainActor
public protocol PendingElicitationOwner: AnyObject {
  /// The accepted URL mode elicitations that wait for the
  /// `elicitation/complete` of the agent, oldest first.
  var awaitingURLCompletions: [PendingElicitation] { get }

  /// Accepts one pending elicitation.
  ///
  /// - Parameters:
  ///   - id: The local id of the pending elicitation.
  ///   - content: The form values as ACP JSON, or `nil` for no content.
  func acceptElicitation(_ id: PendingElicitation.ID, content: FoundationModelsACP.JSONValue?)

  /// Stops the wait for one accepted URL mode elicitation, and removes it
  /// from ``awaitingURLCompletions``. The agent gets no message.
  ///
  /// - Parameter id: The local id of the accepted elicitation.
  func stopWaiting(_ id: PendingElicitation.ID)

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
