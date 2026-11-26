import AppKit
import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The theme metrics of the chrome rules: the spacing tokens of the style,
/// and the sizes of the one-line chrome views of the rows.
///
/// A chrome view of one line, such as a header text, a toolbar button or a
/// symbol, has the same size in each row and at each width. ``probe(theme:)``
/// lays out each one a single time on the main actor, so the chrome rules
/// need no view.
nonisolated public struct TranscriptRowMetrics: Hashable, Sendable {
  /// One chrome view of one line.
  enum Atom: Hashable, Sendable {
    /// The role header of a message.
    case messageHeader

    /// The send state caption of a user message.
    case sendState(SendState)

    /// A text in the font of the row, such as the title of a thought.
    case rowText

    /// The disclosure toggle of a thought.
    case disclosureButton

    /// The copy button of a code block or an output.
    case copyButton

    /// A text in the font of a plain button.
    case buttonText

    /// A symbol, by name, in the font of a plain button.
    case buttonSymbol(String)

    /// The title of a block header (`BlockHeader`).
    case blockHeaderTitle

    /// The file chip of a diff.
    case pathChip

    /// A text in the code font.
    case codeText

    /// A text in the UI headline font.
    case headline

    /// A symbol, by name, in the font of the row.
    case symbol(String)

    /// The exit label of an output, by the name of its symbol.
    case exitLabel(String)
  }

  /// The extra-small spacing token.
  let spacingXS: CGFloat

  /// The small spacing token.
  let spacingS: CGFloat

  /// The medium spacing token.
  let spacingM: CGFloat

  /// The large spacing token.
  let spacingL: CGFloat

  /// The padding of a content tile.
  let tilePadding: CGFloat

  /// The gap between the parts of a content tile.
  let tileGap: CGFloat

  /// The width of the symbol column.
  let symbolColumnWidth: CGFloat

  /// The space between two views of a stack with no spacing.
  let stackSpacing: CGFloat

  /// The size of each chrome view.
  let sizes: [Atom: CGSize]

  /// The disclosure symbol of a tool call header.
  let disclosureSymbol: String

  /// The symbol of the header of a terminal.
  let terminalSymbol: String

  /// The symbol of an error notice.
  let errorSymbol: String

  /// The height of a chrome view, or `nil` when the probe did not lay it out.
  ///
  /// - Parameter atom: The chrome view.
  /// - Returns: The height.
  func height(_ atom: Atom) -> CGFloat? {
    sizes[atom]?.height
  }

  /// The width of a chrome view, or `nil` when the probe did not lay it out.
  ///
  /// - Parameter atom: The chrome view.
  /// - Returns: The width.
  func width(_ atom: Atom) -> CGFloat? {
    sizes[atom]?.width
  }

  /// Lays out each chrome view of the rows one time, and reads its size.
  ///
  /// - Parameter theme: The theme of the rows, or `nil` for the environment
  ///   with no theme.
  /// - Returns: The metrics.
  @MainActor public static func probe(theme: (any Theme)? = nil) -> TranscriptRowMetrics {
    let probe = TranscriptRowProbe(theme: theme)
    let style = probe.environment.editorStyle
    return TranscriptRowMetrics(
      spacingXS: style.spacing.xs, spacingS: style.spacing.s, spacingM: style.spacing.m,
      spacingL: style.spacing.l, tilePadding: style.tile.padding, tileGap: style.tile.gap,
      symbolColumnWidth: style.symbolColumnWidth, stackSpacing: probe.stackSpacing(),
      sizes: probe.sizes(), disclosureSymbol: TranscriptRowSymbols.disclosure,
      terminalSymbol: TranscriptRowSymbols.terminal, errorSymbol: TranscriptRowSymbols.error)
  }
}

/// The names of the symbols that the chrome rules read.
@MainActor enum TranscriptRowSymbols {
  /// The kinds of tool call that the probe lays out.
  static let toolKinds: [ToolKind] = [
    .read, .edit, .delete, .move, .search, .execute, .think, .fetch, .switchMode, .other, .unknown(""),
  ]

  /// The plan entry statuses that the probe lays out.
  static let planStatuses: [PlanEntryStatus] = [.pending, .inProgress, .completed, .cancelled, .unknown("")]

  /// The plan entry priorities that the probe lays out.
  static let planPriorities: [PlanEntryPriority] = [.high, .medium, .low, .unknown("")]

  /// The symbol of a tool kind.
  ///
  /// - Parameter kind: The kind.
  /// - Returns: The symbol name.
  static func tool(_ kind: ToolKind) -> String {
    EditorSymbol.tool(.init(kind)).systemImage
  }

  /// The symbol of a tool call status.
  ///
  /// - Parameter status: The status.
  /// - Returns: The symbol name.
  static func status(_ status: ToolCallStatus) -> String {
    EditorStatus(status).systemImage
  }

  /// The symbol of a plan entry status.
  ///
  /// - Parameter status: The status.
  /// - Returns: The symbol name.
  static func planStatus(_ status: PlanEntryStatus) -> String {
    EditorStatus(status).systemImage
  }

  /// The disclosure symbol of a tool call header.
  static var disclosure: String {
    EditorSymbol.action(.disclosure).systemImage
  }

