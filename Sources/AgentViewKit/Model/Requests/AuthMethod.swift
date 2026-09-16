/// The identifier of an ACP authentication method (plan.md §3.4, §12).
///
/// For ACP, this is the `methodId`. `AgentThreadActions.login(_:)` takes
/// this type.
public typealias AuthMethodID = Identifier<AuthMethod>

/// A method that an ACP agent gives at `initialize` to authenticate the
/// user (plan.md §12).
///
/// The cases follow the ACP v2 `AuthMethod`. The JSON form is the ACP wire
/// form: the `type` key selects the case. `AgentAuthView` shows each method.
public nonisolated enum AuthMethod: Sendable, Hashable {
  /// The agent authenticates the user itself, through `auth/login`.
  case agent(Agent)

  /// The client runs the agent program again as a separate interactive
  /// process. The client does not send this method to `auth/login`.
  case terminal(Terminal)

  /// A method type that the kit does not know, with its `type` string.
  ///
  /// A view does not offer this method.
  case unknown(String)

  /// A method that the agent runs through `auth/login`.
  ///
  /// The fields follow the ACP v2 `AuthMethodAgent`.
  public struct Agent: Sendable, Hashable, Identifiable {
    /// The identifier of the method.
    public var id: AuthMethodID

    /// The label of the method.
    public var name: String

    /// The text that tells the user about the method, or `nil`.
    public var description: String?

    /// Makes an agent method.
    ///
    /// - Parameters:
    ///   - id: The identifier of the method.
    ///   - name: The label of the method.
    ///   - description: The text that tells the user about the method.
    public init(id: AuthMethodID, name: String, description: String? = nil) {
      self.id = id
      self.name = name
      self.description = description
    }
  }

  /// A method that the client runs as a separate interactive process.
  ///
  /// The fields follow the ACP v2 `AuthMethodTerminal`.
  /// `AgentThreadActions.runTerminalAuth(_:)` takes this type. A zero exit
  /// status of the process tells that the authentication is a success.
  public struct Terminal: Sendable, Hashable, Identifiable {
    /// The identifier of the method.
    public var id: AuthMethodID

    /// The label of the method.
    public var name: String

    /// The text that tells the user about the method, or `nil`.
    public var description: String?

    /// The arguments to add after the configured agent command, in order.
    public var args: [String]

    /// The environment variables to set on the process, by name.
    ///
    /// These values replace the variables of the same name in the launch
    /// configuration of the agent.
    public var env: [String: String]

    /// Makes a terminal method.
    ///
    /// - Parameters:
    ///   - id: The identifier of the method.
    ///   - name: The label of the method.
    ///   - description: The text that tells the user about the method.
    ///   - args: The arguments to add after the agent command, in order.
    ///   - env: The environment variables to set on the process, by name.
    public init(
      id: AuthMethodID,
      name: String,
      description: String? = nil,
      args: [String] = [],
      env: [String: String] = [:]
    ) {
      self.id = id
      self.name = name
      self.description = description
      self.args = args
      self.env = env
    }
  }
}

// MARK: - Codable

nonisolated extension AuthMethod: Codable {
  /// The JSON key that selects the case.
  private enum CodingKeys: String, CodingKey {
    case type
  }

  /// The `type` strings of the known cases.
  private enum MethodType {
    static let agent = "agent"
    static let terminal = "terminal"
  }

  /// Decodes a method from its ACP wire form.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` when `type` is missing, or when a known method
  ///   has no `methodId` or no `name`. A `type` that the kit does not know
  ///   decodes to ``unknown(_:)``.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case MethodType.agent: self = .agent(try Agent(from: decoder))
    case MethodType.terminal: self = .terminal(try Terminal(from: decoder))
    default: self = .unknown(type)
    }
  }

  /// Encodes the method in its ACP wire form.
  ///
  /// For ``unknown(_:)``, the encoder writes only the `type`.
  ///
  /// - Parameter encoder: The encoder to write to.
  /// - Throws: The error of the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .agent(let agent):
      try container.encode(MethodType.agent, forKey: .type)
      try agent.encode(to: encoder)
    case .terminal(let terminal):
      try container.encode(MethodType.terminal, forKey: .type)
      try terminal.encode(to: encoder)
    case .unknown(let type):
      try container.encode(type, forKey: .type)
    }
  }
}

