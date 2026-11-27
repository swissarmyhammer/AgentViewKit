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
///   of code (`EditorLayoutMeasure.measure(code:width:style:grammar:gutter:)`)
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
    case .markdown: markdownMeasurement(of: part.text, width: Self.elementsOnlyWidth).isExact
    case .code, .output: true
    case .diff: TranscriptDiffLayout(patch: part.text) != nil
    case .label(let font): labelFonts[font] != nil
    }
  }

  /// The height of a text part at a width, and whether it is exact.
  ///
  /// A Markdown part and a diff give the two from one measure.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width of the view that shows the text.
  /// - Returns: The height and the exact state.
  public func measurement(of part: TranscriptTextPart, width: CGFloat) -> TranscriptTextMeasurement {
    switch part.style {
    case .markdown:
      markdownMeasurement(of: part.text, width: width)
    case .diff:
      diffMeasurement(of: part.text, width: width)
    case .code(let language):
      TranscriptTextMeasurement(height: codeHeight(of: part.text, language: language, width: width), isExact: true)
    case .output:
      TranscriptTextMeasurement(height: outputHeight(of: part.text, width: width), isExact: true)
    case .label(let font):
      TranscriptTextMeasurement(
        height: Self.labelHeight(of: part.text, font: labelFont(font), width: width), isExact: isExact(part))
    }
  }

  /// The height of a Markdown part, and whether it is exact: EditorKit's
  /// `EditorLayoutMeasure`, with the natural size of each image file of the
  /// image folder that the text shows.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown text.
  ///   - width: The width of the view.
  /// - Returns: The height, exact when EditorKit measures each element.
  func markdownMeasurement(of markdown: String, width: CGFloat) -> TranscriptTextMeasurement {
    let sizes = imageFolder.map { TranscriptImageSizes.sizes(in: markdown, folder: $0) } ?? [:]
    let measured = EditorLayoutMeasure.measure(
      markdown: markdown, width: width, style: markdownStyle, imageSizes: sizes)
    return TranscriptTextMeasurement(height: measured.height, isExact: measured.unmeasured.isEmpty)
  }

  /// The resolved font of a label font, or the system font when the measure
  /// did not resolve it (``isExact(_:)`` is then `false`).
  ///
  /// - Parameter font: The label font.
  /// - Returns: The font.
  func labelFont(_ font: TranscriptLabelFont) -> NSFont {
    labelFonts[font].map { $0.font as NSFont } ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
  }

  /// The height of the code of a `CodeBlockView`: EditorKit's measure of
  /// code with the grammar of the block and the line number gutter.
  ///
  /// - Parameters:
  ///   - code: The code.
  ///   - language: The language of the code block, or `nil`.
  ///   - width: The width of the editor.
  /// - Returns: The height.
  func codeHeight(of code: String, language: String?, width: CGFloat) -> CGFloat {
    EditorLayoutMeasure.height(
      ofCode: code, width: width, style: codeStyle,
      grammar: CodeBlockView.grammar(of: CodeBlockView.normalized(language)),
      gutter: .lineNumbers(gap: gutterGap))
  }

  /// The height of plain text in a read-only editor in the code font, with
  /// no gutter: EditorKit's measure of code as plain text.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - width: The width of the editor. A width of zero or less wraps no
  ///     line.
  /// - Returns: The height.
  func outputHeight(of text: String, width: CGFloat) -> CGFloat {
    EditorLayoutMeasure.height(ofCode: text, width: width, style: codeStyle, grammar: .plainText, gutter: .none)
  }

  /// The height of the EditorKit diff view of a patch, and whether it is
  /// exact.
  ///
  /// A patch that EditorKit cannot read, or a document with context to
  /// fold, takes the height of the rows of the patch text at the full
  /// width, and is not exact.
  ///
  /// - Parameters:
  ///   - patch: The patch text.
  ///   - width: The width of the diff view.
  /// - Returns: The height and the exact state.
  func diffMeasurement(of patch: String, width: CGFloat) -> TranscriptTextMeasurement {
    guard let layout = TranscriptDiffLayout(patch: patch) else {
      return TranscriptTextMeasurement(height: outputHeight(of: patch, width: width), isExact: false)
    }
    let chrome = layout.chromeWidth(style: codeStyle, fixedColumns: diffFixedColumnsWidth, gap: gutterGap)
    let height = EditorLayoutMeasure.height(
      ofCode: layout.document.text, width: width - chrome, style: codeStyle, grammar: layout.grammar,
      gutter: .none)
    return TranscriptTextMeasurement(height: height, isExact: true)
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
