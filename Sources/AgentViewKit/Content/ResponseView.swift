import EditorSwiftUI
import SwiftUI

/// The Markdown body of a response, in the rendered form of EditorKit
/// (plan.md §4.2, §8, §9 B, D185).
///
/// The model applies the streamed chunks to the text of the entry at the
/// display rate, so the view gets the whole text each time. The view shows
/// the text in one read-only EditorKit model (``RenderedMarkdownView``). A new
/// text that starts with the old text goes into the model as one edit at the
/// end, so EditorKit parses and lays out only the end of the text. Each
/// response has a model of its own, keyed by its id: a chunk changes only the
/// model of its own response. When the environment has a
/// ``CodeBlockModelCache``, the model is in the cache. Otherwise the view
/// keeps the model in its state.
///
/// EditorKit shows each fenced code block, each formula and each image of the
/// text. When the view has a ``CitationPayload``, EditorKit shows a citation
/// chip at each ``CitationMarker``. A press on a chip selects its source, as
/// a press on an ``InlineCitation`` pill does.
///
/// The text is one accessibility element with the identifier
/// ``textIdentifier``, in one linked reading group (plan.md §6). In a
/// message, the group is the group of the message. The view applies
/// ``SwiftUI/View/accessibilityReadingScope()``, so the group works also
/// outside an ``AgentThreadView``.
public struct ResponseView: View {
  /// The accessibility identifier of the text of each response. The value of
  /// that element is the Markdown text.
  public static let textIdentifier = "response-text"

  /// The paragraph id of the whole text of a response in a
  /// ``CodeBlockModelCache``.
  static let textBlockKey = "response-text"

  /// The id that keys the model of the text, unique in the thread.
  let id: String

  /// The Markdown text to show.
  let markdown: String

  /// The sources of the text and the places that cite them, or `nil` when
  /// the text has no citations.
  let citations: CitationPayload?

  @Environment(\.codeBlockModelCache) private var cache
  @Environment(\.accessibilityMessageGroupID) private var messageGroupID

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
    cache.model(for: modelID(for: id), text: markdown, make: RenderedMarkdownView.makeModel)
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

  public var body: some View {
    RenderedMarkdownView(
      markdown, identifier: Self.textIdentifier, citations: chips,
      model: cache.map { Self.model(in: $0, id: id, markdown: markdown) }
    )
    // A new id is a new response, with a model of its own.
    .id(id)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityReadingGroup(messageGroupID ?? id)
    .accessibilityReadingScope()
  }
}

#Preview("Response with citations") {
  ResponseView(id: "preview-response", markdown: PreviewFixtures.citedResponse, citations: PreviewFixtures.citations)
    .citationScope()
}
