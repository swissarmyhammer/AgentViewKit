@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that the banner of a notice in ``SessionNoticeBanner`` is on the
/// content surface of the kit, and not on glass (D110 (b)).
///
/// The tests use the method of ``ContentSurfaceHostedProbe``. They show one
/// ``NoticeBanner``, because ``SessionNoticeBanner`` puts a margin with no
/// surface around its banners.
@Suite(.serialized, .hostedSerially) @MainActor struct SessionNoticeBannerSurfaceHostedTests {
  /// The size of the window. The banner fills the width and is shorter than
  /// the height.
  static let size = CGSize(width: 320, height: 160)

  /// A code-built session model that holds one warning notice with a
  /// description.
  static var session: SessionModel {
    let notice = Notice(
      severity: .warning, title: "The context is almost full",
      description: "The agent compacts the context before the next prompt.")
    return SessionModel.preview(transcript: [.update(.notice(notice))])
  }

  /// The pixels of the banner with the backdrop, in light mode, with only
  /// Reduce Transparency changed.
  ///
  /// - Parameters:
  ///   - placement: Where the backdrop is.
  ///   - reducesTransparency: Whether Reduce Transparency is on.
  /// - Returns: The pixels.
  /// - Throws: An issue when the session model holds no notice, or AppKit
  ///   gives no pixels.
  static func pixels(backdrop placement: BackdropPlacement, reducesTransparency: Bool) throws
    -> RenderedPixels
  {
    let notice = try #require(session.notices.first)
    return try ContentSurfaceHostedProbe.pixels(
      of: NoticeBanner(notice: notice) {}, backdrop: placement,
      reducesTransparency: reducesTransparency, size: size)
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func theBackdropShowsWhenItIsInFrontOfTheBanner(reducesTransparency: Bool) throws {
    let pixels = try Self.pixels(backdrop: .inFront, reducesTransparency: reducesTransparency)
    #expect(pixels.contains(GlassRenderProbeTests.backdrop))
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func noPixelOfTheBackdropShowsInsideTheBanner(reducesTransparency: Bool) throws {
    let pixels = try Self.pixels(backdrop: .behind, reducesTransparency: reducesTransparency)
    #expect(!pixels.contains(GlassRenderProbeTests.backdrop))
  }
}
