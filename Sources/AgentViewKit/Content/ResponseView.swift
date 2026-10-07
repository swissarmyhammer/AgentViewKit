import SwiftUI
import Textual

/// The Markdown body of a response, rendered through Textual
/// (plan.md §4.2, §8, §9 B).
///
/// Textual has no streaming mode. Thus the view gives each settled paragraph
/// to Textual one time, in a ``ParagraphView``, and parses only the
/// streaming tail again for each chunk.
///
/// - When `streaming` is `nil`, the view shows the text blocks of the
///   message. Each paragraph is settled.
/// - When `streaming` is not `nil`, the view shows the settled paragraphs of
///   the stream and its balanced tail. A tail that is an open code fence
///   shows in a ``CodeBlockView``. The model of that block gets each new
///   chunk through `EditorModel.appendStreaming(_:)`.
///
/// The view applies ``EditorKitCodeBlockStyle``, so each fenced block shows
/// in a ``CodeBlockView``. The view uses the ``CodeBlockModelCache`` of the
/// environment. When the environment has no cache, the view keeps its own.
///
/// The view shows only the text blocks that are for the user. The other
/// content blocks have their own views.
///
/// When the view has a ``CitationPayload``, each settled paragraph shows an
/// ``InlineCitation`` pill at each ``CitationMarker`` of the paragraph. The paragraph index of a marker counts the paragraphs of
/// ``markdown(of:)``. The streaming tail shows no pill, because its text is
/// not final.
///
/// The settled paragraphs and the tail are in one linked reading group
/// (plan.md §6). In a message, the group is the group of the message. The
/// view applies ``SwiftUI/View/accessibilityReadingScope()``, so the group
/// works also outside an ``AgentThreadView``.
public struct ResponseView: View {
  /// The start of the accessibility identifier of each settled paragraph.
  public static let paragraphIdentifierPrefix = "response-paragraph-"

  /// The accessibility identifier of the streaming tail.
  public static let tailIdentifier = "response-tail"

  /// The start of the ``BodyEvaluationCounter`` key of the streaming tail.
  public static let tailCounterKeyPrefix = "response-tail-"

  /// The paragraph part of the code block identity of the streaming tail.
  static let tailParagraphKey = "tail"

  /// The text between two text blocks of a message.
  static let blockSeparator = "\n\n"

  /// The text that the view shows.
  enum Source {
    /// The text blocks of a kit message.
    case message(Message)

    /// One Markdown text, such as the text of an ACP text block.
    ///
    /// - Parameters:
    ///   - id: The id that keys the code blocks and the evaluation counters,
    ///     such as the id of the block view.
    ///   - text: The Markdown text.
    case markdown(id: String, text: String)
  }

  /// The text to show.
  let source: Source

  /// The stream of the message, or `nil` when the message does not stream.
  let streaming: StreamingMessage?

  /// The sources of the message and the places that cite them, or `nil`
  /// when the message has no citations.
  let citations: CitationPayload?

  @Environment(\.codeBlockModelCache) private var environmentCache
  @Environment(\.agentTheme) private var theme

  /// The cache that the view uses when the environment has no cache.
  @State private var ownCache = CodeBlockModelCache()

  /// Makes the body of a response.
  ///
  /// - Parameters:
  ///   - message: The message to show.
  ///   - streaming: The stream of the message, or `nil` when the message
  ///     does not stream. Give `thread.streaming[message.id]`.
  ///   - citations: The sources of the message and the places that cite
  ///     them, or `nil` when the message has no citations. Show the sources
  ///     in a ``SourcesView``, and put the two views in one
  ///     ``SwiftUI/View/citationScope()``.
  public init(message: Message, streaming: StreamingMessage?, citations: CitationPayload? = nil) {
    self.source = .message(message)
    self.streaming = streaming
    self.citations = citations
  }

