import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that ``AgentInfoHeader`` does not use the accent of the EditorKit
/// theme (D113 answer 5).
///
/// The accent is only for the selection and the focus (card ^y2mrfxt). The
/// symbol of the header is neither of these, so it uses a semantic
/// style. The test gives the header ``DistinctRolesTheme``, so a pixel of the
/// accent can come only from the accent role. The test captures the header in
/// a real window (``EditorThemeViewsTests``).
@Suite(.serialized, .hostedSerially) @MainActor struct AgentInfoHeaderColorTests {
  @Test func theHeaderDrawsNoPixelOfTheAccent() async throws {
    let connection = ConnectionModel.previewSample
    try #require(connection.initializeResponse?.info != nil)

    let image = try await EditorThemeViewsTests.drawnCapture(of: AgentInfoHeader(connection: connection))

    #expect(try !EditorThemeViewsTests.contains(image, DistinctRolesTheme.Role.accent))
  }
}
