import Foundation
import Observation

/// The reasoning of the agent (plan.md §3.2).
///
/// The FoundationModels SDK and ACP both send reasoning as an entry of its
/// own. The host measures ``startedAt`` and ``endedAt``, because no source
/// gives a time. ``ReasoningView`` shows the duration when both times are
/// present.
@Observable
public final class Reasoning: ThreadRecord {
  /// The identifier of the record.
  public nonisolated let id: String

  /// The number of patches on the record. Call ``bump()`` to change it.
  public var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The text segments of the reasoning, in order.
  public var segments: [String]

  /// The signature that the model gave for the reasoning, if any.
  public var signature: String?

  /// The time when the host saw the reasoning start.
  public var startedAt: Date?

  /// The time when the host saw the reasoning end.
  public var endedAt: Date?

  /// Makes a reasoning record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - segments: The text segments of the reasoning, in order.
  ///   - signature: The signature that the model gave for the reasoning.
  ///   - startedAt: The time when the host saw the reasoning start.
  ///   - endedAt: The time when the host saw the reasoning end.
  ///   - meta: The `_meta` value of the source.
  public init(
    id: String,
    segments: [String],
    signature: String? = nil,
    startedAt: Date? = nil,
    endedAt: Date? = nil,
    meta: JSONValue? = nil
  ) {
    self.id = id
    self.segments = segments
    self.signature = signature
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.meta = meta
  }

  /// The text of the reasoning: the segments, joined with no separator.
  ///
  /// A source adds each streamed chunk as a segment, so the segments join
  /// with no text between them.
  public var text: String {
    segments.joined()
  }

  /// The time from ``startedAt`` to ``endedAt``, or `nil` when a time is
  /// missing or the end is before the start.
  public var duration: TimeInterval? {
    guard let startedAt, let endedAt, endedAt >= startedAt else { return nil }
    return endedAt.timeIntervalSince(startedAt)
  }
}
