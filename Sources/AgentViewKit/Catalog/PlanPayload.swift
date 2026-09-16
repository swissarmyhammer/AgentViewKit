/// The task list of an agent, as a structured segment (plan.md §3.3).
///
/// The schema name is `AgentViewKit.PlanPayload`. A source turns the payload
/// into a ``Plan``.
public nonisolated struct PlanPayload: StructuredPayload, Hashable, Identifiable {
  /// The identifier of the plan in the thread.
  public var id: String

  /// The entries, in the order that the agent gave.
  public var entries: [PlanEntry]

  /// Makes a plan payload.
  ///
  /// - Parameters:
  ///   - id: The identifier of the plan in the thread.
  ///   - entries: The entries, in the order that the agent gave.
  public init(id: String, entries: [PlanEntry]) {
    self.id = id
    self.entries = entries
  }

  /// The plan that the payload holds.
  public var plan: Plan {
    Plan(id: PlanID(id), entries: entries)
  }
}
