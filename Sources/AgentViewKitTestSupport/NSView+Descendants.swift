import AppKit

extension NSView {
  /// Each view under this view, in depth first order: a subview, then the
  /// views under it, then the next subview. The list does not have this
  /// view.
  ///
  /// This is the one walk of an AppKit view tree in the test support and the
  /// tests. A test that looks for a view of a class, or with an identifier,
  /// filters this list.
  public var descendants: [NSView] {
    subviews.flatMap { [$0] + $0.descendants }
  }
}
