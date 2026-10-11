import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The colors of the status, the priority and the severity values of ACP,
/// from the color roles of the EditorKit theme (plan.md §5).
///
/// The kit keeps no copy of a color. Each view reads the EditorKit theme of
/// the environment (`@Environment(\.editorTheme)`) and gives it a value to
/// tint. A host sets the theme with `.editorTheme(_:)`.
nonisolated extension EditorTheme.Theme {
  /// The color of a tool call with `status`.
  ///
  /// Each view that tints a tool call by its status uses this function, so
  /// that the views show the same color for the same status.
  ///
  /// - Parameter status: The ACP status of the tool call.
  /// - Returns: `statusRunning` for a call that runs, `statusSucceeded` for
  ///   a completed call, `statusFailed` for a failed call or a call whose
  ///   result is lost (``ToolStatusSymbol/lostWireValue``), `statusCancelled`
  ///   for a cancelled call, and `statusPending` for a pending call or a
  ///   status that the kit does not know.
  public func statusColor(for status: FoundationModelsACP.ToolCallStatus) -> Color {
    switch status {
    case .inProgress: statusRunning
    case .completed: statusSucceeded
    case .failed, .unknown(ToolStatusSymbol.lostWireValue): statusFailed
    case .cancelled: statusCancelled
    case .pending, .unknown: statusPending
    }
  }

  /// The color of a plan entry with `status`.
  ///
  /// - Parameter status: The ACP status of the plan entry.
  /// - Returns: `statusRunning` for an entry in progress, `statusSucceeded`
  ///   for a completed entry, `statusCancelled` for a cancelled entry, and
  ///   `statusPending` for a pending entry or a status that the kit does not
  ///   know.
  public func statusColor(for status: FoundationModelsACP.PlanEntryStatus) -> Color {
    switch status {
    case .inProgress: statusRunning
    case .completed: statusSucceeded
    case .cancelled: statusCancelled
    case .pending, .unknown: statusPending
    }
  }

  /// The color of a context compaction with `status`.
  ///
  /// - Parameter status: The status of the compaction (stable ACP since
  ///   schema alpha.8).
  /// - Returns: `statusRunning` for a compaction in progress,
  ///   `statusSucceeded` for a completed compaction, `statusFailed` for a
  ///   failed compaction, `statusCancelled` for a cancelled compaction, and
  ///   `statusPending` for a compaction with no reported status or with a
  ///   status that the kit does not know.
  public func statusColor(for status: CompactionStatus) -> Color {
    switch status {
    case .inProgress: statusRunning
    case .completed: statusSucceeded
    case .failed: statusFailed
    case .cancelled: statusCancelled
    case .unknown: statusPending
    }
  }

  /// The color of a user message with the send state `state`.
  ///
  /// - Parameter state: The send state of a `UserMessageEntry`.
  /// - Returns: `statusPending` for a message that the agent did not link
  ///   yet, `statusSucceeded` for a sent message, and `statusFailed` for a
  ///   message whose prompt failed.
  public func statusColor(for state: SendState) -> Color {
    switch state {
    case .pending: statusPending
    case .sent: statusSucceeded
    case .failed: statusFailed
    }
  }

  /// The tint of a plan entry with `priority`.
  ///
  /// The theme has no priority roles, so the tint uses the role that has the
  /// same strength: the error color shows high importance, the warning color
  /// shows medium importance, and the pending color shows low importance.
  ///
  /// - Parameter priority: The ACP priority of the plan entry.
  /// - Returns: `severityError` for a high priority, `severityWarning` for a
  ///   medium priority, and `statusPending` for a low priority or a priority
  ///   that the kit does not know.
  public func tint(for priority: FoundationModelsACP.PlanEntryPriority) -> Color {
    switch priority {
    case .high: severityError
    case .medium: severityWarning
    case .low, .unknown: statusPending
    }
  }

  /// The tint of a session notice with `severity`.
  ///
  /// - Parameter severity: The severity of the notice (stable ACP since
  ///   schema alpha.8).
  /// - Returns: `severityError` for an error, `severityWarning` for a
  ///   warning, and `severityInfo` for information or a severity that the
  ///   kit does not know.
  public func tint(for severity: NoticeSeverity) -> Color {
    switch severity {
    case .error: severityError
    case .warning: severityWarning
    case .info, .unknown: severityInfo
    }
  }
}