/// The JSON keys of the fields that each known method has.
private enum AuthMethodKeys: String, CodingKey {
  case id = "methodId"
  case name
  case description
  case args
  case env
}

nonisolated extension AuthMethod.Agent: Codable {
  /// Decodes an agent method from its ACP wire form.
  ///
  /// A `description` that is not a string decodes to `nil`, as the ACP
  /// schema tells.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` when `methodId` or `name` is missing.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: AuthMethodKeys.self)
    self.init(
      id: try container.decode(AuthMethodID.self, forKey: .id),
      name: try container.decode(String.self, forKey: .name),
      description: container.lenientDescription()
    )
  }

  /// Encodes the fields of the agent method, but not its `type`.
  ///
  /// - Parameter encoder: The encoder to write to.
  /// - Throws: The error of the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: AuthMethodKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(description, forKey: .description)
  }
}

nonisolated extension AuthMethod.Terminal: Codable {
  /// Decodes a terminal method from its ACP wire form.
  ///
  /// As the ACP schema tells, a `description`, `args`, or `env` that has the
  /// wrong type decodes to its default, and an item of `args` or `env` that
  /// has the wrong shape is skipped. The wire form of `env` is a list of
  /// `name` and `value` objects. When a name occurs two times, the last
  /// value is kept.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` when `methodId` or `name` is missing.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: AuthMethodKeys.self)
    let args = container.lenientItems(forKey: .args).compactMap(\.stringValue)
    let variables = container.lenientItems(forKey: .env).compactMap(EnvironmentVariable.init(json:))
    self.init(
      id: try container.decode(AuthMethodID.self, forKey: .id),
      name: try container.decode(String.self, forKey: .name),
      description: container.lenientDescription(),
      args: args,
      env: Dictionary(variables.map { ($0.name, $0.value) }) { _, last in last }
    )
  }

  /// Encodes the fields of the terminal method, but not its `type`.
  ///
  /// The encoder writes `env` as a list of `name` and `value` objects, in
  /// name order, so that the output is stable.
  ///
  /// - Parameter encoder: The encoder to write to.
  /// - Throws: The error of the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: AuthMethodKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encode(args, forKey: .args)
    let variables = env.sorted { $0.key < $1.key }.map { EnvironmentVariable(name: $0.key, value: $0.value) }
    try container.encode(variables, forKey: .env)
  }

  /// One item of the ACP v2 `env` list.
  private struct EnvironmentVariable: Codable {
    /// The name of the variable.
    let name: String

    /// The value of the variable.
    let value: String

    /// Makes a variable from its name and value.
    ///
    /// - Parameters:
    ///   - name: The name of the variable.
    ///   - value: The value of the variable.
    init(name: String, value: String) {
      self.name = name
      self.value = value
    }

    /// Reads a variable from one item of the `env` list.
    ///
    /// - Parameter json: The item.
    /// - Returns: `nil` when the item has no string `name` or no string
    ///   `value`.
    init?(json: JSONValue) {
      guard let name = json["name"]?.stringValue, let value = json["value"]?.stringValue else {
        return nil
      }
      self.init(name: name, value: value)
    }
  }
}

nonisolated extension KeyedDecodingContainer where Key == AuthMethodKeys {
  /// Reads the `description`, or `nil` when it is missing or is not a string.
  ///
  /// - Returns: The description, or `nil`.
  fileprivate func lenientDescription() -> String? {
    (try? decodeIfPresent(String.self, forKey: .description)) ?? nil
  }

  /// Reads a list, or an empty list when it is missing or is not a list.
  ///
  /// - Parameter key: The key of the list.
  /// - Returns: The items of the list, in order.
  fileprivate func lenientItems(forKey key: Key) -> [JSONValue] {
    ((try? decodeIfPresent([JSONValue].self, forKey: key)) ?? nil) ?? []
  }
}
