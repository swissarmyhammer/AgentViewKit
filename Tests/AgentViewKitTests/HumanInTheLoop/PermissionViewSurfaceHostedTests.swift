@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that the card of ``PermissionView`` has no fill and no glass, and
/// that the separator stroke of the content edge marks its edge (D113).
///
/// The tests use the edge check of ``ContentEdgeHostedProbe``. The card can
/// take the VoiceOver focus, so `ImageRenderer` draws nothing for it, and the
/// method reads the cache of a window.
@Suite(.serialized, .hostedSerially) @MainActor struct PermissionViewSurfaceHostedTests {
  /// The size of the window. The card fills the width and is shorter than
  /// the height.
  static let size = CGSize(width: 320, height: 200)

  /// A code-built session model that holds one permission request, with
  /// one `allow_once` option and one `reject_once` option.
  static var session: SessionModel {
    SessionModel.preview(pendingPermissions: [
      RequestPermissionRequest(
        options: [
          PermissionOption(kind: .allowOnce, name: "Allow", optionId: PermissionOptionId(rawValue: "allow")),
          PermissionOption(kind: .rejectOnce, name: "Reject", optionId: PermissionOptionId(rawValue: "reject")),
        ],
        sessionId: SessionModel.previewSessionId,
        title: "Run the database migration?"
      )
    ])
  }

  /// The card of the one request of ``session``.
  ///
  /// - Returns: The card.
  /// - Throws: An issue when the session model holds no request.
  static func card() throws -> PermissionView {
    let session = session
    let request = try #require(session.pendingPermissions.first)
    return PermissionView(request: request, session: session)
  }

  @Test func theBackdropShowsInsideTheEdgeOfTheCard() throws {
    try ContentEdgeHostedProbe.expectBackdropShowsInsideTheEdge(of: Self.card(), size: Self.size)
  }
}
