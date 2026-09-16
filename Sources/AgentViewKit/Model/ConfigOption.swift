/// The identifier of a ``ConfigOption`` (plan.md §3.4).
///
/// For ACP, this is the `configId`. `AgentThreadActions.setConfigOption`
/// takes this type.
public nonisolated struct ConfigOptionID: Sendable, Hashable, RawRepresentable, Codable {
  /// The identifier string.
  public let rawValue: String

  /// Makes an identifier from its string.
  ///
  /// - Parameter rawValue: The identifier string.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// Makes an identifier from its string.
  ///
  /// - Parameter rawValue: The identifier string.
  public init(_ rawValue: String) {
    self.init(rawValue: rawValue)
  }
}

/// A setting of the session that the user can change (plan.md §3.2, §3.4).
///
/// The fields follow the ACP v2 `SessionConfigOption`. The JSON form is the
/// ACP wire form: `configId`, `name`, `description`, `category`, `type`,
/// `currentValue`, and `options`. An option with a `type` that the kit does
/// not know decodes to ``Kind/unknown(type:raw:)`` and keeps its payload.
public nonisolated struct ConfigOption: Sendable, Hashable, Identifiable {
  /// The identifier of the option.
  public var id: ConfigOptionID

  /// The label of the option.
  public var name: String

  /// The text that tells the user what the option does, or `nil`.
  public var description: String?

  /// The group of the option in the user interface, or `nil` when the
  /// source gave no category.
  public var category: Category?

  /// The type of the option and its current value.
  public var kind: Kind

  /// Makes a config option.
  ///
  /// - Parameters:
  ///   - id: The identifier of the option.
  ///   - name: The label of the option.
  ///   - description: The text that tells the user what the option does.
  ///   - category: The group of the option in the user interface.
  ///   - kind: The type of the option and its current value.
  public init(
    id: ConfigOptionID,
    name: String,
    description: String? = nil,
    category: Category? = nil,
    kind: Kind
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.category = category
    self.kind = kind
  }

  /// The group of a config option in the user interface.
  ///
  /// The wire values are the ACP v2 `SessionConfigOptionCategory` strings.
  public enum Category: WireValueEnum, Codable {
    /// The option selects the session mode, such as the permission mode.
    case mode

    /// The option selects the model.
    case model

    /// The option sets a parameter of the model.
    case modelConfig

    /// The option selects the level of thought or reasoning.
    case thoughtLevel

    /// A category that the kit does not know, with its wire string.
    case unknown(String)

    /// Each case of the enum, but not ``unknown(_:)``.
    public static let knownCases: [Category] = [.mode, .model, .modelConfig, .thoughtLevel]

    /// The ACP wire string of the case.
    public var wireValue: String {
      switch self {
      case .mode: "mode"
      case .model: "model"
      case .modelConfig: "model_config"
      case .thoughtLevel: "thought_level"
      case .unknown(let wireValue): wireValue
      }
    }
  }

  /// The type of a config option and its current value.
  public enum Kind: Sendable, Hashable {
    /// The user selects one value from a list.
    ///
    /// - Parameters:
    ///   - current: The ``SelectOption/id`` of the selected value.
    ///   - choices: The values that the user can select.
    case select(current: String, choices: SelectChoices)

    /// The user sets the option on or off.
    ///
    /// - Parameter current: The current value.
    case boolean(current: Bool)

    /// An option type that the kit does not know.
    ///
    /// - Parameters:
    ///   - type: The `type` string that the source gave.
    ///   - raw: The full option object as the source gave it.
    case unknown(type: String, raw: JSONValue)
  }
}

/// The values that the user can select for a select ``ConfigOption``.
///
/// The ACP v2 `SessionConfigSelectOptions` is a flat list or a list of
/// groups.
public nonisolated enum SelectChoices: Sendable, Hashable {
  /// A list of values with no groups.
  case flat([SelectOption])

  /// A list of values in groups, each with a header.
  case grouped([SelectGroup])
}

/// One value that the user can select (plan.md §3.4).
///
/// The fields follow the ACP v2 `SessionConfigSelectOption`. The JSON key of
/// ``id`` is `value`.
public nonisolated struct SelectOption: Sendable, Hashable, Identifiable {
  /// The identifier of the value. This is the string that
  /// ``ConfigValue/id(_:)`` sends.
  public var id: String

  /// The label of the value.
  public var name: String

  /// The text that tells the user about the value, or `nil`.
  public var description: String?

  /// Makes a select option.
  ///
  /// - Parameters:
  ///   - id: The identifier of the value.
  ///   - name: The label of the value.
  ///   - description: The text that tells the user about the value.
  public init(id: String, name: String, description: String? = nil) {
    self.id = id
    self.name = name
    self.description = description
  }
}

/// A group of values with a header (plan.md §3.4).
///
/// The fields follow the ACP v2 `SessionConfigSelectGroup`. The JSON key of
/// ``id`` is `groupId`.
public nonisolated struct SelectGroup: Sendable, Hashable, Identifiable {
  /// The identifier of the group.
  public var id: String

  /// The header of the group.
  public var name: String

  /// The values in the group, in order.
  public var options: [SelectOption]

  /// Makes a select group.
  ///
  /// - Parameters:
  ///   - id: The identifier of the group.
  ///   - name: The header of the group.
  ///   - options: The values in the group, in order.
  public init(id: String, name: String, options: [SelectOption]) {
    self.id = id
    self.name = name
    self.options = options
  }
}

