import Foundation

/// The identifier of an ``ElicitationRequest`` (plan.md §13).
///
/// The source makes this value. For ACP, the source can use the JSON-RPC id
/// of the `elicitation/create` request.
public typealias ElicitationRequestID = Identifier<ElicitationRequest>

/// A request from a server for input from the user, during a tool call
/// (plan.md §3.2, §13).
///
/// The request comes from ACP `elicitation/create` or from a Router
/// `OperationEvent`. `AgentThread.pendingElicitations` holds the requests
/// that wait for the user. The user answers with
/// `AgentThreadActions.respond(to:_:)` and an ``ElicitationResult``.
///
/// The kit uses ``JSONValue`` for the schema and the values, not
/// `GeneratedContent`. The FoundationModels target converts the values.
public nonisolated struct ElicitationRequest: Sendable, Hashable, Identifiable {
  /// The identifier of the request.
  public var id: ElicitationRequestID

  /// The display name of the server that asks for the input.
  public var server: String

  /// The text that tells the user which input the server needs.
  public var message: String

  /// The form of the request: a form to fill in, or a URL to open.
  public var mode: Mode

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// Makes an elicitation request.
  ///
  /// - Parameters:
  ///   - id: The identifier of the request.
  ///   - server: The display name of the server that asks for the input.
  ///   - message: The text that tells the user which input the server needs.
  ///   - mode: The form of the request.
  ///   - meta: The `_meta` value of the source.
  public init(
    id: ElicitationRequestID,
    server: String,
    message: String,
    mode: Mode,
    meta: JSONValue? = nil
  ) {
    self.id = id
    self.server = server
    self.message = message
    self.mode = mode
    self.meta = meta
  }

  /// The form of an elicitation request (MCP 2025-11-25).
  ///
  /// The JSON form is the ACP v2 `elicitation/create` wire form. The `mode`
  /// key selects the case. `form` has a `requestedSchema`. `url` has a `url`
  /// and an `elicitationId`.
  public enum Mode: Sendable, Hashable {
    /// The user fills in a form.
    ///
    /// - Parameter requestedSchema: The JSON Schema of the form: a flat
    ///   object of primitive properties. `ElicitationFieldSchema` reads it.
    case form(requestedSchema: JSONValue)

    /// The user opens a URL, after consent.
    ///
    /// - Parameters:
    ///   - url: The location to open.
    ///   - elicitationId: The identifier that `elicitation/complete` uses
    ///     for the request.
    case url(URL, elicitationId: String)
  }
}

/// The answer of the user to an ``ElicitationRequest`` (plan.md §13).
///
/// The cases follow the MCP elicitation result actions.
public nonisolated enum ElicitationResult: Sendable, Hashable {
  /// The user accepts the request.
  ///
  /// - Parameter content: For a form, the values that passed validation. For
  ///   a URL, `nil`: the user gives consent to open the URL.
  case accept(JSONValue?)

  /// The user declines the request.
  case decline

  /// The user closes the request with no answer.
  case cancel
}

// MARK: - Codable

nonisolated extension ElicitationRequest.Mode: Codable {
  /// The JSON keys that the enum reads and writes.
  private enum CodingKeys: String, CodingKey {
    case mode
    case requestedSchema
    case url
    case elicitationId
  }

  /// The `mode` strings of the cases.
  private enum ModeName {
    static let form = "form"
    static let url = "url"
  }

  /// Decodes a mode from its ACP wire form.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` when a required key is missing, when a value
  ///   has the wrong type, or when the `mode` is not `form` or `url`. The
  ///   ACP schema tells a client not to show a mode that it does not know
  ///   as a known mode.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let mode = try container.decode(String.self, forKey: .mode)
    switch mode {
    case ModeName.form:
      self = .form(requestedSchema: try container.decode(JSONValue.self, forKey: .requestedSchema))
    case ModeName.url:
      self = .url(
        try container.decode(URL.self, forKey: .url),
        elicitationId: try container.decode(String.self, forKey: .elicitationId)
      )
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .mode,
        in: container,
        debugDescription: "The elicitation mode \(mode) is not form or url."
      )
    }
  }

  /// Encodes the mode in its ACP wire form.
  ///
  /// - Parameter encoder: The encoder to write to.
  /// - Throws: The error of the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .form(let requestedSchema):
      try container.encode(ModeName.form, forKey: .mode)
      try container.encode(requestedSchema, forKey: .requestedSchema)
    case .url(let url, let elicitationId):
      try container.encode(ModeName.url, forKey: .mode)
      try container.encode(url, forKey: .url)
      try container.encode(elicitationId, forKey: .elicitationId)
    }
  }
}
