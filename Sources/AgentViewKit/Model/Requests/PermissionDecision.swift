/// The answer of the user to a ``PermissionRequest`` (plan.md §3.4).
///
/// `AgentThreadActions.respond(to:_:)` takes this value. The ACP wire has no
/// field for a comment. When ``comment`` has a value, the source sends it as
/// the next user message after the decision.
public nonisolated struct PermissionDecision: Sendable, Hashable {
  /// The result of the request, in the ACP shape.
  public var outcome: Outcome

  /// The reason of the user, or `nil`. Usually a rejection has a reason.
  public var comment: String?

  /// Makes a permission decision.
  ///
  /// - Parameters:
  ///   - outcome: The result of the request.
  ///   - comment: The reason of the user, or `nil`.
  public init(outcome: Outcome, comment: String? = nil) {
    self.outcome = outcome
    self.comment = comment
  }

  /// The result of a permission request.
  ///
  /// The cases follow the ACP v2 `RequestPermissionOutcome`.
  public enum Outcome: Sendable, Hashable {
    /// The user selected an option.
    ///
    /// - Parameter optionId: The ``PermissionOption/id`` of the option.
    case selected(PermissionOptionID)

    /// The turn stopped before the user answered.
    case cancelled
  }
}
