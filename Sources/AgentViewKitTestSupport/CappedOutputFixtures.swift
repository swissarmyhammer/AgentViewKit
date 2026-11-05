import AgentViewKit

/// The capped output of a command that the button suites and the review
/// gallery share: more rows than its limit, so the output shows its cap row
/// with the Show All button.
///
/// Each suite reads the fixture from here, so that a change to it is made in
/// one place.
public enum CappedOutputFixtures {
  /// The output: four rows.
  public static let output = "one\ntwo\nthree\nfour"

  /// The row limit of the output: fewer rows than ``output`` has.
  public static let rowLimit = 2

  /// The rows of ``output`` that show under ``rowLimit``.
  public static var rows: CommandOutputView.VisibleRows {
    CommandOutputView.VisibleRows(output: output, limit: rowLimit)
  }
}
