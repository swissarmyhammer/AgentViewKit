import EditorStyle
import EditorSwiftUI
import EditorTheme
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
/// The view has no style of its own. The text of the time is one localized
/// string of the catalog (``lineText(startedAt:duration:locale:timeZone:)``)
/// that holds the start in ``startStyle(locale:timeZone:)`` and the duration
/// in ``lineDurationStyle(locale:)``, such as "6:13 AM · 1m 15s". The catalog
/// holds the separator and the order of the parts, so the code joins no text.
/// The text takes the locale and the time zone of the environment, draws in
/// the `ui` font role of the theme and uses `\.themeSecondary`. The spacing
/// and the symbol weight come from the shared style (`\.editorStyle`).
///
/// The text is the one accessibility element of the view. Its label tells
/// the start and the duration in words, as
/// ``accessibilityLabel(startedAt:duration:locale:timeZone:)`` gives them in
/// the locale and the time zone of the environment, and VoiceOver reads it
/// after the content of the row.
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

  /// The units that a duration of the line and of the label can use.
  static let durationUnits: Set<Duration.UnitsFormatStyle.Unit> = [.hours, .minutes, .seconds]

  /// The rounding of the fraction of a second of a duration: half a second
  /// rounds up, so the ``shortestShownDuration`` shows one second.
  static let secondsRounding = FloatingPointRoundingRule.toNearestOrAwayFromZero

  /// The transcript entry whose time the view shows.
  let entry: TranscriptEntry

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

  /// The format of a start time, which the line shows and the label tells:
  /// the short time of the day, with no date, such as "6:13 AM".
  ///
  /// - Parameters:
  ///   - locale: The locale of the text.
  ///   - timeZone: The time zone of the clock time.
  /// - Returns: The time format of `locale` and `timeZone`.
  static func startStyle(locale: Locale, timeZone: TimeZone) -> Date.FormatStyle {
    Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
  }

  /// The format of a duration that the line shows: the narrow units of the
  /// duration, with no unit of zero, such as "1m 15s".
  ///
  /// - Parameter locale: The locale of the text.
  /// - Returns: The narrow duration format of `locale`.
  static func lineDurationStyle(locale: Locale) -> Duration.UnitsFormatStyle {
    durationStyle(locale: locale, width: .narrow, zeroValueUnits: .hide)
  }

  /// The format of a duration that a label tells: at most
  /// ``largestUnitCount`` whole units in words, such as "1 minute,
  /// 15 seconds".
  ///
  /// - Parameter locale: The locale of the text.
  /// - Returns: The wide duration format of `locale`.
  static func spokenDurationStyle(locale: Locale) -> Duration.UnitsFormatStyle {
    durationStyle(locale: locale, width: .wide, maximumUnitCount: largestUnitCount)
  }

  /// The one builder of the duration formats of the view: the units of
  /// ``durationUnits``, with the fraction of a second rounded away.
  ///
  /// - Parameters:
  ///   - locale: The locale of the text.
  ///   - width: The width of the unit names.
  ///   - zeroValueUnits: Whether units of zero show.
  ///   - maximumUnitCount: The largest number of units that show, or `nil`
  ///     for each unit.
  /// - Returns: The duration format of `locale`.
  private static func durationStyle(
    locale: Locale, width: Duration.UnitsFormatStyle.UnitWidth,
    zeroValueUnits: Duration.UnitsFormatStyle.ZeroValueUnitsDisplayStrategy = .hide,
    maximumUnitCount: Int? = nil
  ) -> Duration.UnitsFormatStyle {
    Duration.UnitsFormatStyle(
      allowedUnits: durationUnits, width: width, maximumUnitCount: maximumUnitCount,
      zeroValueUnits: zeroValueUnits, fractionalPart: .hide(rounded: secondsRounding)
    ).locale(locale)
  }

  /// The text of the duration that a label shows, with whole words, for a
  /// label that VoiceOver reads or for a title.
  ///
  /// The text stands in a sentence, so it names its units in words. Each
  /// caller puts the text in its own localized phrase and gives its own text
  /// when the result is `nil`.
  ///
  /// - Parameters:
  ///   - duration: The duration of an entry, in seconds, or `nil` when the
  ///     entry has no end time.
  ///   - locale: The locale of the text.
  /// - Returns: The ``shownDuration(_:)`` in
  ///   ``spokenDurationStyle(locale:)``, such as "1 minute, 15 seconds", or
  ///   `nil` when the view shows no duration.
  public static func spokenDuration(_ duration: TimeInterval?, locale: Locale = .autoupdatingCurrent) -> String? {
    shownDuration(duration).map { Duration.seconds($0).formatted(spokenDurationStyle(locale: locale)) }
  }

  /// A localized phrase that holds the ``spokenDuration(_:locale:)`` of a
  /// duration, or a fallback phrase when the view shows no duration.
  ///
  /// The titles and labels of a ``ReasoningView`` use this shape. Each
  /// caller gives its own phrases.
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

  /// The text that the line of a time shows: one localized string of the
  /// catalog for each set of parts that the time has.
  ///
  /// - Parameters:
  ///   - startedAt: The start time of the entry, or `nil` when it has none.
  ///   - duration: The duration of the entry, in seconds, or `nil` when the
  ///     entry has no end time.
  ///   - locale: The locale of the text.
  ///   - timeZone: The time zone of the clock time of the start.
  /// - Returns: The start in ``startStyle(locale:timeZone:)`` and the
  ///   ``shownDuration(_:)`` in ``lineDurationStyle(locale:)``, such as
  ///   "6:13 AM · 1m 15s"; the one part that the time has; or `nil` when it
  ///   has neither.
  public static func lineText(
    startedAt: Date?, duration: TimeInterval?, locale: Locale = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent
  ) -> String? {
    let start = startStyle(locale: locale, timeZone: timeZone)
    let length = lineDurationStyle(locale: locale)
    switch (startedAt, shownDuration(duration).map(Duration.seconds)) {
    case (let startedAt?, let shown?):
      return String(
        localized: "entry-timing.start-and-duration",
        defaultValue: "\(startedAt, format: start) · \(shown, format: length)", bundle: .module, locale: locale,
        comment: "The time of a transcript entry: its start time, such as 6:13 AM, and its duration, such as 1m 15s.")
    case (let startedAt?, nil):
      return String(
        localized: "entry-timing.start", defaultValue: "\(startedAt, format: start)", bundle: .module, locale: locale,
        comment: "The time of a transcript entry with no duration: its start time, such as 6:13 AM.")
    case (nil, let shown?):
      return String(
        localized: "entry-timing.duration", defaultValue: "\(shown, format: length)", bundle: .module, locale: locale,
        comment: "The time of a transcript entry with no start time: its duration, such as 1m 15s.")
    case (nil, nil):
      return nil
    }
  }

  /// The label that VoiceOver reads for the time of an entry.
  ///
  /// - Parameters:
  ///   - startedAt: The start time of the entry, or `nil` when it has none.
  ///   - duration: The duration of the entry, in seconds, or `nil` when the
  ///     entry has no end time.
  ///   - locale: The locale of the label.
  ///   - timeZone: The time zone of the clock time of the start.
  /// - Returns: "Started at T, took D"; "Started at T" when the view shows
  ///   no duration; "Took D" when the entry has no start time; or `nil` when
  ///   the view shows neither.
  public static func accessibilityLabel(
    startedAt: Date?, duration: TimeInterval?, locale: Locale = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent
  ) -> String? {
    let start = startStyle(locale: locale, timeZone: timeZone)
    let length = spokenDurationStyle(locale: locale)
    switch (startedAt, shownDuration(duration).map(Duration.seconds)) {
    case (let startedAt?, let shown?):
      return String(
        localized: "Started at \(startedAt, format: start), took \(shown, format: length)", bundle: .module,
        locale: locale,
        comment: "The VoiceOver label of the time of a transcript entry: its start time, and its duration in words.")
    case (let startedAt?, nil):
      return String(
        localized: "Started at \(startedAt, format: start)", bundle: .module, locale: locale,
        comment: "The VoiceOver label of the time of a transcript entry with no duration: its start time.")
    case (nil, let shown?):
      return String(
        localized: "Took \(shown, format: length)", bundle: .module, locale: locale,
        comment: "The VoiceOver label of the time of a transcript entry with no start time: its duration in words.")
    case (nil, nil):
      return nil
    }
  }

  public var body: some View {
    let timing = entry.timing
    EntryTimingLine(
      startedAt: timing.startedAt, duration: timing.duration, identifier: Self.identifier(for: entry.rowKey))
  }
}

