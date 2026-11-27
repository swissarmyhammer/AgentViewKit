import EditorSwiftUI
import SwiftUI

/// The rules of the pictures of the static Markdown text of a thread (card
/// ^9ync5h3).
///
/// EditorKit draws a picture of rendered Markdown with no view
/// (`EditorLayoutMeasure.render(markdown:width:style:imageSizes:)`): the
/// text in the fonts and the colors of the theme, the background of inline
/// code, the links, the quote bars and the code bands. The picture does not
/// draw math, the grid of a table, the line of a strikethrough, an image,
/// the header of a code block, the title of an alert, or another inline
/// widget, such as the checkbox of a task item or a footnote mark. A text
/// that holds one of these keeps its SwiftUI `Text` in the static form of
/// its row. The rules read the source text, and keep the `Text` for each
/// source that can hold such a part.
nonisolated enum StaticMarkdownPicture {
  /// The marks of a part that the picture does not draw, anywhere in a
  /// text: a strikethrough or a code fence of tildes, an image, a table
  /// row, a footnote, an HTML tag or an autolink, and a code fence of
  /// backticks.
  static let unsupportedMarks = ["~~", "![", "|", "[^", "<", "```"]

  /// The indent of a line of indented code.
  static let indentedCodeIndent = "    "

  /// The start of a line of indented code with a tab.
  static let tabIndent = "\t"

  /// Tells if EditorKit draws each part of `markdown` in a picture.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: `true` when the text has no math, no mark of
  ///   ``unsupportedMarks``, and no line that ``drawsLine(_:)`` rejects.
  static func draws(_ markdown: String) -> Bool {
    !RenderedMarkdownView.hasMath(markdown) && !unsupportedMarks.contains(where: markdown.contains)
      && markdown.split(separator: "\n", omittingEmptySubsequences: false).allSatisfy(drawsLine)
  }

  /// Tells if EditorKit draws one source line in a picture: the line is no
  /// indented code, no title of an alert, no task item, and no thematic
  /// break or underline of a setext heading.
  ///
  /// - Parameter line: The source line, with no line break.
  /// - Returns: `true` when the picture draws the line.
  static func drawsLine(_ line: Substring) -> Bool {
    let isIndentedCode = line.hasPrefix(indentedCodeIndent) || line.hasPrefix(tabIndent)
    let isAlert = line.wholeMatch(of: /\s{0,3}>\s*\[!.*/) != nil
    let isTask = line.wholeMatch(of: /\s*(?:[-*+]|\d+[.)])\s+\[[ xX]\].*/) != nil
    let isRule = line.wholeMatch(of: /\s{0,3}([-*_=])(?:\s*\1){2,}\s*/) != nil
    return !(isIndentedCode || isAlert || isTask || isRule)
  }
}

/// The picture of a static text slot: the bitmap that EditorKit drew off the
/// main thread, at the size of the picture (card ^9ync5h3).
///
/// SwiftUI draws the bitmap as an image, and lays out no text. The view
/// has the size of the picture: the width of the text area and the
/// measured height of the text, so the row has the height of the cache.
/// The text of the picture is the accessibility label of the image.
struct StaticPictureView: View {
  /// The start of the ``BodyEvaluationCounter`` key of each picture.
  static let counterKeyPrefix = "static-picture-"

  /// The picture.
  let picture: EditorStaticRendering

  /// The text of the picture: Markdown, code or an output.
  let text: String

  /// Makes the view of a picture.
  ///
  /// - Parameters:
  ///   - picture: The picture.
  ///   - text: The text of the picture.
  init(_ picture: EditorStaticRendering, text: String) {
    self.picture = picture
    self.text = text
  }

  /// The ``BodyEvaluationCounter`` key of the picture of `text`.
  ///
  /// - Parameter text: The text of the picture.
  /// - Returns: `static-picture-<text>`.
  static func counterKey(for text: String) -> String {
    BodyEvaluationKey.make(prefix: counterKeyPrefix, id: text)
  }

  var body: some View {
    #if DEBUG
      let _ = BodyEvaluationCounter.note(Self.counterKey(for: text))
    #endif
    ZStack(alignment: .topLeading) {
      if let image = picture.image {
        // The text is the label, so an assistive app finds the text of the
        // slot, and its focus on the slot makes the row real (card ^7625j1b).
        Image(image, scale: picture.scale, label: Text(verbatim: text))
      }
    }
    .frame(width: picture.size.width, height: picture.size.height, alignment: .topLeading)
  }
}

/// The still view of a ``StaticEditorSlot``: the picture of its text when
/// the height cache of the thread has one in the appearance of the slot,
/// else the still view of the slot (card ^9ync5h3).
struct StaticSlotStill<Still: View>: View {
  /// The text part of the slot, or `nil` for a slot with no picture.
  let picturePart: TranscriptTextPart?

  /// Makes the still view of the slot.
  @ViewBuilder let still: () -> Still

  @Environment(\.transcriptRowPictures) private var pictures
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.displayScale) private var displayScale

  var body: some View {
    if let picturePart, let picture = picture(of: picturePart) {
      StaticPictureView(picture, text: picturePart.text)
    } else {
      still()
    }
  }

  /// The picture of the text part in the appearance of the slot.
  ///
  /// - Parameter part: The text part of the slot.
  /// - Returns: The picture, or `nil` when the cache has none, or when the
  ///   picture has no bitmap.
  private func picture(of part: TranscriptTextPart) -> EditorStaticRendering? {
    let appearance = TranscriptTextAppearance(colorScheme: colorScheme, scale: displayScale)
    return pictures?.picture(of: part, appearance: appearance).flatMap { $0.image == nil ? nil : $0 }
  }
}
