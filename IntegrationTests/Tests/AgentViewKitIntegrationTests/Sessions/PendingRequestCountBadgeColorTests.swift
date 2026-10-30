import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that ``PendingRequestCountBadge`` does not use the accent of the
/// EditorKit theme (D113 answer 5).
///
/// The accent is only for the selection and the focus (card ^y2mrfxt). A
/// count badge is neither of these, so its text and its capsule use
/// semantic styles. The test gives the badge ``DistinctRolesTheme``, so a
/// pixel of the accent can come only from the accent role. The test captures
/// the badge in a real window (``EditorThemeViewsTests``).
@Suite(.serialized, .hostedSerially) @MainActor struct PendingRequestCountBadgeColorTests {
  @Test func theBadgeDrawsNoPixelOfTheAccent() async throws {
    let session = SessionModel.previewSample
    try #require(!session.pendingRequests.isEmpty)

    let image = try await EditorThemeViewsTests.drawnCapture(of: PendingRequestCountBadge(session: session))

    #expect(try !EditorThemeViewsTests.contains(image, DistinctRolesTheme.Role.accent))
  }
}