/// The line of a time: the symbol of the time and the
/// ``EntryTimingView/lineText(startedAt:duration:locale:timeZone:)`` of a
/// start time and a duration, in the locale and the time zone of the
/// environment. It shows nothing when the time has neither part.
///
/// ``EntryTimingView`` shows the line of its entry. The line takes the two
/// parts of a time apart from an entry, so a test shows each set of parts.
struct EntryTimingLine: View {
  /// The start time, or `nil` when there is none.
  let startedAt: Date?

  /// The duration, in seconds, or `nil` when there is none.
  let duration: TimeInterval?

  /// The accessibility identifier of the text.
  let identifier: String

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.locale) private var locale
  @Environment(\.themeSecondary) private var themeSecondary
  @Environment(\.timeZone) private var timeZone

  var body: some View {
    if let text = EntryTimingView.lineText(
      startedAt: startedAt, duration: duration, locale: locale, timeZone: timeZone),
      let label = EntryTimingView.accessibilityLabel(
        startedAt: startedAt, duration: duration, locale: locale, timeZone: timeZone)
    {
      line(text, label: label)
    }
  }

  /// The symbol and the text of the time, in one line.
  ///
  /// - Parameters:
  ///   - text: The text that the line shows.
  ///   - label: The label that VoiceOver reads for the text.
  /// - Returns: The line, whose text is its one accessibility element.
  private func line(_ text: String, label: String) -> some View {
    HStack(spacing: editorStyle.spacing.xs) {
      Image(systemName: EntryTimingView.symbolName)
        .fontWeight(editorStyle.symbolWeight)
        .accessibilityHidden(true)
      Text(text)
        .font(editorTheme.font(for: .ui, style: .body))
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
    .foregroundStyle(themeSecondary)
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
