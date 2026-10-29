@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that the banner of a notice in ``SessionNoticeBanner`` has no fill
/// and no glass, and that the separator stroke of the content edge marks its
/// edge (D113).
///
/// The tests use the edge check of ``ContentEdgeHostedProbe``. They show
/// one ``NoticeBanner``, because ``SessionNoticeBanner`` puts a margin around
/// its banners, and the edge check needs a banner that fills the width of
/// the window.
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

  @Test func theBackdropShowsInsideTheEdgeOfTheBanner() async throws {
    try await ContentEdgeHostedProbe.expectBackdropShowsInsideTheEdge(of: Self.banner(), size: Self.size)
  }
}
