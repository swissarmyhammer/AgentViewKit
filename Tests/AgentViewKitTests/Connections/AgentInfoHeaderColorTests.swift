import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that ``AgentInfoHeader`` does not use the accent of the EditorKit
/// theme (D113 answer 5).
///
/// In content, the accent marks only a link, the selection or the current
/// item. The symbol of the header is none of these, so it uses a semantic
/// style. The test gives the header ``DistinctRolesTheme``, so a pixel of the
/// accent can come only from the accent role.
@Suite @MainActor struct AgentInfoHeaderColorTests {
  @Test func theHeaderDrawsNoPixelOfTheAccent() throws {
    let connection = ConnectionModel.previewSample
    try #require(connection.initializeResponse?.info != nil)

    let pixels = try EditorThemeViewsTests.drawnPixels(of: AgentInfoHeader(connection: connection))

    #expect(!pixels.contains(DistinctRolesTheme.Role.accent))
  }
}
