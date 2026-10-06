import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import OSLog
import SwiftUI

/// The model that takes the answer of the user to a permission request
/// (update.md §3 D7, §4.2 "Pending requests").
///
/// `SessionModel` holds the pending permission requests of a session, so it
/// takes each answer. ``PermissionView`` reads the model from
/// ``SwiftUI/EnvironmentValues/permissionReplies``.
@MainActor
protocol PermissionReplying: AnyObject {
  /// Sends the answer of the user to a pending permission request.
  ///
  /// - Parameters:
  ///   - request: The request that the card shows.
  ///   - decision: The answer of the user.
  func reply(to request: PermissionRequest, _ decision: PermissionDecision) async
}

/// The model that takes the answer of the user to an elicitation
/// (update.md §3 D7, §4.2 "Pending requests", §4.3 "Request-scoped
/// elicitations").
///
/// `SessionModel` holds the elicitations of a session, and `ConnectionModel`
/// holds the request-scoped elicitations. ``ElicitationView`` and
/// ``ElicitationURLConsentView`` read the model from
/// ``SwiftUI/EnvironmentValues/elicitationReplies``.
@MainActor
protocol ElicitationReplying: AnyObject {
  /// Sends the answer of the user to a pending elicitation.
  ///
  /// - Parameters:
  ///   - request: The request that the card shows.
  ///   - result: The answer of the user.
  func reply(to request: ElicitationRequest, _ result: ElicitationResult)
}

/// A client model that holds pending elicitations and has the three reply
/// methods of the client models.
@MainActor
protocol PendingElicitationOwner: ElicitationReplying {
  /// Accepts one pending elicitation with the form values.
  ///
  /// - Parameters:
  ///   - id: The local id of the pending elicitation.
  ///   - content: The form values, or `nil`.
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

extension PendingElicitationOwner {
  /// Calls the reply method of the model for `result`.
  ///
  /// - Parameters:
  ///   - request: The request that the card shows. Its id is the local id of
  ///     the pending elicitation.
  ///   - result: The answer of the user.
  func reply(to request: ElicitationRequest, _ result: ElicitationResult) {
    guard let id = PendingRequestID.localID(of: request.id.rawValue) else { return }
    switch result {
    case .accept(let content):
      acceptElicitation(id, content: content.map(SessionUpdateMapping.wireJSON))
    case .decline:
      declineElicitation(id)
    case .cancel:
      cancelElicitation(id)
    }
  }
}

extension SessionModel: PendingElicitationOwner {}

extension ConnectionModel: PendingElicitationOwner {}

extension SessionModel: PermissionReplying {
  /// Selects the option of `decision`, or cancels the request.
  ///
  /// The wire has no field for a comment, so a comment goes out as the next
  /// prompt (`Docs/decisions/permission-ux.md`). The model gives no signal
  /// when the answer is on the wire, so the prompt goes after the call that
  /// answers the request returns.
  ///
  /// - Parameters:
  ///   - request: The request that the card shows. Its id is the local id of
  ///     the pending permission request.
  ///   - decision: The answer of the user.
  func reply(to request: PermissionRequest, _ decision: PermissionDecision) async {
    guard let id = PendingRequestID.localID(of: request.id.rawValue) else { return }
    switch decision.outcome {
    case .selected(let optionId):
      selectPermission(id, option: PermissionOptionId(rawValue: optionId.rawValue))
    case .cancelled:
      cancelPermission(id)
    }
    guard let comment = decision.comment, !comment.isEmpty else { return }
    await sendPrompt(with: UserInput(text: comment))
  }
}

/// The local id of a pending request in the kit request that shows it.
private enum PendingRequestID {
  /// The log of an answer that names no pending request.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "PendingRequestReplies")

  /// The local id that a kit request id names.
  ///
  /// The host makes each kit request from a pending request of a client
  /// model, so the kit request id is the text of the local id. Another id is
  /// an error of the host.
  ///
  /// - Parameter rawValue: The text of the kit request id.
  /// - Returns: The local id, or `nil` when the text is not a UUID.
  static func localID(of rawValue: String) -> UUID? {
    guard let id = UUID(uuidString: rawValue) else {
      assertionFailure("The request id \(rawValue) is not the local id of a pending request.")
      logger.error(
        "The request id \(rawValue, privacy: .public) is not a local id. The answer does not go out.")
      return nil
    }
    return id
  }
}

extension EnvironmentValues {
  /// The model that takes the answer to each permission card, or `nil`.
  ///
  /// ``PendingRequestsHost`` sets its session model.
  @Entry var permissionReplies: (any PermissionReplying)? = nil

  /// The model that takes the answer to each elicitation card, or `nil`.
  ///
  /// ``PendingRequestsHost`` sets its session model or its connection model.
  /// A tool call row sets the session model of its entry.
  @Entry var elicitationReplies: (any ElicitationReplying)? = nil
}
