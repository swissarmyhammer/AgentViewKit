import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Checks that ``ConversationEmptyState`` does not use the accent of the
/// EditorKit theme (D113 answer 5).
///
/// The accent is only for the selection and the focus (card ^y2mrfxt). The
/// symbol of the empty state is neither of these, so it uses a
/// semantic style. The standard content has a symbol and no link. The test
/// gives the empty state ``DistinctRolesTheme``, so a pixel of the accent can
/// come only from the accent role.
///
/// The empty state is in a `ScrollView`, an AppKit `NSScrollView` on macOS,
/// so the test captures it in a real window, where the window server draws
/// the content of the scroll view (``EditorThemeViewsTests``).
@Suite(.serialized, .hostedSerially) @MainActor struct ConversationEmptyStateColorHostedTests {
  @Test func theEmptyStateDrawsNoPixelOfTheAccent() async throws {
    let image = try await EditorThemeViewsTests.drawnCapture(of: ConversationEmptyState())

    #expect(try !EditorThemeViewsTests.contains(image, DistinctRolesTheme.Role.accent))
  }
}
