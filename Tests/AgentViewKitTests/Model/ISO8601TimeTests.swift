import AgentViewKit
import Foundation
import Testing

@Suite struct ISO8601TimeTests {
  /// The time `2026-09-16T10:00:00Z`, in seconds after 1970-01-01T00:00:00Z.
  private static let seconds: TimeInterval = 1_789_552_800

  /// The fractional seconds of the time with fractional seconds.
  private static let fraction: TimeInterval = 0.25

  @Test func readsATimeWithNoFractionalSeconds() {
    #expect(
      ISO8601Time.date(from: "2026-09-16T10:00:00Z") == Date(timeIntervalSince1970: Self.seconds))
  }

  @Test func readsATimeWithFractionalSeconds() {
    #expect(
      ISO8601Time.date(from: "2026-09-16T10:00:00.250Z")
        == Date(timeIntervalSince1970: Self.seconds + Self.fraction))
  }

  @Test func givesNilForTextThatIsNotATime() {
    #expect(ISO8601Time.date(from: "yesterday") == nil)
    #expect(ISO8601Time.date(from: "2026-09-16") == nil)
  }
}
