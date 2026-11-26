import AppKit

/// The text views of a view tree, for the tests that count the EditorKit
/// editors of a row.
enum TextViewTree {
  /// The text views in the view tree under `view`.
  ///
  /// - Parameter view: The root of the tree.
  /// - Returns: Each text view of the tree.
  static func textViews(in view: NSView) -> [NSTextView] {
    let own = (view as? NSTextView).map { [$0] } ?? []
    return own + view.subviews.flatMap { textViews(in: $0) }
  }
}
