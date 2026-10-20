import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The bar of one status message: a symbol, a title, an explanation, and one
/// optional button with a symbol and a text.
///
/// The bar shows in the thread with the transcript. It is content, so it is
/// on the content surface of the kit (``SwiftUI/View/agentContentSurface()``)
/// and has no glass (D110 (b)). Only its button uses a glass button style.
///
/// ``StateBanner``, ``SessionStreamBanner`` and ``AgentConnectionBanner`` show
/// their messages in this bar. The text of the bar has the
/// ``StateBanner/Message/identifier`` of its message. The accessibility label
/// of the bar is the title.
///
/// The symbol of a failure message (``StateBanner/Message/isFailure``) has the
/// error color of the EditorKit theme. The symbol of each other message has
/// the accent color of the theme.
///
/// The symbol of a message of work that goes on
/// (``StateBanner/Message/isOngoing``), such as the running banner and the
/// replaying banner, shows the live symbol effect of ``LiveSymbolEffect``.
/// Under Reduce Motion, the symbol does not move.
struct StatusBar: View {
  /// The button of a bar.
  struct Action {
    /// The text of the button.
    let title: String

    /// The SF Symbol name that the button shows before its text. Read it
    /// from ``SharedSymbol``.
    let systemImage: String

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
  @Environment(\.editorTheme) private var editorTheme

  /// The color of the symbol of `message`, from the EditorKit theme.
  ///
  /// - Parameters:
  ///   - message: The message of the bar.
  ///   - theme: The EditorKit theme.
  /// - Returns: `severityError` for a failure message, and `accent` for each
  ///   other message.
  static func symbolColor(for message: StateBanner.Message, in theme: any EditorTheme.Theme) -> Color {
    message.isFailure ? theme.severityError : theme.accent
  }

  var body: some View {
    HStack(spacing: theme.spacing.m) {
      StatusSymbolImage(name: message.symbolName, color: Self.symbolColor(for: message, in: editorTheme))
        .liveSymbolEffect(isActive: message.isOngoing)
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
        Button(action.title, systemImage: action.systemImage, action: action.perform)
          .buttonStyle(.glass)
          .disabled(!action.isEnabled)
          .accessibilityIdentifier(action.identifier)
      }
    }
    .padding(theme.spacing.m)
    .agentContentSurface()
    .accessibilityElement(children: .contain)
    .accessibilityLabel(message.title)
  }
}
