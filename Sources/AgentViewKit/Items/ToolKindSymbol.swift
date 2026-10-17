import Foundation
import FoundationModelsACP

/// The SF Symbol of each ACP `ToolKind` (plan.md §3.8, §5, §9 C).
///
/// ``ToolCallView`` shows this symbol at the start of the row. Each kind has
/// a different symbol. All unknown kinds share one symbol.
public nonisolated enum ToolKindSymbol {
  /// The SF Symbol name of a tool of `kind`.
  ///
  /// - Parameter kind: The ACP type of the tool.
  /// - Returns: The SF Symbol name.
  public static func name(for kind: FoundationModelsACP.ToolKind) -> String {
    switch kind {
    case .read: SharedSymbol.read
    case .edit: SharedSymbol.edit
    case .delete: SharedSymbol.delete
    case .move: SharedSymbol.move
    case .search: SharedSymbol.search
    case .execute: SharedSymbol.terminal
    case .think: SharedSymbol.reasoning
    case .fetch: SharedSymbol.web
    case .switchMode: SharedSymbol.switchMode
    case .other: SharedSymbol.tool
    case .unknown: SharedSymbol.unknown
    }
  }
}

/// The SF Symbol and the label of each ACP `ToolCallStatus` (plan.md §3.8,
/// §5, §9 C).
///
/// ``ToolCallView`` shows the symbol at the end of the row, and VoiceOver
/// reads the label. Each status has a different symbol and a different
/// label. ACP has no lost status: an agent sends the custom status
/// ``lostWireValue`` when the result of a call is lost, and that status has
/// its own symbol and label. All other unknown statuses share one symbol, and
/// each label of an unknown status has its wire string.
public nonisolated enum ToolStatusSymbol {
  /// The wire value of the custom status of a call whose result is lost.
  public static let lostWireValue = "_lost"

  /// The SF Symbol name of a call with `status`.
  ///
  /// - Parameter status: The ACP progress of the call.
  /// - Returns: The SF Symbol name.
  public static func name(for status: FoundationModelsACP.ToolCallStatus) -> String {
    switch status {
    case .pending: SharedSymbol.pending
    case .inProgress: SharedSymbol.inProgress
    case .completed: SharedSymbol.completed
    case .failed: SharedSymbol.error
    case .cancelled: SharedSymbol.cancelled
    case .unknown(Self.lostWireValue): SharedSymbol.warning
    case .unknown: SharedSymbol.unknown
    }
  }

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
  /// - Returns: `true` for `pending` and `inProgress`.
  public static func isLive(_ status: FoundationModelsACP.ToolCallStatus) -> Bool {
    switch status {
    case .pending, .inProgress: true
    case .completed, .failed, .cancelled, .unknown: false
    }
  }
}
