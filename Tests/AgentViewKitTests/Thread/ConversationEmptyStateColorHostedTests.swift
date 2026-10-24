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
/// The empty state is in a `ScrollView`, and `ImageRenderer` does not draw
/// the content of a `ScrollView`: on macOS, a `ScrollView` is an AppKit
/// `NSScrollView`, and `ImageRenderer` does not draw an AppKit view
/// (``RenderedPixels``). Thus the test reads the cache of a window.
@Suite @MainActor struct ConversationEmptyStateColorHostedTests {
  @Test(.hostedSerially) func theEmptyStateDrawsNoPixelOfTheAccent() throws {
    let pixels = try EditorThemeViewsTests.drawnCachedPixels(of: ConversationEmptyState())

    #expect(!pixels.contains(DistinctRolesTheme.Role.accent))
  }
}
