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
/// its label, the full path of the working folder as its value, and the
/// identifier ``identifier``. With crumbs, it is a container, so that each
/// crumb is an element. The `directory` module shows the widest form of its
/// path that fits the width of the line, with whole names only, and the full
/// path of the working folder as its tooltip and its accessibility value.
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
  @Environment(\.statusLineHomeFolder) private var homeFolder
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
      session: session, connection: connection, sessionTitle: sessionTitle, model: model, homeFolder: homeFolder)
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
    session: SessionModel, connection: ConnectionModel?, sessionTitle: String?, model: StatusLineModel,
    homeFolder: URL? = nil
  ) -> StatusLineInput {
    let info = connection?.initializeResponse?.info
    let usage = session.usage
    let title = session.parent == nil ? (sessionTitle ?? session.displayTitle) : session.displayTitle
    var input = StatusLineInput(
      cwd: folder(of: session), displayNames: model.displayNames, git: model.git, files: model.files,
      sessionTitle: title,
      agentName: info?.displayName, agentVersion: info?.version,
      modelName: modelName(of: session.configOptions), contextUsed: usage?.used, contextSize: usage?.size)
    if let homeFolder {
      input.homeFolder = homeFolder.path(percentEncoded: false)
    }
    return input
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
    // The full width of the line takes a click, so that a right click on
    // its empty part opens the context menu of the header (D193 (f)).
    .contentShape(Rectangle())
    .accessibilityElement(children: path.isEmpty ? .ignore : .contain)
    .accessibilityLabel(rendering.plainText)
    // One element has no child, so the line gives the value of the
    // directory module.
    .statusLineAccessibilityValue(path.isEmpty ? rendering.help(of: .directory) : nil)
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
      StatusLinePieceText(piece: piece)
        .contentShape(Rectangle())
        .onTapGesture { actions?(module, folder: input.cwd.map { AbsolutePath(rawValue: $0) }) }
        .statusLineHelp(piece.help)
        .accessibilityIdentifier(StatusLineView.identifier(for: module))
    } else {
      StatusLineText(spans: piece.spans)
    }
  }
}

extension View {
  /// Shows a text as the tooltip and as the accessibility value of a
  /// module.
  ///
  /// - Parameter text: The help text of the module, or `nil` for none.
  /// - Returns: The view with the tooltip and the value.
  @ViewBuilder fileprivate func statusLineHelp(_ text: String?) -> some View {
    if let text {
      help(Text(verbatim: text)).statusLineAccessibilityValue(text)
    } else {
      self
    }
  }

  /// Sets the accessibility value of the line.
  ///
  /// - Parameter text: The value, or `nil` for no value.
  /// - Returns: The view with the value.
  @ViewBuilder fileprivate func statusLineAccessibilityValue(_ text: String?) -> some View {
    if let text {
      accessibilityValue(Text(verbatim: text))
    } else {
      self
    }
  }
}

/// The runs of one part of the line in the widest form that fits the width
/// that the line gives to the part.
///
/// The view uses no `ViewThatFits`, which measures each form again in each
/// layout pass (^2n9ymsh). ``StatusLineFormLayout`` measures each form one
/// time for each change of the forms, and gives the part the size of the
/// widest form that fits. The view reads the width of each form and the
/// width of the part with `onGeometryChange(for:of:action:)`, and shows only
/// the form that fits. The other forms are hidden, and VoiceOver does not
/// read them.
struct StatusLinePieceText: View {
  let piece: StatusLinePiece

  /// The measured width of each form, by its index in ``forms``.
  @State private var formWidths: [Int: CGFloat] = [:]

  /// The measured width of the part, or `nil` before the first layout.
  @State private var width: CGFloat?

  /// The forms of the runs, from the widest.
  private var forms: [[StatusLineSpan]] {
    [piece.spans] + piece.narrowerSpans
  }

  var body: some View {
    let forms = forms
    if forms.count == 1 {
      StatusLineText(spans: piece.spans)
    } else {
      let shown = StatusLineFormLayout.indexOfWidestForm(
        fitting: width, in: forms.indices.map { formWidths[$0] ?? .infinity })
      StatusLineFormLayout {
        ForEach(forms.indices, id: \.self) { index in
          StatusLineText(spans: forms[index])
            .opacity(index == shown ? 1 : 0)
            .accessibilityHidden(index != shown)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { formWidths[index] = $0 }
        }
      }
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
  }
}

/// The layout of the forms of one part of the status line, from the widest:
/// the part takes the size of the widest form that fits the proposed width,
/// as a `ViewThatFits` in the horizontal axis does.
///
/// The layout measures the ideal width of each form one time, in its cache,
/// and measures again only when the forms change. It puts the form that fits
/// in the proposed size, and each other form at its ideal size, so that the
/// view can read the width of each form. When no form fits, the part shows
/// the narrowest form, which the line then truncates.
struct StatusLineFormLayout: Layout {
  /// The ideal width of each form.
  struct Cache {
    /// The ideal width of each form, from the widest form.
    let widths: [CGFloat]
  }

