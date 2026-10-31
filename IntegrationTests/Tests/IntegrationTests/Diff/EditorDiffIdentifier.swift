import EditorSwiftUI
import EditorTestSupport

/// The accessibility identifiers and the gutter column ids of the EditorKit
/// `DiffView`.
///
/// The kit also has a type with the name `DiffView`. This file does not
/// import AgentViewKit, so the name `DiffView` here is the EditorKit view.
/// EditorKit puts these identifiers on its AppKit views. A hosted test finds
/// them with `views(withAccessibilityIdentifier:in:)` of EditorTestSupport.
enum EditorDiffIdentifier {
  /// The identifier of the root of the EditorKit diff view, in both layouts.
  static let root = DiffView.accessibilityIdentifier

  /// The identifier of the old column of the side-by-side layout.
  static let oldColumn = DiffView.oldColumnAccessibilityIdentifier

  /// The identifier of the new column of the side-by-side layout.
  static let newColumn = DiffView.newColumnAccessibilityIdentifier

  /// The id of the one line-number gutter column of the inline layout,
  /// `diff.line`. A hosted test reads its glyph rows from the gutter lane.
  static let inlineLineNumbers = DiffLineNumbers.Side.inline.columnID

  /// The ids of the old and the new line-number gutter columns of the
  /// side-by-side layout, `diff.old` and `diff.new`.
  static let sideBySideLineNumbers = [
    DiffLineNumbers.Side.old.columnID,
    DiffLineNumbers.Side.new.columnID,
  ]
}
