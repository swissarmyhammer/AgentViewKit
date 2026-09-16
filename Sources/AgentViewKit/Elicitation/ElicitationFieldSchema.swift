/// One field of an elicitation form (plan.md §13.1).
///
/// ``normalize(from:)`` makes the fields from the `requestedSchema` of a form
/// mode elicitation. The field views and ``ElicitationValidator`` use this
/// type, so they do not read the JSON Schema text.
public nonisolated struct ElicitationFieldSchema: Sendable, Hashable, Identifiable {
  /// The property name in the `requestedSchema`. The answer uses this key.
  public var name: String

  /// The label of the field. When the schema has no title, this is ``name``.
  public var title: String

  /// The help text of the field, or `nil` when the schema has none.
  public var description: String?

  /// Whether the `required` list of the schema contains ``name``.
  public var required: Bool

  /// The control kind and its constraints.
  public var kind: Kind

  /// The answer that the form shows first, or `nil` when there is no default.
  ///
  /// The value always has the JSON type of ``kind``: a string for text, date,
  /// and single-choice fields, a number for number fields, a boolean for
  /// boolean fields, and an array of strings for multi-choice fields.
  public var defaultValue: JSONValue?

  /// The identifier of the field. This is ``name``.
  public var id: String { name }

  /// Makes a field schema.
  ///
  /// - Parameters:
  ///   - name: The property name in the `requestedSchema`.
  ///   - title: The label of the field.
  ///   - description: The help text of the field.
  ///   - required: Whether the answer is necessary.
  ///   - kind: The control kind and its constraints.
  ///   - defaultValue: The answer that the form shows first.
  public init(
    name: String,
    title: String,
    description: String?,
    required: Bool,
    kind: Kind,
    defaultValue: JSONValue?
  ) {
    self.name = name
    self.title = title
    self.description = description
    self.required = required
    self.kind = kind
    self.defaultValue = defaultValue
  }
}

// MARK: - Kind

extension ElicitationFieldSchema {
  /// The control kind of a field and its constraints (plan.md §13.1).
  ///
  /// The set of cases is closed. Each case has one typed override modifier on
  /// `ElicitationView` (plan.md §13.2).
  public nonisolated enum Kind: Sendable, Hashable {
    /// A `string` property that is not a date and has no choices.
    ///
    /// - Parameters:
    ///   - minLength: The minimum number of Unicode scalars.
    ///   - maxLength: The maximum number of Unicode scalars.
    ///   - pattern: A regular expression that must match the full text.
    ///   - format: The format of the text.
    case text(minLength: Int?, maxLength: Int?, pattern: String?, format: TextFormat?)

    /// A `string` property with the `date` or `date-time` format.
    ///
    /// - Parameter dateTime: `true` for `date-time` (RFC 3339), `false` for
    ///   `date` (`YYYY-MM-DD`).
    case date(dateTime: Bool)

    /// A `number` or `integer` property.
    ///
    /// - Parameters:
    ///   - integer: `true` for an `integer` property.
    ///   - minimum: The inclusive lower bound.
    ///   - maximum: The inclusive upper bound.
    case number(integer: Bool, minimum: Double?, maximum: Double?)

    /// A `boolean` property.
    case boolean

    /// A `string` property with `enum` or `oneOf` choices.
    case singleChoice([Choice])

    /// An `array` property with `items.enum` or `items.anyOf` choices.
    ///
    /// - Parameters:
    ///   - choices: The choices.
    ///   - minItems: The minimum number of selected choices.
    ///   - maxItems: The maximum number of selected choices.
    case multiChoice([Choice], minItems: Int?, maxItems: Int?)
  }

  /// The format of a ``Kind/text(minLength:maxLength:pattern:format:)`` field.
  ///
  /// The `date` and `date-time` formats are not in this type. They give a
  /// ``Kind/date(dateTime:)`` field.
  public nonisolated enum TextFormat: Sendable, Hashable {
    /// An email address.
    case email
    /// A URI with a scheme.
    case uri
    /// A format that the kit does not know. The validator does not apply it.
    case unknown(String)

    /// Makes the format for its wire string.
    ///
    /// - Parameter wireValue: The value of the `format` member.
    public init(wireValue: String) {
      switch wireValue {
      case "email": self = .email
      case "uri": self = .uri
      default: self = .unknown(wireValue)
      }
    }

    /// The wire string of the format.
    public var wireValue: String {
      switch self {
      case .email: "email"
      case .uri: "uri"
      case .unknown(let value): value
      }
    }
  }

