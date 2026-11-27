@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI

/// The list of Jump to Session for the review gallery (^vkcj2qh): the eight
/// sessions of ``SessionJumpListFixtures``, each with a long path, at a
/// narrow width and at the normal width.
///
/// At the narrow width each path is wider than its row. The image shows that
/// no label of a row stands over another row.
@MainActor
enum SessionJumpListGalleryFixtures {
  /// The jump list of the descendants of `session`.
  ///
  /// - Parameter session: The scripted session of ``SessionJumpListFixtures``.
  /// - Returns: The list.
  static func gallery(of session: ScriptedSession) -> some View {
    SessionJumpList(agent: SessionJumpListFixtures.agent, entries: session.model.jumpEntries) { _ in }
  }

  /// The normal width of the list, in points.
  static let normalWidth: CGFloat = 640

  /// The height of each image, in points: tall enough for each row of the
  /// tree.
  static let height: CGFloat = 600

  /// The width of an image of the list.
  enum Width: CaseIterable, Sendable {
    /// The normal width, ``normalWidth``.
    case normal

    /// The narrow width: the least width of the list, at which each path is
    /// wider than its row.
    case narrow

    /// The name of the image.
    var name: String {
      switch self {
      case .normal: "session-jump-list"
      case .narrow: "session-jump-list-narrow"
      }
    }

    /// The size of the image, in points.
    @MainActor var size: CGSize {
      switch self {
      case .normal: CGSize(width: normalWidth, height: height)
      case .narrow: CGSize(width: SessionJumpList.minimumWidth, height: height)
      }
    }
  }
}
