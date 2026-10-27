import QuartzCore

extension CATransaction {
  /// Runs `changes` in a transaction with no animation: begins a
  /// transaction, turns off its actions, runs the changes and commits.
  ///
  /// This is the one transaction with no animation of the test support. A
  /// render that moves a layer or swaps its filters for a moment, such as
  /// ``LayerTreeRenderer`` and ``VibrantLabelFilters``, makes and undoes its
  /// changes this way, so that no implicit animation runs between them.
  ///
  /// - Parameter changes: The layer changes.
  static func withoutActions(_ changes: () -> Void) {
    begin()
    setDisableActions(true)
    changes()
    commit()
  }
}
