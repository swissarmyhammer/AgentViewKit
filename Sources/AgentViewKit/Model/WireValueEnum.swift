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

nonisolated extension WireValueEnum {
  /// Reads a case from its wire string.
  ///
  /// - Parameter wireValue: A wire string, such as `max_tokens`.
  /// - Returns: The known case whose ``wireValue`` is equal to `wireValue`, or
  ///   ``unknown(_:)`` with `wireValue`.
  public init(wireValue: String) {
    self = Self.knownCases.first { $0.wireValue == wireValue } ?? Self.unknown(wireValue)
  }
}

/// The JSON form of a wire value enum is its wire string. A string that the
/// kit does not know decodes to the `unknown` case, so decode never fails
/// for a string.
///
/// The standard library uses the same pattern for `RawRepresentable`: these
/// implementations replace the synthesized `Codable` form of the enum.
nonisolated extension WireValueEnum where Self: Codable {
  /// Decodes a case from its wire string.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` when the value is not a string.
  public init(from decoder: any Decoder) throws {
    self.init(wireValue: try String(from: decoder))
  }

  /// Encodes the wire string of the case.
  ///
  /// - Parameter encoder: The encoder to write to.
  /// - Throws: The error of the encoder.
  public func encode(to encoder: any Encoder) throws {
    try wireValue.encode(to: encoder)
  }
}
