import EditorStyle
import SwiftUI
import Textual

/// The Markdown body of a response, rendered through Textual
/// (plan.md §4.2, §8, §9 B).
///
/// The model applies the streamed chunks to the text of the entry at the
/// display rate, so the view gets the whole text each time. The view splits
/// the text into paragraphs (``ParagraphSplitter``) and gives each paragraph
/// to Textual in a ``ParagraphView``. A paragraph that does not change keeps
/// its view, so a chunk evaluates only the paragraphs that it changes.
///
/// The view applies ``EditorKitCodeBlockStyle``, so each fenced block shows
/// in a ``CodeBlockView``. The view uses the ``CodeBlockModelCache`` of the
/// environment. When the environment has no cache, the view keeps its own.
///
/// When the view has a ``CitationPayload``, each paragraph shows an
/// ``InlineCitation`` pill at each ``CitationMarker`` of the paragraph. The
/// paragraph index of a marker counts the paragraphs of the Markdown text.
///
/// The paragraphs are in one linked reading group (plan.md §6). In a message,
/// the group is the group of the message. The view applies
/// ``SwiftUI/View/accessibilityReadingScope()``, so the group works also
/// outside an ``AgentThreadView``.
public struct ResponseView: View {
  /// The start of the accessibility identifier of each paragraph.
  public static let paragraphIdentifierPrefix = "response-paragraph-"

  /// The id that keys the code blocks and the evaluation counters.
  let id: String

  /// The Markdown text to show.
  let markdown: String

  /// The sources of the text and the places that cite them, or `nil` when
  /// the text has no citations.
  let citations: CitationPayload?

  @Environment(\.codeBlockModelCache) private var environmentCache
  @Environment(\.editorStyle) private var editorStyle

  /// The cache that the view uses when the environment has no cache.
  @State private var ownCache = CodeBlockModelCache()

  /// Makes the body of one Markdown text, such as the text of an ACP text
  /// block of a transcript entry.
  ///
  /// - Parameters:
  ///   - id: The id that keys the code blocks and the evaluation counters,
  ///     unique in the thread, such as the id of the block view.
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

  /// The accessibility identifier of the paragraph at `index`.
  ///
  /// - Parameter index: The position of the paragraph in the text.
  /// - Returns: `response-paragraph-<index>`.
  public static func paragraphIdentifier(index: Int) -> String {
    AccessibilityIdentifier.make(prefix: paragraphIdentifierPrefix, value: String(index))
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.m) {
      ParagraphList(
        messageID: id,
        paragraphs: ParagraphSplitter.paragraphs(markdown),
        citations: citations?.placementsByParagraph() ?? [:])
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .environment(\.codeBlockModelCache, environmentCache ?? ownCache)
    .textual.codeBlockStyle(EditorKitCodeBlockStyle())
    .accessibilityReadingScope()
  }
}

/// One ``ParagraphView`` for each paragraph, keyed by the paragraph id.
///
/// This view, and not each ``ParagraphView``, reads the reading group of the
/// message from the environment, and gives it to each paragraph as a value.
///
/// The list gives each paragraph view through a ``ParagraphViewCache``, so a
/// settled paragraph keeps the same stored value from one update to the next.
/// Then SwiftUI does not evaluate it again, also before SwiftUI can call `==`.
private struct ParagraphList: View {
  /// The id of the message.
  let messageID: String

  /// The paragraphs to show, in message order.
  let paragraphs: [ParagraphSplitter.Paragraph]

  /// The citation pills of each paragraph, keyed by the paragraph index.
  let citations: [Int: [CitationPlacement]]

  /// The linked reading group of the message that holds the view, or `nil`
  /// to use the group of ``messageID``.
  @Environment(\.accessibilityMessageGroupID) private var messageGroupID

  /// The last view of each paragraph.
  @State private var cache = ParagraphViewCache()

  var body: some View {
    let readingGroupID = messageGroupID ?? messageID
    let views = cache.reuse(
      paragraphs.map { paragraph in
        ParagraphView(
          messageID: messageID,
          paragraph: paragraph,
          citations: citations[paragraph.id.index] ?? [],
          readingGroupID: readingGroupID
        )
      })
    ForEach(views, id: \.paragraph.id) { view in
      ParagraphSlot(paragraph: view)
    }
  }
}

/// The element of the ``ParagraphList`` ForEach: it shows its
/// ``ParagraphView`` with `.equatable()` one level below the ForEach.
///
/// The ForEach updates an element that it inserted after the mount again on
/// each update when a transaction modifier, such as
/// `.transaction { $0.disablesAnimations = true }`, is above the list. When
/// the `.equatable()` view is the direct element, SwiftUI then evaluates the
/// body of each such paragraph again, and `==` has no effect. This slot takes
/// that update: its body is only the equatable paragraph, so SwiftUI compares
/// the new paragraph view with the old one, and a settled paragraph does not
/// evaluate again.
private struct ParagraphSlot: View {
  /// The paragraph view to show.
  let paragraph: ParagraphView

  var body: some View {
    paragraph.equatable()
  }
}

#Preview("Response with citations") {
  ResponseView(id: "preview-response", markdown: PreviewFixtures.citedResponse, citations: PreviewFixtures.citations)
    .citationScope()
}
