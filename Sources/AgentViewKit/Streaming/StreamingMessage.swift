import Observation

/// The text of a message that still streams (plan.md §8).
///
/// ``AgentThread/streaming`` holds one of these for each record id that
/// streams. A source adds each chunk here, not to the record, so that a new
/// chunk changes only the views that read this object.
///
/// The message gives each chunk to a ``StreamingCoalescer``. When the
/// coalescer flushes, the message splits its text with ``ParagraphSplitter``
/// and balances the tail with ``StreamingMarkdownBalancer``. Each property is
/// observed on its own, and the message writes a property only when its value
/// changes. So a chunk that changes only the tail does not make a view of
/// ``settledParagraphs`` invalid.
@MainActor
@Observable
public final class StreamingMessage: Identifiable {
  /// The identifier of the record that streams.
  public nonisolated let id: String

  /// All of the text that the coalescer flushed, in order.
  public private(set) var text: String

  /// The paragraphs that the stream cannot change, in message order.
  ///
  /// While the message is open, a chunk only adds paragraphs to this list.
  /// ``replace(_:)`` can make the list shorter.
  public private(set) var settledParagraphs: [ParagraphSplitter.Paragraph] = []

  /// The balanced form of the paragraph that the stream can still change.
  ///
  /// After ``close()``, the tail is empty Markdown.
  public private(set) var tail: StreamingMarkdownBalancer.BalancedTail = .markdown("")

  /// `false` after ``close()``. A closed message ignores new chunks.
  public private(set) var isOpen = true

  /// The time from the first chunk of a batch to the flush of the batch.
  @ObservationIgnored private let interval: Duration

  /// The coalescer that collects the chunks and calls ``didFlush(_:)``.
  @ObservationIgnored private lazy var coalescer = StreamingCoalescer(interval: interval) {
    [weak self] batch in
    self?.didFlush(batch)
  }

  /// Makes a streaming message, and renders `text` at once.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record that streams.
  ///   - text: The text that streamed before.
  ///   - interval: The time from the first chunk of a batch to its flush.
  public init(
    id: String,
    text: String = "",
    interval: Duration = StreamingCoalescer.defaultInterval
  ) {
    self.id = id
    self.text = text
    self.interval = interval
    render()
  }

  /// Gives a chunk to the coalescer. The message changes when the coalescer
  /// flushes.
  ///
  /// A closed message ignores the chunk.
  ///
  /// - Parameter chunk: The text to add to the end of the message.
  public func append(_ chunk: String) {
    guard isOpen else { return }
    coalescer.append(chunk)
  }

  /// Adds the chunks that the coalescer holds to the message at once.
  public func flush() {
    coalescer.flushNow()
  }

  /// Replaces the full text of the message, and splits it again from the
  /// start.
  ///
  /// Use this for a whole-message upsert. The chunks that the coalescer holds
  /// are discarded, because `text` replaces them. A closed message stays
  /// closed, and its tail stays settled.
  ///
  /// - Parameter text: The new full text of the message.
  public func replace(_ text: String) {
    flush()
    self.text = text
    render()
  }

  /// Flushes the chunks, settles the tail as the last paragraph, and closes
  /// the message.
  ///
  /// A second call does nothing.
  public func close() {
    guard isOpen else { return }
    flush()
    isOpen = false
    render()
  }

  /// Adds a flushed batch to the text, and renders the message again.
  ///
  /// - Parameter batch: The chunks that the coalescer joined.
  private func didFlush(_ batch: String) {
    text += batch
    render()
  }

  /// Splits ``text``, and writes each property whose value changed.
  private func render() {
    let split = ParagraphSplitter.split(text)
    var settled = split.settled
    var newTail = StreamingMarkdownBalancer.BalancedTail.markdown("")
    if isOpen {
      newTail = StreamingMarkdownBalancer.balance(tail: split.tail)
    } else if let last = Self.finalParagraph(tail: split.tail, index: settled.count) {
      settled.append(last)
    }
    if settled != settledParagraphs { settledParagraphs = settled }
    if newTail != tail { tail = newTail }
  }

  /// Makes the last paragraph of a closed message from its raw tail.
  ///
  /// - Parameters:
  ///   - tail: The raw tail that ``ParagraphSplitter`` returned.
  ///   - index: The position of the paragraph in the message.
  /// - Returns: The paragraph with no line break at the end, or `nil` when
  ///   the tail has only line breaks.
  private static func finalParagraph(tail: String, index: Int) -> ParagraphSplitter.Paragraph? {
    guard let lastCharacter = tail.lastIndex(where: { !$0.isNewline }) else { return nil }
    return ParagraphSplitter.Paragraph(index: index, text: String(tail[...lastCharacter]))
  }
}
