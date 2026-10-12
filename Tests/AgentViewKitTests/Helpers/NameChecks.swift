import Testing

/// Checks on lists of names and other values. The tests that make sure that
/// each case of a kit type shows its own symbol, label, or key use it.
enum NameChecks {
  /// Expects that no two of the names are equal.
  ///
  /// - Parameters:
  ///   - names: The names to compare, such as the symbol name of each case.
  ///   - sourceLocation: The location of the caller, for the failure report.
  static func expectDistinctNames(
    _ names: [String], sourceLocation: SourceLocation = #_sourceLocation
  ) {
    expectDistinct(names, sourceLocation: sourceLocation)
  }

  /// Expects that no two of the values are equal.
  ///
  /// Use it for values that are not names, such as the position of each row
  /// in a table or the file of each attachment.
  ///
  /// - Parameters:
  ///   - values: The values to compare.
  ///   - sourceLocation: The location of the caller, for the failure report.
  static func expectDistinct<Value: Hashable>(
    _ values: [Value], sourceLocation: SourceLocation = #_sourceLocation
  ) {
    #expect(Set(values).count == values.count, "\(values)", sourceLocation: sourceLocation)
  }
}
