import AppKit

/// The hit test of a window at the center of a text view, as AppKit
/// hit-tests a click or a scroll-wheel event there (card ^9ync5h3).
@MainActor enum TextHitTest {
  /// The view that `root` hit-tests at the center of `text`.
  ///
  /// - Parameters:
  ///   - root: The view whose tree holds `text`, such as the host of a
  ///     row or of a thread.
  ///   - text: The text view.
  /// - Returns: The view that takes the point, or `nil` when no view takes
  ///   it or `root` has no superview.
  static func hit(in root: NSView, atCenterOf text: NSView) -> NSView? {
    guard let frame = root.superview else { return nil }
    let center = text.convert(CGPoint(x: text.bounds.midX, y: text.bounds.midY), to: frame)
    return root.hitTest(center)
  }

  /// Tells if a hit test reaches the view of a text: a view in the tree of
  /// `root` that is not `root`, and that does not hold the text view, such
  /// as a scroll view does.
  ///
  /// - Parameters:
  ///   - hit: The view that the hit test gave, or `nil`.
  ///   - text: The text view at whose center the hit test was made.
  ///   - root: The view whose tree holds `text`.
  /// - Returns: `true` when `hit` is the text view or a view that does not
  ///   hold it.
  static func reaches(_ hit: NSView?, text: NSView, in root: NSView) -> Bool {
    guard let hit, hit !== root else { return false }
    return hit === text || !text.isDescendant(of: hit)
  }
}
