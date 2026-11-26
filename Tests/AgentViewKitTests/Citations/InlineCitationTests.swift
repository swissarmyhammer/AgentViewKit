import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The pill of an ``InlineCitation``: an EditorKit `EditorPlainButton` whose
/// label keeps the font of the text around the pill
/// (Docs/decisions/focus-audit.md, "Raw controls").
///
/// Each test lays out the pill in a window that is never ordered in
/// (``ControlProbe``), and reads its accessibility element.
@MainActor @Suite struct InlineCitationTests {
  /// The number of the source of the pill.
  static let index = 1

  /// The frame of the pill in text of `font`.
  ///
  /// - Parameter font: The font of the text around the pill.
  /// - Returns: The frame, or `nil` when the layout has no pill.
  static func frame(in font: Font) async -> CGRect? {
    await ControlProbe.read(
      InlineCitation.identifier(index: index), in: InlineCitation(index: index).font(font), accessibilityFrame(of:))
      ?? nil
  }

  /// A production change that fails this test: the button of the pill sets
  /// its own font on the pill, such as the caption font of a plain button,
  /// so the pill does not take the size of the text around it.
  @Test func thePillTakesTheSizeOfTheTextAroundIt() async throws {
    let body = try #require(await Self.frame(in: .body))
    let largeTitle = try #require(await Self.frame(in: .largeTitle))

    #expect(largeTitle.height > body.height)
  }
}
