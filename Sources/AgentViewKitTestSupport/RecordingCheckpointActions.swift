import AgentViewKit

/// A ``CheckpointActions`` that records each call and does nothing else.
///
/// ``restore(_:code:conversation:)`` first appends one ``Call`` to ``calls``,
/// then runs ``onRestore``, if it is set. The closure lets a test delay the
/// restore or make it throw.
public final class RecordingCheckpointActions: CheckpointActions {
  /// One recorded call of ``restore(_:code:conversation:)``.
  public struct Call: Equatable, Sendable {
    /// The restore point.
    public let checkpoint: Checkpoint

    /// `true` when the call asked to put the files back.
    public let code: Bool

    /// `true` when the call asked to put the conversation back.
    public let conversation: Bool

    /// Makes a call record.
    ///
    /// - Parameters:
    ///   - checkpoint: The restore point.
    ///   - code: `true` when the call asked to put the files back.
    ///   - conversation: `true` when the call asked to put the conversation
    ///     back.
    public init(checkpoint: Checkpoint, code: Bool, conversation: Bool) {
      self.checkpoint = checkpoint
      self.code = code
      self.conversation = conversation
    }
  }

  /// Each call, in call order.
  public private(set) var calls: [Call] = []

  /// Runs after each recorded call. The error that it throws is the error of
  /// the restore.
  public var onRestore: (@MainActor (Call) async throws -> Void)?

  /// Makes actions with no calls and no closure.
  public init() {}

  /// Removes each recorded call. The closure does not change.
  public func reset() {
    calls.removeAll()
  }

  public func restore(_ checkpoint: Checkpoint, code: Bool, conversation: Bool) async throws {
    let call = Call(checkpoint: checkpoint, code: code, conversation: conversation)
    calls.append(call)
    try await onRestore?(call)
  }
}
