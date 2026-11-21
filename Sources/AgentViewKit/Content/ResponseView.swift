import EditorSwiftUI
import SwiftUI

/// The Markdown body of a response, in the rendered form of EditorKit
/// (plan.md §4.2, §8, §9 B, D185).
///
/// The model applies the streamed chunks to the text of the entry at the
/// display rate, so the view gets the whole text each time. The view shows
/// a text with no fence in one read-only EditorKit model
/// (``RenderedMarkdownView``). A new text that starts with the old text goes
/// into the model as one edit at the end, so EditorKit parses and lays out
/// only the end of the text. Each response has a model of its own, keyed by
/// its id: a chunk changes only the model of its own response. When the environment has a
/// ``CodeBlockModelCache``, the model is in the cache. Otherwise the view
/// keeps the model in its state.
///
/// In a thread, a response far from the rows in view drops its editor and
/// its model (``LiveRowRange``, task ^t9416x5). It keeps only its text, and
/// shows an empty space of the height of its last layout. When its row comes
/// near again, the response makes a new model from its text, so a text that
/// streamed in while the row was far shows whole. A response whose editor
/// holds the selection of the thread (``ResponseSelectionClaim``) keeps its
/// editor, so the selection stays and a copy still copies it. A response
/// that was never laid out shows its editor. In the empty space, the text is
/// still one accessibility element with the same identifier and value.
///
/// A text with a fenced code block shows in segments (``MarkdownCodeFences``,
/// task ^4g2xbx1): each prose segment in a ``RenderedMarkdownView``, and each
/// fenced code block in a ``CodeBlockView``, with its line numbers and its
/// Copy button. Each code block is in its own command scope
/// (``AgentCodeBlockScope``), so Copy Code Block of the item menu and of the
/// palette copies its code. Each segment is keyed by its index, so a streamed
/// chunk changes only the last segment. In a ``CodeBlockModelCache``, each
/// segment has a model of its own (``segmentModelID(for:index:isCode:)``). A
/// text with no fence shows in one ``RenderedMarkdownView``.
///
/// EditorKit shows each formula and each image of the text. When the view
/// has a ``CitationPayload``, EditorKit shows a citation chip at each
/// ``CitationMarker``, in the prose segment that holds it. A press on a chip
/// selects its source, as a press on an ``InlineCitation`` pill does.
///
/// The text of each prose segment is one accessibility element with the
/// identifier ``textIdentifier``, in one linked reading group (plan.md §6).
/// A text with no fence is one such element. In a message, the group is the
/// group of the message. The view applies
/// ``SwiftUI/View/accessibilityReadingScope()``, so the group works also
/// outside an ``AgentThreadView``.
public struct ResponseView: View {
  /// The accessibility identifier of the text of each response. The value of
  /// that element is the Markdown text.
  public static let textIdentifier = "response-text"

  /// The paragraph id of the whole text of a response in a
  /// ``CodeBlockModelCache``.
  static let textBlockKey = "response-text"

  /// The start of the paragraph id of a code segment of a response in a
  /// ``CodeBlockModelCache``.
  static let codeSegmentKey = "response-code"

  /// The id that keys the model of the text, unique in the thread.
  let id: String

  /// The Markdown text to show.
  let markdown: String

  /// The sources of the text and the places that cite them, or `nil` when
  /// the text has no citations.
  let citations: CitationPayload?

  @Environment(\.codeBlockModelCache) private var cache
  @Environment(\.accessibilityMessageGroupID) private var messageGroupID
  @Environment(\.liveRowRange) private var liveRows
  @Environment(\.transcriptRowPosition) private var rowPosition
  @Environment(\.textSelectionRegion) private var selectionRegion

  /// The height of the text at its last layout with its editor.
  @State private var laidOutHeight = LaidOutHeight()

  /// The selection region of the editor, which records whether the editor
  /// holds the selection of the thread.
  @State private var selectionClaim = ResponseSelectionClaim()

  /// Makes the body of one Markdown text, such as the text of an ACP text
  /// block of a transcript entry.
  ///
  /// - Parameters:
  ///   - id: The id that keys the model of the text, unique in the thread,
  ///     such as the id of the block view.
  ///   - markdown: The Markdown text.
  ///   - citations: The sources of the text and the places that cite them,
  ///     or `nil` when the text has no citations. Show the sources in a
  ///     ``SourcesView``, and put the two views in one
  ///     ``SwiftUI/View/citationScope()``.
  public init(id: String, markdown: String, citations: CitationPayload? = nil) {
    self.id = id
    self.markdown = markdown
    self.citations = citations
  }

