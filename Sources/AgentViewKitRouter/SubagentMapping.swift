import AgentViewKit
import Foundation
import FoundationModelsExtras
import FoundationModelsRouter

/// Changes FoundationModelsRouter values into subagent changes
/// (`Docs/decisions/subagent-source.md`, plan.md §9 C).
///
/// This is the adapter of ``SubagentSource/router``, the v1 subagent source.
/// Each function is pure. The id of a run is the id of the parent tool call
/// that started it. The `session` `TranscriptEvent` of a spawned session
/// gives the run and its child thread id. The tool call events and the run
/// events of the parent session give the title, the state, and the times.
///
/// A session event does not tell whether its tool call started a subagent.
/// So ``patch(for:now:)`` gives a patch for each tool call, and
/// ``RouterThreadSource`` applies it only to a run that the thread has.
public enum SubagentMapping {
  // MARK: - Spawn

  /// The change that adds the run of a spawned session.
  ///
  /// - Parameters:
  ///   - event: A Router transcript event.
  ///   - parentRunID: The id of the run whose thread is the parent session,
  ///     or `nil` when the parent session is the thread root.
  /// - Returns: An ``ThreadChange/upsertSubagent(_:)`` change with the run
  ///   id, the parent id, and the child thread id. `nil` when the event is
  ///   not the `session` event of a spawned session.
  public static func spawnChange(
    for event: TranscriptEvent,
    parentRunID: SubagentRunID?
  ) -> ThreadChange? {
    guard event.kind == .session, let spawn = event.agentSpawn else { return nil }
    return .upsertSubagent(
      SubagentPatch(
        id: SubagentRunID(spawn.parentToolCallId),
        parentID: parentRunID.map { .value($0) } ?? .cleared,
        threadID: .value(event.sessionId.ulidString)
      )
    )
  }

  /// The id of the session that spawned the session of the event.
  ///
  /// - Parameter event: A Router transcript event.
  /// - Returns: The parent session id, or `nil` when the event is not the
  ///   `session` event of a spawned session.
  public static func parentSessionID(of event: TranscriptEvent) -> String? {
    guard event.kind == .session else { return nil }
    return event.agentSpawn?.parentSessionId.ulidString
  }

  // MARK: - Parent session events

  /// The patch that a parent session event gives to the run with the id of
  /// its tool call.
  ///
  /// - Parameters:
  ///   - event: A session event of the parent session.
  ///   - now: The host clock value for the start and the end times.
  /// - Returns: The patch, or `nil` for an event that does not change a run.
  public static func patch(for event: SessionEvent, now: Date) -> SubagentPatch? {
    switch event {
    case .toolCall(let id, let name, _):
      return SubagentPatch(id: SubagentRunID(id), title: .value(name), startedAt: .value(now))
    case .toolStatus(let id, let status, _, _):
      return SubagentPatch(
        id: SubagentRunID(id),
        state: .value(state(for: status)),
        endedAt: status == .running ? .unchanged : .value(now)
      )
    case .runSettled(let operation):
      return SubagentPatch(
        id: SubagentRunID(operation.correlationID),
        state: operation.outcome.map { .value(state(for: $0)) } ?? .unchanged,
        endedAt: .value(now)
      )
    case .elicitationRequested(let operation):
      return SubagentPatch(id: SubagentRunID(operation.correlationID), state: .value(.needsInput))
    case .turnStarted, .textDelta, .textReset, .reasoningDelta, .toolInvocation, .toolCallReport,
      .entryRecorded, .compaction, .discoveryPrimingFailed, .generationStalled, .turnEnded:
      return nil
    }
  }

  // MARK: - States

  /// The run state for a Router tool call status.
  ///
  /// - Parameter status: The Router status of the parent tool call.
  /// - Returns: `working`, `done`, or `failed`.
  public static func state(for status: FoundationModelsRouter.ToolCallStatus) -> SubagentState {
    switch status {
    case .running: .working
    case .completed: .done
    case .failed: .failed
    }
  }

  /// The run state for the kit status of the parent tool call record.
  ///
  /// - Parameter status: The kit status of the parent tool call.
  /// - Returns: `working` while the call waits or runs, `done` for a
  ///   complete call, `failed` for a call that did not complete, and
  ///   `unknown` with the same string for an unknown status.
  public static func state(for status: AgentViewKit.ToolCallStatus) -> SubagentState {
    switch status {
    case .pending, .inProgress: .working
    case .completed: .done
    case .failed, .cancelled, .lost: .failed
    case .unknown(let wireValue): .unknown(wireValue)
    }
  }

  /// The run state for the outcome of a settled run.
  ///
  /// A cancelled run can still do work, so its state is `unknown` with the
  /// wire string of the outcome.
  ///
  /// - Parameter outcome: The outcome of the settled run.
  /// - Returns: `done` for success, `failed` for a failure outcome, and
  ///   `unknown` with the wire string for the other outcomes.
  public static func state(for outcome: OperationOutcome) -> SubagentState {
    switch outcome {
    case .succeeded: .done
    case .failed, .timedOut, .stopped, .lost: .failed
    case .cancelled, .other: .unknown(outcome.rawValue)
    }
  }
}
