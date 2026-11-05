import EditorSwiftUI
import EditorTheme
import SwiftUI

// MARK: - Who asks

extension ElicitationView {
  /// The accessibility identifier of the "who asks" line of the default
  /// header (``ElicitationHeader``).
  public static let whoAsksIdentifier = "elicitation-who-asks"
}

extension ElicitationHeader {
  /// The largest number of agent path names that the visible text shows in
  /// full. A longer path shows the root label, "…" and the last
  /// ``whoAsksTailCount`` names.
  static let whoAsksFullPathLimit = 3

  /// The number of last agent path names that the visible text of a long
  /// path shows.
  static let whoAsksTailCount = 2

  /// The visible text of the "who asks" line of an elicitation card.
  ///
  /// The text is the root label and the agent path, joined by the visible
  /// path pattern of the catalog (``ChainText/visiblePath(_:locale:)``), for
  /// example "root › planner › reviewer". With more than
  /// ``whoAsksFullPathLimit`` names, the text shows the root label, "…" and
  /// the last ``whoAsksTailCount`` names, for example "root › … › c › d". A
  /// source comes after " · ", for example "root › reviewer · runCode". The
  /// names and the source are agent data, so the function does not
  /// translate them.
  ///
  /// - Parameters:
  ///   - agentPath: The names of the agents between the root agent and the
  ///     agent that asks, outermost first (`PendingElicitation.agentPath`).
  ///   - source: The thing that asks inside the agent, or `nil`
  ///     (`PendingElicitation.source`).
  ///   - rootLabel: The label of the root agent, for example the
  ///     ``SwiftUI/EnvironmentValues/elicitationRootAgentLabel`` environment
  ///     value.
  ///   - locale: The locale of the text.
  /// - Returns: The text, or `nil` for no line when `agentPath` is empty and
  ///   `source` is `nil`.
  public static func whoAsks(
    agentPath: [String], source: String?, rootLabel: String, locale: Locale = .autoupdatingCurrent
  ) -> String? {
    guard hasWhoAsks(agentPath: agentPath, source: source) else { return nil }
    let shownNames =
      agentPath.count > whoAsksFullPathLimit
      ? [String(localized: "…", bundle: .module, locale: locale)] + agentPath.suffix(whoAsksTailCount)
      : agentPath
    let path = ChainText.visiblePath([rootLabel] + shownNames, locale: locale)
    guard let source else { return path }
    return String(localized: "\(path) · \(source)", bundle: .module, locale: locale)
  }

  /// The accessibility label of the "who asks" line of an elicitation card.
  ///
  /// The label has the full path, with no "…" and no "›", for example
  /// "Asked by root, planner, reviewer, from runCode". With no source, the
  /// label is, for example, "Asked by root, reviewer". The names are a list
  /// in the narrow list format of `locale`, inside one localized string.
  ///
  /// - Parameters:
  ///   - agentPath: The names of the agents between the root agent and the
  ///     agent that asks, outermost first (`PendingElicitation.agentPath`).
  ///   - source: The thing that asks inside the agent, or `nil`
  ///     (`PendingElicitation.source`).
  ///   - rootLabel: The label of the root agent.
  ///   - locale: The locale of the label.
  /// - Returns: The label, or `nil` for no line when `agentPath` is empty
  ///   and `source` is `nil`.
  public static func whoAsksAccessibilityLabel(
    agentPath: [String], source: String?, rootLabel: String, locale: Locale = .autoupdatingCurrent
  ) -> String? {
    guard hasWhoAsks(agentPath: agentPath, source: source) else { return nil }
    let names = [rootLabel] + agentPath
    let style: ListFormatStyle<StringStyle, [String]> = .spokenParts(locale: locale)
    guard let source else {
      return String(
        localized: "Asked by \(names, format: style)", bundle: .module, locale: locale,
        comment: "The VoiceOver label of the agents that ask for input: the agent path, from the root agent.")
    }
    return String(
      localized: "Asked by \(names, format: style), from \(source)", bundle: .module, locale: locale,
      comment: "The VoiceOver label of the agents that ask for input: the agent path, then the thing that asks.")
  }

  /// Tells whether a request has "who asks" data.
  ///
  /// - Parameters:
  ///   - agentPath: The agent path of the request.
  ///   - source: The source of the request, or `nil`.
  /// - Returns: `false` when `agentPath` is empty and `source` is `nil`.
  static func hasWhoAsks(agentPath: [String], source: String?) -> Bool {
    !agentPath.isEmpty || source != nil
  }
}

/// The "who asks" line of the default header of an elicitation card.
///
/// The line shows
/// ``ElicitationHeader/whoAsks(agentPath:source:rootLabel:locale:)`` in the
/// locale of the environment, in one line, with the middle truncated, in the `ui` font role of the
/// EditorKit theme at the callout text style, and in `\.placedSecondary`. The
/// text is selectable. VoiceOver reads the line as one element with the label
/// of
/// ``ElicitationHeader/whoAsksAccessibilityLabel(agentPath:source:rootLabel:locale:)``
/// in the locale of the environment, and the identifier ``ElicitationView/whoAsksIdentifier``. A request with
/// no "who asks" data shows no line.
struct ElicitationWhoAsksLine: View {
  /// The agent path of the request.
  let agentPath: [String]

  /// The source of the request, or `nil`.
  let source: String?

  @Environment(\.elicitationRootAgentLabel) private var rootLabel
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.locale) private var locale
  @Environment(\.placedSecondary) private var placedSecondary

  var body: some View {
    if let text = ElicitationHeader.whoAsks(agentPath: agentPath, source: source, rootLabel: rootLabel, locale: locale),
      let label = ElicitationHeader.whoAsksAccessibilityLabel(
        agentPath: agentPath, source: source, rootLabel: rootLabel, locale: locale)
    {
      Text(text)
        .font(editorTheme.font(for: .ui, style: .callout))
        .foregroundStyle(placedSecondary)
        .lineLimit(1)
        .truncationMode(.middle)
        .textSelection(.enabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityIdentifier(ElicitationView.whoAsksIdentifier)
    }
  }
}

extension EnvironmentValues {
  /// The label of the root agent in the "who asks" line of each elicitation
  /// card (``ElicitationHeader``). The default is the localized "root".
  ///
  /// The agent sends no name for the root agent, so the app gives one, for
  /// example the name of the agent.
  @Entry public var elicitationRootAgentLabel: String = String(localized: "root", bundle: .module)
}

// MARK: - Previews

/// The "who asks" line of the previews, in a narrow column, so that a long
/// line truncates in the middle.
private struct ElicitationWhoAsksLineSample: View {
  /// The agent path and the source of the line.
  let whoAsks: PreviewFixtures.WhoAsks

  var body: some View {
    ElicitationWhoAsksLine(agentPath: whoAsks.agentPath, source: whoAsks.source)
      .frame(width: PreviewFixtures.narrowWidth, alignment: .leading)
      .padding()
  }
}

#Preview("Short agent and tool names") {
  ElicitationWhoAsksLineSample(whoAsks: .short)
}

#Preview("Long agent and tool names: the middle truncates") {
  ElicitationWhoAsksLineSample(whoAsks: .long)
}
