import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The row toggle of a ``ToolCallView``: EditorKit's `EditorPlainButton`,
/// with the toggle identifier of the call (Docs/decisions/focus-audit.md,
/// "Raw controls").
///
/// Each test lays out the call in a window that is never ordered in
/// (``ControlProbe``), and reads the element of the toggle.
@MainActor @Suite struct ToolCallHeaderTests {
  /// The title of the tool call.
  static let title = "Read the parser"

  /// A production change that fails this test: the row toggle is a plain
  /// system `Button` in place of the EditorKit `EditorPlainButton`, so its
  /// title does not take the caption style of the button tokens of the
  /// theme.
  @Test func theToggleTakesTheCaptionStyleOfTheButtonTokens() async throws {
    let item = PreviewTranscriptItem.toolCall(title: Self.title, kind: .read, status: .completed)
    let entry = try #require(PreviewFixtures.entry(item, as: ToolCallEntry.self))
    let identifier = ToolCallView.toggleIdentifier(for: entry.id.rowKey)

    let frames = try #require(
      await ControlProbe.framesWithLargeButtonCaptions(of: identifier, in: ToolCallView(entry: entry)))

    #expect(frames.themed.height > frames.plain.height)
  }
}
