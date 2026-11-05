@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import Testing

/// The text of the time of a transcript entry: the formats of the start time
/// and the duration that EditorKit's `DateText` and `DurationText` show, the
/// VoiceOver label, and the "Thought for N seconds" title of a thought.
///
/// The texts come from the system formatters, so the tests give the English
/// locale of the United States.
@Suite struct EntryTimingTextTests {
  /// The locale of the tests.
  static let locale = Locale(identifier: "en_US")

  /// A start time of the tests.
  static let start = TimedSessionClock.start

  /// A duration of one minute and fifteen seconds.
  static let minuteAndQuarter = TimedSessionClock.stepSeconds

  /// A duration of seven seconds.
  static let sevenSeconds: TimeInterval = 7

  /// A duration that rounds to zero seconds.
  static let tooShort: TimeInterval = 0.2

  /// A duration that rounds to one second.
  static let almostOneSecond: TimeInterval = 0.6

  /// The text of ``start`` in the start format of the view.
  static var startText: String {
    EntryTimingView.startFormat.format(start, locale: locale)
  }

  @Test func theStartFormatIsTheShortTimeOfTheDate() {
    let expected = Self.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Self.locale))

    #expect(Self.startText == expected)
  }

  @Test func theDurationFormatShowsMinutesAndSeconds() {
    #expect(EntryTimingView.durationFormat.locale(Self.locale).format(.seconds(Self.minuteAndQuarter)) == "1:15")
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

  @Test func theLabelTellsTheStartAndTheDuration() {
    let start = Self.startText

    #expect(
      EntryTimingView.accessibilityLabel(startedAt: Self.start, duration: Self.sevenSeconds, locale: Self.locale)
        == "Started at \(start), took 7 seconds")
  }

  @Test func theLabelOfAnEntryWithNoShownDurationTellsOnlyTheStart() {
    let start = Self.startText

    #expect(
      EntryTimingView.accessibilityLabel(startedAt: Self.start, duration: Self.tooShort, locale: Self.locale)
        == "Started at \(start)")
    #expect(
      EntryTimingView.accessibilityLabel(startedAt: Self.start, duration: nil, locale: Self.locale)
        == "Started at \(start)")
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