  /// The index of the widest form that fits a width.
  ///
  /// - Parameters:
  ///   - width: The width, or `nil` for the ideal size.
  ///   - widths: The width of each form, from the widest form.
  /// - Returns: The index of the first form that is not wider than `width`,
  ///   the first index for no width, and the last index when no form fits.
  static func indexOfWidestForm(fitting width: CGFloat?, in widths: [CGFloat]) -> Int {
    guard let width else { return 0 }
    return widths.firstIndex { $0 <= width } ?? max(widths.count - 1, 0)
  }

  /// Measures the ideal width of each form.
  ///
  /// - Parameter subviews: The forms, from the widest.
  /// - Returns: The cache with the width of each form.
  func makeCache(subviews: Subviews) -> Cache {
    Cache(widths: subviews.map { $0.sizeThatFits(.unspecified).width })
  }

  /// The size of the widest form that fits the proposal.
  ///
  /// - Parameters:
  ///   - proposal: The size that the parent proposes.
  ///   - subviews: The forms, from the widest.
  ///   - cache: The width of each form.
  /// - Returns: The size of the form in the proposal, or zero with no form.
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
    guard !subviews.isEmpty else { return .zero }
    return subviews[Self.indexOfWidestForm(fitting: proposal.width, in: cache.widths)].sizeThatFits(proposal)
  }

  /// Puts the form that fits in `bounds`, and each other form at its ideal
  /// size at the same origin.
  ///
  /// - Parameters:
  ///   - bounds: The bounds of the part.
  ///   - proposal: The size that the parent proposes.
  ///   - subviews: The forms, from the widest.
  ///   - cache: The width of each form.
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
    let shown = Self.indexOfWidestForm(fitting: bounds.width, in: cache.widths)
    for (index, subview) in subviews.enumerated() {
      subview.place(
        at: bounds.origin, anchor: .topLeading,
        proposal: index == shown ? ProposedViewSize(bounds.size) : .unspecified)
    }
  }

  /// The vertical guide of the form that fits, such as its first text
  /// baseline, so that the line aligns the part on the shown form.
  ///
  /// - Parameters:
  ///   - guide: The guide.
  ///   - bounds: The bounds of the part.
  ///   - proposal: The size that the parent proposes.
  ///   - subviews: The forms, from the widest.
  ///   - cache: The width of each form.
  /// - Returns: The position of the guide of the shown form, or `nil` with
  ///   no form.
  func explicitAlignment(
    of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout Cache
  ) -> CGFloat? {
    guard !subviews.isEmpty else { return nil }
    let shown = subviews[Self.indexOfWidestForm(fitting: bounds.width, in: cache.widths)]
    return bounds.minY + shown.dimensions(in: ProposedViewSize(bounds.size))[guide]
  }
}

/// The input of the text of a ``StatusLineText``: the runs, and the colors
/// and the icon size that the environment gives to them.
nonisolated struct StatusLineTextInput: Equatable {
  /// The runs.
  let spans: [StatusLineSpan]

  /// The color of each run, with the dimmed opacity.
  let colors: [Color]

  /// The side of a bundled icon, in points.
  let iconSide: CGFloat
}

/// The parts of the text of a ``StatusLineText``, in order: each sequence
/// of text runs joins into one `AttributedString`, and each image is a part
/// of its own.
private struct StatusLineTextParts {
  /// The parts before the pending text.
  private var parts: [Text] = []

  /// The text runs after the last image.
  private var pending = AttributedString()

  /// Adds a text run to the pending text.
  ///
  /// - Parameter run: The styled run.
  mutating func append(_ run: AttributedString) {
    pending.append(run)
  }

  /// Adds the pending text as a part, and then an image.
  ///
  /// - Parameter image: The styled text of the image.
  mutating func append(_ image: Text) {
    flushPending()
    parts.append(image)
  }

  /// The parts, with the pending text as the last part.
  ///
  /// - Returns: The parts, or one empty text when no run has text.
  mutating func finished() -> [Text] {
    flushPending()
    return parts.isEmpty ? [Text(AttributedString())] : parts
  }

  /// Adds the pending text as a part when it is not empty.
  private mutating func flushPending() {
    guard !pending.characters.isEmpty else { return }
    parts.append(Text(pending))
    pending = AttributedString()
  }
}

