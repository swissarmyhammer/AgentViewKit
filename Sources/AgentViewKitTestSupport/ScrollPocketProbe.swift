import AppKit

/// The scroll edge effect of a scroll view, read from PRIVATE AppKit state.
///
/// This type is the only code in the kit that reads or changes private
/// AppKit state for the scroll edge effect. Neither AppKit nor SwiftUI has a
/// public getter of the effect: `NSScrollEdgeEffectStyle` (macOS 26.1) has no
/// reader on `NSScrollView`, and SwiftUI's `scrollEdgeEffectStyle(_:for:)`
/// only writes. AppKit keeps the effect of each edge in an `NSScrollPocket`,
/// a subview of the scroll view, with its `edge` and `style` integers.
///
/// The values below were measured on macOS 26 with
/// `scrollEdgeEffectStyle(_:for:)`: `.automatic` gives the style 0, `.soft`
/// gives 1 and `.hard` gives 2. The pocket of the top edge has the edge 0,
/// and the pocket of the bottom edge has the edge 1. When AppKit changes this
/// state, the tests that use the type fail with no pocket found, and this
/// type is the one to update.
@MainActor public enum ScrollPocketProbe {
  /// The `edge` value of the pocket of the top edge.
  public static let topEdge = 0

  /// The `edge` value of the pocket of the bottom edge.
  public static let bottomEdge = 1

  /// The `style` value of the soft scroll edge effect.
  public static let softStyle = 1

  /// The name of the private AppKit class of the pocket of one edge.
  static let pocketClassName = "NSScrollPocket"

  /// The key of the edge of a pocket.
  static let edgeKey = "edge"

  /// The key of the style of a pocket.
  static let styleKey = "style"

  /// The style of each pocket of `scrollView`, by edge.
  ///
  /// - Parameter scrollView: The scroll view whose pockets the probe reads.
  /// - Returns: The `style` of each pocket, keyed by its `edge`, or an empty
  ///   dictionary when the scroll view has no pocket.
  public static func styles(of scrollView: NSScrollView) -> [Int: Int] {
    let pairs = pockets(in: scrollView.subviews).compactMap { pocket in
      (pocket.value(forKey: edgeKey) as? Int).flatMap { edge in
        (pocket.value(forKey: styleKey) as? Int).map { style in (edge, style) }
      }
    }
    return Dictionary(pairs) { first, _ in first }
  }

  /// Hides each pocket under `root`, so that the cache of the window draws
  /// no scroll edge effect.
  ///
  /// The cache of a window cannot draw the effect. The backdrop layer of a
  /// soft effect leaves an empty image with only the gradient of the effect.
  ///
  /// - Parameter root: The view whose subtree the probe changes.
  public static func hidePockets(in root: NSView) {
    for pocket in pockets(in: descendants(of: root)) {
      pocket.isHidden = true
    }
  }

  /// The pockets in `views`.
  ///
  /// - Parameter views: The views to filter.
  /// - Returns: Each view in `views` of the pocket class, or an empty array
  ///   when AppKit has no such class.
  static func pockets(in views: [NSView]) -> [NSView] {
    let pocketClass: AnyClass? = NSClassFromString(pocketClassName)
    return views.filter { view in pocketClass.map { view.isKind(of: $0) } ?? false }
  }

  /// Each view under `root`, in depth first order.
  ///
  /// - Parameter root: The root of the subtree.
  /// - Returns: The subviews of `root` and their subviews, not `root`.
  static func descendants(of root: NSView) -> [NSView] {
    root.subviews.flatMap { [$0] + descendants(of: $0) }
  }
}
