/// A request for the user to approve an action (plan.md §3.3).
///
/// The schema name is `AgentViewKit.ApprovalPayload`.
public nonisolated struct ApprovalPayload: StructuredPayload, Hashable, Identifiable {
  /// The identifier of the request.
  public var id: String

  /// The short title of the action.
  public var title: String

  /// The full text that tells the user about the action.
  public var description: String

  /// The labels of the answers that the user can select, in display order.
  public var options: [String]

  /// Makes an approval request.
  ///
  /// - Parameters:
  ///   - id: The identifier of the request.
  ///   - title: The short title of the action.
  ///   - description: The full text that tells the user about the action.
  ///   - options: The labels of the answers, in display order.
  public init(id: String, title: String, description: String, options: [String]) {
    self.id = id
    self.title = title
    self.description = description
    self.options = options
  }
}