  /// One choice of a single-choice or multi-choice field (plan.md §13.1).
  ///
  /// Each choice encoding of the schema gives this type. A choice and a
  /// config select value have the same shape, so the two use one type. The
  /// elicitation names ``SelectOption/value`` and ``SelectOption/title`` are
  /// other names for ``SelectOption/id`` and ``SelectOption/name``.
  public typealias Choice = SelectOption
}

extension SelectOption {
  /// Makes a choice of an elicitation field.
  ///
  /// - Parameters:
  ///   - value: The string that the answer contains. This is ``id``.
  ///   - title: The label of the choice. This is ``name``.
  ///   - description: The help text of the choice.
  public nonisolated init(value: String, title: String, description: String? = nil) {
    self.init(id: value, name: title, description: description)
  }

  /// The string that an elicitation answer contains when this choice is
  /// selected. This is ``id``.
  public nonisolated var value: String {
    get { id }
    set { id = newValue }
  }

  /// The label of an elicitation choice. For an untitled choice, this is
  /// ``value``. This is ``name``.
  public nonisolated var title: String {
    get { name }
    set { name = newValue }
  }
}

// MARK: - Normalization

extension ElicitationFieldSchema {
  /// Makes the fields of an elicitation `requestedSchema` (plan.md §13.1).
  ///
  /// The function reads the four choice encodings and gives the same
  /// ``Choice`` list for each:
  ///
  /// - a plain `enum` on a `string` property. Each title is the value.
  /// - a legacy `enum` with `enumNames` from an MCP source. A value that has
  ///   no name uses the value as its title.
  /// - a titled `oneOf` list of `{const, title, description}` options.
  /// - an `array` property with `items.enum` or `items.anyOf`.
  ///
  /// The function does not make a field for a property that has an unknown
  /// or missing `type`, or for an `array` property that has no string
  /// choices. ACP v2 tells a client that it must not show such a property as
  /// a known control.
  ///
  /// The JSON object of `properties` does not keep the order of its keys. So
  /// the fields are in the order of their names.
  ///
  /// A `default` that does not have the JSON type of the field is ignored,
  /// as ACP v2 tells a client to do. In an `array` default, each item that is
  /// not a string is ignored.
  ///
  /// - Parameter requestedSchema: The `requestedSchema` object.
  /// - Returns: The fields, in the order of their names. The list is empty
  ///   when the schema has no `properties` object.
  public static func normalize(from requestedSchema: JSONValue) -> [ElicitationFieldSchema] {
    guard case .object(let properties)? = requestedSchema["properties"] else { return [] }
    let requiredNames = Set(requestedSchema["required"]?.strings ?? [])
    return properties.sorted { $0.key < $1.key }.compactMap { name, property in
      field(named: name, property: property, required: requiredNames.contains(name))
    }
  }

  /// Makes the field for one property schema.
  ///
  /// - Parameters:
  ///   - name: The property name.
  ///   - property: The property schema.
  ///   - required: Whether the `required` list contains the name.
  /// - Returns: The field, or `nil` when the property has no known kind.
  private static func field(
    named name: String,
    property: JSONValue,
    required: Bool
  ) -> ElicitationFieldSchema? {
    guard let type = property["type"]?.stringValue, let kind = kind(type: type, property: property)
    else { return nil }
    return ElicitationFieldSchema(
      name: name,
      title: property["title"]?.stringValue ?? name,
      description: property["description"]?.stringValue,
      required: required,
      kind: kind,
      defaultValue: defaultValue(property["default"], for: kind)
    )
  }

  /// The kind of a property schema.
  ///
  /// - Parameters:
  ///   - type: The value of the `type` member.
  ///   - property: The property schema.
  /// - Returns: The kind, or `nil` when the property has no known kind.
  private static func kind(type: String, property: JSONValue) -> Kind? {
    switch type {
    case "string":
      return stringKind(property)
    case "number", "integer":
      return .number(
        integer: type == "integer",
        minimum: property["minimum"]?.doubleValue,
        maximum: property["maximum"]?.doubleValue
      )
    case "boolean":
      return .boolean
    case "array":
      return arrayKind(property)
    default:
      return nil
    }
  }

