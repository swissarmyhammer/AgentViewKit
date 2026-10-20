@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that the card of ``PermissionView`` is on the content surface of
/// the kit, and not on glass (D110 (b)).
///
/// The tests use the method of ``ContentSurfaceHostedProbe``. The card is
/// `focusable()`, so the method reads the cache of a window.
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
        title: "Run swift test?"
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

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func theBackdropShowsWhenItIsInFrontOfTheCard(reducesTransparency: Bool) throws {
    try ContentSurfaceHostedProbe.expectBackdropShowsOnlyInFront(
      of: Self.card(), backdrop: .inFront, reducesTransparency: reducesTransparency, size: Self.size)
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func noPixelOfTheBackdropShowsInsideTheCard(reducesTransparency: Bool) throws {
    try ContentSurfaceHostedProbe.expectBackdropShowsOnlyInFront(
      of: Self.card(), backdrop: .behind, reducesTransparency: reducesTransparency, size: Self.size)
  }
}
