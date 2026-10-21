import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that ``PendingRequestCountBadge`` does not use the accent of the
/// EditorKit theme (D113 answer 5).
///
/// In content, the accent marks only a link, the selection or the current
/// item. A count badge is none of these, so its text and its capsule use
/// semantic styles. The test gives the badge ``DistinctRolesTheme``, so a
/// pixel of the accent can come only from the accent role.
@Suite @MainActor struct PendingRequestCountBadgeColorTests {
  @Test func theBadgeDrawsNoPixelOfTheAccent() throws {
    let session = SessionModel.previewSample
    try #require(!session.pendingRequests.isEmpty)
    let blank = try EditorThemeViewsTests.pixels(of: Color.clear)

    let pixels = try EditorThemeViewsTests.pixels(of: PendingRequestCountBadge(session: session))

    try #require(!pixels.isClose(to: blank))
    #expect(!pixels.contains(DistinctRolesTheme.Role.accent))
  }
}
