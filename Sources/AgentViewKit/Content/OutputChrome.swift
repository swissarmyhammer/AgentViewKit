import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The row that tells how many rows of an output show, with a Show All
/// button.
///
/// ``CommandOutputView`` and ``TerminalView`` show this row when the output
/// has more rows than the row limit.
struct OutputCapRow: View {
  /// The symbol of the Show All button.
  static let showAllSymbol = SharedSymbol.showAll

  /// The rows that show.
  let rows: CommandOutputView.VisibleRows
  /// The accessibility identifier of the text.
  let capIdentifier: String
  /// The accessibility identifier of the Show All button.
  let showAllIdentifier: String
  /// The action of the Show All button.
  let showAll: () -> Void

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.themeSecondary) private var themeSecondary

  var body: some View {
    HStack(spacing: editorStyle.spacing.s) {
      Text(
        String(
          localized: "Showing the last \(rows.visibleCount) of \(rows.totalCount) lines",
          bundle: .module)
      )
        .font(editorTheme.font(for: .ui, style: .caption))
        .foregroundStyle(themeSecondary)
        .accessibilityIdentifier(capIdentifier)
      Spacer(minLength: editorStyle.spacing.s)
      Button(
        String(localized: "Show all \(rows.totalCount) lines", bundle: .module),
        systemImage: Self.showAllSymbol, action: showAll
      )
        .buttonStyle(.borderless)
        .font(editorTheme.font(for: .ui, style: .caption))
        .accessibilityIdentifier(showAllIdentifier)
    }
  }
}

/// The label that shows how a command exited, as EditorKit's
/// `EditorStatusLabel`.
///
/// ``CommandOutputView`` and ``TerminalView`` show this label in their
/// footer. VoiceOver reads the text as the label and the outcome as the
/// value, which is also the help tag.
struct OutputExitLabel: View {
  /// The text of the label.
  let text: String
  /// The SF Symbol name of the label.
  let symbolName: String
  /// The outcome of the command, or `nil` when it is not known. The symbol
  /// draws in the tone of the EditorKit status of the outcome, and in the
  /// neutral tone for an unknown outcome.
  let outcome: CommandOutputView.ExitOutcome?
  /// The accessibility identifier of the label.
  let identifier: String

  @Environment(\.editorTheme) private var editorTheme

  /// The status token of the exit: the symbol in the tone of the outcome,
  /// the text as the label, and the outcome as the detail.
  var status: EditorStatus {
    EditorStatus(
      systemName: symbolName, tone: outcome?.symbol.tone ?? .neutral, label: text, detail: outcome?.label)
  }

  var body: some View {
    EditorStatusLabel(status)
      .font(editorTheme.font(for: .ui, style: .caption))
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityIdentifier(identifier)
  }
}

#Preview("Output cut to its last rows") {
  OutputCapRow(
    rows: PreviewFixtures.cappedOutputRows, capIdentifier: CommandOutputView.capIdentifier,
    showAllIdentifier: CommandOutputView.showAllIdentifier, showAll: {})
}

#Preview("Exit code 0, a failing exit code, and a stop by a signal") {
  VStack(alignment: .leading) {
    ForEach(PreviewFixtures.exitSummaries, id: \.label) { summary in
      OutputExitLabel(
        text: summary.label, symbolName: summary.symbolName, outcome: summary.outcome,
        identifier: CommandOutputView.footerIdentifier)
    }
  }
}
