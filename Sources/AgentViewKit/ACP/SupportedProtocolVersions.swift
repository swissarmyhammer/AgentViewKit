import FoundationModelsACP
import FoundationModelsACPClient

/// The ACP protocol versions that the kit accepts (plan.md §11 decision 20).
///
/// `Docs/decisions/acp-version.md` records the survey and the decision. Its
/// `supported:` line must list the same integers as ``values``. A test
/// compares the two.
public nonisolated enum SupportedProtocolVersions {
  /// The wire integers of the accepted versions, in increasing order.
  public static let values: [UInt16] = [ProtocolVersion.v2.rawValue]

  /// Tells whether the kit accepts a version.
  ///
  /// - Parameter version: The version that the agent answered with.
  /// - Returns: `true` when ``values`` contains the wire integer of
  ///   `version`.
  public static func contains(_ version: ProtocolVersion) -> Bool {
    values.contains(version.rawValue)
  }

  /// Checks the protocol version that the agent answered with, for a host
  /// that sends `initialize` itself.
  ///
  /// - Parameters:
  ///   - negotiated: The version in the `initialize` answer.
  ///   - requested: The version in the `initialize` request.
  /// - Throws: ``UnsupportedProtocolVersionError`` when ``values`` does not
  ///   contain `negotiated`.
  public static func accept(
    _ negotiated: ProtocolVersion, requested: ProtocolVersion
  ) throws(UnsupportedProtocolVersionError) {
    guard contains(negotiated) else {
      throw UnsupportedProtocolVersionError(received: negotiated, requested: requested)
    }
  }

  /// The text of the error for a refused version.
  ///
  /// - Parameters:
  ///   - received: The version that the agent answered with.
  ///   - requested: The version that the client sent.
  /// - Returns: A message that names both versions and the accepted list.
  static func refusalMessage(received: ProtocolVersion, requested: ProtocolVersion) -> String {
    let accepted = values.map(String.init).joined(separator: ", ")
    return "The agent answered with ACP protocol version \(received.rawValue). "
      + "The client sent protocol version \(requested.rawValue). "
      + "This kit accepts only protocol version \(accepted)."
  }
}

/// The error when an agent answers `initialize` with a protocol version that
/// ``SupportedProtocolVersions`` does not contain
/// (`Docs/decisions/acp-version.md`).
///
/// The description names both versions and the accepted list, so that the
/// host can show why the kit refused the agent.
public nonisolated struct UnsupportedProtocolVersionError: Error, Hashable, Sendable, CustomStringConvertible {
  /// The version that the agent answered with.
  public let received: ProtocolVersion

  /// The version that the client sent in its `initialize` request.
  public let requested: ProtocolVersion

  /// Makes the error for a refused version.
  ///
  /// - Parameters:
  ///   - received: The version that the agent answered with.
  ///   - requested: The version that the client sent.
  public init(received: ProtocolVersion, requested: ProtocolVersion) {
    self.received = received
    self.requested = requested
  }

  public var description: String {
    SupportedProtocolVersions.refusalMessage(received: received, requested: requested)
  }
}

extension ConnectionModel {
  /// Sends `initialize` with `ConnectionModel.initialize(_:)`, and refuses an
  /// agent whose protocol version the kit does not accept.
  ///
  /// The wire package throws `ProtocolVersionMismatchError` when the answer
  /// is not the sent version. This function throws
  /// ``UnsupportedProtocolVersionError`` for that error too, so that a host
  /// gets one error for each refused version.
  ///
  /// - Parameter request: The `initialize` request.
  /// - Returns: The answer of the agent. The connection model keeps it, with
  ///   its capability flags.
  /// - Throws: ``UnsupportedProtocolVersionError`` when the kit refuses the
  ///   version of the answer, else each error of `ConnectionModel.initialize(_:)`.
  public func initializeCheckingProtocolVersion(_ request: InitializeRequest) async throws -> InitializeResponse {
    let response: InitializeResponse
    do {
      response = try await initialize(request)
    } catch let mismatch as ProtocolVersionMismatchError {
      throw UnsupportedProtocolVersionError(received: mismatch.received, requested: mismatch.sent)
    }
    try SupportedProtocolVersions.accept(response.protocolVersion, requested: request.protocolVersion)
    return response
  }
}
