import AgentViewKitTestSupport
import SwiftUI

@testable import AgentViewKit

/// The reply targets of the card tests: each answer of a card goes to
/// ``AgentThreadActions/respond(to:_:)-(PermissionRequest,_)`` or
/// ``AgentThreadActions/respond(to:_:)-(ElicitationRequest,_)`` of a
/// recording ``NoopThreadActions``.
///
/// A card sends its answer to the client model that holds the request. A
/// card test that shows a fixture request has no client model, so this type
/// takes the place of the model and records the answers in the actions.
@MainActor
private final class ActionsReplies: PermissionReplying, ElicitationReplying {
  /// The actions that record each answer.
  let actions: any AgentThreadActions

  /// Makes the reply targets of `actions`.
  ///
  /// - Parameter actions: The actions that record each answer.
  init(actions: any AgentThreadActions) {
    self.actions = actions
  }

  func reply(to request: PermissionRequest, _ decision: PermissionDecision) async {
    await actions.respond(to: request, decision)
  }

  func reply(to request: ElicitationRequest, _ result: ElicitationResult) {
    let actions = actions
    Task { await actions.respond(to: request, result) }
  }
}

extension View {
  /// Sends each answer of the cards in this view to `actions`, in place of
  /// a client model.
  ///
  /// - Parameter actions: The actions that record each answer.
  /// - Returns: A view whose cards answer to `actions`.
  func repliesRecorded(by actions: any AgentThreadActions) -> some View {
    let replies = ActionsReplies(actions: actions)
    return environment(\.permissionReplies, replies)
      .environment(\.elicitationReplies, replies)
  }
}
