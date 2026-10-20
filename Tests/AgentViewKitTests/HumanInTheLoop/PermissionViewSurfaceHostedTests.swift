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

  /// The pixels of the card with the backdrop, in light mode, with only
  /// Reduce Transparency changed.
  ///
  /// - Parameters:
  ///   - placement: Where the backdrop is.
  ///   - reducesTransparency: Whether Reduce Transparency is on.
  /// - Returns: The pixels.
  /// - Throws: An issue when the session model holds no request, or AppKit
  ///   gives no pixels.
  static func pixels(backdrop placement: BackdropPlacement, reducesTransparency: Bool) throws
    -> RenderedPixels
  {
    let session = session
    let request = try #require(session.pendingPermissions.first)
    return try ContentSurfaceHostedProbe.pixels(
      of: PermissionView(request: request, session: session), backdrop: placement,
      reducesTransparency: reducesTransparency, size: size)
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func theBackdropShowsWhenItIsInFrontOfTheCard(reducesTransparency: Bool) throws {
    let pixels = try Self.pixels(backdrop: .inFront, reducesTransparency: reducesTransparency)
    #expect(pixels.contains(GlassRenderProbeTests.backdrop))
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func noPixelOfTheBackdropShowsInsideTheCard(reducesTransparency: Bool) throws {
    let pixels = try Self.pixels(backdrop: .behind, reducesTransparency: reducesTransparency)
    #expect(!pixels.contains(GlassRenderProbeTests.backdrop))
  }
}
