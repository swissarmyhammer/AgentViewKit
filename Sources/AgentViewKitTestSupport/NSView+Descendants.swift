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

  /// Whether the class of this view is one of `types`, or a subclass of one.
  ///
  /// This is the one class match of the test support for a list of classes,
  /// such as the classes that ``hideDescendants(of:)`` hides.
  ///
  /// - Parameter types: The classes to match.
  /// - Returns: `true` when `isKind(of:)` holds for one of `types`, and
  ///   `false` for an empty list.
  func isKind(ofAny types: [AnyClass]) -> Bool {
    types.contains(where: isKind(of:))
  }

  /// Hides each view under this view whose class is one of `types`, or a
  /// subclass of one (``isKind(ofAny:)``).
  ///
  /// This is the one hide by class of the test support. A snapshot hides a
  /// view this way when the cache of a window cannot draw it, such as the
  /// scroll edge effect (``ScrollPocketProbe/hidePockets(in:)``), or when it
  /// draws different pixels on each run.
  ///
  /// - Parameter types: The classes of the views to hide. An empty list
  ///   hides no view.
  func hideDescendants(of types: [AnyClass]) {
    for view in descendants where view.isKind(ofAny: types) {
      view.isHidden = true
    }
  }
}