/// The runs of one part of the line, as one text.
///
/// The view builds its text one time for each set of runs and colors
/// (``ParseMemo``), and not in each evaluation of its body (^2n9ymsh). Each
/// sequence of text runs is one `AttributedString`, so SwiftUI does not scan
/// a nested localized key in each layout pass. A set of runs with no image
/// is one `Text` of one `AttributedString`. An `AttributedString` holds no
/// image, so a set of runs with an SF Symbol or an icon is one `Text` that
/// puts its text parts and its images side by side, at one level.
///
/// In a debug build, each build adds one count to the
/// ``BodyEvaluationCounter`` key ``counterKey(for:)``.
struct StatusLineText: View {
  let spans: [StatusLineSpan]

  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.themeForeground) private var themeForeground
  @Environment(\.themeSecondary) private var themeSecondary
  @Environment(\.themeAccent) private var themeAccent

  /// The last text that the view built, with its input.
  @State private var memo = ParseMemo<StatusLineTextInput, Text>()

  /// The start of the ``BodyEvaluationCounter`` key of each text build.
  static let counterKeyPrefix = "status-line-text-"

  /// The ``BodyEvaluationCounter`` key of the text builds of a set of runs.
  ///
  /// - Parameter spans: The runs.
  /// - Returns: ``counterKeyPrefix`` and the plain text of the runs.
  static func counterKey(for spans: [StatusLineSpan]) -> String {
    counterKeyPrefix + spans.map(\.plainText).joined()
  }

  var body: some View {
    let input = StatusLineTextInput(
      spans: spans, colors: spans.map { styleColor(of: $0.style) },
      iconSide: StatusLineIcons.side(forPointSize: Self.pointSize))
    memo.value(for: input, counterKey: Self.counterKey(for: spans), parse: Self.text(of:))
  }

  /// The text of a set of runs.
  ///
  /// - Parameter input: The runs, with their colors.
  /// - Returns: One `Text` of one `AttributedString` when the runs have no
  ///   image. Otherwise one `Text` with the parts side by side.
  static func text(of input: StatusLineTextInput) -> Text {
    let parts = parts(of: input)
    if parts.count == 1, let part = parts.first {
      return part
    }
    var interpolation = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: parts.count)
    for part in parts {
      interpolation.appendInterpolation(part)
    }
    return Text(LocalizedStringKey(stringInterpolation: interpolation))
  }

  /// The parts of the text of a set of runs: one `Text` of one
  /// `AttributedString` for each sequence of text runs, and one `Text` for
  /// each image.
  ///
  /// - Parameter input: The runs, with their colors.
  /// - Returns: The parts, in order. Runs with no text give one empty part.
  private static func parts(of input: StatusLineTextInput) -> [Text] {
    var parts = StatusLineTextParts()
    for (span, color) in zip(input.spans, input.colors) {
      switch span.content {
      case .text(let value):
        parts.append(attributedRun(value, style: span.style, color: color))
      case .sfSymbol(let name):
        parts.append(styledImage(Text(Image(systemName: name)), style: span.style, color: color))
      case .icon(let name):
        parts.append(styledImage(iconText(named: name, side: input.iconSide), style: span.style, color: color))
      }
    }
    return parts.finished()
  }

  /// The styled text of a text run.
  ///
  /// - Parameters:
  ///   - value: The text of the run.
  ///   - style: The style of the run.
  ///   - color: The color of the run.
  /// - Returns: The text, bold and italic as the style asks.
  private static func attributedRun(_ value: String, style: StatusLineStyle, color: Color) -> AttributedString {
    var run = AttributedString(value)
    run.swiftUI.foregroundColor = color
    var intent: InlinePresentationIntent = []
    if style.modifiers.contains(.bold) { intent.insert(.stronglyEmphasized) }
    if style.modifiers.contains(.italic) { intent.insert(.emphasized) }
    if !intent.isEmpty { run.inlinePresentationIntent = intent }
    return run
  }

  /// The text of a bundled icon. An icon that the kit does not bundle shows
  /// its name.
  ///
  /// - Parameters:
  ///   - name: The name of the icon, such as `swift`.
  ///   - side: The side of the icon, in points.
  /// - Returns: The text of the icon.
  private static func iconText(named name: String, side: CGFloat) -> Text {
    guard let image = StatusLineIcons.image(named: name, side: side) else { return Text(verbatim: name) }
    return Text(Image(nsImage: image).renderingMode(.template)).baselineOffset(Self.iconBaselineOffset)
  }

  /// The text of an image run in the style of the run.
  ///
  /// - Parameters:
  ///   - text: The text of the image.
  ///   - style: The style of the run.
  ///   - color: The color of the run.
  /// - Returns: The text, bold and italic as the style asks, in the color.
  private static func styledImage(_ text: Text, style: StatusLineStyle, color: Color) -> Text {
    var text = text
    if style.modifiers.contains(.bold) { text = text.bold() }
    if style.modifiers.contains(.italic) { text = text.italic() }
    return text.foregroundStyle(color)
  }

  /// The color of a run, with the dimmed opacity for a dimmed run.
  ///
  /// - Parameter style: The style of the run.
  /// - Returns: The color.
  private func styleColor(of style: StatusLineStyle) -> Color {
    let color = color(of: style.color)
    return style.modifiers.contains(.dimmed) ? color.opacity(Self.dimmedOpacity) : color
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
