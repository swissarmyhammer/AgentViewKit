import SwiftUI

/// One settled paragraph of a response, rendered through Textual
/// (plan.md §4.2, §8).
///
/// A settled paragraph does not change. Two paragraph views are equal when
/// they show the same paragraph of the same message with the same citation
/// pills. Apply `.equatable()` to the view, so that a new chunk in the
/// streaming tail does not evaluate the body again.
///
/// The paragraph is in the linked reading group of its message
/// (plan.md §6), so VoiceOver reads from one paragraph into the next. The
/// view gets the id of the group as a value, and it reads no environment
/// value itself. SwiftUI can evaluate the body of a view that reads the
/// environment again on the first change of the paragraph list after the
/// mount, with no Equatable check. A view with no environment property
/// evaluates again only when `==` gives `false`.
///
/// The view gives its code block identity to the environment. Thus
/// ``EditorKitCodeBlockStyle`` gets the cached model of a fenced block from
/// the ``CodeBlockModelCache`` of the environment.
public struct ParagraphView: View, Equatable {
  /// The start of the ``BodyEvaluationCounter`` key of each paragraph.
  public static let counterKeyPrefix = "paragraph-"

  /// The radix of the text hash in the paragraph key.
  private static let hashRadix = 16

  /// The id of the message that holds the paragraph.
  let messageID: String

  /// The paragraph to show.
  let paragraph: ParagraphSplitter.Paragraph

  /// The citation pills of the paragraph.
  let citations: [CitationPlacement]

  /// The id of the linked reading group of the paragraph.
  let readingGroupID: String

  /// Makes the view of one settled paragraph.
  ///
  /// - Parameters:
  ///   - messageID: The id of the message that holds the paragraph.
  ///   - paragraph: The paragraph to show.
  ///   - readingGroupID: The id of the linked reading group of the message
  ///     that holds the paragraph, or `nil` to use the group of `messageID`.
  public init(
    messageID: String, paragraph: ParagraphSplitter.Paragraph, readingGroupID: String? = nil
  ) {
    self.init(
      messageID: messageID, paragraph: paragraph, citations: [],
      readingGroupID: readingGroupID ?? messageID)
  }

  /// Makes the view of one settled paragraph with citation pills.
  ///
  /// - Parameters:
  ///   - messageID: The id of the message that holds the paragraph.
  ///   - paragraph: The paragraph to show.
  ///   - citations: The citation pills of the paragraph.
  ///   - readingGroupID: The id of the linked reading group of the
  ///     paragraph.
  init(
    messageID: String, paragraph: ParagraphSplitter.Paragraph, citations: [CitationPlacement],
    readingGroupID: String
  ) {
    self.messageID = messageID
    self.paragraph = paragraph
    self.citations = citations
    self.readingGroupID = readingGroupID
  }

  /// Tells whether two views show the same paragraph of the same message
  /// with the same citation pills, in the same reading group.
  ///
  /// - Parameters:
  ///   - lhs: A paragraph view.
  ///   - rhs: A paragraph view.
  /// - Returns: `true` when the message id, the paragraph, the citation
  ///   pills, and the reading group are equal.
  public static func == (lhs: ParagraphView, rhs: ParagraphView) -> Bool {
    lhs.messageID == rhs.messageID && lhs.paragraph == rhs.paragraph
      && lhs.citations == rhs.citations && lhs.readingGroupID == rhs.readingGroupID
  }

  /// The text form of a paragraph id: the index and the hexadecimal text
  /// hash.
  ///
  /// - Parameter paragraphID: The id of the paragraph.
  /// - Returns: `<index>-<hash>`.
  public static func key(for paragraphID: ParagraphSplitter.Paragraph.ID) -> String {
    "\(paragraphID.index)-\(String(paragraphID.textHash, radix: hashRadix))"
  }

  /// The ``BodyEvaluationCounter`` key of a paragraph.
  ///
  /// - Parameters:
  ///   - messageID: The id of the message that holds the paragraph.
  ///   - paragraphID: The id of the paragraph.
  /// - Returns: `paragraph-<message id>-<index>-<hash>`.
  public static func counterKey(
    messageID: String, paragraphID: ParagraphSplitter.Paragraph.ID
  ) -> String {
    "\(counterKeyPrefix)\(messageID)-\(key(for: paragraphID))"
  }

  public var body: some View {
    #if DEBUG
      BodyEvaluationCounter.note(Self.counterKey(messageID: messageID, paragraphID: paragraph.id))
    #endif
    return MarkdownProse(text: paragraph.text, citations: citations)
      .environment(
        \.codeBlockID,
        CodeBlockID(messageID: messageID, paragraphID: Self.key(for: paragraph.id))
      )
      .contentContainer(identifier: ResponseView.paragraphIdentifier(index: paragraph.id.index))
      .accessibilityReadingGroup(readingGroupID)
  }
}
