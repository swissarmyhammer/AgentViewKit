import Foundation

/// A request to connect to an MCP server that needs authorization
/// (plan.md §3.3, §12).
///
/// The schema name is `AgentViewKit.AuthorizationPayload`. A source turns the
/// payload into an `AuthorizationRequest` and puts ``elicitationId`` in its
/// `meta`.
public nonisolated struct AuthorizationPayload: StructuredPayload, Hashable, Identifiable {
  /// The identifier of the request.
  public var id: String

  /// The display name of the MCP server.
  public var serverName: String

  /// The OAuth scopes that the server asks for.
  public var scopes: [String]

  /// The location where the user authorizes the connection.
  public var authorizationURL: URL

  /// The identifier of the URL-mode elicitation that the request answers, or
  /// `nil` when the request has no elicitation.
  public var elicitationId: String?

  /// Makes an authorization payload.
  ///
  /// - Parameters:
  ///   - id: The identifier of the request.
  ///   - serverName: The display name of the MCP server.
  ///   - scopes: The OAuth scopes that the server asks for.
  ///   - authorizationURL: The location where the user authorizes.
  ///   - elicitationId: The identifier of the elicitation, or `nil`.
  public init(
    id: String,
    serverName: String,
    scopes: [String],
    authorizationURL: URL,
    elicitationId: String? = nil
  ) {
    self.id = id
    self.serverName = serverName
    self.scopes = scopes
    self.authorizationURL = authorizationURL
    self.elicitationId = elicitationId
  }
}
