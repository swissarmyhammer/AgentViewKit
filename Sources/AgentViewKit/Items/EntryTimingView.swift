import EditorStyle
import EditorSwiftUI
import FoundationModelsACPClient
import SwiftUI

/// The time of one transcript entry: when the entry started and, when it
/// ended, its duration.
///
/// The view reads the `EntryTiming` of the entry, which the client model
/// writes. The kit records no time and keeps no copy of a time. Each time is
/// written one time only, so a streamed chunk does not evaluate this view.
///
/// An entry with no start time shows nothing. This is the case for an entry
/// of a replay or of a history, because the client did not see it live. An
/// entry with a start time and no end time shows only its start time. A
/// duration that rounds to zero seconds does not show (see
/// ``shownDuration(_:)``).
///
/// The view is a decorator. The message views do not show a time by
/// themselves. Attach the view to one view with
/// ``SwiftUI/View/entryTiming(_:)``, or to each row of a ``ConversationView``
/// and an ``AgentThreadView`` with ``SwiftUI/View/transcriptTiming(_:)``.
///
/// The view has no style of its own. EditorKit's value texts show the time:
/// a `DateText` of the start in `startFormat` and a `DurationText` of the
/// duration in `durationFormat`, each in the `ui` font role of the theme
/// and the locale and the time zone of the environment. The text uses
/// `\.themeSecondary`, and
/// the spacing and the symbol weight come from the shared style
/// (`\.editorStyle`).
///
/// The view is one accessibility element. Its label tells the start and the
/// duration, as ``accessibilityLabel(startedAt:duration:locale:timeZone:)``
/// gives them in the locale and the time zone of the environment, and
/// VoiceOver reads it after the content of the row.
public struct EntryTimingView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of each time view. The rest is
  /// the row key of the entry.
  public static let identifierPrefix = "entry-timing-"

  /// The shortest duration that the view shows, in seconds. A shorter
  /// duration rounds to zero seconds.
  public static let shortestShownDuration: TimeInterval = 0.5

  /// The SF Symbol name of the time.
  static let symbolName = AgentSymbol.entryTime

  /// The largest number of units in a spoken duration, such as "1 minute,
  /// 15 seconds".
  static let largestUnitCount = 2

  /// The units that a spoken duration can use.
  static let spokenDurationUnits: Set<Duration.UnitsFormatStyle.Unit> = [.hours, .minutes, .seconds]

  /// The format of a start time, which the `DateText` of the view shows and
  /// the VoiceOver label tells: the short time of the day, with no date,
  /// such as "6:00 PM".
  static let startFormat = ValueFieldFormat<Date>(Date.FormatStyle(date: .omitted, time: .shortened))

  /// The format of a duration, which the `DurationText` of the view and the
  /// duration row of an entry's inspection show: minutes and seconds, such
  /// as "1:15".
  static let durationFormat = DurationFieldFormat(units: .minutesSeconds)

  /// The transcript entry whose time the view shows.
  let entry: TranscriptEntry

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.locale) private var locale
  @Environment(\.themeSecondary) private var themeSecondary
  @Environment(\.timeZone) private var timeZone

  /// Makes the time view of a transcript entry.
  ///
  /// - Parameter entry: The entry whose time the view shows.
  public init(entry: TranscriptEntry) {
    self.entry = entry
  }

  /// The duration that a view shows.
  ///
  /// - Parameter duration: The duration of an entry, in seconds, or `nil`
  ///   when the entry has no end time.
  /// - Returns: `duration`, or `nil` when it is `nil` or shorter than
  ///   ``shortestShownDuration``.
  public static func shownDuration(_ duration: TimeInterval?) -> TimeInterval? {
    guard let duration, duration >= shortestShownDuration else { return nil }
    return duration
  }

  /// The text of the duration that a label shows, with whole words, for a
  /// label that VoiceOver reads or for a title.
  ///
  /// The text stands in a sentence, so it names its units, which a
  /// `DurationText` does not. Each caller puts the text in its own localized
  /// phrase and gives its own text when the result is `nil`.
  ///
  /// - Parameters:
  ///   - duration: The duration of an entry, in seconds, or `nil` when the
  ///     entry has no end time.
  ///   - locale: The locale of the text.
  /// - Returns: The ``shownDuration(_:)`` in at most two whole units of the
  ///   system duration formatter, such as "1 minute, 15 seconds", or `nil`
  ///   when the view shows no duration.
  public static func spokenDuration(_ duration: TimeInterval?, locale: Locale = .autoupdatingCurrent) -> String? {
    let style = Duration.UnitsFormatStyle(
      allowedUnits: spokenDurationUnits, width: .wide, maximumUnitCount: largestUnitCount)
    return shownDuration(duration).map { Duration.seconds($0).formatted(style.locale(locale)) }
  }

  /// A localized phrase that holds the ``spokenDuration(_:locale:)`` of a
  /// duration, or a fallback phrase when the view shows no duration.
  ///
  /// The VoiceOver label of the time and the titles and labels of a
  /// ``ReasoningView`` use this shape. Each caller gives its own phrases.
  ///
  /// - Parameters:
  ///   - duration: The duration of an entry, in seconds, or `nil` when the
  ///     entry has no end time.
  ///   - locale: The locale of the duration text.
  ///   - phrase: Makes the phrase from the spoken duration text.
  ///   - fallback: Makes the phrase when the view shows no duration.
  /// - Returns: `phrase` of the spoken duration, or `fallback()` when
  ///   ``spokenDuration(_:locale:)`` gives `nil`.
  static func durationPhrase(
    _ duration: TimeInterval?, locale: Locale = .autoupdatingCurrent,
    phrase: (String) -> String, fallback: () -> String
  ) -> String {
    spokenDuration(duration, locale: locale).map(phrase) ?? fallback()
  }

  /// The label that VoiceOver reads for the time of an entry.
  ///
  /// - Parameters:
  ///   - startedAt: The start time of the entry.
  ///   - duration: The duration of the entry, in seconds, or `nil` when the
  ///     entry has no end time.
  ///   - locale: The locale of the label.
  ///   - timeZone: The time zone of the clock time of the start.
  /// - Returns: "Started at T, took D", or "Started at T" when the view shows
  ///   no duration.
  public static func accessibilityLabel(
    startedAt: Date, duration: TimeInterval?, locale: Locale = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent
  ) -> String {
    let start = startFormat.format(startedAt, locale: locale, timeZone: timeZone)
    return durationPhrase(duration, locale: locale) {
      String(localized: "Started at \(start), took \($0)", bundle: .module)
    } fallback: {
      String(localized: "Started at \(start)", bundle: .module)
    }
  }

  public var body: some View {
    let timing = entry.timing
    if let startedAt = timing.startedAt {
      line(startedAt: startedAt, duration: timing.duration)
    }
  }

  /// The symbol, the start time and the shown duration, in one line.
  ///
  /// - Parameters:
  ///   - startedAt: The start time of the entry.
  ///   - duration: The duration of the entry, in seconds, or `nil`.
  /// - Returns: The line, as one accessibility element.
  private func line(startedAt: Date, duration: TimeInterval?) -> some View {
    HStack(spacing: editorStyle.spacing.xs) {
      Image(systemName: Self.symbolName)
        .fontWeight(editorStyle.symbolWeight)
        .accessibilityHidden(true)
      DateText(startedAt, format: Self.startFormat)
      if let shown = Self.shownDuration(duration) {
        DurationText(.seconds(shown), format: Self.durationFormat)
      }
    }
    .foregroundStyle(themeSecondary)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      Self.accessibilityLabel(startedAt: startedAt, duration: duration, locale: locale, timeZone: timeZone))
    .accessibilityIdentifier(Self.identifier(for: entry.rowKey))
  }
}

