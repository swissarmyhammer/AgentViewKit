/// An enum that an adapter reads from a wire string and that keeps each
/// string that it does not know (plan.md §3.2).
///
/// Each enum in the model has an `unknown` case, so that a new value from a
/// newer agent is rendered and not dropped. A conforming enum lists its known
/// cases and gives the wire string of each case. The protocol then gives
/// ``init(wireValue:)``.
public nonisolated protocol WireValueEnum: Sendable, Hashable {
  /// Each case of the enum, but not the `unknown` case.
  static var knownCases: [Self] { get }

  /// The case for a wire string that is not the wire value of a known case.
  ///
  /// The `unknown(String)` case of the enum satisfies this requirement.
  ///
  /// - Parameter wireValue: The wire string, unchanged.
  /// - Returns: The `unknown` case that holds `wireValue`.
  static func unknown(_ wireValue: String) -> Self

  /// The wire string of the case.
  ///
  /// For the `unknown` case, this is the string that the case holds.
  var wireValue: String { get }
}

extension WireValueEnum {
  /// Reads a case from its wire string.
  ///
  /// - Parameter wireValue: A wire string, such as `max_tokens`.
  /// - Returns: The known case whose ``wireValue`` is equal to `wireValue`, or
  ///   ``unknown(_:)`` with `wireValue`.
  public init(wireValue: String) {
    self = Self.knownCases.first { $0.wireValue == wireValue } ?? Self.unknown(wireValue)
  }
}
