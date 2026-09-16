import OSLog
import SwiftUI

/// The verb that restores a thread to a ``Checkpoint`` (plan.md §9 E).
///
/// A source that makes checkpoints implements this protocol.
/// ``CheckpointView`` reads the actions from
/// ``SwiftUI/EnvironmentValues/checkpointActions``. Set them with
/// ``SwiftUI/View/checkpointActions(_:)``.
@MainActor
public protocol CheckpointActions: AnyObject {
  /// Restores the thread to the checkpoint.
  ///
  /// A conversation restore removes the turns after
  /// ``Checkpoint/turnIndex`` from the thread.
  ///
  /// - Parameters:
  ///   - checkpoint: The restore point.
  ///   - code: `true` to put the files of the working directory back.
  ///   - conversation: `true` to put the conversation back.
  /// - Throws: The error of the source when the restore fails.
  func restore(_ checkpoint: Checkpoint, code: Bool, conversation: Bool) async throws
}

/// The checkpoint actions that a view gets when no ancestor sets actions.
///
/// The verb does nothing, does not throw, and writes one `debug` message to
/// the log, so that a developer can see that the host did not set actions.
public final class LoggingCheckpointActions: CheckpointActions {
  /// The log of the actions.
  private let logger = Logger(subsystem: "AgentViewKit", category: "LoggingCheckpointActions")

  /// Makes actions that only log.
  public init() {}

  public func restore(_ checkpoint: Checkpoint, code: Bool, conversation: Bool) async throws {
    logger.debug(
      "restore was called, but no checkpointActions are set. Nothing occurs.")
  }
}

extension EnvironmentValues {
  /// The checkpoint actions that the views of this subtree call.
  ///
  /// The default is a ``LoggingCheckpointActions``, which does nothing.
  @Entry public var checkpointActions: any CheckpointActions = LoggingCheckpointActions()
}

extension View {
  /// Sets the checkpoint actions that the views of this subtree call.
  ///
  /// - Parameter actions: The checkpoint actions of the thread source.
  /// - Returns: A view that gives the actions to its subtree.
  public func checkpointActions(_ actions: any CheckpointActions) -> some View {
    environment(\.checkpointActions, actions)
  }
}
