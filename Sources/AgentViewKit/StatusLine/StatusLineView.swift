import AppKit
import EditorStyle
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The status line of a session: the header of the top bar of
/// ``AgentThreadView`` (D194).
///
/// The line shows the ``StatusLineDefinition`` of the environment
/// (``SwiftUI/View/statusLine(_:)``): by default the working folder, the git
/// branch and status, the languages of the code, and the session. It follows
/// the file and git changes of the folder and the end of each turn. The
/// text has the UI font and the colors of the theme (D143). The line has no
/// button (D193 (f)): a click on a module runs the host command of the
/// module (``SwiftUI/View/statusLineActions(_:)``). For a child session, the
/// session module shows the crumbs of the path to it, with their sibling
/// menus.
///
/// The view is one accessibility element with the plain text of the line as
/// its label, and the identifier ``identifier``. With crumbs, it is a
/// container, so that each crumb is an element.
public struct StatusLineView: View {
  /// The accessibility identifier of the line.
  public static let identifier = "agent-status-line"

  /// The start of the accessibility identifier of each module.
  public static let moduleIdentifierPrefix = "agent-status-line-"

  /// The session.
  let session: SessionModel

  /// The connection, or `nil`: the `agent` module reads its name.
  let connection: ConnectionModel?

  /// The title of the session that the host gives, or `nil` for the title
  /// of the session model.
  let sessionTitle: String?

  /// Shows a session of the crumbs.
  let select: (SessionId) -> Void

  @Environment(\.statusLineDefinition) private var definition
  @State private var model: StatusLineModel

  /// Makes the status line of a session.
  ///
  /// - Parameters:
  ///   - session: The session.
  ///   - connection: The connection, or `nil`.
  ///   - sessionTitle: The title of the session, or `nil` for the title of
  ///     the session model.
  ///   - model: The folder data, or `nil` for a model that reads the folder
  ///     with libgit2.
  ///   - select: Shows a session of the crumbs.
  public init(
    session: SessionModel, connection: ConnectionModel? = nil, sessionTitle: String? = nil,
    model: StatusLineModel? = nil, select: @escaping (SessionId) -> Void = { _ in }
  ) {
    self.session = session
    self.connection = connection
    self.sessionTitle = sessionTitle
    self.select = select
    _model = State(initialValue: model ?? StatusLineModel())
  }

  /// The accessibility identifier of a module.
  ///
  /// - Parameter module: The module.
  /// - Returns: `agent-status-line-<module>`.
  public static func identifier(for module: StatusLineModuleID) -> String {
    moduleIdentifierPrefix + module.rawValue
  }

  public var body: some View {
    let path = session.path
    let showsCrumbs = path.count > 1 && definition.session.showsPath
    let input = StatusLineView.input(
      session: session, connection: connection, sessionTitle: sessionTitle, model: model)
    StatusLineContent(
      input: input, definition: definition, path: showsCrumbs ? path : [], rootTitle: sessionTitle, select: select
    )
    .task(id: StatusLineFollow(folder: Self.folder(of: session), ignoreSubmodules: definition.gitStatus.ignoreSubmodules)) {
      await model.follow(Self.folder(of: session), ignoreSubmodules: definition.gitStatus.ignoreSubmodules)
    }
    .onChange(of: session.isRunning) { _, isRunning in
      // The end of each turn reads the folder again (D194 (j)).
      guard !isRunning else { return }
      Task { await model.refresh() }
    }
  }

  /// The data of the line.
  static func input(
    session: SessionModel, connection: ConnectionModel?, sessionTitle: String?, model: StatusLineModel
  ) -> StatusLineInput {
    let info = connection?.initializeResponse?.info
    let usage = session.usage
    let title = session.parent == nil ? (sessionTitle ?? session.displayTitle) : session.displayTitle
    return StatusLineInput(
      cwd: folder(of: session), git: model.git, files: model.files, sessionTitle: title,
      agentName: info.map { $0.title ?? $0.name }, agentVersion: info?.version,
      modelName: modelName(of: session.configOptions), contextUsed: usage?.used, contextSize: usage?.size)
  }

  /// The working folder of a session: its own `cwd`, or for a child session
  /// with no `cwd` the folder of the nearest session above it that has one.
  ///
  /// - Parameter session: The session.
  /// - Returns: The path, or `nil` when no session of the path has a `cwd`.
  static func folder(of session: SessionModel) -> String? {
    session.path.reversed().lazy.compactMap(\.cwd).first?.rawValue
  }

  /// The name of the current value of the model config option.
  static func modelName(of options: [SessionConfigOption]?) -> String? {
    guard let option = options?.first(where: { $0.category == .model }),
      case .select(let select) = option.type
    else { return nil }
    let choice = select.choices?.options.first { $0.value == select.currentValue }
    return choice?.name ?? select.currentValue.rawValue
  }
}

/// The key of the folder task of a ``StatusLineView``.
private struct StatusLineFollow: Equatable {
  let folder: String?
  let ignoreSubmodules: Bool
}

/// The rendered line.
struct StatusLineContent: View {
  let input: StatusLineInput
  let definition: StatusLineDefinition
  /// The path of crumbs, or empty for no crumbs.
  let path: [SessionModel]
  let rootTitle: String?
  let select: (SessionId) -> Void

