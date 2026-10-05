import Observation

/// An error that the user must see (plan.md §3.2, §9 A2).
///
/// The source is an ACP error, or a stop reason that needs attention.
@Observable
public final class ThreadError: ThreadRecord {
  /// The identifier of the record.
  public nonisolated let id: String

  /// The number of patches on the record. Call ``bump()`` to change it.
  public var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The type of the error and its values.
  public var kind: Kind

  /// Makes an error record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - kind: The type of the error and its values.
  ///   - meta: The `_meta` value of the source.
  public init(id: String, kind: Kind, meta: JSONValue? = nil) {
    self.id = id
    self.kind = kind
    self.meta = meta
  }

  /// The type of a thread error.
  public nonisolated enum Kind: Sendable, Hashable {
    /// The model refused to answer.
    ///
    /// - Parameter explanation: The reason that the model gave, if any.
    case refusal(explanation: String?)

    /// An ACP JSON-RPC error.
    ///
    /// - Parameters:
    ///   - code: The JSON-RPC error code.
    ///   - message: The error message.
    case acp(code: Int, message: String)

    /// An error that the kit does not know.
    ///
    /// - Parameter message: The text of the error.
    case unknown(message: String)
  }
}
