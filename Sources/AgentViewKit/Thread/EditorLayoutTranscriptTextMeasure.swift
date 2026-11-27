import AppKit
import EditorDiff
import EditorStyle
import EditorSwiftUI
import EditorText
import EditorTheme
import SwiftUI

/// The text measure of the transcript rows on EditorKit's layout, with no
/// view and off the main thread (cards ^9h7bm9j and ^9ync5h3).
///
/// The measure gives the height of each kind of text part:
///
/// - Markdown (`RenderedMarkdownView`): EditorKit's `EditorLayoutMeasure`
///   in the display font role, with a header row above each fenced code
///   block. The height is exact when EditorKit measures each element of the
///   text (`Measurement.unmeasured` is empty). The measure gives EditorKit
///   the natural size of each image file of the image folder that the text
///   shows (``TranscriptImageSizes``), so an image of the folder is
///   measured. EditorKit typesets inline and block math off the main actor
///   (EditorKit ^tg1hnz7), so math is measured when the iosMath typesetter
///   is available. An image that is not a file of the folder takes its
///   height from a view, so a text with one is not exact.
/// - Code with a line number gutter (`CodeBlockView`): EditorKit's measure
///   of code (`EditorLayoutMeasure.prepare(code:style:grammar:gutter:)`)
///   in the code font role, with the grammar of the block
///   (``CodeBlockView/grammar(of:)``) and the line number gutter with the
///   gutter gap of the style. The height is exact.
/// - Output (`CommandOutputView`, `TerminalView`): EditorKit's measure of
///   code in the code font role, as plain text with no gutter. The height is
///   exact.
/// - A diff (`DiffView`): EditorKit's measure of a diff
///   (`EditorLayoutMeasure.prepare(diff:style:language:contextLines:gutterGap:)`):
///   the inline document of the patch, with each run of context folded as
///   the EditorKit diff view folds it on mount, at the width that the lanes
///   and the change bars of the view leave. The height is exact when
///   EditorKit reads the patch.
/// - A label (`EditorLabel`, `PlacedLabel`): TextKit lays out the text in
///   the font that the label resolves, with no line padding, and the height
///   is rounded up to a whole point, as the label does. The height is exact.
///
/// The measure prepares each part one time (``prepared(_:)``): the
/// prepared value keeps the work that does not depend on the width, so a
/// measure at a new width costs only the line breaks at that width.
///
/// Make the measure on the main actor: it resolves the fonts of the theme
/// and the gutter gap of the style there. The measure is a value, so the
/// cache sends it to its background worker.
nonisolated public struct EditorLayoutTranscriptTextMeasure: TranscriptTextMeasure {
  /// The width of a Markdown measure that only reads the elements of the
  /// text: no width, so the measure wraps no line.
  static let elementsOnlyWidth: CGFloat = .zero

  /// The style of the Markdown parts: the display font role and the code
  /// block headers of `RenderedMarkdownView`.
  let markdownStyle: EditorLayoutMeasure.Style

  /// The style of the code, the output and the diff parts: the code font
  /// role of the theme. A code block header has no effect on a measure of
  /// code.
  let codeStyle: EditorLayoutMeasure.Style

  /// The space between a gutter lane of an editor and its text: the gutter
  /// gap of the style of the environment.
  let gutterGap: CGFloat

  /// The resolved font of each label font.
  let labelFonts: [TranscriptLabelFont: SendableFont]

  /// The folder that the images of the Markdown parts load from, or `nil`
  /// when no image loads.
  let imageFolder: URL?

  /// Makes the measure for a theme.
  ///
  /// - Parameters:
  ///   - theme: The theme of the rows, or `nil` for the default theme of the
  ///     environment.
  ///   - imageFolder: The folder that the images of the Markdown load from
  ///     (``RenderedMarkdownView/imageFolder(of:)``), or `nil` when no image
  ///     loads.
  @MainActor public init(theme: (any Theme)? = nil, imageFolder: URL? = nil) {
    let environment = EnvironmentValues()
    let theme = theme ?? environment.editorTheme
    let context = environment.fontResolutionContext
    let display = EditorTextFont(resolving: theme.displayFont, in: context)
    markdownStyle = EditorLayoutMeasure.Style(
      theme: theme, font: display, lineHeight: display.lineHeight, showsCodeBlockHeader: true)
    let code = EditorTextFont(resolving: theme.codeFont, in: context)
    codeStyle = EditorLayoutMeasure.Style(
      theme: theme, font: code, lineHeight: code.lineHeight, showsCodeBlockHeader: false)
    gutterGap = environment.editorStyle.gutterGap
    labelFonts = Dictionary(
      uniqueKeysWithValues: Self.labelFonts(of: theme).map { label, font in
        (label, SendableFont(font.resolve(in: context).ctFont))
      })
    self.imageFolder = imageFolder
  }

  /// The SwiftUI font of each label font, as the views of the labels set it.
  ///
  /// - Parameter theme: The theme of the rows.
  /// - Returns: The font of each label font.
  @MainActor static func labelFonts(of theme: any Theme) -> [(TranscriptLabelFont, Font)] {
    Font.TextStyle.allCases.map { style in (.ui(style), theme.font(for: .ui, style: style)) } + [
      (.code, theme.codeFont),
      // A label with no font of its own draws in the body font
      // (`EditorLabel`).
      (.inherited, .body),
      (.systemCaption, .caption),
    ]
  }

  /// The height of a text part at a width.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width of the view that shows the text.
  /// - Returns: The height.
  public func height(of part: TranscriptTextPart, width: CGFloat) -> CGFloat {
    measurement(of: part, width: width).height
  }

  /// Tells if the height of a part is the height of the mounted view of the
  /// part.
  ///
  /// Markdown is exact when EditorKit measures each of its elements. Code
  /// with a line number gutter, output and a label are exact. A diff is
  /// exact when EditorKit reads the patch. A label font that the measure
  /// did not resolve is not exact.
  ///
  /// - Parameter part: The text part.
  /// - Returns: `true` when ``height(of:width:)`` is exact for the part.
  public func isExact(_ part: TranscriptTextPart) -> Bool {
    switch part.style {
    case .markdown: measurement(of: part, width: Self.elementsOnlyWidth).isExact
    case .code, .output: true
    case .diff: (try? UnifiedDiff.parse(part.text)) != nil
    case .label(let font): labelFonts[font] != nil
    }
  }

  /// The height of a text part at a width, and whether it is exact: one
  /// measure of the prepared part (``prepared(_:)``).
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width of the view that shows the text.
  /// - Returns: The height and the exact state.
  public func measurement(of part: TranscriptTextPart, width: CGFloat) -> TranscriptTextMeasurement {
    var prepared = prepared(part)
    return prepared.measurement(width: width)
  }

  /// A picture of a text part at a width, drawn by EditorKit with no view,
  /// for the static form of its row (card ^9ync5h3).
  ///
  /// - Markdown: `EditorLayoutMeasure.render(markdown:width:style:imageSizes:citations:)`
  ///   in the Markdown style of the measure. Only a Markdown part whose
  ///   parts EditorKit each draws has a picture
  ///   (``StaticMarkdownPicture/draws(_:)``). Such a part has no image, so
  ///   the picture needs no image size.
  /// - Code and output: `EditorLayoutMeasure.render(code:width:style:grammar:gutter:)`
  ///   in the code style of the measure, with the grammar and the gutter of
  ///   the measure of the part (``codeInputs(of:)``): the syntax colors and
  ///   the line numbers of a `CodeBlockView`, or the plain text of an
  ///   output.
  ///
  /// The picture has the measured height of the part at the width.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width of the view that shows the text.
  ///   - appearance: The color scheme and the scale of the picture.
  /// - Returns: The picture, or `nil` for a diff, a label, or Markdown with
  ///   a part that EditorKit does not draw.
  public func picture(
    of part: TranscriptTextPart, width: CGFloat, appearance: TranscriptTextAppearance
  ) -> EditorStaticRendering? {
    if let code = codeInputs(of: part) {
      let style = EditorLayoutMeasure.RenderStyle(
        codeStyle, colorScheme: appearance.colorScheme, scale: appearance.scale)
      return EditorLayoutMeasure.render(
        code: part.text, width: width, style: style, grammar: code.grammar, gutter: code.gutter)
    }
    guard part.style == .markdown, StaticMarkdownPicture.draws(part.text) else { return nil }
    let style = EditorLayoutMeasure.RenderStyle(
      markdownStyle, colorScheme: appearance.colorScheme, scale: appearance.scale)
    return EditorLayoutMeasure.render(markdown: part.text, width: width, style: style)
  }

  /// The grammar and the gutter of the read-only editor of a code part: the
  /// grammar of a `CodeBlockView` (``CodeBlockView/grammar(of:)``) and the
  /// line number gutter with the gutter gap of the style for code, plain
  /// text with no gutter for an output.
  ///
  /// - Parameter part: The text part.
  /// - Returns: The grammar and the gutter, or `nil` for a part that is not
  ///   code or output.
  func codeInputs(of part: TranscriptTextPart) -> CodeInputs? {
    switch part.style {
    case .code(let language): codeBlockInputs(language: language)
    case .output: .output
    case .markdown, .diff, .label: nil
    }
  }

  /// The grammar and the gutter of the editor of a `CodeBlockView`: the
  /// grammar of the language (``CodeBlockView/grammar(of:)``) and the line
  /// number gutter with the gutter gap of the style.
  ///
  /// - Parameter language: The language of the code, or `nil`.
  /// - Returns: The grammar and the gutter.
  func codeBlockInputs(language: String?) -> CodeInputs {
    CodeInputs(
      grammar: CodeBlockView.grammar(of: CodeBlockView.normalized(language)), gutter: .lineNumbers(gap: gutterGap))
  }

  /// A text part, ready to measure at many widths with EditorKit's
  /// `EditorLayoutMeasure.Prepared`.
  ///
  /// The prepared value keeps the work that does not depend on the width:
  /// the parse, the captures and the font runs, the image chips, the
  /// typeset formulas and the measured tables. A label has no prepared
  /// work: TextKit lays it out at each width.
  ///
  /// - Parameter part: The text part.
  /// - Returns: The prepared part.
  public func prepared(_ part: TranscriptTextPart) -> any PreparedTranscriptTextPart {
    switch part.style {
    case .markdown:
      preparedMarkdown(part.text)
    case .diff:
      preparedDiff(part.text)
    case .code(let language):
      preparedCode(part.text, inputs: codeBlockInputs(language: language))
    case .output:
      preparedCode(part.text, inputs: .output)
    case .label(let font):
      PreparedTranscriptLabel(measure: self, text: part.text, font: font)
    }
  }

  /// A Markdown part, prepared with EditorKit's `EditorLayoutMeasure`, with
  /// the natural size of each image file of the image folder that the text
  /// shows. It is exact when EditorKit measures each element.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The prepared part.
  func preparedMarkdown(_ markdown: String) -> EditorLayoutPreparedTextPart {
    let sizes = imageFolder.map { TranscriptImageSizes.sizes(in: markdown, folder: $0) } ?? [:]
    return EditorLayoutPreparedTextPart(
      prepared: EditorLayoutMeasure.prepare(markdown: markdown, style: markdownStyle, imageSizes: sizes),
      exactness: .whenEachElementIsMeasured)
  }

  /// Code in a read-only editor in the code font, prepared with EditorKit's
  /// measure of code: the code of a `CodeBlockView` with its grammar and
  /// the line number gutter, or plain text with no gutter for an output.
  ///
  /// - Parameters:
  ///   - code: The code.
  ///   - inputs: The grammar and the gutter of the editor.
  ///   - exactness: When the height is exact. The default is exact.
  /// - Returns: The prepared part.
  func preparedCode(
    _ code: String, inputs: CodeInputs, exactness: EditorLayoutPreparedTextPart.Exactness = .exact
  ) -> EditorLayoutPreparedTextPart {
    EditorLayoutPreparedTextPart(
      prepared: EditorLayoutMeasure.prepare(
        code: code, style: codeStyle, grammar: inputs.grammar, gutter: inputs.gutter),
      exactness: exactness)
  }

  /// The EditorKit diff view of a patch (the `PreviewField` of a
  /// `DiffView`), prepared with EditorKit's measure of a diff: the inline
  /// document of the patch at the default context of the view, with each
  /// run of context folded, in the width that the lanes and the strip of
  /// the change bars of the view leave, with the gutter gap of the style.
  /// The view names no language, so the grammar is the one of the files of
  /// the patch.
  ///
  /// A patch that EditorKit cannot read takes the height of the rows of the
  /// patch text at the full width, and is not exact.
  ///
  /// - Parameter patch: The patch text.
  /// - Returns: The prepared part.
  func preparedDiff(_ patch: String) -> EditorLayoutPreparedTextPart {
    guard let diff = try? UnifiedDiff.parse(patch) else {
      return preparedCode(patch, inputs: .output, exactness: .notExact)
    }
    return EditorLayoutPreparedTextPart(
      prepared: EditorLayoutMeasure.prepare(diff: diff, style: codeStyle, gutterGap: gutterGap), exactness: .exact)
  }

  /// The height of a label at a width, and whether it is exact.
  ///
  /// - Parameters:
  ///   - text: The text of the label.
  ///   - font: The font of the label.
  ///   - width: The width of the label.
  /// - Returns: The height and the exact state.
  func labelMeasurement(of text: String, font: TranscriptLabelFont, width: CGFloat) -> TranscriptTextMeasurement {
    TranscriptTextMeasurement(
      height: Self.labelHeight(of: text, font: labelFont(font), width: width), isExact: labelFonts[font] != nil)
  }

  /// The resolved font of a label font, or the system font when the measure
  /// did not resolve it (``isExact(_:)`` is then `false`).
  ///
  /// - Parameter font: The label font.
  /// - Returns: The font.
  func labelFont(_ font: TranscriptLabelFont) -> NSFont {
    labelFonts[font].map { $0.font as NSFont } ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
  }

  /// The height of a label, as `EditorLabel` lays it out: TextKit with no
  /// line padding, rounded up to a whole point.
  ///
  /// - Parameters:
  ///   - text: The text of the label.
  ///   - font: The font of the label.
  ///   - width: The width of the label.
  /// - Returns: The height.
  static func labelHeight(of text: String, font: NSFont, width: CGFloat) -> CGFloat {
    let storage = NSTextStorage(string: text, attributes: [.font: font])
    let layout = NSLayoutManager()
    let container = NSTextContainer(size: CGSize(width: max(width, .zero), height: .greatestFiniteMagnitude))
    container.lineFragmentPadding = .zero
    layout.addTextContainer(container)
    storage.addLayoutManager(layout)
    layout.ensureLayout(for: container)
    return layout.usedRect(for: container).height.rounded(.up)
  }
}

