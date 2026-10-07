import FoundationModelsACP
import Synchronization

/// Keeps the agent side of the connection that the factory of
/// ``AgentViewKit/InProcessAgent`` got, so that the host can close it or wait
/// for its close.
///
/// A close of the agent side is the in-process form of an agent process that
/// stops: the helper then closes the two ends of the pair, and the state of
/// the `ConnectionModel` becomes `.disconnected`.
///
/// The factory runs outside the main actor, so the box is not isolated. A
/// `Mutex` holds the connection.
public nonisolated final class AgentConnectionBox: Sendable {
  /// The agent side of the connection, or `nil` before the factory ran.
  private let connection = Mutex<AgentSideConnection?>(nil)

  /// Makes an empty box.
  public init() {}

  /// Keeps the agent side of the connection.
  ///
  /// - Parameter agentConnection: The connection that the factory got.
  public func keep(_ agentConnection: AgentSideConnection) {
    connection.withLock { $0 = agentConnection }
  }

  /// Closes the agent side of the connection, as an agent process that
  /// stops. Before the factory ran, the call does nothing.
  public func close() async {
    await connection.withLock { $0 }?.close()
  }

  /// Waits until the agent side of the connection closed, for example after
  /// the client side disconnected. Before the factory ran, the call returns
  /// at once.
  public func waitUntilClosed() async {
    _ = await connection.withLock { $0 }?.closed
  }
}
