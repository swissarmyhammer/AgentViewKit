import Observation

/// A message from the user or from the agent (plan.md §3.2).
///
/// The ``ThreadItem`` case tells who sent the message.
@Observable
public final class Message: ThreadRecord {
  /// The identifier of the record.
  public nonisolated let id: String

  /// The number of patches on the record.
  public private(set) var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The content of the message, in order.
  public var blocks: [ContentBlock]

  /// Makes a message record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - blocks: The content of the message, in order.
  ///   - meta: The `_meta` value of the source.
  public init(id: String, blocks: [ContentBlock], meta: JSONValue? = nil) {
    self.id = id
    self.blocks = blocks
    self.meta = meta
  }

  /// Increments ``revision`` by one.
  public func bump() {
    revision += 1
  }
}
