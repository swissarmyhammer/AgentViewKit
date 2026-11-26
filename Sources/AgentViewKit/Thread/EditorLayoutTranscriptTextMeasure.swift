import AppKit
import EditorCore
import EditorDiff
import EditorSwiftUI
import EditorText
import EditorTheme
import SwiftUI

/// The text measure of the transcript rows on EditorKit's layout, with no
/// view and off the main thread (card ^9h7bm9j).
///
/// The measure gives the height of each kind of text part:
///
/// - Markdown (`RenderedMarkdownView`): EditorKit's `EditorLayoutMeasure`
///   in the display font role, with a header row above each fenced code
///   block. The height is exact when EditorKit measures each element of the
///   text (`Measurement.unmeasured` is empty). An image and math take their
///   height from a view, so a text with one of them is not exact.
/// - Output (`CommandOutputView`, `TerminalView`): plain text in a
///   read-only editor in the code font role, with no gutter. The height is
///   the rows of the EditorKit wrap map (`WrapMap`) times the row height of
///   the font, so it is exact.
/// - A label (`EditorLabel`, `PlacedLabel`): TextKit lays out the text in
///   the font that the label resolves, with no line padding, and the height
///   is rounded up to a whole point, as the label does. The height is exact.
/// - Code with a line number gutter (`CodeBlockView`) and a diff
///   (`DiffView`): EditorKit has no measure of their gutters (EditorKit
///   ^v8t0pka). The height is the rows of the text at the full width, so it
///   is not exact.
///
/// Make the measure on the main actor: it resolves the fonts of the theme
/// there. The measure is a value, so the cache sends it to its background
/// worker.
nonisolated public struct EditorLayoutTranscriptTextMeasure: TranscriptTextMeasure {
  /// The width of a Markdown measure that only reads the elements of the
  /// text: no width, so the measure wraps no line.
  static let elementsOnlyWidth: CGFloat = .zero

  /// The style of the Markdown parts: the display font role and the code
  /// block headers of `RenderedMarkdownView`.
  let markdownStyle: EditorLayoutMeasure.Style

  /// The font of the code, the output and the diff parts: the code font role
  /// of the theme.
  let codeFont: EditorTextFont

  /// The resolved font of each label font.
  let labelFonts: [TranscriptLabelFont: SendableFont]

  /// Makes the measure for a theme.
  ///
  /// - Parameter theme: The theme of the rows, or `nil` for the default
  ///   theme of the environment.
  @MainActor public init(theme: (any Theme)? = nil) {
    let environment = EnvironmentValues()
    let theme = theme ?? environment.editorTheme
    let context = environment.fontResolutionContext
    let display = EditorTextFont(resolving: theme.displayFont, in: context)
    markdownStyle = EditorLayoutMeasure.Style(
      theme: theme, font: display, lineHeight: display.lineHeight, showsCodeBlockHeader: true)
    codeFont = EditorTextFont(resolving: theme.codeFont, in: context)
    labelFonts = Dictionary(
      uniqueKeysWithValues: Self.labelFonts(of: theme).map { label, font in
        (label, SendableFont(font.resolve(in: context).ctFont))
      })
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
  /// Markdown is exact when EditorKit measures each of its elements. Output
  /// and a label are exact. Code with a line number gutter and a diff are not
  /// exact. A label font that the measure did not resolve is not exact.
  ///
  /// - Parameter part: The text part.
  /// - Returns: `true` when ``height(of:width:)`` is exact for the part.
  public func isExact(_ part: TranscriptTextPart) -> Bool {
    switch part.style {
    case .markdown: markdownMeasurement(of: part.text, width: Self.elementsOnlyWidth).isExact
    case .output: true
    case .label(let font): labelFonts[font] != nil
    case .code, .diff: false
    }
  }

  /// The height of a text part at a width, and whether it is exact.
  ///
  /// A Markdown part gives the two from one EditorKit measure.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width of the view that shows the text.
  /// - Returns: The height and the exact state.
  public func measurement(of part: TranscriptTextPart, width: CGFloat) -> TranscriptTextMeasurement {
    switch part.style {
    case .markdown:
      markdownMeasurement(of: part.text, width: width)
    case .output, .code, .diff, .label:
      TranscriptTextMeasurement(height: partHeight(of: part, width: width), isExact: isExact(part))
    }
  }

  /// The height of a Markdown part, and whether it is exact: EditorKit's
  /// `EditorLayoutMeasure`.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown text.
  ///   - width: The width of the view.
  /// - Returns: The height, exact when EditorKit measures each element.
  func markdownMeasurement(of markdown: String, width: CGFloat) -> TranscriptTextMeasurement {
    let measured = EditorLayoutMeasure.measure(markdown: markdown, width: width, style: markdownStyle)
    return TranscriptTextMeasurement(height: measured.height, isExact: measured.unmeasured.isEmpty)
  }

  /// The height of a part at a width, with the layout of its kind of view.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width of the view.
  /// - Returns: The height.
  func partHeight(of part: TranscriptTextPart, width: CGFloat) -> CGFloat {
    switch part.style {
    case .markdown: markdownMeasurement(of: part.text, width: width).height
    case .output, .code: plainHeight(of: part.text, width: width)
    case .diff: plainHeight(of: Self.diffText(of: part.text), width: width)
    case .label(let font): Self.labelHeight(of: part.text, font: labelFont(font), width: width)
    }
  }

  /// The resolved font of a label font, or the system font when the measure
  /// did not resolve it (``isExact(_:)`` is then `false`).
  ///
  /// - Parameter font: The label font.
  /// - Returns: The font.
  func labelFont(_ font: TranscriptLabelFont) -> NSFont {
    labelFonts[font].map { $0.font as NSFont } ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
  }

  /// The height of plain text in a read-only editor in the code font, with
  /// no gutter: the rows of the EditorKit wrap map times the row height.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - width: The width of the editor. A width of zero or less wraps no
  ///     line.
  /// - Returns: The height.
  func plainHeight(of text: String, width: CGFloat) -> CGFloat {
    let rows = WrapMap(
      buffer: TextBuffer(text), mode: width > .zero ? .viewportWidth(width) : .none,
      breaker: LineBreaker(font: codeFont.font)
    ).totalRows
    return CGFloat(rows) * codeFont.lineHeight
  }

  /// The text of the inline document of the EditorKit diff view of a
  /// patch: a header row for each file and each hunk, and the rows of the
  /// lines.
  ///
  /// - Parameter patch: The patch text.
  /// - Returns: The text of the document, or the patch text when EditorKit
  ///   cannot read the patch.
  static func diffText(of patch: String) -> String {
    guard let parsed = try? UnifiedDiff.parse(patch) else { return patch }
    return DiffDocument(inline: parsed, contextLines: LineDiff.defaultContext).text
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
