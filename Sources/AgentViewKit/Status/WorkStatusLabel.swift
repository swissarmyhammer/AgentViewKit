import Foundation

/// The names of the steps of a unit of work, such as a plan entry or a tool
/// call.
///
/// ``TaskListView/statusLabel(_:)`` and ``ToolStatusSymbol/label(for:)`` use
/// these names, so that the same step has the same name in each view.
nonisolated enum WorkStatusLabel {
  /// The name of work that did not start.
  static var pending: String { String(localized: "Pending", bundle: .module) }

  /// The name of work that runs now.
  static var inProgress: String { String(localized: "In progress", bundle: .module) }

  /// The name of work that completed.
  static var completed: String { String(localized: "Completed", bundle: .module) }

  /// The name of work that failed.
  static var failed: String { String(localized: "Failed", bundle: .module) }

  /// The name of work that was cancelled.
  static var cancelled: String { String(localized: "Cancelled", bundle: .module) }

  /// The name of a status that the kit does not know.
  ///
  /// - Parameter wireValue: The wire string of the status.
  /// - Returns: "Unknown status: <wireValue>".
  static func unknown(for wireValue: String) -> String {
    String(localized: "Unknown status: \(wireValue)", bundle: .module)
  }
}
