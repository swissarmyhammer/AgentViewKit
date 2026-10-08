import AgentViewKit
import Foundation
import FoundationModelsACP

/// The byte that ends each JSON-RPC frame on the wire.
private let frameEnd = UInt8(ascii: "\n")

/// The JSON-RPC error code that a scripted failure sends.
private let internalErrorCode = -32603

/// The method of a prompt request.
private let promptMethod = "session/prompt"

/// The method of a session update notification.
private let sessionUpdateMethod = "session/update"

/// The JSON-RPC version of each notification frame.
private let jsonRPCVersion = "2.0"

/// An ACP agent that reads the raw JSON-RPC frames of the client and
/// records them.
///
/// The agent answers each request with the scripted result for its method,
/// or with `{}`. A method in ``failingMethods`` gets an error with the code
/// that ``errorCodes`` gives. The result of
/// each `session/prompt` request gets a new `messageId` (a UUID string), and
/// the agent echoes the prompt text in a `user_message_chunk` update with the
/// same `messageId`. ``promptEchoOrder`` tells if the echo comes before or
/// after the result. Before the answer, the agent sends the frames that
/// ``leadIns`` gives for the method. After the answer, the agent sends the
/// frames that ``followUps`` gives for the method. The agent can also send a
/// raw frame to the client. The agent holds the answer to each request with
/// a method in ``heldMethods`` until ``releaseHeldAnswer()``.
///
/// The ACP tests and the demo app use this agent. The demo app binds it with
/// the `--in-memory-agent` launch argument (``InMemoryDemoAgent``), so that
/// its end-to-end test needs no agent binary.
///
/// The class states `@MainActor`, because the benchmark target of
/// `Benchmarks/` compiles this file through a link with no default
/// isolation.
@MainActor
public final class ScriptedWireAgent {
  /// Gives the frames that the agent sends before or after it answers one
  /// request.
  ///
  /// The first argument is the request frame. The second argument is the
  /// number of requests with the same method, this request included.
  public typealias FollowUp = (JSONValue, Int) -> [String]

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

  /// The methods whose answers the agent holds until ``releaseHeldAnswer()``.
  ///
  /// The agent sends the lead-in frames of a held request, and then holds
  /// its answer. While the agent holds an answer, it sends no frame and reads
  /// no frame. A test uses this to see the client state while the request is
  /// in flight.
  public var heldMethods: Set<String> = []

  /// The number of releases that came before the agent held an answer.
  private var earlyReleases = 0

  /// The continuation of the held answer, or `nil`.
  private var heldAnswer: CheckedContinuation<Void, Never>?

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

  /// The JSON-RPC error code of each method in ``failingMethods``.
  ///
  /// A failing method with no code here gets `-32603` (internal error). For
  /// example, `-32000` tells the client that the agent requires
  /// authentication.
  public var errorCodes: [String: Int] = [:]

  /// The frames to send after the answer to a request, keyed by method.
  public var followUps: [String: FollowUp] = [:]

  /// The frames to send before the answer to a request, keyed by method.
  ///
  /// For example, the replay of a `session/resume` comes before its answer.
  public var leadIns: [String: FollowUp] = [:]

  /// Each frame from the client, in arrival order.
  public private(set) var received: [JSONValue] = []

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

  /// Stops the reader and closes the transport. A held answer goes out to
  /// the closed transport, so the reader ends.
  public func stop() {
    reader?.cancel()
    transport.close()
    releaseHeldAnswer()
  }

