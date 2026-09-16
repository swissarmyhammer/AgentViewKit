import Foundation
import Observation

/// The identifier of a ``SubagentRun`` in a thread (plan.md §9 C).
///
/// For the Router source, this is the id of the parent tool call that started
/// the run (`Docs/decisions/subagent-source.md`).
public typealias SubagentRunID = Identifier<SubagentRun>

/// The state of a ``SubagentRun`` (plan.md §9 C, §11 decision 15).
///
/// The set of states comes from the AG-UI subagent events and from the
/// subagent trees of the 2026 coding agents (plan.md §2).
public nonisolated enum SubagentState: WireValueEnum, Codable {
  /// The run does work.
  case working

  /// The run waits for an answer from the user.
  case needsInput

  /// The run is complete, and its result waits for a review by the user.
  case readyForReview

  /// The run is complete.
  case done

  /// The run stopped with an error.
  case failed

  /// A state that the kit does not know, with its wire string.
  case unknown(String)

  /// Each case of the enum, but not ``unknown(_:)``.
  public static let knownCases: [SubagentState] = [
    .working, .needsInput, .readyForReview, .done, .failed,
  ]

  /// The wire string of the case.
  public var wireValue: String {
    switch self {
    case .working: "working"
    case .needsInput: "needs_input"
    case .readyForReview: "ready_for_review"
    case .done: "done"
    case .failed: "failed"
    case .unknown(let wireValue): wireValue
    }
  }

  /// Whether the run can still change. The Stop button shows only for an
  /// active run.
  public var isActive: Bool {
    switch self {
    case .working, .needsInput: true
    case .readyForReview, .done, .failed, .unknown: false
    }
  }
}

/// One subagent run that the agent started (plan.md §9 C, §11 decision 15).
///
/// A run is not a ``ThreadItem``. ``AgentThread/subagents`` holds the runs of
/// a thread, and ``SubagentTreeView`` shows them as a tree by
/// ``parentID``. The record uses the revision rule of ``TerminalRecord``: a
/// patch changes the record in place and calls ``bump()``. Thus a state patch
/// makes only the row of that run invalid.
@Observable
public final class SubagentRun: Identifiable {
  /// The identifier of the run.
  public nonisolated let id: SubagentRunID

  /// The number of patches on the record. Call ``bump()`` to change it.
  ///
  /// A new record has revision zero.
  public private(set) var revision = 0

  /// The identifier of the run that started this run, or `nil` when the
  /// thread itself started it.
  public var parentID: SubagentRunID?

  /// The title of the run, such as the name of the tool that started it.
  public var title: String

  /// The state of the run.
  public var state: SubagentState

  /// The time when the run started, if it is known.
  public var startedAt: Date?

  /// The time when the run ended, or `nil` while it runs.
  public var endedAt: Date?

  /// The identifier of the thread of the run, or `nil` until the source
  /// knows it. For the Router source, this is the id of the child session.
  public var threadID: String?

  /// Makes a run.
  ///
  /// - Parameters:
  ///   - id: The identifier of the run.
  ///   - parentID: The identifier of the parent run, or `nil` for a root run.
  ///   - title: The title of the run.
  ///   - state: The state of the run.
  ///   - startedAt: The time when the run started.
  ///   - endedAt: The time when the run ended.
  ///   - threadID: The identifier of the thread of the run.
  public init(
    id: SubagentRunID,
    parentID: SubagentRunID? = nil,
    title: String = "",
    state: SubagentState = .working,
    startedAt: Date? = nil,
    endedAt: Date? = nil,
    threadID: String? = nil
  ) {
    self.id = id
    self.parentID = parentID
    self.title = title
    self.state = state
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.threadID = threadID
  }

  /// Increments ``revision`` by one.
  ///
  /// Call this function after each patch on the record.
  public func bump() {
    revision += 1
  }
}

/// A change to the fields of a ``SubagentRun`` (plan.md §3.2).
///
/// The fields use the upsert rule of ``PatchField``.
public nonisolated struct SubagentPatch: Sendable, Hashable {
  /// The identifier of the run to change.
  public var id: SubagentRunID

  /// The identifier of the parent run.
  public var parentID: PatchField<SubagentRunID>

  /// The title of the run. ``PatchField/cleared`` sets the empty string.
  public var title: PatchField<String>

  /// The state of the run. ``PatchField/cleared`` sets
  /// ``SubagentState/working``, the state of a new run.
  public var state: PatchField<SubagentState>

  /// The time when the run started.
  public var startedAt: PatchField<Date>

  /// The time when the run ended.
  public var endedAt: PatchField<Date>

  /// The identifier of the thread of the run.
  public var threadID: PatchField<String>

  /// Makes a subagent patch.
  ///
  /// - Parameters:
  ///   - id: The identifier of the run to change.
  ///   - parentID: The identifier of the parent run.
  ///   - title: The title of the run.
  ///   - state: The state of the run.
  ///   - startedAt: The time when the run started.
  ///   - endedAt: The time when the run ended.
  ///   - threadID: The identifier of the thread of the run.
  public init(
    id: SubagentRunID,
    parentID: PatchField<SubagentRunID> = .unchanged,
    title: PatchField<String> = .unchanged,
    state: PatchField<SubagentState> = .unchanged,
    startedAt: PatchField<Date> = .unchanged,
    endedAt: PatchField<Date> = .unchanged,
    threadID: PatchField<String> = .unchanged
  ) {
    self.id = id
    self.parentID = parentID
    self.title = title
    self.state = state
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.threadID = threadID
  }
}

@MainActor
extension SubagentPatch {
  /// Makes a new run with the id, and applies the patch to it.
  ///
  /// The new record has revision zero.
  ///
  /// - Returns: The new run.
  func makeRun() -> SubagentRun {
    let run = SubagentRun(id: id)
    applyFields(to: run)
    return run
  }

  /// Applies the patch to the run. The revision does not change.
  ///
  /// - Parameter run: The run to change.
  func applyFields(to run: SubagentRun) {
    run.parentID = parentID.applied(to: run.parentID)
    run.title = title.applied(to: run.title)
    run.state = state.applied(to: run.state, clearedValue: .working)
    run.startedAt = startedAt.applied(to: run.startedAt)
    run.endedAt = endedAt.applied(to: run.endedAt)
    run.threadID = threadID.applied(to: run.threadID)
  }
}