  /// The citation chips of the text.
  var chips: [EditorCitation] {
    citations?.editorCitations(in: markdown) ?? []
  }

  /// The model of the text of the response `id` in `cache`.
  ///
  /// - Parameters:
  ///   - cache: The cache of the models.
  ///   - id: The id of the response.
  ///   - markdown: The text of a new model.
  /// - Returns: The read-only model in the rendered presentation.
  static func model(in cache: CodeBlockModelCache, id: String, markdown: String) -> EditorModel {
    model(in: cache, modelID: modelID(for: id), markdown: markdown)
  }

  /// The model of one Markdown text of a response in `cache`: the whole
  /// text, or one prose segment of a text with a fence.
  ///
  /// - Parameters:
  ///   - cache: The cache of the models.
  ///   - modelID: The identity of the model (``modelID(for:)`` or
  ///     ``segmentModelID(for:index:isCode:)``).
  ///   - markdown: The text of a new model.
  /// - Returns: The read-only model in the rendered presentation.
  static func model(in cache: CodeBlockModelCache, modelID: CodeBlockID, markdown: String)
    -> EditorModel
  {
    cache.model(for: modelID, text: markdown, make: RenderedMarkdownView.makeModel)
  }

  /// The identity of the text of the response `id` in a
  /// ``CodeBlockModelCache``.
  ///
  /// - Parameter id: The id of the response.
  /// - Returns: The identity. Its message id is `id`, so that
  ///   ``CodeBlockModelCache/evict(messageID:)`` removes the model.
  static func modelID(for id: String) -> CodeBlockID {
    CodeBlockID(messageID: id, paragraphID: textBlockKey)
  }

  /// The identity of the model of one segment of the text of the response
  /// `id` in a ``CodeBlockModelCache``, for a text with a fence.
  ///
  /// - Parameters:
  ///   - id: The id of the response.
  ///   - index: The index of the segment (``MarkdownCodeFences``).
  ///   - isCode: Whether the segment is a fenced code block. A prose
  ///     segment and a code segment at the same index have different
  ///     models, so a segment that streams from prose to code gets a new
  ///     model of the correct kind.
  /// - Returns: The identity. Its message id is `id`, so that
  ///   ``CodeBlockModelCache/evict(messageID:)`` removes the model.
  static func segmentModelID(for id: String, index: Int, isCode: Bool) -> CodeBlockID {
    CodeBlockID(messageID: id, paragraphID: "\(isCode ? codeSegmentKey : textBlockKey)-\(index)")
  }

  /// The citation chips of one prose segment of the text.
  ///
  /// - Parameters:
  ///   - chips: The chips of the whole text. The offset of each chip is a
  ///     UTF-8 offset in the whole text.
  ///   - range: The range of the prose segment in the whole text.
  ///   - markdown: The whole text.
  /// - Returns: The chips whose offset is in `range`, each with its offset
  ///   moved to the start of the segment.
  static func chips(_ chips: [EditorCitation], in range: Range<String.Index>, of markdown: String)
    -> [EditorCitation]
  {
    let start = markdown.utf8.distance(from: markdown.startIndex, to: range.lowerBound)
    let end = markdown.utf8.distance(from: markdown.startIndex, to: range.upperBound)
    return chips.filter { (start...end).contains($0.offset) }.map { chip in
      var moved = chip
      moved.offset -= start
      return moved
    }
  }

  /// Whether the row of the response keeps its models. A response outside
  /// a thread row is always live.
  private var isLive: Bool {
    guard let liveRows, let rowPosition else { return true }
    return liveRows.isLive(rowPosition)
  }

  /// The height of the empty space that the response shows in place of its
  /// editor, or `nil` when the response shows its editor.
  ///
  /// - Parameters:
  ///   - isLive: Whether the row of the response keeps its models.
  ///   - laidOutHeight: The height of the text at its last layout with its
  ///     editor, or `nil` when the text was never laid out.
  ///   - holdsSelection: Whether the editor holds the selection of the
  ///     thread.
  /// - Returns: The height of the last layout when the row is not live, the
  ///   text was laid out, and the editor does not hold the selection.
  ///   Otherwise `nil`.
  static func placeholderHeight(isLive: Bool, laidOutHeight: CGFloat?, holdsSelection: Bool)
    -> CGFloat?
  {
    guard !isLive, !holdsSelection else { return nil }
    return laidOutHeight
  }

