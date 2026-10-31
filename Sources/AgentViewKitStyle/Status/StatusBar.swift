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
/// A bar is dismissible when its action is
/// ``Action/makeDismiss(identifier:perform:)``, as the bar of a notice is. Its
/// button shows only its symbol, and its title is the tooltip and the
/// accessibility label. The bar has no outer padding: the layout that holds it
/// gives the space around it (`style.md`, rule 10).
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

    /// The explanation below the title. An empty explanation shows no line.
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

    /// The accessibility label of the text of the bar, or `nil` for the title
    /// and the explanation.
    public let accessibilityLabel: String?

    /// The help tag of the symbol, or `nil` for no help tag.
    public let symbolHelp: String?

    /// Makes the text of a bar.
    ///
    /// - Parameters:
    ///   - title: The short title of the bar.
    ///   - explanation: The explanation below the title. An empty explanation
    ///     shows no line.
    ///   - symbolName: The SF Symbol name of the bar. Read it from
    ///     ``SharedSymbol``, or from `ItemStatus` of EditorStyle.
    ///   - identifier: The accessibility identifier of the text of the bar.
    ///   - severity: How much the message asks of the user. The default is
    ///     ``Severity/neutral``.
    ///   - isOngoing: Whether the message tells of work that goes on. The
    ///     default is `false`.
    ///   - accessibilityLabel: The accessibility label of the text of the bar,
    ///     or `nil` for the title and the explanation.
    ///   - symbolHelp: The help tag of the symbol, or `nil` for no help tag.
    public init(
      title: String, explanation: String, symbolName: String, identifier: String, severity: Severity = .neutral,
      isOngoing: Bool = false, accessibilityLabel: String? = nil, symbolHelp: String? = nil
    ) {
      self.title = title
      self.explanation = explanation
      self.symbolName = symbolName
      self.identifier = identifier
      self.severity = severity
      self.isOngoing = isOngoing
      self.accessibilityLabel = accessibilityLabel
      self.symbolHelp = symbolHelp
    }

    /// The accessibility label of the text of the bar: ``accessibilityLabel``,
    /// or the title and the explanation.
    var textLabel: String {
      accessibilityLabel ?? (explanation.isEmpty ? title : "\(title), \(explanation)")
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

    /// Whether the button shows only its symbol. Its title is then the tooltip
    /// and the accessibility label.
    public let isIconOnly: Bool

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
    ///   - isIconOnly: Whether the button shows only its symbol. The default
    ///     is `false`.
    ///   - perform: The closure that a press calls.
    public init(
      title: String, systemImage: String, identifier: String, isEnabled: Bool, hint: String? = nil,
      isIconOnly: Bool = false, perform: @escaping () -> Void
    ) {
      self.title = title
      self.systemImage = systemImage
      self.identifier = identifier
      self.isEnabled = isEnabled
      self.hint = hint
      self.isIconOnly = isIconOnly
      self.perform = perform
    }

    /// Makes the Dismiss button of a dismissible bar, such as the bar of a
    /// notice.
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier of the button.
    ///   - perform: The closure that a press calls: it removes the bar.
    /// - Returns: The button, which shows only the ``SharedSymbol/dismiss``
    ///   symbol.
    public static func makeDismiss(identifier: String, perform: @escaping () -> Void) -> Action {
      Action(
        title: String(localized: "Dismiss", bundle: .module), systemImage: SharedSymbol.dismiss,
        identifier: identifier, isEnabled: true, isIconOnly: true, perform: perform)
    }
  }

  /// The text of the bar.
  let message: Message

  /// The button of the bar, or `nil` for no button.
  let action: Action?

  /// The accessibility identifier of the whole bar, or `nil` for none.
  let identifier: String?

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.statusBarActionStyle) private var actionStyle

  /// Makes the bar of one message.
  ///
  /// - Parameters:
  ///   - message: The text of the bar.
  ///   - action: The button of the bar, or `nil` for no button.
  ///   - identifier: The accessibility identifier of the whole bar, or `nil`
  ///     for none. The ``Message/identifier`` of the message names its text.
  public init(message: Message, action: Action?, identifier: String? = nil) {
    self.message = message
    self.action = action
    self.identifier = identifier
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
        .help(message.symbolHelp ?? "")
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: editorStyle.spacing.xs) {
        Text(message.title)
          .font(editorTheme.font(for: .ui, style: .headline))
        if !message.explanation.isEmpty {
          Text(message.explanation)
            .font(editorTheme.font(for: .ui, style: .callout))
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }
      // A selectable text leaves a combined element, so the text is one
      // element with an explicit label.
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(message.textLabel)
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
    .modifier(BarIdentifier(identifier: identifier))
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

/// The accessibility identifier of a bar, when it has one.
private struct BarIdentifier: ViewModifier {
  /// The identifier, or `nil` for none.
  let identifier: String?

  func body(content: Content) -> some View {
    if let identifier {
      content.accessibilityIdentifier(identifier)
    } else {
      content
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
