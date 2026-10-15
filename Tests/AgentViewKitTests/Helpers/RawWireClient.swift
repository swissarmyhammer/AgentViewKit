import Foundation
import FoundationModelsACP

/// The client end of an ACP agent for the wire tests. It writes raw request
/// frames and raw notification frames, and reads the raw frames of the agent.
///
/// The client keeps one iterator of the bytes of the transport, and the bytes
/// that it did not read yet. Thus a test can read the frames in more than one
/// step, and no frame goes by unseen.
@MainActor final class RawWireClient {
  /// The byte that ends each JSON-RPC frame on the wire.
  private static let frameEnd = UInt8(ascii: "\n")

  /// The JSON-RPC version of each frame.
  private static let jsonRPCVersion = JSONValue.string("2.0")

  /// The client end of the transport.
  let transport: InMemoryTransport

  /// The iterator of the bytes of the agent.
  private var bytes: AsyncThrowingStream<Data, any Error>.Iterator

  /// The bytes of the agent that no read gave yet.
  private var buffer = Data()

  /// Makes the client of one transport end.
  ///
  /// - Parameter transport: The client end of the transport.
  init(transport: InMemoryTransport) {
    self.transport = transport
    bytes = transport.bytes.makeAsyncIterator()
  }

  /// Writes one request frame.
  ///
  /// - Parameters:
  ///   - method: The JSON-RPC method.
  ///   - id: The JSON-RPC id.
  ///   - params: The parameters.
  /// - Throws: The error of the transport.
  func request(method: String, id: Double, params: JSONValue) async throws {
    try await write(.object(["jsonrpc": Self.jsonRPCVersion, "id": .number(id), "method": .string(method), "params": params]))
  }

  /// Writes one notification frame.
  ///
  /// - Parameters:
  ///   - method: The JSON-RPC method.
  ///   - params: The parameters.
  /// - Throws: The error of the transport.
  func notify(method: String, params: JSONValue) async throws {
    try await write(.object(["jsonrpc": Self.jsonRPCVersion, "method": .string(method), "params": params]))
  }

  /// Reads the frames of the agent until a frame matches `isLast`.
  ///
  /// - Parameter isLast: Tells if a frame is the last frame to read.
  /// - Returns: The frames in arrival order, the last frame included. When
  ///   the agent closes the transport first, the frames up to the close.
  /// - Throws: The error of the transport, or of the JSON decoder.
  func frames(through isLast: (JSONValue) -> Bool) async throws -> [JSONValue] {
    var frames: [JSONValue] = []
    while true {
      while let frame = try nextBufferedFrame() {
        frames.append(frame)
        if isLast(frame) { return frames }
      }
      // A main actor property cannot take a mutating async call, so the
      // read uses a copy of the iterator and then keeps the copy.
      var iterator = bytes
      let chunk = try await iterator.next(isolation: #isolation)
      bytes = iterator
      guard let chunk else { return frames }
      buffer.append(chunk)
    }
  }

  /// Takes the first whole frame out of the buffer.
  ///
  /// - Returns: The frame, or `nil` when the buffer holds no whole frame.
  /// - Throws: The error of the JSON decoder.
  private func nextBufferedFrame() throws -> JSONValue? {
    guard let end = buffer.firstIndex(of: Self.frameEnd) else { return nil }
    let line = Data(buffer[buffer.startIndex..<end])
    buffer = Data(buffer[buffer.index(after: end)...])
    return try JSONDecoder().decode(JSONValue.self, from: line)
  }

  /// Writes one frame and its line end.
  ///
  /// - Parameter frame: The frame.
  /// - Throws: The error of the transport.
  private func write(_ frame: JSONValue) async throws {
    try await transport.write(Data((frame.jsonString + "\n").utf8))
  }
}
