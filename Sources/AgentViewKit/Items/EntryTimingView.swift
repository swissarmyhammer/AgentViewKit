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
/// The view has no style of its own. The time is chrome, so it draws in the
/// root font of the theme, its text uses the
/// secondary level of the foreground, and its spacing and symbol weight come
/// from the shared style (`\.editorStyle`). The system formatters write the time and the
/// duration in the locale of the environment.
///
/// The view is one accessibility element. Its label tells the start and the
/// duration, as ``accessibilityLabel(startedAt:duration:locale:)`` gives
/// them, and VoiceOver reads it after the content of the row.
public struct EntryTimingView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of each time view. The rest is
  /// the row key of the entry.
  public static let identifierPrefix = "entry-timing-"

  /// The shortest duration that the view shows, in seconds. A shorter
  /// duration rounds to zero seconds.
  public static let shortestShownDuration: TimeInterval = 0.5

  /// The SF Symbol name of the time.
  static let symbolName = SharedSymbol.entryTime

  /// The largest number of units in a duration text, such as "1 min, 15
  /// sec".
  static let largestUnitCount = 2

  /// The units that a duration text can use.
  static let durationUnits: Set<Duration.UnitsFormatStyle.Unit> = [.hours, .minutes, .seconds]

  /// The format of a start time: the short time of the day, with no date.
  static let startStyle = Date.FormatStyle(date: .omitted, time: .shortened)

  /// The transcript entry whose time the view shows.
  let entry: TranscriptEntry

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.locale) private var locale

  /// Makes the time view of a transcript entry.
  ///
  /// - Parameter entry: The entry whose time the view shows.
  public init(entry: TranscriptEntry) {
    self.entry = entry
  }

  /// The text of a start time.
  ///
  /// - Parameters:
  ///   - date: The start time.
  ///   - locale: The locale of the text.
  /// - Returns: The short time of the day, such as "6:00 PM".
  public static func startText(for date: Date, locale: Locale = .autoupdatingCurrent) -> String {
    date.formatted(startStyle.locale(locale))
  }

  /// The text of a duration, from the system duration formatter.
  ///
  /// - Parameters:
  ///   - duration: The duration, in seconds.
  ///   - width: The width of the unit names: `.abbreviated` for the view,
  ///     and `.wide` for a label that VoiceOver reads.
  ///   - locale: The locale of the text.
  /// - Returns: At most two units, in whole seconds, such as "1 min, 15 sec"
  ///   or "1 minute, 15 seconds".
  public static func durationText(
    for duration: TimeInterval, width: Duration.UnitsFormatStyle.UnitWidth, locale: Locale = .autoupdatingCurrent
  ) -> String {
    let style = Duration.UnitsFormatStyle(
      allowedUnits: durationUnits, width: width, maximumUnitCount: largestUnitCount)
    return Duration.seconds(duration).formatted(style.locale(locale))
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
  /// Each caller puts the text in its own localized phrase and gives its own
  /// text when the result is `nil`.
  ///
  /// - Parameters:
  ///   - duration: The duration of an entry, in seconds, or `nil` when the
  ///     entry has no end time.
  ///   - locale: The locale of the text.
  /// - Returns: The ``durationText(for:width:locale:)`` of the
  ///   ``shownDuration(_:)`` with `.wide` units, such as "1 minute, 15
  ///   seconds", or `nil` when the view shows no duration.
  public static func spokenDuration(_ duration: TimeInterval?, locale: Locale = .autoupdatingCurrent) -> String? {
    shownDuration(duration).map { durationText(for: $0, width: .wide, locale: locale) }
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
  /// - Returns: "Started at T, took D", or "Started at T" when the view shows
  ///   no duration.
  public static func accessibilityLabel(
    startedAt: Date, duration: TimeInterval?, locale: Locale = .autoupdatingCurrent
  ) -> String {
    let start = startText(for: startedAt, locale: locale)
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
      Text(Self.startText(for: startedAt, locale: locale))
      if let shown = Self.shownDuration(duration) {
        Text(Self.durationText(for: shown, width: .abbreviated, locale: locale))
      }
    }
    .foregroundStyle(.secondary)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.accessibilityLabel(startedAt: startedAt, duration: duration, locale: locale))
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