  /// The symbol of the header of a terminal.
  static var terminal: String {
    EditorSymbol.tool(.execute).systemImage
  }

  /// The symbol of an error notice.
  static var error: String {
    ErrorView.content(code: .zero, message: "").symbolName
  }

  /// The symbols that a plain button shows in a tool call header.
  static var buttonSymbols: Set<String> {
    let statuses = PreviewFixtures.toolCallStatuses + [ToolCallBackground.staleStatus]
    return Set(toolKinds.map(tool) + statuses.map(status) + [disclosure])
  }

  /// The symbols that a row shows in its own font.
  static var rowSymbols: Set<String> {
    Set(
      planStatuses.map(planStatus) + planPriorities.map(TaskListView.prioritySymbol)
        + [terminal, error, CompactionEntryView.symbolName])
  }

  /// The symbols of the exit labels of an output.
  static var exitSymbols: Set<String> {
    let summaries: [TerminalView.ExitSummary] = [.code(.zero), .code(1), .signal(""), .unknown]
    return Set(summaries.map(\.symbolName))
  }
}

/// Lays out the chrome views of the rows in the environment of a theme.
@MainActor private struct TranscriptRowProbe {
  /// A text of one line.
  static let sample = "Ag"

  /// The title of a probe button.
  static let buttonTitle = "Probe"

  /// The theme, or `nil` for the environment with no theme.
  let theme: (any Theme)?

  /// The environment of the probe.
  var environment: EnvironmentValues {
    var values = EnvironmentValues()
    if let theme {
      values.editorTheme = theme
    }
    return values
  }

  /// The size of a view in the environment of the theme.
  ///
  /// - Parameter view: The view.
  /// - Returns: The size.
  func size(of view: some View) -> CGSize {
    NSHostingView(rootView: themed(view)).fittingSize
  }

  /// The view in the environment of the theme.
  ///
  /// - Parameter view: The view.
  /// - Returns: The view with the theme.
  @ViewBuilder private func themed(_ view: some View) -> some View {
    if let theme {
      view.environment(\.editorTheme, theme)
    } else {
      view
    }
  }

  /// The space that a stack with no spacing puts between two views.
  func stackSpacing() -> CGFloat {
    let one = size(of: VStack { Color.clear.frame(height: 1) }).height
    let two = size(of: VStack { Color.clear.frame(height: 1); Color.clear.frame(height: 1) }).height
    return two - one - one
  }

  /// The size of each chrome view.
  func sizes() -> [TranscriptRowMetrics.Atom: CGSize] {
    var sizes = fixedSizes()
    for state in [SendState.pending, .sent, .failed] {
      sizes[.sendState(state)] = size(of: StatusCaption(status: EditorStatus(state), identifier: ""))
    }
    for name in TranscriptRowSymbols.buttonSymbols {
      sizes[.buttonSymbol(name)] = size(of: button { EditorSymbolImage(systemName: name, tone: .neutral) })
    }
    for name in TranscriptRowSymbols.rowSymbols {
      sizes[.symbol(name)] = size(of: EditorSymbolImage(systemName: name, tone: .neutral))
    }
    for name in TranscriptRowSymbols.exitSymbols {
      sizes[.exitLabel(name)] = size(
        of: OutputExitLabel(text: Self.sample, symbolName: name, outcome: nil, identifier: ""))
    }
    return sizes
  }

  /// The sizes of the chrome views that take no value.
  private func fixedSizes() -> [TranscriptRowMetrics.Atom: CGSize] {
    [
      .messageHeader: size(of: MessageHeader(role: .assistant)),
      .rowText: size(of: Text(Self.sample)),
      .disclosureButton: size(
        of: EditorToolbarButton(Self.buttonTitle, symbol: .action(.disclosure), isOn: .constant(false))
          .editorButtonCaptions(.hidden)),
      .copyButton: size(
        of: EditorToolbarButton(Self.buttonTitle, systemImage: AgentSymbol.copy) {}.editorButtonCaptions(.hidden)),
      .buttonText: size(of: button { Text(Self.sample) }),
      .blockHeaderTitle: size(
        of: BlockHeader {
          Image(systemName: AgentSymbol.codeBlock).symbolColumn()
          Text(Self.sample)
        } actions: {}),
      .pathChip: size(of: PathChip(Self.sample, counts: PathChip.LineCounts(added: 1, removed: 1)) {}),
      .codeText: size(of: ThemeFontText(font: \.code)),
      .headline: size(of: ThemeFontText(font: \.headline)),
    ]
  }

  /// A plain button around a label.
  ///
  /// - Parameter label: The label.
  /// - Returns: The button.
  private func button(@ViewBuilder _ label: () -> some View) -> some View {
    EditorPlainButton(Self.buttonTitle, action: {}, label: label)
  }
}

/// A text of one line in a font of the theme of the environment.
private struct ThemeFontText: View {
  /// The fonts that the probe reads.
  struct Fonts {
    /// The code font.
    let code: Font

    /// The UI headline font.
    let headline: Font
  }

  /// The font to read.
  let font: KeyPath<Fonts, Font>

  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    let fonts = Fonts(code: editorTheme.codeFont, headline: editorTheme.font(for: .ui, style: .headline))
    Text(TranscriptRowProbe.sample).font(fonts[keyPath: font])
  }
}
