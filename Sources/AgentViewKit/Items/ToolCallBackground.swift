import FoundationModelsACP
import FoundationModelsACPClient

/// The background state that the row of a tool call shows.
///
/// An agent keeps a background call `in_progress` with
/// `_meta.sah.backgroundRun.completionToken` until the work ends. Then it
/// sends `completed`, `failed`, `cancelled` or `_lost` on the same tool call
/// id. While the call is live, the row shows "Running in the background"
/// (`ToolCallEntry.backgroundRun`).
///
/// A live call is stale when no update can end it: the session is closed,
/// or the agent is idle and does not list the call in its `background` list
/// (`ToolCallEntry.isStale`). A stale call shows the lost status, not the
/// live symbol.
enum ToolCallBackground {
  /// The status that a stale call shows.
  static let staleStatus = FoundationModelsACP.ToolCallStatus.unknown(
    ToolStatusSymbol.lostWireValue)

  /// Tells if a status is live: pending or in progress.
  ///
  /// - Parameter status: The status of the call.
  /// - Returns: `true` for a live status.
  static func isLive(_ status: FoundationModelsACP.ToolCallStatus) -> Bool {
    status == .pending || status == .inProgress
  }

  /// The status that the row of a call shows.
  ///
  /// - Parameter entry: The tool call entry.
  /// - Returns: The lost status for a stale call, or the status of the
  ///   entry. The function reads the staleness only for a live call, so a
  ///   final row does not observe the state of the agent.
  static func shownStatus(of entry: ToolCallEntry) -> FoundationModelsACP.ToolCallStatus {
    let status = entry.shownStatus
    guard isLive(status) else { return status }
    return entry.isStale ? staleStatus : status
  }

  /// Tells if the row of a call shows "Running in the background".
  ///
  /// - Parameters:
  ///   - entry: The tool call entry.
  ///   - shownStatus: The status that the row shows (``shownStatus(of:)``).
  /// - Returns: `true` for a live call with a completion token.
  static func showsBackgroundCaption(
    _ entry: ToolCallEntry, shownStatus: FoundationModelsACP.ToolCallStatus
  ) -> Bool {
    isLive(shownStatus) && entry.backgroundRun != nil
  }
}
