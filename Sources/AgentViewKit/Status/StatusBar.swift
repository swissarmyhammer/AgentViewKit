import SwiftUI

/// The glass bar of one status message: a symbol, a title, an explanation,
/// and one optional button.
///
/// ``StateBanner`` and ``SessionStreamBanner`` show their messages in this
/// bar. The text of the bar has the ``StateBanner/Message/identifier`` of its
/// message. The accessibility label of the bar is the title.
struct StatusBar: View {
  /// The button of a bar.
  struct Action {
    /// The text of the button.
    let title: String

    /// The accessibility identifier of the button.
    let identifier: String

    /// Whether the button takes a press.
    let isEnabled: Bool

    /// The closure that a press calls.
    let perform: () -> Void
  }

  /// The text of the bar.
  let message: StateBanner.Message

  /// The button of the bar, or `nil` for no button.
  let action: Action?

  @Environment(\.agentTheme) private var theme

  var body: some View {
    HStack(spacing: theme.spacing.m) {
      Image(systemName: message.symbolName)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(theme.accent)
        .fontWeight(theme.symbolWeight)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        Text(message.title)
          .font(.headline)
        Text(message.explanation)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(message.identifier)
      Spacer(minLength: theme.spacing.s)
      if let action {
        Button(action.title, action: action.perform)
          .buttonStyle(.glass)
          .disabled(!action.isEnabled)
          .accessibilityIdentifier(action.identifier)
      }
    }
    .padding(theme.spacing.m)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(message.title)
  }
}
