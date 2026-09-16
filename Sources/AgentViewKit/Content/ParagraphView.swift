import SwiftUI
import Textual

/// One settled paragraph of a response, rendered through Textual
/// (plan.md §4.2, §8).
///
/// A settled paragraph does not change. Two paragraph views are equal when
/// they show the same paragraph of the same message. Apply `.equatable()` to
/// the view, so that a new chunk in the streaming tail does not evaluate the
/// body again.
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

  /// Makes the view of one settled paragraph.
  ///
  /// - Parameters:
  ///   - messageID: The id of the message that holds the paragraph.
  ///   - paragraph: The paragraph to show.
  public init(messageID: String, paragraph: ParagraphSplitter.Paragraph) {
    self.messageID = messageID
    self.paragraph = paragraph
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
    return StructuredText(markdown: paragraph.text)
      .environment(
        \.codeBlockID,
        CodeBlockID(messageID: messageID, paragraphID: Self.key(for: paragraph.id))
      )
      .contentContainer(identifier: ResponseView.paragraphIdentifier(index: paragraph.id.index))
  }
}
