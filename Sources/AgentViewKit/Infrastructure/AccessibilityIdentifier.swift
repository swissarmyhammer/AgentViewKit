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
