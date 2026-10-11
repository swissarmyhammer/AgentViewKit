import AgentViewKit
import Foundation
import Testing

/// The text of the time of a transcript entry: the start time, the duration,
/// the VoiceOver label, and the "Thought for N seconds" title of a thought.
///
/// The texts come from the system formatters, so the tests give the English
/// locale of the United States.
@Suite struct EntryTimingTextTests {
  /// The locale of the tests.
  static let locale = Locale(identifier: "en_US")

  /// A start time of the tests.
  static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

  /// A duration of one minute and fifteen seconds.
  static let minuteAndQuarter: TimeInterval = 75

  /// A duration of seven seconds.
  static let sevenSeconds: TimeInterval = 7

  /// A duration that rounds to zero seconds.
  static let tooShort: TimeInterval = 0.2

  /// A duration that rounds to one second.
  static let almostOneSecond: TimeInterval = 0.6

  @Test func theStartTextIsTheShortTimeOfTheDate() {
    let expected = Self.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Self.locale))

    #expect(EntryTimingView.startText(for: Self.start, locale: Self.locale) == expected)
  }

  @Test func theShortDurationTextUsesAbbreviatedUnits() {
    #expect(
      EntryTimingView.durationText(for: Self.minuteAndQuarter, width: .abbreviated, locale: Self.locale)
        == "1 min, 15 sec")
  }

  @Test func theLongDurationTextUsesWholeWords() {
    #expect(
      EntryTimingView.durationText(for: Self.minuteAndQuarter, width: .wide, locale: Self.locale)
        == "1 minute, 15 seconds")
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
    let start = EntryTimingView.startText(for: Self.start, locale: Self.locale)

    #expect(
      EntryTimingView.accessibilityLabel(startedAt: Self.start, duration: Self.sevenSeconds, locale: Self.locale)
        == "Started at \(start), took 7 seconds")
  }

  @Test func theLabelOfAnEntryWithNoShownDurationTellsOnlyTheStart() {
    let start = EntryTimingView.startText(for: Self.start, locale: Self.locale)

    #expect(
      EntryTimingView.accessibilityLabel(startedAt: Self.start, duration: Self.tooShort, locale: Self.locale)
        == "Started at \(start)")
    #expect(
      EntryTimingView.accessibilityLabel(startedAt: Self.start, duration: nil, locale: Self.locale)
        == "Started at \(start)")
  }

  @Test func theThoughtTitleTellsTheDurationInWholeWords() {
    #expect(ReasoningView.completedTitle(duration: Self.sevenSeconds) == "Thought for 7 seconds")
    #expect(ReasoningView.completedTitle(duration: Self.minuteAndQuarter) == "Thought for 1 minute, 15 seconds")
    #expect(ReasoningView.completedTitle(duration: nil) == "Thought")
  }
}