  /// Makes the body of one Markdown text that does not stream, such as the
  /// text of an ACP text block of a transcript entry.
  ///
  /// - Parameters:
  ///   - id: The id that keys the code blocks and the evaluation counters,
  ///     unique in the thread, such as the id of the block view.
  ///   - markdown: The Markdown text.
  init(id: String, markdown: String) {
    self.source = .markdown(id: id, text: markdown)
    self.streaming = nil
    self.citations = nil
  }

  /// The id of the message, or the id of the Markdown text.
  private var messageID: String {
    switch source {
    case .message(let message): message.id
    case .markdown(let id, _): id
    }
  }

  /// The Markdown text that the view shows when it does not stream.
  private var markdownText: String {
    switch source {
    case .message(let message): Self.markdown(of: message)
    case .markdown(_, let text): text
    }
  }

  /// The accessibility identifier of the settled paragraph at `index`.
  ///
  /// - Parameter index: The position of the paragraph in the message.
  /// - Returns: `response-paragraph-<index>`.
  public static func paragraphIdentifier(index: Int) -> String {
    AccessibilityIdentifier.make(prefix: paragraphIdentifierPrefix, value: String(index))
  }

  /// The ``BodyEvaluationCounter`` key of the streaming tail of a message.
  ///
  /// - Parameter messageID: The id of the message.
  /// - Returns: `response-tail-<message id>`.
  public static func tailCounterKey(messageID: String) -> String {
    tailCounterKeyPrefix + messageID
  }

  /// The code block identity of an open fence in the streaming tail.
  ///
  /// - Parameter messageID: The id of the message.
  /// - Returns: The identity of the tail code block.
  public static func tailBlockID(messageID: String) -> CodeBlockID {
    CodeBlockID(messageID: messageID, paragraphID: tailParagraphKey)
  }

  /// The Markdown text of a message: its text blocks for the user, with a
  /// blank line between two blocks.
  ///
  /// - Parameter message: The message.
  /// - Returns: The Markdown text.
  public static func markdown(of message: Message) -> String {
    message.blocks
      .compactMap { block -> String? in
        guard block.isVisible(to: .user), case .text(let text) = block.content else {
          return nil
        }
        return text
      }
      .joined(separator: blockSeparator)
  }

  /// The code that the tail code block shows for the body of an open fence.
  ///
  /// The body can end with the line break of its last complete line. The
  /// block does not show that line break. The result for a longer body
  /// always starts with the result for a shorter body, so the model gets
  /// each chunk as an append.
  ///
  /// - Parameter body: The body of the open fence.
  /// - Returns: The body with no line break at its end.
  public static func displayedCode(ofFenceBody body: String) -> String {
    body.hasSuffix("\n") ? String(body.dropLast()) : body
  }

  public var body: some View {
    let placements = citations?.placementsByParagraph() ?? [:]
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      if let streaming {
        SettledParagraphs(messageID: messageID, streaming: streaming, citations: placements)
        StreamingTail(messageID: messageID, streaming: streaming)
      } else {
        MessageParagraphs(messageID: messageID, markdown: markdownText, citations: placements)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .environment(\.codeBlockModelCache, environmentCache ?? ownCache)
    .textual.codeBlockStyle(EditorKitCodeBlockStyle())
    .accessibilityReadingScope()
  }
}

extension EnvironmentValues {
  /// Whether each ``ResponseView`` in this subtree puts its settled
  /// paragraphs in a lazy stack (research R1, `Benchmarks/README.md`).
  ///
  /// A chunk changes the height of the streaming tail. In a `VStack`, each
  /// height change places each settled paragraph again, so the cost of a
  /// chunk grows with the message. A `LazyVStack` places only the paragraphs
  /// that are on screen, so the cost of a chunk stays the same. A lazy stack
  /// shows its content only in a scroll view. ``ConversationView`` sets the
  /// value for its rows. Set the value with
  /// ``SwiftUI/View/lazyResponseParagraphs(_:)`` for a response in another
  /// scroll view.
  @Entry public var lazyResponseParagraphs = false
}

extension View {
  /// Tells each ``ResponseView`` in this subtree whether to put its settled
  /// paragraphs in a lazy stack.
  ///
  /// Apply the value `true` only in a scroll view.
  ///
  /// - Parameter isLazy: Whether the settled paragraphs are in a lazy stack.
  /// - Returns: A view that gives the value to its subtree.
  public func lazyResponseParagraphs(_ isLazy: Bool = true) -> some View {
    environment(\.lazyResponseParagraphs, isLazy)
  }
}

/// The settled paragraphs of a stream.
///
/// The view reads only ``StreamingMessage/settledParagraphs``. Thus a chunk
/// that changes only the tail does not evaluate this body.
///
/// The paragraphs are one child of the response stack. In a scroll view, they
/// are in a lazy stack (``SwiftUI/EnvironmentValues/lazyResponseParagraphs``).
private struct SettledParagraphs: View {
  /// The id of the message.
  let messageID: String

