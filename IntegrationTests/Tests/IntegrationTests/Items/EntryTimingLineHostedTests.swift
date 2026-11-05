#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorTestSupport
  import Foundation
  import SwiftUI
  import Testing

  /// The time line (`EntryTimingLine`) as accessibility reads it: the label
  /// of its one element, which VoiceOver reads in words, for each set of
  /// parts of a time, and no element when the time has no part.
  ///
  /// The label replaces the text of the element, so accessibility gives no
  /// copy of the visible text; `EntryTimingTextTests` reads the
  /// `lineText(startedAt:duration:locale:timeZone:)` that the line draws.
  ///
  /// The line shows the start of ``TimedSessionClock`` and one step of its
  /// clock in the English locale of the United States and the GMT time zone,
  /// where the start is 6:13 AM. The system formatter puts a narrow no-break
  /// space before the day period.
  @Suite(.serialized, .hostedSerially) @MainActor struct EntryTimingLineHostedTests {
    /// The locale of the line.
    static let locale = Locale(identifier: "en_US")

    /// The accessibility identifier of the line of the tests.
    static let identifier = EntryTimingView.identifier(for: "line")

    /// The duration of the tests: one step of the clock, one minute and
    /// fifteen seconds.
    static let duration = TimedSessionClock.stepSeconds

    /// The short time of the start of the clock in GMT.
    static let startText = "6:13\u{202F}AM"

    /// Mounts the line of a start time and a duration in ``locale`` and the
    /// GMT time zone.
    ///
    /// - Parameters:
    ///   - startedAt: The start time, or `nil`.
    ///   - duration: The duration in seconds, or `nil`.
    /// - Returns: The harness, after one render pass.
    static func mountLine(startedAt: Date?, duration: TimeInterval?) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness {
        EntryTimingLine(startedAt: startedAt, duration: duration, identifier: identifier)
          .environment(\.locale, locale)
          .environment(\.timeZone, .gmt)
      }
      harness.render()
      return harness
    }

    /// The element of the line of a start time and a duration.
    ///
    /// - Parameters:
    ///   - startedAt: The start time, or `nil`.
    ///   - duration: The duration in seconds, or `nil`.
    /// - Returns: The element, or `nil` when the line shows nothing.
    static func lineElement(startedAt: Date?, duration: TimeInterval?) -> AccessibilityElementSnapshot? {
      let harness = mountLine(startedAt: startedAt, duration: duration)
      defer { harness.close() }
      return harness.element(identifier: identifier)
    }

    @Test func theLabelTellsTheStartAndTheDurationInWords() throws {
      let element = try #require(Self.lineElement(startedAt: TimedSessionClock.start, duration: Self.duration))

      #expect(element.label == "Started at \(Self.startText), took 1 minute, 15 seconds")
    }

    @Test func theLabelOfALineWithNoDurationTellsOnlyTheStart() throws {
      let element = try #require(Self.lineElement(startedAt: TimedSessionClock.start, duration: nil))

      #expect(element.label == "Started at \(Self.startText)")
    }

    @Test func theLabelOfALineWithNoStartTellsOnlyTheDuration() throws {
      let element = try #require(Self.lineElement(startedAt: nil, duration: Self.duration))

      #expect(element.label == "Took 1 minute, 15 seconds")
    }

    @Test func aLineWithNeitherPartShowsNothing() {
      #expect(Self.lineElement(startedAt: nil, duration: nil) == nil)
    }
  }
#endif
