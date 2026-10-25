import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The bar of one status message: a symbol, a title, an explanation, and one
/// optional button with a symbol and a text.
///
/// The bar shows in the thread with the transcript. It is content, so it has
/// no fill and no glass. A separator stroke marks its edge
/// (`.inlineEdge(radius:)`, D113). Only its button has a
/// button style of its own, which comes from the place of the bar
/// (``RequestDeckPlace/style(of:)``): the `.glass` style. A bar has no glass
/// surface, and the content scrolls under it, so its button keeps the glass
/// style in the top bar and in the bottom bar of a thread too (TestudoApp
/// `features/style.md`, rule 4). In the bottom bar, ``StateBanner`` declares
/// the place of a bar with no glass for it
/// (``RequestDeckPlace/barWithoutGlass``).
///
/// ``StateBanner``, ``SessionStreamBanner`` and ``AgentConnectionBanner`` show
/// their messages in this bar. The text of the bar has the
/// ``StateBanner/Message/identifier`` of its message. The accessibility label
/// of the bar is the title.
///
/// The symbol of a failure message (``StateBanner/Message/isFailure``) has the
/// error color of the EditorKit theme, a status color of the theme (D112).
/// The symbol of each other message has the `.secondary` style. It does not
/// use the accent of the theme: the accent is only for the selection and the
/// focus (card ^y2mrfxt).
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

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  /// The color of the symbol of `message`.
  ///
  /// - Parameters:
  ///   - message: The message of the bar.
  ///   - theme: The EditorKit theme.
  /// - Returns: `severityError` of `theme` for a failure message, and
  ///   `Color.secondary` for each other message.
  static func symbolColor(for message: StateBanner.Message, in theme: any EditorTheme.Theme) -> Color {
    message.isFailure ? theme.severityError : Color.secondary
  }

  var body: some View {
    HStack(spacing: editorStyle.spacing.m) {
      StatusSymbolImage(name: message.symbolName, color: Self.symbolColor(for: message, in: editorTheme))
        .liveSymbolEffect(isActive: message.isOngoing)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: editorStyle.spacing.xs) {
        Text(message.title)
          .font(editorTheme.font(for: .ui, style: .headline))
        Text(message.explanation)
          .font(editorTheme.font(for: .ui, style: .callout))
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(message.identifier)
      Spacer(minLength: editorStyle.spacing.s)
      if let action {
        Button(action.title, systemImage: action.systemImage, action: action.perform)
          .requestActionStyle(.secondary)
          .disabled(!action.isEnabled)
          .accessibilityIdentifier(action.identifier)
          .agentControlScope(action.identifier)
      }
    }
    .padding(editorStyle.spacing.m)
    .inlineEdge(radius: editorStyle.radii.l)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(message.title)
  }
}

#Preview("Each agent state") {
  VStack(alignment: .leading) {
    ForEach(PreviewFixtures.statusMessages, id: \.identifier) { message in
      StatusBar(message: message, action: nil)
    }
  }
  .padding()
}

#Preview("Long status text") {
  StatusBar(message: PreviewFixtures.longStatusMessage, action: PreviewFixtures.statusAction(isEnabled: true))
    .frame(width: PreviewFixtures.narrowWidth)
    .padding()
}

#Preview("Bar with its buttons") {
  // The button has the `.glass` style in content and in a bar with no glass,
  // so the previews declare no place.
  VStack(alignment: .leading) {
    ForEach([true, false], id: \.self) { isEnabled in
      StatusBar(
        message: PreviewFixtures.failedTurnStatusMessage, action: PreviewFixtures.statusAction(isEnabled: isEnabled))
    }
  }
  .padding()
}