/// The grammar and the gutter of a read-only EditorKit editor of code, for
/// the measure and the picture of a code part
/// (``EditorLayoutTranscriptTextMeasure/codeInputs(of:)``).
nonisolated struct CodeInputs: Sendable {
  /// The grammar of the code.
  let grammar: EditorLayoutMeasure.CodeGrammar

  /// The gutter of the editor.
  let gutter: EditorLayoutMeasure.CodeGutter

  /// The editor of an output, and of a text that EditorKit cannot read as
  /// a patch: plain text with no gutter.
  static let output = CodeInputs(grammar: .plainText, gutter: .none)
}

/// A text part that EditorKit's `EditorLayoutMeasure` prepared
/// (``EditorLayoutTranscriptTextMeasure/prepared(_:)``).
nonisolated struct EditorLayoutPreparedTextPart: PreparedTranscriptTextPart {
  /// When the height of a prepared part is the height of the mounted view.
  enum Exactness: Sendable {
    /// The height is exact at each width.
    case exact

    /// The height is not exact.
    case notExact

    /// The height is exact when EditorKit measures each element of the
    /// text (`Measurement.unmeasured` is empty).
    case whenEachElementIsMeasured
  }

  /// The prepared document of EditorKit. Each measure keeps the work of its
  /// width for the next width.
  var prepared: EditorLayoutMeasure.Prepared

  /// When the height is exact.
  let exactness: Exactness

  mutating func measurement(width: CGFloat) -> TranscriptTextMeasurement {
    let measured = prepared.measure(width: width)
    return TranscriptTextMeasurement(height: measured.height, isExact: isExact(measured))
  }

  /// Tells if a measurement of the document is exact.
  ///
  /// - Parameter measured: The measurement of EditorKit.
  /// - Returns: `true` when the height is the height of the mounted view.
  private func isExact(_ measured: EditorLayoutMeasure.Measurement) -> Bool {
    switch exactness {
    case .exact: true
    case .notExact: false
    case .whenEachElementIsMeasured: measured.unmeasured.isEmpty
    }
  }
}

/// A label text part (``EditorLayoutTranscriptTextMeasure/prepared(_:)``).
/// A label has no work that does not depend on the width, so TextKit lays
/// it out at each width.
nonisolated struct PreparedTranscriptLabel: PreparedTranscriptTextPart {
  /// The measure that resolved the fonts of the labels.
  let measure: EditorLayoutTranscriptTextMeasure

  /// The text of the label.
  let text: String

  /// The font of the label.
  let font: TranscriptLabelFont

  func measurement(width: CGFloat) -> TranscriptTextMeasurement {
    measure.labelMeasurement(of: text, font: font, width: width)
  }
}
