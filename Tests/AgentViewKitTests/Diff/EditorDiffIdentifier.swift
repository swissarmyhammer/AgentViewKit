import EditorSwiftUI

/// The accessibility identifiers of the EditorKit `DiffView`.
///
/// The kit also has a type with the name `DiffView`. This file does not
/// import AgentViewKit, so the name `DiffView` here is the EditorKit view.
/// EditorKit puts these identifiers on its AppKit views. A hosted test finds
/// them with `HostedViewHarness.views(withAccessibilityIdentifier:)`.
enum EditorDiffIdentifier {
  /// The identifier of the root of the EditorKit diff view, in both layouts.
  static let root = DiffView.accessibilityIdentifier

  /// The identifier of the old column of the side-by-side layout.
  static let oldColumn = DiffView.oldColumnAccessibilityIdentifier

  /// The identifier of the new column of the side-by-side layout.
  static let newColumn = DiffView.newColumnAccessibilityIdentifier
}
