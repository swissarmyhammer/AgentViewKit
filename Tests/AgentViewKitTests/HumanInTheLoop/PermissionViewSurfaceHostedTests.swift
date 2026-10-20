@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that the card of ``PermissionView`` is on the content surface of
/// the kit, and not on glass (D110 (b)).
///
/// Each test shows the card over the backdrop of ``GlassRenderProbeTests``
/// in an off-screen window, and reads the pixels with ``RenderedPixels``. It
/// does this one time with Reduce Transparency off and one time with it on
/// (the method of ^dbbyg9w).
///
/// The tests read the cache of the window, and not an `ImageRenderer`
/// render. The card is `focusable()`, and `ImageRenderer` does not draw a
/// focusable view. The cache of a window shows no glass
/// (``GlassRenderProbeHostedTests``). Thus a card on glass shows the
/// backdrop, and only an opaque surface hides it.
@Suite(.serialized, .hostedSerially) @MainActor struct PermissionViewSurfaceHostedTests {
  /// The size of the window. The card fills the width and is shorter than
  /// the height.
  static let size = CGSize(width: 320, height: 200)

  /// The two values of Reduce Transparency that each test shows the card
  /// with. It is `nonisolated` because the arguments of a test use it.
  nonisolated static let reduceTransparencyValues = [false, true]

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
    let card = PermissionCardWithBackdrop(request: request, session: session, placement: placement)
    return try GlassRenderProbeHostedTests.cachedPixels(
      of: GlassRenderProbeTests.pinned(card, with: .reduceTransparency, on: reducesTransparency),
      size: size)
  }

  @Test(arguments: reduceTransparencyValues)
  func theBackdropShowsWhenItIsInFrontOfTheCard(reducesTransparency: Bool) throws {
    let pixels = try Self.pixels(backdrop: .inFront, reducesTransparency: reducesTransparency)
    #expect(pixels.contains(GlassRenderProbeTests.backdrop))
  }

  @Test(arguments: reduceTransparencyValues)
  func noPixelOfTheBackdropShowsInsideTheCard(reducesTransparency: Bool) throws {
    let pixels = try Self.pixels(backdrop: .behind, reducesTransparency: reducesTransparency)
    #expect(!pixels.contains(GlassRenderProbeTests.backdrop))
  }
}

/// Where ``PermissionCardWithBackdrop`` puts its backdrop.
enum BackdropPlacement {
  /// The backdrop is behind the card. Only a card that lets the backdrop
  /// through shows its color.
  case behind
  /// The backdrop is in front of the card. The window always shows its
  /// color.
  case inFront
}

/// A ``PermissionView`` with the backdrop of ``GlassRenderProbeTests`` in the
/// frame of the card.
///
/// The backdrop is inset by the large radius of the theme from each edge of
/// the card. Thus it is not in the corners, where the rounded shape of the
/// card does not cover the frame. The backdrop is only at points that the
/// card covers.
struct PermissionCardWithBackdrop: View {
  /// The pending request that the card shows.
  let request: PendingPermissionRequest

  /// The session model that holds the request.
  let session: SessionModel

  /// Where the backdrop is.
  let placement: BackdropPlacement

  @Environment(\.agentTheme) private var theme

  var body: some View {
    switch placement {
    case .behind:
      PermissionView(request: request, session: session).background { backdrop }
    case .inFront:
      PermissionView(request: request, session: session).overlay { backdrop }
    }
  }

  /// The backdrop, inset by the large radius of the theme.
  private var backdrop: some View {
    GlassRenderProbeTests.backdrop.padding(theme.radii.l)
  }
}
