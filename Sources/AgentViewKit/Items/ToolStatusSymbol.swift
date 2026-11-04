import Foundation
import FoundationModelsACP

/// The label and the liveness of each ACP `ToolCallStatus` (plan.md §3.8,
/// §5, §9 C).
///
/// ``ToolCallView`` shows the symbol of the status at the end of the row,
/// the EditorKit status symbol of the ACP status (`EditorSymbol.Status`), and
/// VoiceOver reads the label. Each status has a different symbol and a
/// different label. ACP has no lost status: an agent sends the custom status
/// ``lostWireValue`` when the result of a call is lost, and that status has
/// its own symbol and label. All other unknown statuses share one symbol, and
/// each label of an unknown status has its wire string.
public nonisolated enum ToolStatusSymbol {
  /// The wire value of the custom status of a call whose result is lost.
  public static let lostWireValue = "_lost"

  /// The text that tells the status of a call.
  ///
  /// A status that a plan entry also has uses the same name as in
  /// ``TaskListView/statusLabel(_:)``.
  ///
  /// - Parameter status: The ACP progress of the call.
  /// - Returns: The label, such as "In progress". The lost status gives
  ///   "Result lost". Each other unknown status gives its wire string.
  public static func label(for status: FoundationModelsACP.ToolCallStatus) -> String {
    switch status {
    case .pending: WorkStatusLabel.pending
    case .inProgress: WorkStatusLabel.inProgress
    case .paused: WorkStatusLabel.paused
    case .completed: WorkStatusLabel.completed
    case .failed: WorkStatusLabel.failed
    case .cancelled: WorkStatusLabel.cancelled
    case .unknown(Self.lostWireValue): String(localized: "Result lost", bundle: .module)
    case .unknown(let wireValue): WorkStatusLabel.unknown(for: wireValue)
    }
  }

  /// Tells whether a call with `status` is live: it did not start, or it
  /// runs.
  ///
  /// - Parameter status: The ACP progress of the call.
  /// - Returns: `true` for `pending` and `inProgress`. A paused call is not
  ///   live: it does not run, and it did not end.
  public static func isLive(_ status: FoundationModelsACP.ToolCallStatus) -> Bool {
    switch status {
    case .pending, .inProgress: true
    case .paused, .completed, .failed, .cancelled, .unknown: false
    }
  }
}
