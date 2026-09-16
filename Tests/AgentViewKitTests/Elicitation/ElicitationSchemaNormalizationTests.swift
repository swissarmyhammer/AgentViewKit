import AgentViewKit
import Testing

/// Tests for `ElicitationFieldSchema.normalize(from:)` (plan.md §13.1).
///
/// The fixtures use the shapes of `ElicitationSchema` and
/// `ElicitationPropertySchema` in `../FoundationModelsACP/Schema/acp-v2.json`.
/// The legacy `enumNames` fixture uses the MCP shape.
@Suite struct ElicitationSchemaNormalizationTests {
  typealias Choice = ElicitationFieldSchema.Choice

  /// The choices that each choice fixture declares.
  nonisolated private static let expectedChoices: [Choice] = [
    Choice(value: "red", title: "Red"),
    Choice(value: "green", title: "Green"),
  ]

  /// Parses the JSON text of a fixture.
  ///
  /// - Parameter json: The JSON text.
  /// - Returns: The parsed value.
  private func fixture(_ json: String) throws -> JSONValue {
    try JSONValue(json: json)
  }

  /// Normalizes a schema that has one property and returns its field.
  ///
  /// - Parameter property: The JSON text of the property schema.
  /// - Returns: The one field.
  private func onlyField(_ property: String) throws -> ElicitationFieldSchema {
    let schema = try fixture(#"{"type": "object", "properties": {"field": \#(property)}}"#)
    let fields = ElicitationFieldSchema.normalize(from: schema)
    try #require(fields.count == 1)
    return fields[0]
  }

  /// The choices of a single-choice or multi-choice field.
  ///
  /// - Parameter field: The field.
  /// - Returns: The choices, or `nil` when the field has no choices.
  private func choices(of field: ElicitationFieldSchema) -> [Choice]? {
    switch field.kind {
    case .singleChoice(let choices), .multiChoice(let choices, _, _):
      return choices
    default:
      return nil
    }
  }

  // MARK: - Choice encodings

  @Test func aPlainEnumGivesChoicesWithTheValueAsTitle() throws {
    let field = try onlyField(#"{"type": "string", "enum": ["red", "green"]}"#)

    #expect(
      field.kind
        == .singleChoice([
          Choice(value: "red", title: "red"),
          Choice(value: "green", title: "green"),
        ]))
  }

  @Test func theFourChoiceEncodingsGiveTheSameChoices() throws {
    let legacyEnumNames = try onlyField(
      #"{"type": "string", "enum": ["red", "green"], "enumNames": ["Red", "Green"]}"#)
    let titledOneOf = try onlyField(
      #"""
      {"type": "string", "oneOf": [
        {"const": "red", "title": "Red"},
        {"const": "green", "title": "Green"}
      ]}
      """#)
    let titledArray = try onlyField(
      #"""
      {"type": "array", "items": {"anyOf": [
        {"const": "red", "title": "Red"},
        {"const": "green", "title": "Green"}
      ]}}
      """#)
    let untitledArray = try onlyField(
      #"{"type": "array", "items": {"type": "string", "enum": ["Red", "Green"]}}"#)
    let plainEnum = try onlyField(#"{"type": "string", "enum": ["Red", "Green"]}"#)
    let untitledChoices = [
      Choice(value: "Red", title: "Red"),
      Choice(value: "Green", title: "Green"),
    ]

    #expect(choices(of: legacyEnumNames) == Self.expectedChoices)
    #expect(choices(of: titledOneOf) == Self.expectedChoices)
    #expect(choices(of: titledArray) == Self.expectedChoices)
    #expect(choices(of: untitledArray) == untitledChoices)
    #expect(choices(of: plainEnum) == untitledChoices)
  }

  @Test func legacyEnumNamesThatAreTooShortGiveTheValueAsTitle() throws {
    let field = try onlyField(
      #"{"type": "string", "enum": ["red", "green"], "enumNames": ["Red"]}"#)

    #expect(
      field.kind
        == .singleChoice([
          Choice(value: "red", title: "Red"),
          Choice(value: "green", title: "green"),
        ]))
  }

  @Test func aTitledOptionKeepsItsDescription() throws {
    let field = try onlyField(
      #"{"type": "string", "oneOf": [{"const": "a", "title": "A", "description": "The first."}]}"#)

    #expect(
      field.kind == .singleChoice([Choice(value: "a", title: "A", description: "The first.")]))
  }

  @Test func anArrayPropertyGivesAMultiChoiceWithItemBounds() throws {
    let field = try onlyField(
      #"{"type": "array", "minItems": 1, "maxItems": 2, "items": {"type": "string", "enum": ["a", "b", "c"]}}"#
    )

    #expect(
      field.kind
        == .multiChoice(
          [
            Choice(value: "a", title: "a"),
            Choice(value: "b", title: "b"),
            Choice(value: "c", title: "c"),
          ],
          minItems: 1,
          maxItems: 2
        ))
  }

  @Test func aChoiceIsASelectOptionWithElicitationNames() {
    var choice = Choice(value: "a", title: "A", description: "The first.")

    #expect(choice == SelectOption(id: "a", name: "A", description: "The first."))
    #expect(choice.id == "a")

    choice.value = "b"
    choice.title = "B"

    #expect(choice == SelectOption(id: "b", name: "B", description: "The first."))
  }

  // MARK: - Primitive kinds

  @Test func aStringGivesATextFieldWithItsConstraints() throws {
    let field = try onlyField(
      #"{"type": "string", "minLength": 2, "maxLength": 8, "pattern": "[a-z]+", "format": "email"}"#
    )

    #expect(field.kind == .text(minLength: 2, maxLength: 8, pattern: "[a-z]+", format: .email))
  }

  @Test func aStringWithAURIFormatGivesAURITextField() throws {
    let field = try onlyField(#"{"type": "string", "format": "uri"}"#)

    #expect(field.kind == .text(minLength: nil, maxLength: nil, pattern: nil, format: .uri))
  }

  @Test func aStringWithAnUnknownFormatKeepsTheFormat() throws {
    let field = try onlyField(#"{"type": "string", "format": "hostname"}"#)

    #expect(
      field.kind
        == .text(minLength: nil, maxLength: nil, pattern: nil, format: .unknown("hostname")))
  }

  @Test func aStringWithADateTimeFormatGivesADateTimeField() throws {
    let field = try onlyField(#"{"type": "string", "format": "date-time"}"#)

    #expect(field.kind == .date(dateTime: true))
  }

  @Test func aStringWithADateFormatGivesADateField() throws {
    let field = try onlyField(#"{"type": "string", "format": "date"}"#)

    #expect(field.kind == .date(dateTime: false))
  }

  @Test func aNumberGivesANumberFieldWithItsBounds() throws {
    let field = try onlyField(#"{"type": "number", "minimum": 0.5, "maximum": 9.5}"#)

    #expect(field.kind == .number(integer: false, minimum: 0.5, maximum: 9.5))
  }

  @Test func anIntegerGivesAnIntegerNumberField() throws {
    let field = try onlyField(#"{"type": "integer", "minimum": 1}"#)

    #expect(field.kind == .number(integer: true, minimum: 1, maximum: nil))
  }

  @Test func aBooleanGivesABooleanField() throws {
    let field = try onlyField(#"{"type": "boolean"}"#)

    #expect(field.kind == .boolean)
  }

  // MARK: - Defaults

  @Test(arguments: [
    (#"{"type": "string", "default": "text"}"#, JSONValue.string("text")),
    (#"{"type": "string", "format": "date", "default": "2026-09-16"}"#, .string("2026-09-16")),
    (#"{"type": "number", "default": 2.5}"#, .number(2.5)),
    (#"{"type": "integer", "default": 3}"#, .number(3)),
    (#"{"type": "boolean", "default": false}"#, .bool(false)),
    (#"{"type": "string", "enum": ["a", "b"], "default": "b"}"#, .string("b")),
    (
      #"{"type": "array", "items": {"type": "string", "enum": ["a", "b"]}, "default": ["a"]}"#,
      .array([.string("a")])
    ),
  ])
  func aDefaultGivesTheDefaultValue(property: String, expected: JSONValue) throws {
    let field = try onlyField(property)

    #expect(field.defaultValue == expected)
  }

  @Test(arguments: [
    #"{"type": "string"}"#,
    #"{"type": "string", "default": null}"#,
    #"{"type": "string", "default": 3}"#,
    #"{"type": "integer", "default": 2.5}"#,
    #"{"type": "boolean", "default": "true"}"#,
  ])
  func aMissingOrWrongDefaultGivesNoDefaultValue(property: String) throws {
    let field = try onlyField(property)

    #expect(field.defaultValue == nil)
  }

  @Test func anArrayDefaultSkipsItemsThatAreNotStrings() throws {
    let field = try onlyField(
      #"{"type": "array", "items": {"type": "string", "enum": ["a"]}, "default": ["a", 1]}"#)

    #expect(field.defaultValue == .array([.string("a")]))
  }

  // MARK: - Schema-level fields

  @Test func theFieldsHaveTheirNamesTitlesDescriptionsAndRequiredMarks() throws {
    let schema = try fixture(
      #"""
      {
        "type": "object",
        "properties": {
          "name": {"type": "string", "title": "Your name", "description": "The full name."},
          "age": {"type": "integer"}
        },
        "required": ["name"]
      }
      """#)

    let fields = ElicitationFieldSchema.normalize(from: schema)

    #expect(
      fields == [
        ElicitationFieldSchema(
          name: "age",
          title: "age",
          description: nil,
          required: false,
          kind: .number(integer: true, minimum: nil, maximum: nil),
          defaultValue: nil
        ),
        ElicitationFieldSchema(
          name: "name",
          title: "Your name",
          description: "The full name.",
          required: true,
          kind: .text(minLength: nil, maxLength: nil, pattern: nil, format: nil),
          defaultValue: nil
        ),
      ])
  }

  @Test func theFieldsAreInNameOrder() throws {
    let schema = try fixture(
      #"{"properties": {"b": {"type": "boolean"}, "c": {"type": "boolean"}, "a": {"type": "boolean"}}}"#
    )

    #expect(ElicitationFieldSchema.normalize(from: schema).map(\.name) == ["a", "b", "c"])
  }

  @Test(arguments: [
    #"{"type": "object", "properties": {"x": {"type": "_custom"}}}"#,
    #"{"type": "object", "properties": {"x": {"title": "No type"}}}"#,
    #"{"type": "object", "properties": {"x": {"type": "array", "items": {"type": "_custom"}}}}"#,
    #"{"type": "object", "properties": {"x": 3}}"#,
    #"{"type": "object"}"#,
    #"[]"#,
  ])
  func anUnknownPropertyOrSchemaGivesNoFields(json: String) throws {
    #expect(ElicitationFieldSchema.normalize(from: try fixture(json)).isEmpty)
  }
}
