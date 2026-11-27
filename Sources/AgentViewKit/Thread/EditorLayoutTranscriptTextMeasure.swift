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
/// - A diff (`DiffView`): EditorKit's measure of code of the inline document
///   of the patch, at the width that the gutters and the change bars of the
///   EditorKit diff view leave (``TranscriptDiffLayout``). The height is exact when EditorKit
///   reads the patch and the document has no context to fold.
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

  /// The width of the two gutter columns of fixed width of the EditorKit
  /// diff view: the expand column (`DiffExpandGutter`) and the marker
  /// column (`DiffMarkerGutter`).
  let diffFixedColumnsWidth: CGFloat

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
    diffFixedColumnsWidth = DiffExpandGutter.defaultWidth + DiffMarkerGutter.defaultWidth
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
  /// exact when EditorKit reads the patch and the document has no context
  /// to fold. A label font that the measure did not resolve is not exact.
  ///
  /// - Parameter part: The text part.
  /// - Returns: `true` when ``height(of:width:)`` is exact for the part.
  public func isExact(_ part: TranscriptTextPart) -> Bool {
    switch part.style {
    case .markdown: measurement(of: part, width: Self.elementsOnlyWidth).isExact
    case .code, .output: true
    case .diff: TranscriptDiffLayout(patch: part.text) != nil
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
      preparedCode(
        part.text, grammar: CodeBlockView.grammar(of: CodeBlockView.normalized(language)),
        gutter: .lineNumbers(gap: gutterGap))
    case .output:
      preparedCode(part.text, grammar: .plainText, gutter: .none)
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
      exactness: .whenEachElementIsMeasured, chromeWidth: .zero)
  }

  /// Code in a read-only editor in the code font, prepared with EditorKit's
  /// measure of code: the code of a `CodeBlockView` with its grammar and
  /// the line number gutter, plain text with no gutter for an output, or
  /// the inline document of a diff.
  ///
  /// - Parameters:
  ///   - code: The code.
  ///   - grammar: The grammar of the code.
  ///   - gutter: The gutter of the editor.
  ///   - exactness: When the height is exact. The default is exact.
  ///   - chromeWidth: The width of the view that the code does not get.
  ///     The default is none.
  /// - Returns: The prepared part.
  func preparedCode(
    _ code: String, grammar: EditorLayoutMeasure.CodeGrammar, gutter: EditorLayoutMeasure.CodeGutter,
    exactness: EditorLayoutPreparedTextPart.Exactness = .exact, chromeWidth: CGFloat = .zero
  ) -> EditorLayoutPreparedTextPart {
    EditorLayoutPreparedTextPart(
      prepared: EditorLayoutMeasure.prepare(code: code, style: codeStyle, grammar: grammar, gutter: gutter),
      exactness: exactness, chromeWidth: chromeWidth)
  }

  /// The EditorKit diff view of a patch, prepared with EditorKit's measure
  /// of code of the inline document of the patch. The measure takes the
  /// width that the gutters and the change bars of the diff view leave.
  ///
  /// A patch that EditorKit cannot read, or a document with context to
  /// fold, takes the height of the rows of the patch text at the full
  /// width, and is not exact.
  ///
  /// - Parameter patch: The patch text.
  /// - Returns: The prepared part.
  func preparedDiff(_ patch: String) -> EditorLayoutPreparedTextPart {
    guard let layout = TranscriptDiffLayout(patch: patch) else {
      return preparedCode(patch, grammar: .plainText, gutter: .none, exactness: .notExact)
    }
    return preparedCode(
      layout.document.text, grammar: layout.grammar, gutter: .none,
      chromeWidth: layout.chromeWidth(style: codeStyle, fixedColumns: diffFixedColumnsWidth, gap: gutterGap))
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

  /// The width of the view that the document does not get, such as the
  /// gutters of a diff view.
  let chromeWidth: CGFloat

  mutating func measurement(width: CGFloat) -> TranscriptTextMeasurement {
    let measured = prepared.measure(width: width - chromeWidth)
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
