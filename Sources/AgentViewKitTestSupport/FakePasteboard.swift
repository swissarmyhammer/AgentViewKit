import AgentViewKit

/// A ``Pasteboard`` that records each copy and writes nothing to the system.
public final class FakePasteboard: Pasteboard {
  /// The text of each ``copyText(_:)`` call, in call order.
  public private(set) var copies: [String] = []

  /// The text of the last copy, or `nil` before the first copy.
  public var contents: String? { copies.last }

  /// Makes a pasteboard with no copies.
  public init() {}

  /// Records `text`.
  ///
  /// - Parameter text: The copied text.
  public func copyText(_ text: String) {
    copies.append(text)
  }

  /// Removes each recorded copy.
  public func reset() {
    copies.removeAll()
  }
}
