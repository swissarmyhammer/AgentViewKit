/// Builds the accessibility identifiers of the views of the kit.
///
/// An identifier of an element that repeats, such as one card for each
/// request, is a fixed prefix and the value of the element.
nonisolated enum AccessibilityIdentifier {
  /// Makes the identifier of one element.
  ///
  /// - Parameters:
  ///   - prefix: The fixed start of the identifier, such as `pending-card-`.
  ///   - value: The value of the element, such as the identifier of a
  ///     request.
  /// - Returns: `<prefix><value>`.
  static func make(prefix: String, value: String) -> String {
    prefix + value
  }
}

/// A type whose repeated elements have the accessibility identifier
/// `<identifierPrefix><value>`.
///
/// A conforming type gets ``identifier(for:)``, so that each type does not
/// write the same builder again.
public nonisolated protocol PrefixedAccessibilityIdentifier {
  /// The fixed start of the accessibility identifier of each element.
  static var identifierPrefix: String { get }
}

extension PrefixedAccessibilityIdentifier {
  /// The accessibility identifier of the element with `value`.
  ///
  /// - Parameter value: The value of the element, such as the identifier of
  ///   a record.
  /// - Returns: `<identifierPrefix><value>`.
  public nonisolated static func identifier(for value: String) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: value)
  }
}
