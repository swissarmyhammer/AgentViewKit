import EditorStyle
import EditorSwiftUI
import SwiftUI

/// The bar of one status message: a title line, and an explanation below it.
///
/// The title line holds the symbol, the title, and one optional button with a
/// symbol and a text, at the end of the line. The symbol and the button are
/// centered on the title. The explanation stands below that line, under the
/// title and not under the symbol, and wraps at the width of the bar, so its
/// length never moves the symbol or the button down the bar. With no
/// explanation, the bar is only its title line (``StatusTitleLayout``).
///
/// Each message has a title, a few words that stand alone on the title line.
/// A longer text is the explanation.
///
/// The surface of the bar comes from the ``StatusBarPlacement`` of the
/// environment (``SwiftUI/View/statusBarPlacement(_:)``, TestudoApp D213):
///
/// - In content, the default, the bar has no fill and no glass. A separator
///   stroke marks its edge (`.inlineEdge(radius:)`, D113).
/// - A note that floats over content is on the floating glass of the kit
///   (`.floatingGlass()` of EditorStyle), the glass of the status line, so
///   the text under the note does not show through it. The glass has no
///   separator stroke. Under Reduce Transparency, the system gives the glass
///   an opaque background. The button of the bar stands on that glass
///   (`.editorButtonSurface(.glass)`), so it takes the bordered style, and no
///   glass stands on glass.
///
/// Its button takes its look from the ``StatusBarActionStyle`` of the
/// environment: by default ``GlassStatusBarActionStyle``, the button of the
/// action in the style of its surface: the `.glass` style of a button that
/// the content scrolls under, and the bordered style on the glass of a
/// floating note (EditorKit `style.md`, rule 4). A kit that gives the button
/// more, such as the focus scope of a bar control, sets its own style with
/// ``SwiftUI/View/statusBarActionStyle(_:)``.
///
/// The text of the bar has the ``Message/identifier`` of its message. It is one
/// accessibility element, the title, with the label of the title and the
/// explanation. The accessibility label of the bar is the title.
///
/// A bar is dismissible when its action is
/// ``Action/makeDismiss(identifier:perform:)``, as the bar of a notice is. Its
/// button shows only its symbol, and its title is the tooltip and the
/// accessibility label. The bar has no outer padding: the layout that holds it
/// gives the space around it (`style.md`, rule 10).
///
/// The symbol is an EditorKit `EditorSymbolImage` in the tone of the
/// ``Message/severity`` of the message (``Message/Severity/tone``): the
/// error, warning or information color of the EditorKit theme (D112), or the
/// secondary style of its place for a neutral message. No symbol uses the
/// accent of the theme: the accent is only for the selection and the focus
/// (card ^y2mrfxt).
///
/// The symbol of a message of work that goes on (``Message/isOngoing``)
/// shows EditorKit's live symbol effect (`liveSymbolEffect(isActive:)` of
/// `EditorSwiftUI`). Under Reduce Motion, the symbol does not move.
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

      /// The EditorKit tone the symbol of a message of this severity draws
      /// in: `EditorSymbol.Tone.neutral` for a neutral message, which
      /// draws in the secondary style of its place, and the information,
      /// warning or error token of the theme for each other severity.
      public var tone: EditorSymbol.Tone {
        switch self {
        case .neutral: .neutral
        case .information: .information
        case .warning: .warning
        case .failure: .error
        }
      }
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
    ///     EditorKit's `EditorSymbol`, or from `ItemStatus` of EditorStyle.
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
    /// or the ``StatusTitleText/label(title:explanation:)`` of the title and
    /// the explanation.
    var textLabel: String {
      accessibilityLabel ?? StatusTitleText.label(title: title, explanation: explanation)
    }
  }

  /// The button of a bar.
  public struct Action {
    /// The text of the button.
    public let title: String

    /// The SF Symbol name that the button shows before its text. Read it
    /// from EditorKit's `EditorSymbol`.
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
    /// - Returns: The button, which shows only the `EditorSymbol.action(.dismiss)`
    ///   symbol.
    public static func makeDismiss(identifier: String, perform: @escaping () -> Void) -> Action {
      Action(
        title: String(localized: "Dismiss", bundle: .module), systemImage: EditorSymbol.action(.dismiss).systemImage,
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
  @Environment(\.statusBarActionStyle) private var actionStyle

  /// The place of the bar, which gives its surface.
  @Environment(\.statusBarPlacement) private var placement

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

  /// The title line of the message, with its symbol in the tone of its severity, and the button of the action.
  public var body: some View {
    StatusTitleLayout(
      title: message.title, explanation: message.explanation, textLabel: message.textLabel,
      identifier: message.identifier
    ) {
      EditorSymbolImage(systemName: message.symbolName, tone: message.severity.tone, isLive: message.isOngoing)
        .help(message.symbolHelp ?? "")
        .accessibilityHidden(true)
    } action: {
      if let action {
        actionButton(action)
      }
    }
    // A bar is chrome, so a neutral symbol keeps the vibrant `.secondary`,
    // and the explanation (a `PlacedLabel`) has the vibrant secondary
    // foreground (D110).
    .onChrome()
    .contentTile()
    .modifier(StatusBarSurface(placement: placement, radius: editorStyle.radii.l))
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

/// The surface of a bar in its place: the separator edge in content, and the
/// floating glass of the kit for a floating note.
private struct StatusBarSurface: ViewModifier {
  /// The place of the bar.
  let placement: StatusBarPlacement

  /// The least corner radius of the edge in content. The floating glass
  /// takes the same large radius of the style.
  let radius: CGFloat

  func body(content: Content) -> some View {
    switch placement {
    case .content:
      content.inlineEdge(radius: radius)
    case .floating:
      // The button stands on the glass of the note, so it takes the
      // bordered style, and no glass stands on glass (EditorKit `style.md`,
      // rule 4). This surface is inside the surface that a banner declares
      // around its bar, so it wins.
      content
        .editorButtonSurface(.glass)
        .floatingGlass()
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

#Preview("Short title, long explanation and a button") {
  StatusBar(
    message: StylePreviewFixtures.longExplanationStatusMessage,
    action: StylePreviewFixtures.statusAction(isEnabled: true)
  )
  .frame(width: StylePreviewFixtures.narrowWidth)
  .padding()
}

#Preview("Only a title line") {
  VStack(alignment: .leading) {
    StatusBar(message: StylePreviewFixtures.titleOnlyStatusMessage, action: nil)
    StatusBar(
      message: StylePreviewFixtures.titleOnlyStatusMessage, action: StylePreviewFixtures.statusAction(isEnabled: true))
  }
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
