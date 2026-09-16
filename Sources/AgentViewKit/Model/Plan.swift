/// The identifier of a ``Plan`` in a thread (plan.md §3.2).
///
/// `AgentThread.plans` is keyed by this type. An ACP agent sends one plan for
/// each session, so the ACP adapter uses one fixed identifier. Other sources
/// can keep more than one plan.
public nonisolated struct PlanID: Sendable, Hashable, RawRepresentable {
  /// The identifier string.
  public let rawValue: String

  /// Makes an identifier from its string.
  ///
  /// - Parameter rawValue: The identifier string.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// Makes an identifier from its string.
  ///
  /// - Parameter rawValue: The identifier string.
  public init(_ rawValue: String) {
    self.init(rawValue: rawValue)
  }
}

/// The task list of an agent (plan.md §3.2).
///
/// A new plan from the agent replaces the full entry list.
public nonisolated struct Plan: Sendable, Hashable, Identifiable {
  /// The identifier of the plan in the thread.
  public var id: PlanID

  /// The entries, in the order that the agent gave.
  public var entries: [PlanEntry]

  /// Makes a plan.
  ///
  /// - Parameters:
  ///   - id: The identifier of the plan in the thread.
  ///   - entries: The entries, in the order that the agent gave.
  public init(id: PlanID, entries: [PlanEntry]) {
    self.id = id
    self.entries = entries
  }
}

/// One task in a ``Plan`` (plan.md §3.2).
///
/// The fields are the fields of an ACP `PlanEntry`.
public nonisolated struct PlanEntry: Sendable, Hashable {
  /// The text of the task.
  public var content: String

  /// The importance of the task.
  public var priority: Priority

  /// The progress of the task.
  public var status: Status

  /// Makes a plan entry.
  ///
  /// - Parameters:
  ///   - content: The text of the task.
  ///   - priority: The importance of the task.
  ///   - status: The progress of the task.
  public init(content: String, priority: Priority, status: Status) {
    self.content = content
    self.priority = priority
    self.status = status
  }

  /// The importance of a plan entry.
  ///
  /// The wire values are the ACP `PlanEntryPriority` strings.
  public enum Priority: WireValueEnum {
    /// A task of high importance.
    case high

    /// A task of medium importance.
    case medium

    /// A task of low importance.
    case low

    /// A priority that the kit does not know, with its wire string.
    case unknown(String)

    /// Each case of the enum, but not ``unknown(_:)``.
    public static let knownCases: [Priority] = [.high, .medium, .low]

    /// The ACP wire string of the case.
    public var wireValue: String {
      switch self {
      case .high: "high"
      case .medium: "medium"
      case .low: "low"
      case .unknown(let wireValue): wireValue
      }
    }
  }

  /// The progress of a plan entry.
  ///
  /// The wire values are the ACP v2 `PlanEntryStatus` strings.
  public enum Status: WireValueEnum {
    /// The work did not start.
    case pending

    /// The work is in progress.
    case inProgress

    /// The work is complete.
    case completed

    /// The work stopped before it was complete.
    case cancelled

    /// A status that the kit does not know, with its wire string.
    case unknown(String)

    /// Each case of the enum, but not ``unknown(_:)``.
    public static let knownCases: [Status] = [.pending, .inProgress, .completed, .cancelled]

    /// The ACP wire string of the case.
    public var wireValue: String {
      switch self {
      case .pending: "pending"
      case .inProgress: "in_progress"
      case .completed: "completed"
      case .cancelled: "cancelled"
      case .unknown(let wireValue): wireValue
      }
    }
  }
}
