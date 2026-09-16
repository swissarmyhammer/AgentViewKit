import SwiftUI

/// The row that tells how many rows of an output show, with a Show All
/// button.
///
/// ``CommandOutputView`` and ``TerminalView`` show this row when the output
/// has more rows than the row limit.
struct OutputCapRow: View {
  /// The rows that show.
  let rows: CommandOutputView.VisibleRows
  /// The accessibility identifier of the text.
  let capIdentifier: String
  /// The accessibility identifier of the Show All button.
  let showAllIdentifier: String
  /// The action of the Show All button.
  let showAll: () -> Void

  @Environment(\.agentTheme) private var theme

  var body: some View {
    HStack(spacing: theme.spacing.s) {
      Text(String(localized: "Showing the last \(rows.visibleCount) of \(rows.totalCount) lines"))
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(capIdentifier)
      Spacer(minLength: theme.spacing.s)
      Button(String(localized: "Show all \(rows.totalCount) lines"), action: showAll)
        .buttonStyle(.borderless)
        .font(.caption)
        .accessibilityIdentifier(showAllIdentifier)
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.xs)
  }
}

/// The label that shows how a command exited.
///
/// ``CommandOutputView`` and ``TerminalView`` show this label in their
/// footer. VoiceOver reads the text as the label and the outcome as the
/// value.
struct OutputExitLabel: View {
  /// The text of the label.
  let text: String
  /// The SF Symbol name of the label.
  let symbolName: String
  /// The outcome of the command, or `nil` when it is not known. The label
  /// uses the secondary color for an unknown outcome.
  let outcome: CommandOutputView.ExitOutcome?
  /// The accessibility identifier of the label.
  let identifier: String

  @Environment(\.agentTheme) private var theme

  var body: some View {
    Label(text, systemImage: symbolName)
      .font(.caption)
      .fontWeight(theme.symbolWeight)
      .foregroundStyle(outcome.map(theme.statusColors.color(for:)) ?? Color.secondary)
      .padding(.horizontal, theme.spacing.m)
      .padding(.vertical, theme.spacing.xs)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(text)
      .accessibilityValue(outcome?.label ?? "")
      // An element with no role does not give its value. The trait gives the
      // static text role.
      .accessibilityAddTraits(.isStaticText)
      .accessibilityIdentifier(identifier)
  }
}
