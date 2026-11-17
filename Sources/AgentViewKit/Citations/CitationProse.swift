import EditorSwiftUI

nonisolated extension CitationPayload {
  /// The citation chips that EditorKit shows in `markdown` (plan.md §9 C,
  /// D185).
  ///
  /// Each marker becomes one chip at its place in the whole text. The offset
  /// of a chip is the UTF-8 byte offset of the character at the marker
  /// offset in the paragraph of the marker (``MarkdownParagraphs``). The text
  /// at that offset shows after the chip. An offset below zero is the start of
  /// the paragraph, and an offset past its end is the end of the paragraph.
  ///
  /// The number of a chip is the position of its source in ``sources`` plus
  /// one. These markers make no chip: a marker of a source that is not in
  /// ``sources``, a marker of a paragraph that the text does not have, and a
  /// marker in a fenced code block, because a code block shows its text as it
  /// is. The chips keep the order of ``markers``.
  ///
  /// - Parameter markdown: The Markdown text of the response.
  /// - Returns: The chips.
  func editorCitations(in markdown: String) -> [EditorCitation] {
    let positions = Dictionary(
      sources.enumerated().map { position, source in (source.id, position) },
      uniquingKeysWith: { first, _ in first })
    let paragraphs = MarkdownParagraphs.paragraphs(in: markdown)
    return markers.compactMap { marker in
      guard let position = positions[marker.sourceID],
        paragraphs.indices.contains(marker.paragraphIndex)
      else { return nil }
      let paragraph = paragraphs[marker.paragraphIndex]
      guard !paragraph.isFence else { return nil }
      let source = sources[position]
      return EditorCitation(
        offset: Self.utf8Offset(of: marker.offset, in: paragraph, of: markdown), number: position + 1, id: source.id,
        title: source.title)
    }
  }

  /// The UTF-8 byte offset in the whole text of a character offset in one
  /// paragraph.
  ///
  /// - Parameters:
  ///   - offset: The character offset in the paragraph. The function clamps
  ///     it to the paragraph.
  ///   - paragraph: The paragraph.
  ///   - markdown: The whole text.
  /// - Returns: The UTF-8 byte offset, on a character boundary.
  private static func utf8Offset(of offset: Int, in paragraph: MarkdownParagraph, of markdown: String) -> Int {
    let characters = markdown[paragraph.range]
    let index =
      characters.index(characters.startIndex, offsetBy: max(offset, 0), limitedBy: characters.endIndex)
      ?? characters.endIndex
    return markdown.utf8.distance(from: markdown.startIndex, to: index)
  }
}