  /// The kind of a `string` property schema.
  ///
  /// - Parameter property: The property schema.
  /// - Returns: A single-choice kind when the property has choices, a date
  ///   kind for the `date` and `date-time` formats, and a text kind for each
  ///   other property.
  private static func stringKind(_ property: JSONValue) -> Kind {
    if let choices = titledChoices(property["oneOf"])
      ?? untitledChoices(property["enum"], names: property["enumNames"])
    {
      return .singleChoice(choices)
    }
    let format = property["format"]?.stringValue
    switch format {
    case "date":
      return .date(dateTime: false)
    case "date-time":
      return .date(dateTime: true)
    default:
      return .text(
        minLength: property["minLength"]?.intValue,
        maxLength: property["maxLength"]?.intValue,
        pattern: property["pattern"]?.stringValue,
        format: format.map(TextFormat.init(wireValue:))
      )
    }
  }

  /// The kind of an `array` property schema.
  ///
  /// - Parameter property: The property schema.
  /// - Returns: A multi-choice kind, or `nil` when the items are not string
  ///   choices.
  private static func arrayKind(_ property: JSONValue) -> Kind? {
    guard let items = property["items"] else { return nil }
    if let itemType = items["type"]?.stringValue, itemType != "string" { return nil }
    guard
      let choices = titledChoices(items["anyOf"])
        ?? untitledChoices(items["enum"], names: nil)
    else { return nil }
    return .multiChoice(
      choices,
      minItems: property["minItems"]?.intValue,
      maxItems: property["maxItems"]?.intValue
    )
  }

  /// The choices of a titled option list (`oneOf` or `items.anyOf`).
  ///
  /// - Parameter options: The option list.
  /// - Returns: One choice for each option that has a string `const`, or
  ///   `nil` when there is no such option. An option with no title uses its
  ///   value as the title.
  private static func titledChoices(_ options: JSONValue?) -> [Choice]? {
    guard case .array(let elements)? = options else { return nil }
    let choices = elements.compactMap { option -> Choice? in
      guard let value = option["const"]?.stringValue else { return nil }
      return Choice(
        value: value,
        title: option["title"]?.stringValue ?? value,
        description: option["description"]?.stringValue
      )
    }
    return choices.isEmpty ? nil : choices
  }

  /// The choices of an untitled `enum` list.
  ///
  /// - Parameters:
  ///   - values: The `enum` list.
  ///   - names: The legacy `enumNames` list, or `nil`.
  /// - Returns: One choice for each string value, or `nil` when there is no
  ///   string value. A value that has no name at its position uses the value
  ///   as the title.
  private static func untitledChoices(_ values: JSONValue?, names: JSONValue?) -> [Choice]? {
    guard let strings = values?.strings, !strings.isEmpty else { return nil }
    let titles = names?.strings ?? []
    return strings.enumerated().map { index, value in
      Choice(value: value, title: titles.indices.contains(index) ? titles[index] : value)
    }
  }

  /// The default value of a field, if it has the JSON type of the kind.
  ///
  /// - Parameters:
  ///   - value: The `default` member.
  ///   - kind: The kind of the field.
  /// - Returns: The default value, or `nil` when there is none or when its
  ///   type is wrong.
  private static func defaultValue(_ value: JSONValue?, for kind: Kind) -> JSONValue? {
    guard let value else { return nil }
    switch kind {
    case .text, .date, .singleChoice:
      return value.stringValue == nil ? nil : value
    case .number(let integer, _, _):
      let isValid = integer ? value.intValue != nil : value.doubleValue != nil
      return isValid ? value : nil
    case .boolean:
      return value.boolValue == nil ? nil : value
    case .multiChoice:
      return value.strings.map { .array($0.map(JSONValue.string)) }
    }
  }
}

extension JSONValue {
  /// The string elements of an array, or `nil` when the value is not an
  /// array. Each element that is not a string is ignored.
  fileprivate nonisolated var strings: [String]? {
    guard case .array(let elements) = self else { return nil }
    return elements.compactMap(\.stringValue)
  }
}