  /// Lets the agent send one held answer.
  ///
  /// When the agent holds no answer, the release applies to the next answer
  /// that the agent holds.
  public func releaseHeldAnswer() {
    guard let heldAnswer else {
      earlyReleases += 1
      return
    }
    self.heldAnswer = nil
    heldAnswer.resume()
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
  public func messages(method: String) -> [JSONValue] {
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
  public func response(to id: Double) -> JSONValue? {
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

  /// Records one frame. When it is a request, sends the lead-in frames of its
  /// method, holds the answer when ``heldMethods`` has the method, answers
  /// it, and then sends the follow-up frames of its method.
  private func handle(_ line: Data) async {
    guard let frame = try? JSONDecoder().decode(JSONValue.self, from: line) else { return }
    received.append(frame)
    guard let method = frame["method"]?.stringValue, let id = frame["id"] else { return }
    let idText = String(decoding: (try? JSONEncoder().encode(id)) ?? Data(), as: UTF8.self)
    await send(leadIns[method], for: frame, method: method)
    if heldMethods.contains(method) {
      await waitForRelease()
    }
    if failingMethods.contains(method) {
      let code = errorCodes[method] ?? internalErrorCode
      try? await send(#"{"jsonrpc":"2.0","id":\#(idText),"error":{"code":\#(code),"message":"failed"}}"#)
    } else if method == promptMethod {
      await answerPrompt(request: frame, idText: idText)
    } else {
      try? await send(Self.resultFrame(idText: idText, result: nextResult(for: method)))
    }
    await send(followUps[method], for: frame, method: method)
  }

  /// Sends the frames that a lead-in or a follow-up gives for one request.
  ///
  /// - Parameters:
  ///   - frames: The lead-in or the follow-up, or `nil` for no frame.
  ///   - request: The request frame.
  ///   - method: The method of the request.
  private func send(_ frames: FollowUp?, for request: JSONValue, method: String) async {
    guard let frames else { return }
    for frame in frames(request, messages(method: method).count) {
      try? await send(frame)
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
  private func answerPrompt(request: JSONValue, idText: String) async {
    let messageID = JSONValue.string(UUID().uuidString)
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

  /// Waits until ``releaseHeldAnswer()`` lets the held answer go out. A
  /// release that came before returns at once.
  private func waitForRelease() async {
    guard earlyReleases == 0 else {
      earlyReleases -= 1
      return
    }
    await withCheckedContinuation { heldAnswer = $0 }
  }

  /// The result JSON text of the next answer to `session/prompt`: the
  /// scripted result object with `messageId` added.
  ///
  /// A scripted result that is not a JSON object gives an object with
  /// `messageId` only.
  ///
  /// - Parameter messageID: The ID of the user message of the prompt.
  /// - Returns: The JSON text of the result.
  private func promptResult(messageID: JSONValue) -> String {
    let scripted = Data(nextResult(for: promptMethod).utf8)
    var fields = (try? JSONDecoder().decode([String: JSONValue].self, from: scripted)) ?? [:]
    fields["messageId"] = messageID
    return JSONValue.object(fields).jsonString
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
  private static func echoFrame(of request: JSONValue, messageID: JSONValue) -> String {
    let update = JSONValue.object([
      "sessionUpdate": .string("user_message_chunk"),
      "messageId": messageID,
      "content": textBlock(text: promptText(of: request)),
    ])
    let sessionId = request["params"]?["sessionId"] ?? .null
    return makeSessionUpdateFrame(params: .object(["sessionId": sessionId, "update": update]))
  }

  /// Makes a `session/update` notification frame from the agent.
  ///
  /// Each scripted agent and each test helper that sends a `session/update`
  /// frame makes it here, so that the frame has one shape.
  ///
  /// - Parameter params: The params of the notification: the `sessionId`
  ///   and the `update` members.
  /// - Returns: The JSON text of the frame.
  public static func makeSessionUpdateFrame(params: JSONValue) -> String {
    JSONValue.object([
      "jsonrpc": .string(jsonRPCVersion),
      "method": .string(sessionUpdateMethod),
      "params": params,
    ]).jsonString
  }

  /// The text of a `session/prompt` request: the text of each `text` block.
  ///
  /// - Parameter request: The request frame.
  /// - Returns: The joined text.
  public static func promptText(of request: JSONValue) -> String {
    guard case .array(let blocks)? = request["params"]?["prompt"] else { return "" }
    return blocks.compactMap { block in
      block["type"]?.stringValue == "text" ? block["text"]?.stringValue : nil
    }.joined()
  }

  /// A `text` content block.
  ///
  /// - Parameter text: The text of the block.
  /// - Returns: The block.
  static func textBlock(text: String) -> JSONValue {
    .object(["type": .string("text"), "text": .string(text)])
  }
}
