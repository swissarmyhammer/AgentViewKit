import FoundationModelsACP
import FoundationModelsACPClient

/// What the view knows about the state of a session, and how it says it.
///
/// Four cases read differently, and each one has its own text:
///
/// - ``unconfirmed``: a child that was restored and has no current snapshot
///   yet. Its state is not known yet, and the agent will send it.
/// - ``failedToRestore(reason:)``: the agent said that the child did not
///   restore, with a reason.
/// - ``stateOmitted``: the agent sent its current snapshot and left the state
///   out, so the state is unknown and stays unknown.
/// - ``known``: the state is known.
enum SessionStatus: Equatable {
  /// The child waits for its first current snapshot.
  case unconfirmed

  /// The child did not restore. The reason comes from the agent.
  case failedToRestore(reason: String)

  /// The agent confirmed the child and gave no state.
  case stateOmitted

  /// The state is known.
  case known(SessionWorkState)

  /// The status of a session.
  ///
  /// - Parameter session: The session.
  /// - Returns: The status. A root session is always `known`.
  @MainActor
  static func of(_ session: SessionModel) -> SessionStatus {
    guard session.parent != nil else { return .known(session.workState) }
    if let reason = session.restoreFailure { return .failedToRestore(reason: reason) }
    if !session.isWorkStateConfirmed { return .unconfirmed }
    if session.workState == .unknown { return .stateOmitted }
    return .known(session.workState)
  }

  /// The short text of the status, for a dropdown.
  var text: String {
    switch self {
    case .unconfirmed: String(localized: "waiting for the current state", bundle: .module)
    case .failedToRestore(let reason): String(localized: "did not restore: \(reason)", bundle: .module)
    case .stateOmitted: String(localized: "the agent gave no state", bundle: .module)
    case .known(let state): SessionStateText.text(for: state)
    }
  }

  /// Whether the state of the session is not known.
  var isUnknown: Bool {
    if case .known = self { return false }
    return true
  }
}

/// The rule for the controls of a shown session.
enum SessionControls {
  /// Tells if the composer takes input.
  ///
  /// A child session takes no prompt of the user: the client refuses it.
  /// Only a root session has a composer that works.
  ///
  /// - Parameter session: The shown session.
  /// - Returns: `true` for a root session.
  @MainActor
  static func composerEnabled(for session: SessionModel) -> Bool {
    session.parent == nil
  }

  /// Tells if the stop control of a child can work: the child is confirmed
  /// and its capabilities offer a cancel.
  ///
  /// - Parameter session: The child session.
  /// - Returns: `true` when a cancel of the child can run.
  @MainActor
  static func childCanCancel(_ session: SessionModel) -> Bool {
    session.isWorkStateConfirmed && session.capabilities?.cancel != nil
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
