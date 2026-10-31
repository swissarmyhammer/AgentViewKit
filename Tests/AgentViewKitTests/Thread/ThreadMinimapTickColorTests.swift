import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Checks the tick color of a message and the color of the viewport band in
/// the minimap.
///
/// The accent of the EditorKit theme is only for the selection and the focus
/// (card ^y2mrfxt). A message tick and the band of the rows in view are
/// neither, so a user tick is the foreground of the theme, an agent tick is its
/// secondary foreground, and the band is its foreground. The tests give
/// ``DistinctRolesTheme``, which has a different color for each role.
@Suite @MainActor struct ThreadMinimapTickColorTests {
  /// A theme with a different color for each role.
  static let theme = DistinctRolesTheme()

  /// The first entry of the preview transcript that `matches` accepts.
  ///
  /// - Parameter matches: The test of the case of an entry.
  /// - Returns: The entry.
  /// - Throws: An error when no entry of the preview transcript matches.
  static func previewEntry(where matches: (TranscriptEntry) -> Bool) throws -> TranscriptEntry {
    let entry = SessionModel.previewSample.transcript.first(where: matches)
    return try #require(entry)
  }

  @Test func aUserMessageTickIsTheEditorForeground() throws {
    let entry = try Self.previewEntry { if case .userMessage = $0 { true } else { false } }

    #expect(ThreadMinimapView.tint(of: entry, in: Self.theme) == Self.theme.editorForeground)
  }

  @Test func anAgentMessageTickIsTheSecondaryForeground() throws {
    let entry = try Self.previewEntry { if case .agentMessage = $0 { true } else { false } }

    #expect(ThreadMinimapView.tint(of: entry, in: Self.theme) == Self.theme.secondaryForeground)
  }

  @Test func theViewportBandIsTheEditorForegroundAndNotTheAccent() {
    #expect(ThreadMinimapView.bandColor(in: Self.theme) == Self.theme.editorForeground)
  }
}
