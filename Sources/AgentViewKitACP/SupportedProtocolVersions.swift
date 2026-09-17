import FoundationModelsACP

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

  /// The text of the error record for a refused version.
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