extension EnvironmentValues {
  /// Whether each row of a ``ConversationView`` and an ``AgentThreadView``
  /// shows the time of its entry (an ``EntryTimingView``).
  ///
  /// The value is `false` by default, so no row shows a time. Set the value
  /// with ``SwiftUI/View/transcriptTiming(_:)``.
  @Entry public var showsTranscriptTiming = false
}

extension View {
  /// Shows the time of a transcript entry below this view.
  ///
  /// The modifier wraps the view with an ``EntryTimingView`` of the entry.
  /// Use it on a view of a host, such as an item view override:
  ///
  /// ```swift
  /// MyMessageRow(entry: message)
  ///   .entryTiming(.agentMessage(message))
  /// ```
  ///
  /// The rows of a ``ConversationView`` already wrap each entry when
  /// ``SwiftUI/View/transcriptTiming(_:)`` is on. Do not use both on the
  /// same row, or the row shows the time two times.
  ///
  /// - Parameter entry: The entry whose time the view shows.
  /// - Returns: The view and the time of the entry below it.
  public func entryTiming(_ entry: TranscriptEntry) -> some View {
    modifier(EntryTimingDecorator(entry: entry, isShown: true))
  }

  /// Shows the time of each entry below its row in each ``ConversationView``
  /// and ``AgentThreadView`` of this subtree.
  ///
  /// ```swift
  /// AgentThreadView(session: session)
  ///   .transcriptTiming()
  /// ```
  ///
  /// The default is no time. The times come from the client model. A
  /// replayed entry has no time, so its row shows none.
  ///
  /// - Parameter isShown: Whether each row shows the time of its entry.
  /// - Returns: A view that gives the value to its subtree.
  public func transcriptTiming(_ isShown: Bool = true) -> some View {
    environment(\.showsTranscriptTiming, isShown)
  }
}

/// Puts an ``EntryTimingView`` below a view, when `isShown` is `true`.
///
/// The view keeps one structure when `isShown` changes, so the wrapped view
/// keeps its state.
struct EntryTimingDecorator: ViewModifier {
  /// The entry whose time the decorator shows.
  let entry: TranscriptEntry

  /// Whether the decorator shows the time.
  let isShown: Bool

  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.xs) {
      content
      if isShown {
        EntryTimingView(entry: entry)
      }
    }
  }
}

/// The time slot of an ``ItemRow``: the ``EntryTimingDecorator`` of the
/// entry, on when ``SwiftUI/EnvironmentValues/showsTranscriptTiming`` is
/// `true`.
///
/// The slot reads the environment value in its own body, so a change of the
/// value does not evaluate the row.
struct TranscriptTimingSlot: ViewModifier {
  /// The entry of the row.
  let entry: TranscriptEntry

  @Environment(\.showsTranscriptTiming) private var isShown

  func body(content: Content) -> some View {
    content.modifier(EntryTimingDecorator(entry: entry, isShown: isShown))
  }
}

#Preview("Entry time") {
  if let entry = SessionModel.previewSample.transcript.first {
    EntryTimingView(entry: entry)
  }
}
