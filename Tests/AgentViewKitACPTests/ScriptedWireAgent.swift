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
/// or with `{}`. A method in ``failingMethods`` gets an error. The agent can
/// also send a raw request to the client.
final class ScriptedWireAgent {
  /// The transport end of the agent.
  private let transport: InMemoryTransport

  /// The result JSON text of each method.
  var results: [String: String] = [:]

  /// The methods that get an error.
  var failingMethods: Set<String> = []

  /// Each frame from the client, in arrival order.
  private(set) var received: [AgentViewKit.JSONValue] = []

  /// The task that reads the frames.
  private var reader: Task<Void, Never>?

  /// Makes an agent on `transport`.
  ///
  /// - Parameter transport: The transport end of the agent.
  init(transport: InMemoryTransport) {
    self.transport = transport
  }

  /// Starts to read the frames of the client.
  func start() {
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
  func stop() {
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
  func send(_ json: String) async throws {
    let line = json.replacingOccurrences(of: "\n", with: " ")
    try await transport.write(Data((line + "\n").utf8))
  }

  /// The frames with `method`, in arrival order.
  func messages(method: String) -> [AgentViewKit.JSONValue] {
    received.filter { $0["method"]?.stringValue == method }
  }

  /// The position of the first frame with `method`, or `nil`.
  func index(ofMethod method: String) -> Int? {
    received.firstIndex { $0["method"]?.stringValue == method }
  }

  /// The position of the response to the request with `id`, or `nil`.
  func index(ofResponseTo id: Double) -> Int? {
    received.firstIndex { $0["method"] == nil && $0["id"] == .number(id) }
  }

  /// The response to the request with `id`, or `nil`.
  func response(to id: Double) -> AgentViewKit.JSONValue? {
    index(ofResponseTo: id).map { received[$0] }
  }

  /// Records one frame, and answers it when it is a request.
  private func handle(_ line: Data) async {
    guard let frame = try? JSONDecoder().decode(AgentViewKit.JSONValue.self, from: line) else { return }
    received.append(frame)
    guard let method = frame["method"]?.stringValue, let id = frame["id"] else { return }
    let idText = String(decoding: (try? JSONEncoder().encode(id)) ?? Data(), as: UTF8.self)
    let reply =
      if failingMethods.contains(method) {
        #"{"jsonrpc":"2.0","id":\#(idText),"error":{"code":\#(internalErrorCode),"message":"failed"}}"#
      } else {
        #"{"jsonrpc":"2.0","id":\#(idText),"result":\#(results[method] ?? "{}")}"#
      }
    try? await send(reply)
  }
}
