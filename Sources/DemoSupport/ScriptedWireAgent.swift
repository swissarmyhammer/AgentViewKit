import AgentViewKit
import Foundation
import FoundationModelsACP

/// The byte that ends each JSON-RPC frame on the wire.
private let frameEnd = UInt8(ascii: "\n")

/// The JSON-RPC error code that a scripted failure sends.
private let internalErrorCode = -32603

/// An ACP agent that reads the raw JSON-RPC frames of the client and
/// records them.
///
/// The agent answers each request with the scripted result for its method,
/// or with `{}`. A method in ``failingMethods`` gets an error. After the
/// answer, the agent sends the frames that ``followUps`` gives for the
/// method. The agent can also send a raw frame to the client.
///
/// The ACP tests and the demo app use this agent. The demo app binds it with
/// the `--in-memory-agent` launch argument (``InMemoryDemoAgent``), so that
/// its end-to-end test needs no agent binary.
public final class ScriptedWireAgent {
  /// Gives the frames that the agent sends after it answers one request.
  ///
  /// The first argument is the request frame. The second argument is the
  /// number of requests with the same method, this request included.
  public typealias FollowUp = (AgentViewKit.JSONValue, Int) -> [String]

  /// The transport end of the agent.
  private let transport: InMemoryTransport

  /// The result JSON text of each method.
  public var results: [String: String] = [:]

  /// The result JSON texts of each method, in answer order.
  ///
  /// The agent answers each request with the first text of the queue of its
  /// method and removes that text. When the queue is empty, the agent uses
  /// ``results``.
  public var resultQueues: [String: [String]] = [:]

  /// The methods that get an error.
  public var failingMethods: Set<String> = []

  /// The frames to send after the answer to a request, keyed by method.
  public var followUps: [String: FollowUp] = [:]

  /// Each frame from the client, in arrival order.
  public private(set) var received: [AgentViewKit.JSONValue] = []

  /// The task that reads the frames.
  private var reader: Task<Void, Never>?

  /// Makes an agent on `transport`.
  ///
  /// - Parameter transport: The transport end of the agent.
  public init(transport: InMemoryTransport) {
    self.transport = transport
  }

  /// Starts to read the frames of the client.
  public func start() {
    let bytes = transport.bytes
    reader = Task { [weak self] in
      var buffer = Data()
      do {
        for try await chunk in bytes {
          buffer.append(chunk)
          while let end = buffer.firstIndex(of: frameEnd) {
            let line = buffer[buffer.startIndex..<end]
            buffer = Data(buffer[buffer.index(after: end)...])
            await self?.handle(Data(line))
          }
        }
      } catch {
        return
      }
    }
  }

  /// Stops the reader and closes the transport.
  public func stop() {
    reader?.cancel()
    transport.close()
  }

  /// Sends a raw JSON-RPC frame to the client.
  ///
  /// A line end in JSON text is only white space, because a line end in a
  /// string is escaped. The agent changes each line end to a space, so that
  /// the frame is one line.
  ///
  /// - Parameter json: The frame.
  /// - Throws: The error of the transport.
  public func send(_ json: String) async throws {
    let line = json.replacingOccurrences(of: "\n", with: " ")
    try await transport.write(Data((line + "\n").utf8))
  }

  /// The frames with `method`, in arrival order.
  ///
  /// - Parameter method: The JSON-RPC method.
  /// - Returns: The frames.
  public func messages(method: String) -> [AgentViewKit.JSONValue] {
    received.filter { $0["method"]?.stringValue == method }
  }

  /// The position of the first frame with `method`, or `nil`.
  ///
  /// - Parameter method: The JSON-RPC method.
  /// - Returns: The position in ``received``.
  public func index(ofMethod method: String) -> Int? {
    received.firstIndex { $0["method"]?.stringValue == method }
  }

  /// The position of the response to the request with `id`, or `nil`.
  ///
  /// - Parameter id: The JSON-RPC id of the request of the agent.
  /// - Returns: The position in ``received``.
  public func index(ofResponseTo id: Double) -> Int? {
    received.firstIndex { $0["method"] == nil && $0["id"] == .number(id) }
  }

  /// The response to the request with `id`, or `nil`.
  ///
  /// - Parameter id: The JSON-RPC id of the request of the agent.
  /// - Returns: The response frame.
  public func response(to id: Double) -> AgentViewKit.JSONValue? {
    index(ofResponseTo: id).map { received[$0] }
  }

  /// The result JSON text of the next answer to `method`.
  ///
  /// - Parameter method: The method of the request.
  /// - Returns: The first queued text, then the text of ``results``, then
  ///   `{}`.
  private func nextResult(for method: String) -> String {
    if var queue = resultQueues[method], !queue.isEmpty {
      let result = queue.removeFirst()
      resultQueues[method] = queue
      return result
    }
    return results[method] ?? "{}"
  }

  /// Records one frame, answers it when it is a request, and then sends the
  /// follow-up frames of its method.
  private func handle(_ line: Data) async {
    guard let frame = try? JSONDecoder().decode(AgentViewKit.JSONValue.self, from: line) else { return }
    received.append(frame)
    guard let method = frame["method"]?.stringValue, let id = frame["id"] else { return }
    let idText = String(decoding: (try? JSONEncoder().encode(id)) ?? Data(), as: UTF8.self)
    let reply =
      if failingMethods.contains(method) {
        #"{"jsonrpc":"2.0","id":\#(idText),"error":{"code":\#(internalErrorCode),"message":"failed"}}"#
      } else {
        #"{"jsonrpc":"2.0","id":\#(idText),"result":\#(nextResult(for: method))}"#
      }
    try? await send(reply)
    guard let followUp = followUps[method] else { return }
    for followUpFrame in followUp(frame, messages(method: method).count) {
      try? await send(followUpFrame)
    }
  }
}