/// A new value for a ``ConfigOption`` (plan.md §3.4).
///
/// `AgentThreadActions.setConfigOption` takes this type. The cases follow
/// the value types of the ACP v2 `session/set_config_option` request.
public nonisolated enum ConfigValue: Sendable, Hashable {
  /// The ``SelectOption/id`` of a value of a select option.
  case id(String)

  /// The new value of a boolean option.
  case boolean(Bool)
}

// MARK: - Codable

nonisolated extension SelectOption: Codable {
  private enum CodingKeys: String, CodingKey {
    case id = "value"
    case name
    case description
  }

  /// Decodes a select option from its ACP wire form.
  ///
  /// A `description` that is not a string decodes to `nil`, as the ACP
  /// schema tells.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` when `value` or `name` is missing.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try container.decode(String.self, forKey: .id),
      name: try container.decode(String.self, forKey: .name),
      description: (try? container.decodeIfPresent(String.self, forKey: .description)) ?? nil
    )
  }
}

nonisolated extension SelectGroup: Codable {
  private enum CodingKeys: String, CodingKey {
    case id = "groupId"
    case name
    case options
  }
}

nonisolated extension ConfigOption: Codable {
  /// The JSON keys that the struct reads and writes.
  private enum CodingKeys: String, CodingKey {
    case id = "configId"
    case name
    case description
    case category
    case type
    case currentValue
    case options
  }

  /// The `type` strings of the known kinds.
  private enum KindType {
    static let select = "select"
    static let boolean = "boolean"
  }

  /// The JSON key that only a ``SelectGroup`` has.
  private static let groupKey = "groupId"

  /// Decodes a config option from its ACP wire form.
  ///
  /// A `description` or a `category` that has the wrong type decodes to
  /// `nil`, as the ACP schema tells. A list of choices is grouped when its
  /// first item has a `groupId`. An empty list is flat.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` when a required key is missing or has the
  ///   wrong type.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    let kind: Kind
    switch type {
    case KindType.select:
      kind = .select(
        current: try container.decode(String.self, forKey: .currentValue),
        choices: try Self.decodeChoices(from: container)
      )
    case KindType.boolean:
      kind = .boolean(current: try container.decode(Bool.self, forKey: .currentValue))
    default:
      kind = .unknown(type: type, raw: try JSONValue(from: decoder))
    }
    self.init(
      id: try container.decode(ConfigOptionID.self, forKey: .id),
      name: try container.decode(String.self, forKey: .name),
      description: (try? container.decodeIfPresent(String.self, forKey: .description)) ?? nil,
      category: (try? container.decodeIfPresent(Category.self, forKey: .category)) ?? nil,
      kind: kind
    )
  }

  /// Encodes the config option in its ACP wire form.
  ///
  /// For ``Kind/unknown(type:raw:)``, the encoder writes each key of `raw`
  /// first. Then it writes the fields of the struct, so that a change to a
  /// field replaces the value in `raw`.
  ///
  /// - Parameter encoder: The encoder to write to.
  /// - Throws: The error of the encoder.
  public func encode(to encoder: any Encoder) throws {
    switch kind {
    case .select(let current, let choices):
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(KindType.select, forKey: .type)
      try container.encode(current, forKey: .currentValue)
      switch choices {
      case .flat(let options): try container.encode(options, forKey: .options)
      case .grouped(let groups): try container.encode(groups, forKey: .options)
      }
    case .boolean(let current):
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(KindType.boolean, forKey: .type)
      try container.encode(current, forKey: .currentValue)
    case .unknown(let type, let raw):
      var container = encoder.container(keyedBy: RawKey.self)
      if case .object(let fields) = raw {
        for (key, value) in fields {
          try container.encode(value, forKey: RawKey(key))
        }
      }
      try container.encode(type, forKey: RawKey(CodingKeys.type.stringValue))
    }
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(category, forKey: .category)
  }

  /// Decodes the `options` list of a select option.
  ///
  /// - Parameter container: The container of the option object.
  /// - Returns: The grouped choices when the first item has a `groupId`,
  ///   otherwise the flat choices.
  /// - Throws: `DecodingError` when the list does not match its shape.
  private static func decodeChoices(
    from container: KeyedDecodingContainer<CodingKeys>
  ) throws -> SelectChoices {
    let items = try container.decode([JSONValue].self, forKey: .options)
    if items.first?[groupKey] != nil {
      return .grouped(try container.decode([SelectGroup].self, forKey: .options))
    }
    return .flat(try container.decode([SelectOption].self, forKey: .options))
  }

  /// A JSON key of any name, for the payload of an unknown kind.
  private struct RawKey: CodingKey {
    let stringValue: String

    var intValue: Int? { nil }

    init(_ stringValue: String) {
      self.stringValue = stringValue
    }

    init?(stringValue: String) {
      self.init(stringValue)
    }

    init?(intValue: Int) {
      nil
    }
  }
}
