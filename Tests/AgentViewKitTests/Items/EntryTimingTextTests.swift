@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import Testing

/// The text of the time of a transcript entry: the visible line and the
/// VoiceOver label, each one localized string over Foundation format styles,
/// and the "Thought for N seconds" title of a thought.
///
/// The texts come from the system formatters, so the tests give the English
/// locale of the United States and the GMT time zone, where
/// ``TimedSessionClock/start`` is 6:13 AM.
@Suite struct EntryTimingTextTests {
  /// The locale of the tests.
  static let locale = Locale(identifier: "en_US")

  /// The time zone of the tests.
  static let timeZone = TimeZone.gmt

  /// The offset from GMT of the zone of the time zone test, in seconds:
  /// three hours.
  static let shiftedZoneSeconds = 3 * 60 * 60

  /// The short time of ``start`` in the zone of the time zone test.
  static let shiftedStartText = "9:13\u{202F}AM"

  /// A start time of the tests.
  static let start = TimedSessionClock.start

  /// The short time of ``start`` in ``locale`` and ``timeZone``. The system
  /// formatter puts a narrow no-break space before the day period.
  static let startText = "6:13\u{202F}AM"

  /// A duration of one minute and fifteen seconds.
  static let minuteAndQuarter = TimedSessionClock.stepSeconds

  /// A duration of seven seconds.
  static let sevenSeconds: TimeInterval = 7

  /// A duration that rounds to zero seconds.
  static let tooShort: TimeInterval = 0.2

  /// A duration that rounds to one second.
  static let almostOneSecond: TimeInterval = 0.6

  /// The visible line of a start time and a duration in the locale and the
  /// time zone of the tests.
  ///
  /// - Parameters:
  ///   - startedAt: The start time, or `nil`.
  ///   - duration: The duration in seconds, or `nil`.
  /// - Returns: The line, or `nil` when the view shows nothing.
  static func line(startedAt: Date?, duration: TimeInterval?) -> String? {
    EntryTimingView.lineText(startedAt: startedAt, duration: duration, locale: locale, timeZone: timeZone)
  }

  /// The VoiceOver label of a start time and a duration in the locale and
  /// the time zone of the tests.
  ///
  /// - Parameters:
  ///   - startedAt: The start time, or `nil`.
  ///   - duration: The duration in seconds, or `nil`.
  /// - Returns: The label, or `nil` when the view shows nothing.
  static func label(startedAt: Date?, duration: TimeInterval?) -> String? {
    EntryTimingView.accessibilityLabel(startedAt: startedAt, duration: duration, locale: locale, timeZone: timeZone)
  }

  @Test func theLineShowsTheStartAndTheAbbreviatedDuration() {
    #expect(Self.line(startedAt: Self.start, duration: Self.minuteAndQuarter) == "\(Self.startText) · 1m 15s")
  }

  @Test func theLineOfAnEntryWithNoDurationShowsOnlyTheStart() {
    #expect(Self.line(startedAt: Self.start, duration: nil) == Self.startText)
  }

  @Test func theLineOfAnEntryWithATooShortDurationShowsOnlyTheStart() {
    #expect(Self.line(startedAt: Self.start, duration: Self.tooShort) == Self.startText)
  }

  @Test func theLineOfADurationWithNoStartShowsOnlyTheDuration() {
    #expect(Self.line(startedAt: nil, duration: Self.minuteAndQuarter) == "1m 15s")
  }

  @Test func theShortestShownDurationShowsOneSecond() {
    #expect(Self.line(startedAt: nil, duration: EntryTimingView.shortestShownDuration) == "1s")
  }

  @Test func withNoStartAndNoShownDurationThereIsNoLine() {
    #expect(Self.line(startedAt: nil, duration: Self.tooShort) == nil)
  }

  @Test func theStartShowsTheClockTimeOfTheTimeZone() throws {
    let zone = try #require(TimeZone(secondsFromGMT: Self.shiftedZoneSeconds))
    let line = EntryTimingView.lineText(startedAt: Self.start, duration: nil, locale: Self.locale, timeZone: zone)

    #expect(line == Self.shiftedStartText)
  }

  @Test func aDurationThatRoundsToZeroSecondsIsNotShown() {
    #expect(EntryTimingView.shownDuration(Self.tooShort) == nil)
    #expect(EntryTimingView.shownDuration(nil) == nil)
    #expect(EntryTimingView.shownDuration(Self.almostOneSecond) == Self.almostOneSecond)
  }

  @Test func theSpokenDurationIsTheWideTextOfTheShownDuration() {
    #expect(EntryTimingView.spokenDuration(Self.minuteAndQuarter, locale: Self.locale) == "1 minute, 15 seconds")
  }

  @Test func aDurationThatIsNotShownHasNoSpokenText() {
    #expect(EntryTimingView.spokenDuration(Self.tooShort, locale: Self.locale) == nil)
    #expect(EntryTimingView.spokenDuration(nil, locale: Self.locale) == nil)
  }

  @Test func theLabelTellsTheStartAndTheDurationInWords() {
    #expect(
      Self.label(startedAt: Self.start, duration: Self.minuteAndQuarter)
        == "Started at \(Self.startText), took 1 minute, 15 seconds")
  }

  @Test func theLabelOfAnEntryWithNoDurationTellsOnlyTheStart() {
    #expect(Self.label(startedAt: Self.start, duration: nil) == "Started at \(Self.startText)")
  }

  @Test func theLabelOfAnEntryWithATooShortDurationTellsOnlyTheStart() {
    #expect(Self.label(startedAt: Self.start, duration: Self.tooShort) == "Started at \(Self.startText)")
  }

  @Test func theLabelOfADurationWithNoStartTellsOnlyTheDuration() {
    #expect(Self.label(startedAt: nil, duration: Self.sevenSeconds) == "Took 7 seconds")
  }

  @Test func withNoStartAndNoShownDurationThereIsNoLabel() {
    #expect(Self.label(startedAt: nil, duration: nil) == nil)
  }

  @Test func theDurationPhraseHoldsTheSpokenDuration() {
    let phrase = EntryTimingView.durationPhrase(
      Self.minuteAndQuarter, locale: Self.locale, phrase: { "Took \($0)" }, fallback: { "No time" })

    #expect(phrase == "Took 1 minute, 15 seconds")
  }

  @Test func theDurationPhraseIsTheFallbackWhenTheDurationIsNotShown() {
    let tooShort = EntryTimingView.durationPhrase(
      Self.tooShort, locale: Self.locale, phrase: { "Took \($0)" }, fallback: { "No time" })
    let missing = EntryTimingView.durationPhrase(
      nil, locale: Self.locale, phrase: { "Took \($0)" }, fallback: { "No time" })

    #expect(tooShort == "No time")
    #expect(missing == "No time")
  }

  @Test func theThoughtTitleTellsTheDurationInWholeWords() {
    #expect(ReasoningView.completedTitle(duration: Self.sevenSeconds) == "Thought for 7 seconds")
    #expect(ReasoningView.completedTitle(duration: Self.minuteAndQuarter) == "Thought for 1 minute, 15 seconds")
    #expect(ReasoningView.completedTitle(duration: nil) == "Thought")
  }
}
