import AgentViewKit

/// A ``FocusReporter`` that records each focus move.
public final class RecordingFocusReporter: FocusReporter {
  /// The identifier of each focus move, in call order.
  public private(set) var moves: [String] = []

  /// Makes a reporter with no moves.
  public init() {}

  /// Records `identifier`.
  ///
  /// - Parameter identifier: The accessibility identifier of the view that
  ///   has the focus now.
  public func focusMoved(to identifier: String) {
    moves.append(identifier)
  }

  /// Removes each recorded move.
  public func reset() {
    moves.removeAll()
  }
}
