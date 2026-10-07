import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

/// Runs an ACP agent in the process of the host, and connects a
/// `ConnectionModel` to it (update.md §8 item 4).
///
/// The helper pairs `InMemoryTransport.pair()`. It gives one end to an
/// `AgentSideConnection` that serves the `Agent` of the host, and connects a
/// new `ConnectionModel` over the other end. The two sides speak the real ACP
/// wire, so the views see the same model that a subprocess agent gives.
///
/// The helper returns the model and keeps no state of its own. The views
/// bind to the model directly: the connection state is
/// `ConnectionModel.state`, and each open session is a `SessionModel` of the
/// model. The kit does not import an agent package. The host gives the
/// agent, for example the `RoutedACPAgent` of FoundationModelsACPAgent:
///
/// ```swift
/// let model = await InProcessAgent.makeConnection { connection in
///   agent.bind(connection: connection)
///   return agent
/// }
/// ```
///
/// The host closes the connection with `ConnectionModel.disconnect()`. The
/// model then stops the read of its end of the pair, and the helper closes
/// the input of the agent side. The agent side reads the end of its input
/// and stops, as an agent process that `disconnect()` ends.
///
/// The agent side can also stop first, when the agent closes its connection
/// (`AgentSideConnection.close()`). Then the helper closes the two ends of
/// the pair, as an agent process that exits, and `ConnectionModel.state`
/// becomes `.disconnected`.
public enum InProcessAgent {
  /// Starts an agent in this process and connects a new model to it.
  ///
  /// The helper keeps the agent side of the connection until it closes,
  /// because an agent such as `RoutedACPAgent` keeps its connection weakly.
  /// A task waits for the close, closes the two ends of the pair, and then
  /// ends.
  ///
  /// The returned model is connected and not initialized. Send `initialize`
  /// with `ConnectionModel.initialize(_:)`, for example with
  /// ``FoundationModelsACP/InitializeRequest/makeAgentViewKitRequest(info:)``.
  ///
  /// - Parameter makeAgent: Makes the agent from the agent side of the
  ///   connection. The agent sends its session updates through that
  ///   connection.
  /// - Returns: The connection model of the client side.
  public static func makeConnection(
    serving makeAgent: @Sendable (AgentSideConnection) -> any Agent
  ) async -> ConnectionModel {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    let agentConnection = await AgentSideConnection(stream: agentEnd, makeAgent)
    Task {
      _ = await agentConnection.closed
      agentEnd.close()
      clientEnd.close()
    }
    let model = ConnectionModel()
    _ = await model.connect(over: InProcessClientTransport(end: clientEnd))
    return model
  }
}

/// The client end of the in-memory pair of ``InProcessAgent``.
///
/// The transport gives the bytes of the agent to the client, and writes the
/// bytes of the client to the agent. When the client stops the read of
/// ``bytes``, for example in `ConnectionModel.disconnect()`, the transport
/// closes its end. The agent side then reads the end of its input. Thus a
/// disconnect stops an in-process agent, as it stops an agent process.
nonisolated struct InProcessClientTransport: ACPTransport {
  /// The bytes from the agent side.
  let bytes: AsyncThrowingStream<Data, any Error>

  /// The client end of the in-memory pair.
  private let end: InMemoryTransport

  /// Makes the transport over the client end of an in-memory pair.
  ///
  /// A task gives each chunk of `end` to ``bytes``. When the read of
  /// ``bytes`` stops, or when the agent side closes, the task stops and the
  /// transport closes `end`.
  ///
  /// - Parameter end: The client end of the pair.
  init(end: InMemoryTransport) {
    self.end = end
    let (stream, continuation) = AsyncThrowingStream<Data, any Error>.makeStream()
    let forward = Task {
      do {
        for try await chunk in end.bytes {
          continuation.yield(chunk)
        }
        continuation.finish()
      } catch {
        continuation.finish(throwing: error)
      }
    }
    continuation.onTermination = { _ in
      forward.cancel()
      end.close()
    }
    bytes = stream
  }

  /// Writes one chunk to the agent side.
  ///
  /// - Parameter data: The bytes to send, already framed.
  /// - Throws: `InMemoryTransport.ClosedError` after a close.
  func write(_ data: Data) async throws {
    try await end.write(data)
  }
}
