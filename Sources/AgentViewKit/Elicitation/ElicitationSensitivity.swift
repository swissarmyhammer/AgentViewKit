import FoundationModelsACP
import FoundationModelsACPClient

nonisolated extension PendingElicitation {
  /// The `_meta` key of a sensitive request.
  static let sensitiveMetaKey = "sensitive"

  /// `true` when the agent marks the request as sensitive with
  /// `"sensitive": true` in its `_meta`, for example when it asks for the
  /// secret of an MCP server (FoundationModelsACPAgent D101).
  ///
  /// The form of a sensitive request keeps a plain text field, and keeps the
  /// answer in no state after the send (``ElicitationFieldContext/isSensitive``).
  public var isSensitive: Bool {
    guard case .object(let meta) = request.meta else { return false }
    return meta[Self.sensitiveMetaKey] == .bool(true)
  }
}
