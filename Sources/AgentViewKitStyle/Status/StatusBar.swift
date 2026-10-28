import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The bar of one status message: a symbol, a title, an explanation, and one
/// optional button with a symbol and a text.
///
/// The bar is content, so it has no fill and no glass. A separator stroke
/// marks its edge (`.inlineEdge(radius:)`, D113). Its button takes its look
/// from the ``StatusBarActionStyle`` of the environment: by default
/// ``GlassStatusBarActionStyle``, the `.glass` style of a button that the
/// content scrolls under (EditorKit `style.md`, rule 4). A kit that
/// gives the button more, such as the focus scope of a bar control, sets its
/// own style with ``SwiftUI/View/statusBarActionStyle(_:)``.
///
/// The text of the bar has the ``Message/identifier`` of its message. The
/// accessibility label of the bar is the title.
///
/// The symbol takes its color from the ``Message/severity`` of the message:
/// the error, warning or information color of the EditorKit theme, the status
/// colors of the theme (D112), or the `.secondary` style for a neutral
/// message. No symbol uses the accent of the theme: the accent is only for
/// the selection and the focus (card ^y2mrfxt).
///
/// The symbol of a message of work that goes on (``Message/isOngoing``)
/// shows the live symbol effect of ``LiveSymbolEffect``. Under Reduce Motion,
/// the symbol does not move.
public struct StatusBar: View {
  /// The text that a bar shows.
  public struct Message: Equatable, Sendable {
    /// How much a message asks of the user, which gives the color of its
    /// symbol.
    public enum Severity: Equatable, Sendable {
      /// A message of a state with no concern, such as an agent that runs or
      /// a closed session. Its symbol has the `.secondary` style.
      case neutral

      /// A message that informs. Its symbol has the information color of
      /// the theme.
      case information

      /// A message of a state that needs care, such as missed updates. Its
      /// symbol has the warning color of the theme.
      case warning

      /// A message of a failure, such as a failed turn or a failed
      /// connection. Its symbol has the error color of the theme.
      case failure
    }

    /// The short title of the bar.
    public let title: String

    /// The explanation below the title.
    public let explanation: String

    /// The SF Symbol name of the bar.
    public let symbolName: String

    /// The accessibility identifier of the text of the bar. Each message has
    /// a different identifier.
    public let identifier: String

    /// How much the message asks of the user.
    public let severity: Severity

    /// Whether the message tells of work that goes on, such as an agent that
    /// runs or a replay of the history. The bar animates the symbol of such
    /// a message with a symbol effect, except under Reduce Motion.
    public let isOngoing: Bool

    /// Makes the text of a bar.
    ///
    /// - Parameters:
    ///   - title: The short title of the bar.
    ///   - explanation: The explanation below the title.
    ///   - symbolName: The SF Symbol name of the bar. Read it from
    ///     ``SharedSymbol``, or from `ItemStatus` of EditorStyle.
    ///   - identifier: The accessibility identifier of the text of the bar.
    ///   - severity: How much the message asks of the user. The default is
    ///     ``Severity/neutral``.
    ///   - isOngoing: Whether the message tells of work that goes on. The
    ///     default is `false`.
    public init(
      title: String, explanation: String, symbolName: String, identifier: String, severity: Severity = .neutral,
      isOngoing: Bool = false
    ) {
      self.title = title
      self.explanation = explanation
      self.symbolName = symbolName
      self.identifier = identifier
      self.severity = severity
      self.isOngoing = isOngoing
    }
  }

  /// The button of a bar.
  public struct Action {
    /// The text of the button.
    public let title: String

    /// The SF Symbol name that the button shows before its text. Read it
    /// from ``SharedSymbol``.
    public let systemImage: String

    /// The accessibility identifier of the button.
    public let identifier: String

    /// Whether the button takes a press.
    public let isEnabled: Bool

    /// The accessibility hint of the button, or `nil` for no hint.
    public let hint: String?

    /// The closure that a press calls.
    public let perform: () -> Void

    /// Makes the button of a bar.
    ///
    /// - Parameters:
    ///   - title: The text of the button.
    ///   - systemImage: The SF Symbol name that the button shows before its
    ///     text.
    ///   - identifier: The accessibility identifier of the button.
    ///   - isEnabled: Whether the button takes a press.
    ///   - hint: The accessibility hint of the button, or `nil` for no hint.
    ///   - perform: The closure that a press calls.
    public init(
      title: String, systemImage: String, identifier: String, isEnabled: Bool, hint: String? = nil,
      perform: @escaping () -> Void
    ) {
      self.title = title
      self.systemImage = systemImage
      self.identifier = identifier
      self.isEnabled = isEnabled
      self.hint = hint
      self.perform = perform
    }
  }

  /// The text of the bar.
  let message: Message

  /// The button of the bar, or `nil` for no button.
  let action: Action?

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.statusBarActionStyle) private var actionStyle

  /// Makes the bar of one message.
  ///
  /// - Parameters:
  ///   - message: The text of the bar.
  ///   - action: The button of the bar, or `nil` for no button.
  public init(message: Message, action: Action?) {
    self.message = message
    self.action = action
  }

  /// The color of the symbol of `message`.
  ///
  /// - Parameters:
  ///   - message: The message of the bar.
  ///   - theme: The EditorKit theme.
  /// - Returns: `severityError` of `theme` for a failure, `severityWarning`
  ///   for a warning, `severityInfo` for information, and `Color.secondary`
  ///   for a neutral message.
  public static func symbolColor(for message: Message, in theme: any EditorTheme.Theme) -> Color {
    switch message.severity {
    case .neutral: Color.secondary
    case .information: theme.severityInfo
    case .warning: theme.severityWarning
    case .failure: theme.severityError
    }
  }

  public var body: some View {
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
        actionButton(action)
      }
    }
    .contentTile()
    .inlineEdge(radius: editorStyle.radii.l)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(message.title)
  }

  /// The button of `action`, in the style of the environment, or in
  /// ``GlassStatusBarActionStyle`` when the environment has no style.
  ///
  /// - Parameter action: The action of the button.
  /// - Returns: The styled button.
  @ViewBuilder
  private func actionButton(_ action: Action) -> some View {
    let configuration = StatusBarActionConfiguration(action: action, button: StatusBarActionButton(action: action))
    if let actionStyle {
      actionStyle.makeBody(configuration: configuration)
    } else {
      GlassStatusBarActionStyle().makeBody(configuration: configuration)
    }
  }
}

#Preview("Each severity") {
  VStack(alignment: .leading) {
    ForEach(StylePreviewFixtures.statusMessages, id: \.identifier) { message in
      StatusBar(message: message, action: nil)
    }
  }
  .padding()
}

#Preview("Long status text") {
  StatusBar(message: StylePreviewFixtures.longStatusMessage, action: StylePreviewFixtures.statusAction(isEnabled: true))
    .frame(width: StylePreviewFixtures.narrowWidth)
    .padding()
}

#Preview("Bar with its buttons") {
  VStack(alignment: .leading) {
    ForEach([true, false], id: \.self) { isEnabled in
      StatusBar(
        message: StylePreviewFixtures.failureStatusMessage,
        action: StylePreviewFixtures.statusAction(isEnabled: isEnabled))
    }
  }
  .padding()
}
