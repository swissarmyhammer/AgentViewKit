import FoundationModelsACP
import FoundationModelsACPClient

/// Which session of a tree a window shows, and the rules that change it.
///
/// The choice is state of the view and not of the model, so two windows can
/// show different sessions of one connection. The value keeps ids and no
/// model: it remembers the ids of the path from the root to the chosen
/// session, and ``resolve(in:)`` looks them up in the live tree each time.
/// Thus a root that was closed and opened again with the same id works with
/// the new tree and never with the old one.
///
/// The rules:
///
/// - ``choose(_:)`` shows the session that the user chose.
/// - After a resume, ``resumeEnded()`` shows the root again. A child that
///   needs the user shows through its mark and the jump of the banner. The
///   state of a child never changes the choice, so a child that needs the
///   user does not steal the focus.
/// - A chosen session that the client removed gives way to the nearest
///   session of its path that is still in the tree and open: its parent, and
///   so on up to the root.
///
/// The model is parent and child all the way down, so the rules do not know a
/// number of levels.
struct SessionFocus: Equatable {
  /// The ids of the path from the root to the chosen session, or empty when
  /// the root is shown.
  private(set) var path: [SessionId] = []

  /// Shows a session that the user chose.
  ///
  /// - Parameter session: The chosen session.
  mutating func choose(_ session: SessionModel) {
    path = session.pathModels.map(\.sessionId)
  }

  /// Shows the root again, as after a resume.
  mutating func resumeEnded() {
    path = []
  }

  /// The session to show now.
  ///
  /// - Parameter root: The live root of the tree.
  /// - Returns: The last session of the chosen path that the live tree
  ///   still holds and that is open, or the root.
  func resolve(in root: SessionModel) -> SessionModel {
    for id in path.reversed() {
      if let found = root.session(withId: id), !found.isClosed { return found }
    }
    return root
  }
}
