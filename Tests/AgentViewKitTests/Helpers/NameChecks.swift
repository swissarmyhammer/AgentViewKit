import Testing

/// Checks on lists of names. The tests that make sure that each case of a
/// kit type shows its own symbol or label use it.
enum NameChecks {
  /// Expects that no two of the names are equal.
  ///
  /// - Parameters:
  ///   - names: The names to compare, such as the symbol name of each case.
  ///   - sourceLocation: The location of the caller, for the failure report.
  static func expectDistinctNames(
    _ names: [String], sourceLocation: SourceLocation = #_sourceLocation
  ) {
    #expect(Set(names).count == names.count, "\(names)", sourceLocation: sourceLocation)
  }
}
