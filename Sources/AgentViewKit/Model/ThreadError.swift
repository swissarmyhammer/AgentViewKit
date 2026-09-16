import Foundation
import Observation

/// An error that the user must see (plan.md §3.2, §9 A2).
///
/// The source is a FoundationModels `LanguageModelError`, an ACP error, or a
/// stop reason that needs attention.
@Observable
public final class ThreadError: ThreadRecord {
  /// The identifier of the record.
  public nonisolated let id: String

  /// The number of patches on the record.
  public private(set) var revision = 0

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

  /// Increments ``revision`` by one.
  public func bump() {
    revision += 1
  }

  /// The type of a thread error.
  public nonisolated enum Kind: Sendable, Hashable {
    /// The thread has more tokens than the context of the model can hold.
    ///
    /// - Parameters:
    ///   - contextSize: The number of tokens that the context can hold.
    ///   - tokenCount: The number of tokens in the request.
    case contextSizeExceeded(contextSize: Int, tokenCount: Int)

    /// The source refused the request because of a rate limit.
    ///
    /// - Parameter resetAt: The time when the limit stops, if known.
    case rateLimited(resetAt: Date?)

    /// A guardrail stopped the request.
    ///
    /// - Parameter explanation: The reason that the source gave, if any.
    case guardrailViolation(explanation: String?)

    /// The model refused to answer.
    ///
    /// - Parameter explanation: The reason that the model gave, if any.
    case refusal(explanation: String?)

    /// The request took too long.
    case timeout

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
