import Foundation

/// The times of a timed scripted session: the first time its `FixedClock`
/// starts at, and the step the clock moves between two events of the turn.
///
/// The timing tests, the inspection tests and the timed gallery fixtures
/// share these, so each entry they time starts at one known time and takes
/// one known duration.
public nonisolated enum TimedSessionClock {
  /// The seconds of ``start`` after the reference date of `Date`.
  private static let startSecondsSinceReferenceDate: TimeInterval = 800_000_000

  /// The first time of the clock.
  public static let start = Date(timeIntervalSinceReferenceDate: startSecondsSinceReferenceDate)

  /// The time the clock moves between two events, in seconds: one minute
  /// and fifteen seconds, so a duration shows both its minutes and its
  /// seconds.
  public static let stepSeconds: TimeInterval = 75
}