  @Environment(\.statusLineActions) private var actions
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    let usesTime = definition.format.references.contains(StatusLineModuleID.time.rawValue)
    if usesTime {
      TimelineView(.everyMinute) { context in
        line(at: context.date)
      }
    } else {
      line(at: input.date)
    }
  }

  private func line(at date: Date) -> some View {
    var input = input
    input.date = date
    let rendering = StatusLineRenderer.render(definition, input: input)
    return HStack(alignment: .firstTextBaseline, spacing: 0) {
      ForEach(Array(rendering.pieces.enumerated()), id: \.offset) { _, piece in
        pieceView(piece)
      }
    }
    .font(editorTheme.font(for: .ui, style: Self.textStyle))
    .lineLimit(1)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: path.isEmpty ? .ignore : .contain)
    .accessibilityLabel(rendering.plainText)
    .accessibilityAddTraits(.isHeader)
    .accessibilityIdentifier(StatusLineView.identifier)
  }

  /// The text style of the line: the style of each run and of the crumbs.
  static let textStyle = Font.TextStyle.callout

  /// The style of the crumbs in the line: the crumb text in the text style
  /// of the line.
  ///
  /// - Parameter style: The style of the environment.
  /// - Returns: The style with ``textStyle`` for the crumbs.
  static func lineCrumbStyle(_ style: EditorStyle) -> EditorStyle {
    var style = style
    style.buttons.crumbCaptionStyle = textStyle
    return style
  }

  @ViewBuilder
  private func pieceView(_ piece: StatusLinePiece) -> some View {
    if piece.module == .session, !path.isEmpty {
      SessionBreadcrumb(path: path, rootTitle: rootTitle, select: select)
        // The crumbs take the text style of the line, not the bold headline
        // style of a crumb of EditorKit.
        .environment(\.editorStyle, Self.lineCrumbStyle(editorStyle))
        .accessibilityIdentifier(StatusLineView.identifier(for: .session))
    } else if let module = piece.module {
      StatusLineText(spans: piece.spans)
        .contentShape(Rectangle())
        .onTapGesture { actions?(module, folder: input.cwd.map { AbsolutePath(rawValue: $0) }) }
        .accessibilityIdentifier(StatusLineView.identifier(for: module))
    } else {
      StatusLineText(spans: piece.spans)
    }
  }
}

/// The runs of one part of the line, as one text.
struct StatusLineText: View {
  let spans: [StatusLineSpan]

  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.themeForeground) private var themeForeground
  @Environment(\.themeSecondary) private var themeSecondary
  @Environment(\.themeAccent) private var themeAccent

  var body: some View {
    spans.reduce(Text(verbatim: "")) { text, span in
      Text("\(text)\(styled(span))")
    }
  }

  private func styled(_ span: StatusLineSpan) -> Text {
    var text: Text
    switch span.content {
    case .text(let value):
      text = Text(verbatim: value)
    case .sfSymbol(let name):
      text = Text(Image(systemName: name))
    case .icon(let name):
      if let image = StatusLineIcons.image(named: name, side: StatusLineIcons.side(forPointSize: Self.pointSize)) {
        text = Text(Image(nsImage: image).renderingMode(.template)).baselineOffset(Self.iconBaselineOffset)
      } else {
        text = Text(verbatim: name)
      }
    }
    let style = span.style
    if style.modifiers.contains(.bold) { text = text.bold() }
    if style.modifiers.contains(.italic) { text = text.italic() }
    let color = color(of: style.color)
    return text.foregroundStyle(style.modifiers.contains(.dimmed) ? color.opacity(Self.dimmedOpacity) : color)
  }

  /// The point size of the text of the line: the callout size of the
  /// system, as the UI font of the theme in the callout style.
  static var pointSize: CGFloat { NSFont.preferredFont(forTextStyle: .callout).pointSize }

  /// The move of an icon below the baseline, so that it centers on the
  /// letters as an SF Symbol does.
  static let iconBaselineOffset: CGFloat = -2

  /// The opacity of a dimmed run.
  static let dimmedOpacity = 0.6

  /// The color of a style color: an entry of the terminal palette of the
  /// theme, or a role of the theme.
  private func color(of color: StatusLineStyle.Color?) -> Color {
    switch color {
    case nil, .role(.primary): themeForeground
    case .role(.secondary): themeSecondary
    case .role(.tertiary): themeSecondary.opacity(Self.dimmedOpacity)
    case .role(.accent): themeAccent
    case .ansi(let ansi): editorTheme.terminalPalette[Self.paletteEntry(ansi)]
    }
  }

  /// The terminal palette entry of an ANSI color name.
  static func paletteEntry(_ color: StatusLineStyle.ANSIColor) -> TerminalPalette.Entry {
    switch color {
    case .black: .black
    case .red: .red
    case .green: .green
    case .yellow: .yellow
    case .blue: .blue
    case .purple, .magenta: .magenta
    case .cyan: .cyan
    case .white: .white
    case .brightBlack: .brightBlack
    case .brightRed: .brightRed
    case .brightGreen: .brightGreen
    case .brightYellow: .brightYellow
    case .brightBlue: .brightBlue
    case .brightPurple, .brightMagenta: .brightMagenta
    case .brightCyan: .brightCyan
    case .brightWhite: .brightWhite
    }
  }
}
