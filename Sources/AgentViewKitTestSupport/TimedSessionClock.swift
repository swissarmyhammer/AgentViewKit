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

  /// The difference, in seconds, between the offset from GMT of the
  /// machine's time zone at ``start`` and the offset of
  /// ``zoneOtherThanTheMachines()``: three hours, so the two zones show two
  /// different clock times of ``start``.
  public static let zoneShiftSeconds = Int(Measurement(value: zoneShiftHours, unit: UnitDuration.hours).converted(to: .seconds).value)

  /// The hours of ``zoneShiftSeconds``.
  private static let zoneShiftHours: Double = 3

  /// A time zone whose clock time of ``start`` is not the clock time of the
  /// machine's time zone: its offset from GMT is ``zoneShiftSeconds`` more.
  /// A test that gives it to the environment of a view shows that the view
  /// takes the zone of its environment.
  ///
  /// - Returns: The zone, or `nil` when the offset is out of the range of a
  ///   time zone.
  public static func zoneOtherThanTheMachines() -> TimeZone? {
    TimeZone(secondsFromGMT: TimeZone.current.secondsFromGMT(for: start) + zoneShiftSeconds)
  }
}
