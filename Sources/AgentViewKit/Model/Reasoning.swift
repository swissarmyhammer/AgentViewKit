import Observation

/// The reasoning of the agent (plan.md §3.2).
///
/// The FoundationModels SDK and ACP both send reasoning as an entry of its
/// own.
@Observable
public final class Reasoning: ThreadRecord {
  /// The identifier of the record.
  public nonisolated let id: String

  /// The number of patches on the record.
  public private(set) var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The text segments of the reasoning, in order.
  public var segments: [String]

  /// The signature that the model gave for the reasoning, if any.
  public var signature: String?

  /// Makes a reasoning record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - segments: The text segments of the reasoning, in order.
  ///   - signature: The signature that the model gave for the reasoning.
  ///   - meta: The `_meta` value of the source.
  public init(
    id: String,
    segments: [String],
    signature: String? = nil,
    meta: JSONValue? = nil
  ) {
    self.id = id
    self.segments = segments
    self.signature = signature
    self.meta = meta
  }

  /// Increments ``revision`` by one.
  public func bump() {
    revision += 1
  }
}
