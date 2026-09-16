import Foundation

/// The identifier of an ``AuthorizationRequest`` (plan.md §12).
///
/// For a FoundationModels source, this is the ``AuthorizationPayload/id``.
public typealias AuthorizationRequestID = Identifier<AuthorizationRequest>

/// A request to connect to an MCP server that needs authorization
/// (plan.md §3.2, §12).
///
/// `AgentThread.pendingAuthorizations` holds the requests that wait for the
/// user. `AuthorizationView` shows a "Connect to X" card, and
/// `AgentThreadActions.connect(_:)` starts the OAuth handoff. A source that
/// reads an ``AuthorizationPayload`` puts its
/// ``AuthorizationPayload/elicitationId`` in ``meta``.
public nonisolated struct AuthorizationRequest: Sendable, Hashable, Identifiable {
  /// The identifier of the request.
  public var id: AuthorizationRequestID

  /// The display name of the MCP server.
  public var serverName: String

  /// The OAuth scopes that the server asks for, in order.
  public var scopes: [String]

  /// The location where the user authorizes the connection.
  public var authorizationURL: URL

  /// The metadata of the source, unchanged, or `nil`.
  public var meta: JSONValue?

  /// Makes an authorization request.
  ///
  /// - Parameters:
  ///   - id: The identifier of the request.
  ///   - serverName: The display name of the MCP server.
  ///   - scopes: The OAuth scopes that the server asks for.
  ///   - authorizationURL: The location where the user authorizes.
  ///   - meta: The metadata of the source.
  public init(
    id: AuthorizationRequestID,
    serverName: String,
    scopes: [String] = [],
    authorizationURL: URL,
    meta: JSONValue? = nil
  ) {
    self.id = id
    self.serverName = serverName
    self.scopes = scopes
    self.authorizationURL = authorizationURL
    self.meta = meta
  }
}
