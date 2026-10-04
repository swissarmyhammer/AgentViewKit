import AgentViewKit
import Foundation
import FoundationModelsACP

/// The byte that ends each JSON-RPC frame on the wire.
private let frameEnd = UInt8(ascii: "\n")

/// The JSON-RPC error code that a scripted failure sends.
private let internalErrorCode = -32603

/// The method of a prompt request.
private let promptMethod = "session/prompt"

/// An ACP agent that reads the raw JSON-RPC frames of the client and
/// records them.
///
/// The agent answers each request with the scripted result for its method,
/// or with `{}`. A method in ``failingMethods`` gets an error. The result of
/// each `session/prompt` request gets a new `messageId` (a UUID string), and
/// the agent echoes the prompt text in a `user_message_chunk` update with the
/// same `messageId`. ``promptEchoOrder`` tells if the echo comes before or
/// after the result. After the answer, the agent sends the frames that
/// ``followUps`` gives for the method. The agent can also send a raw frame to
/// the client.
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

  /// The position of the echoed user message of a prompt, relative to the
  /// prompt result.
  public enum PromptEchoOrder: Sendable {
    /// The agent sends the echo, and then the result.
    case beforeResult

    /// The agent sends the result, and then the echo.
    case afterResult
  }

  /// The position of the echoed user message of each prompt.
  public var promptEchoOrder = PromptEchoOrder.beforeResult

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
    if failingMethods.contains(method) {
      try? await send(#"{"jsonrpc":"2.0","id":\#(idText),"error":{"code":\#(internalErrorCode),"message":"failed"}}"#)
    } else if method == promptMethod {
      await answerPrompt(frame, idText: idText)
    } else {
      try? await send(Self.resultFrame(idText: idText, result: nextResult(for: method)))
    }
    guard let followUp = followUps[method] else { return }
    for followUpFrame in followUp(frame, messages(method: method).count) {
      try? await send(followUpFrame)
    }
  }

  // MARK: - Prompt

  /// Answers a `session/prompt` request.
  ///
  /// The result gets a new `messageId`. The agent echoes the prompt text in a
  /// `user_message_chunk` update with the same `messageId`, before or after
  /// the result as ``promptEchoOrder`` tells.
  ///
  /// - Parameters:
  ///   - request: The request frame.
  ///   - idText: The JSON text of the id of the request.
  private func answerPrompt(_ request: AgentViewKit.JSONValue, idText: String) async {
    let messageID = AgentViewKit.JSONValue.string(UUID().uuidString)
    let result = Self.resultFrame(idText: idText, result: promptResult(messageID: messageID))
    let echo = Self.echoFrame(of: request, messageID: messageID)
    let frames =
      switch promptEchoOrder {
      case .beforeResult: [echo, result]
      case .afterResult: [result, echo]
      }
    for frame in frames {
      try? await send(frame)
    }
  }

  /// The result JSON text of the next answer to `session/prompt`: the
  /// scripted result object with `messageId` added.
  ///
  /// A scripted result that is not a JSON object gives an object with
  /// `messageId` only.
  ///
  /// - Parameter messageID: The ID of the user message of the prompt.
  /// - Returns: The JSON text of the result.
  private func promptResult(messageID: AgentViewKit.JSONValue) -> String {
    let scripted = Data(nextResult(for: promptMethod).utf8)
    var fields = (try? JSONDecoder().decode([String: AgentViewKit.JSONValue].self, from: scripted)) ?? [:]
    fields["messageId"] = messageID
    return AgentViewKit.JSONValue.object(fields).jsonString
  }

  /// A JSON-RPC response frame with a result.
  ///
  /// - Parameters:
  ///   - idText: The JSON text of the id of the request.
  ///   - result: The JSON text of the result.
  /// - Returns: The frame.
  private static func resultFrame(idText: String, result: String) -> String {
    #"{"jsonrpc":"2.0","id":\#(idText),"result":\#(result)}"#
  }

  /// The `session/update` frame that echoes the text of a prompt as a
  /// `user_message_chunk`.
  ///
  /// - Parameters:
  ///   - request: The `session/prompt` request frame.
  ///   - messageID: The ID of the user message of the prompt.
  /// - Returns: The frame.
  private static func echoFrame(of request: AgentViewKit.JSONValue, messageID: AgentViewKit.JSONValue) -> String {
    let update = AgentViewKit.JSONValue.object([
      "sessionUpdate": .string("user_message_chunk"),
      "messageId": messageID,
      "content": textBlock(promptText(of: request)),
    ])
    let sessionId = request["params"]?["sessionId"] ?? .null
    return AgentViewKit.JSONValue.object([
      "jsonrpc": .string("2.0"),
      "method": .string("session/update"),
      "params": .object(["sessionId": sessionId, "update": update]),
    ]).jsonString
  }

  /// The text of a `session/prompt` request: the text of each `text` block.
  ///
  /// - Parameter request: The request frame.
  /// - Returns: The joined text.
  static func promptText(of request: AgentViewKit.JSONValue) -> String {
    guard case .array(let blocks)? = request["params"]?["prompt"] else { return "" }
    return blocks.compactMap { block in
      block["type"]?.stringValue == "text" ? block["text"]?.stringValue : nil
    }.joined()
  }

  /// A `text` content block.
  ///
  /// - Parameter text: The text of the block.
  /// - Returns: The block.
  static func textBlock(_ text: String) -> AgentViewKit.JSONValue {
    .object(["type": .string("text"), "text": .string(text)])
  }
}
