import AgentViewKitTestSupport
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The tab chip of a field of a form that shows tabs: an EditorKit
/// `EditorPlainButton` (Docs/decisions/focus-audit.md, "Raw controls").
///
/// Each test lays out the chip in a window that is never ordered in
/// (``ControlProbe``), and reads its accessibility element.
@MainActor @Suite struct ElicitationTabChipTests {
  /// The property name of the field of the chip.
  static let name = "field"

  /// The chip of a text field.
  static var chip: ElicitationTabChip {
    let schema = ElicitationTestFields.field(ElicitationTestFields.text(), name: name)
    return ElicitationTabChip(
      field: ElicitationFieldContext(schema: schema, value: AnswerBox().binding), isSelected: true) {}
  }

  /// A production change that fails this test: the chip is a plain system
  /// `Button` in place of the EditorKit `EditorPlainButton`, so its title
  /// does not take the caption style of the button tokens of the theme.
  @Test func theChipTakesTheCaptionStyleOfTheButtonTokens() async throws {
    let frames = try #require(
      await ControlProbe.framesWithLargeButtonCaptions(
        of: ElicitationView.tabIdentifier(for: Self.name), in: Self.chip))

    #expect(frames.themed.width > frames.plain.width)
  }
}
