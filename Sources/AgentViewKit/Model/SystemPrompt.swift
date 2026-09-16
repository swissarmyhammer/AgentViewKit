import Observation

/// The instructions of a session (plan.md §3.2).
///
/// The kit hides this record by default. The user can open it to read it.
@Observable
public final class SystemPrompt: ThreadRecord {
  /// The identifier of the record.
  public nonisolated let id: String

  /// The number of patches on the record.
  public private(set) var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The text of the instructions.
  public var text: String

  /// Makes a system prompt record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - text: The text of the instructions.
  ///   - meta: The `_meta` value of the source.
  public init(id: String, text: String, meta: JSONValue? = nil) {
    self.id = id
    self.text = text
    self.meta = meta
  }

  /// Increments ``revision`` by one.
  public func bump() {
    revision += 1
  }
}