  /// The stream of the message.
  let streaming: StreamingMessage

  /// The citation pills of each paragraph, keyed by the paragraph index.
  let citations: [Int: [CitationPlacement]]

  @Environment(\.agentTheme) private var theme
  @Environment(\.lazyResponseParagraphs) private var isLazy

  var body: some View {
    let paragraphs = ParagraphList(
      messageID: messageID, paragraphs: streaming.settledParagraphs, citations: citations)
    if isLazy {
      LazyVStack(alignment: .leading, spacing: theme.spacing.m) { paragraphs }
    } else {
      VStack(alignment: .leading, spacing: theme.spacing.m) { paragraphs }
    }
  }
}

/// The paragraphs of a text that does not stream.
private struct MessageParagraphs: View {
  /// The id of the message.
  let messageID: String

  /// The Markdown text to show.
  let markdown: String

  /// The citation pills of each paragraph, keyed by the paragraph index.
  let citations: [Int: [CitationPlacement]]

  var body: some View {
    ParagraphList(
      messageID: messageID,
      paragraphs: ParagraphSplitter.paragraphs(markdown),
      citations: citations)
  }
}

/// One ``ParagraphView`` for each paragraph, keyed by the paragraph id.
///
/// This view, and not each ``ParagraphView``, reads the reading group of the
/// message from the environment, and gives it to each paragraph as a value.
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

  var body: some View {
    let readingGroupID = messageGroupID ?? messageID
    ForEach(paragraphs) { paragraph in
      ParagraphView(
        messageID: messageID,
        paragraph: paragraph,
        citations: citations[paragraph.id.index] ?? [],
        readingGroupID: readingGroupID
      )
      .equatable()
    }
  }
}

/// The streaming tail of a stream.
///
/// The view reads only ``StreamingMessage/tail``. A Markdown tail renders
/// through Textual. An open fence renders in a ``CodeBlockView``, with the
/// cached model of ``ResponseView/tailBlockID(messageID:)``.
private struct StreamingTail: View {
  /// The id of the message.
  let messageID: String

  /// The stream of the message.
  let streaming: StreamingMessage

  @Environment(\.codeBlockModelCache) private var cache
  @Environment(\.accessibilityMessageGroupID) private var messageGroupID

  var body: some View {
    #if DEBUG
      BodyEvaluationCounter.note(ResponseView.tailCounterKey(messageID: messageID))
    #endif
    // The tail is in the reading group of the settled paragraphs.
    return content.accessibilityReadingGroup(messageGroupID ?? messageID)
  }

  /// The view of the tail, or nothing when the tail is empty.
  @ViewBuilder private var content: some View {
    switch streaming.tail {
    case .markdown(let text):
      if !text.allSatisfy(\.isWhitespace) {
        MarkdownProse(text: text)
          .contentContainer(identifier: ResponseView.tailIdentifier)
      }
    case .openFence(let language, let body):
      let code = ResponseView.displayedCode(ofFenceBody: body)
      CodeBlockView(
        code: code,
        language: language,
        model: cache?.model(for: ResponseView.tailBlockID(messageID: messageID), code: code)
      )
      .contentContainer(identifier: ResponseView.tailIdentifier)
    }
  }
}