  public var body: some View {
    content
      // A new id is a new response, with a model of its own.
      .id(id)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityReadingGroup(messageGroupID ?? id)
      .accessibilityReadingScope()
  }

  /// The editor of the text, or an empty space of its height when the row
  /// is far from the rows in view.
  @ViewBuilder private var content: some View {
    let height = Self.placeholderHeight(
      isLive: isLive, laidOutHeight: laidOutHeight.points,
      holdsSelection: selectionClaim.holdsSelection)
    if let height {
      placeholder(height: height)
    } else {
      editor
    }
  }

  /// The text in read-only EditorKit editors.
  private var editor: some View {
    let laidOutHeight = laidOutHeight
    return
      text
      .textSelectionRegion(selectionClaim.forwarding(to: selectionRegion))
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        laidOutHeight.points = $0
      }
  }

  /// The text: one ``RenderedMarkdownView`` for a text with no fence, or a
  /// stack of its segments for a text with a fence.
  @ViewBuilder private var text: some View {
    let pieces = MarkdownCodeFences.pieces(in: markdown)
    if pieces.contains(where: \.segment.isCode) {
      // A segment is keyed by its index, so a streamed chunk changes only
      // the last segment.
      VStack(alignment: .leading) {
        ForEach(pieces.indices, id: \.self) { index in
          segment(pieces[index], at: index)
        }
      }
    } else {
      prose(markdown, modelID: Self.modelID(for: id), citations: chips)
    }
  }

  /// One Markdown text of the response in a ``RenderedMarkdownView``: the
  /// whole text, or one prose segment of a text with a fence.
  ///
  /// - Parameters:
  ///   - text: The Markdown text.
  ///   - modelID: The identity of its model in a ``CodeBlockModelCache``.
  ///   - citations: The citation chips of the text, with offsets in the text.
  /// - Returns: The view, with the identifier ``textIdentifier``, and its
  ///   model from the cache when the environment has a cache.
  private func prose(_ text: String, modelID: CodeBlockID, citations: [EditorCitation])
    -> some View
  {
    RenderedMarkdownView(
      text, identifier: Self.textIdentifier, citations: citations,
      model: cache.map { Self.model(in: $0, modelID: modelID, markdown: text) })
  }

  /// The view of one segment of a text with a fence.
  ///
  /// - Parameters:
  ///   - piece: The segment and its range in the text.
  ///   - index: The index of the segment.
  /// - Returns: A ``RenderedMarkdownView`` for prose, with the chips of the
  ///   segment, or a ``CodeBlockView`` in the scope of its block for code.
  @ViewBuilder
  private func segment(_ piece: MarkdownCodeFences.Piece, at index: Int) -> some View {
    switch piece.segment {
    case .prose(let text):
      prose(
        text, modelID: Self.segmentModelID(for: id, index: index, isCode: false),
        citations: Self.chips(chips, in: piece.range, of: markdown))
    case .code(let code, let language, let filename):
      CodeBlockView(
        code: code, language: language, filename: filename,
        model: cache.map {
          $0.model(for: Self.segmentModelID(for: id, index: index, isCode: true), code: code)
        }
      )
      .agentCodeBlockScope(AgentScopeKind.codeBlock(responseID: id, index: index), code: code)
    }
  }

  /// The empty space in place of the editor. Its accessibility element has
  /// the identifier and the value of the text of the editor.
  ///
  /// - Parameter height: The height of the text at its last layout.
  /// - Returns: The empty space.
  private func placeholder(height: CGFloat) -> some View {
    Color.clear
      .frame(height: height)
      .accessibilityElement()
      .accessibilityIdentifier(Self.textIdentifier)
      .accessibilityValue(Text(verbatim: markdown))
  }
}

/// The height of the text of a ``ResponseView`` at its last layout with its
/// editor.
///
/// The value is not observable, so a new height does not make the response
/// evaluate its body again. The response reads it when the row leaves the
/// ``LiveRowRange``.
final class LaidOutHeight {
  /// The height in points, or `nil` when the text was never laid out.
  var points: CGFloat?
}

#Preview("Response with citations") {
  ResponseView(
    id: "preview-response", markdown: PreviewFixtures.citedResponse,
    citations: PreviewFixtures.citations
  )
  .citationScope()
}
