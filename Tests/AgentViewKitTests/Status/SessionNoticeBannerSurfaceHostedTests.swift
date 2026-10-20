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

  /// The banner of the one notice of ``session``.
  ///
  /// - Returns: The banner.
  /// - Throws: An issue when the session model holds no notice.
  static func banner() throws -> NoticeBanner {
    let notice = try #require(session.notices.first)
    return NoticeBanner(notice: notice) {}
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func theBackdropShowsWhenItIsInFrontOfTheBanner(reducesTransparency: Bool) throws {
    try ContentSurfaceHostedProbe.expectBackdropShowsOnlyInFront(
      of: Self.banner(), backdrop: .inFront, reducesTransparency: reducesTransparency, size: Self.size)
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func noPixelOfTheBackdropShowsInsideTheBanner(reducesTransparency: Bool) throws {
    try ContentSurfaceHostedProbe.expectBackdropShowsOnlyInFront(
      of: Self.banner(), backdrop: .behind, reducesTransparency: reducesTransparency, size: Self.size)
  }
}
