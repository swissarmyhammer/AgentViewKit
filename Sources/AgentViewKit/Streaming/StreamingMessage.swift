import Observation

/// The text of a message that still streams (plan.md §8).
///
/// ``AgentThread/streaming`` holds one of these for each record id that
/// streams. A source adds each chunk here, not to the record, so that a new
/// chunk changes only the views that read this object.
///
/// This is the shell of the type. A later change adds the settled paragraphs
/// and the balanced tail on top of it.
@MainActor
@Observable
public final class StreamingMessage: Identifiable {
  /// The identifier of the record that streams.
  public nonisolated let id: String

  /// All of the text that streamed, in order.
  public private(set) var text: String

  /// Makes a streaming message.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record that streams.
  ///   - text: The text that streamed before.
  public init(id: String, text: String = "") {
    self.id = id
    self.text = text
  }

  /// Adds a chunk to the end of ``text``.
  ///
  /// - Parameter chunk: The text to add.
  public func append(_ chunk: String) {
    text += chunk
  }
}
