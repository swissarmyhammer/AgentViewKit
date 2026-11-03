import FoundationModelsACP
import FoundationModelsACPClient

/// How the views say the status of a session.
///
/// The client gives the status (`SessionModel.status`, `SessionPathEntry.status`).
/// Four unknown cases read differently, and each one has its own text:
///
/// - `.unconfirmed`: a child that was restored and has no current snapshot
///   yet. Its state is not known yet, and the agent will send it.
/// - `.restoreFailed(reason:)`: the agent said that the child did not
///   restore, with a reason.
/// - `.unknown`: the agent sent its current snapshot and left the state out,
///   so the state is unknown and stays unknown.
extension SessionStatus {
  /// The short text of the status, for a dropdown.
  var text: String {
    switch self {
    case .running: SessionStateText.text(for: .running)
    case .requiresAction: SessionStateText.text(for: .requiresAction)
    case .idle(let stopReason, let error): SessionStateText.text(for: .idle(stopReason: stopReason, error: error))
    case .unconfirmed: String(localized: "waiting for the current state", bundle: .module)
    case .restoreFailed(let reason): String(localized: "did not restore: \(reason)", bundle: .module)
    case .unknown: String(localized: "the agent gave no state", bundle: .module)
    }
  }
}

extension SessionPathEntry {
  /// The status of the session of this entry, with the same rules as
  /// `SessionModel.status`.
  var status: SessionStatus {
    if let restoreFailure { return .restoreFailed(reason: restoreFailure) }
    if !isConfirmed { return .unconfirmed }
    return switch workState {
    case .running: .running
    case .requiresAction: .requiresAction
    case .idle(let stopReason, let error): .idle(stopReason: stopReason, error: error)
    case .unknown: .unknown
    }
  }
}

/// The menu of the children of the shown session.
enum ChildrenMenu {
  /// The most children that the menu lists. The jump command searches the
  /// rest.
  static let limit = 12

  /// Splits the children into the ones that the menu lists and the count of
  /// the others.
  ///
  /// - Parameters:
  ///   - children: The children, in announce order.
  ///   - limit: The most entries to list.
  /// - Returns: The listed entries, and how many more there are.
  static func split(_ children: [SessionPathEntry], limit: Int = limit) -> (listed: [SessionPathEntry], more: Int) {
    (Array(children.prefix(limit)), max(0, children.count - limit))
  }
}
