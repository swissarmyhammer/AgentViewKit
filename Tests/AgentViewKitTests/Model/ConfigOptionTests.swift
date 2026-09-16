import AgentViewKit
import Foundation
import Testing

@Suite struct ConfigOptionTests {
  /// Each known ACP config option category and the case that it gives.
  nonisolated private static let knownCategories:
    [(wireValue: String, category: ConfigOption.Category)] = [
      ("mode", .mode),
      ("model", .model),
      ("model_config", .modelConfig),
      ("thought_level", .thoughtLevel),
    ]

  /// A select option with a flat choice list, in the ACP v2
  /// `SessionConfigOption` shape.
  nonisolated private static let flatSelectFixture = """
    {
      "configId": "mode",
      "name": "Mode",
      "description": "How the agent asks for permission.",
      "category": "mode",
      "type": "select",
      "currentValue": "ask",
      "options": [
        {"value": "ask", "name": "Ask", "description": "Ask before each edit."},
        {"value": "auto", "name": "Auto"}
      ]
    }
    """

  /// A select option with a grouped choice list, in the ACP v2
  /// `SessionConfigOption` shape.
  nonisolated private static let groupedSelectFixture = """
    {
      "configId": "model",
      "name": "Model",
      "category": "model",
      "type": "select",
      "currentValue": "sonnet",
      "options": [
        {
          "groupId": "fast",
          "name": "Fast",
          "options": [
            {"value": "haiku", "name": "Haiku"},
            {"value": "sonnet", "name": "Sonnet"}
          ]
        },
        {
          "groupId": "deep",
          "name": "Deep",
          "options": [
            {"value": "opus", "name": "Opus", "description": "The largest model."}
          ]
        }
      ]
    }
    """

  /// A boolean option, in the ACP v2 `SessionConfigOption` shape.
  nonisolated private static let booleanFixture = """
    {
      "configId": "web",
      "name": "Web search",
      "category": "_custom",
      "type": "boolean",
      "currentValue": true
    }
    """

  /// An option with a type that the kit does not know.
  nonisolated private static let unknownTypeFixture = """
    {
      "configId": "temp",
      "name": "Temperature",
      "type": "_slider",
      "currentValue": 0.5
    }
    """

  private func decode(_ json: String) throws -> ConfigOption {
    try JSONDecoder().decode(ConfigOption.self, from: Data(json.utf8))
  }

  // MARK: - Category

  @Test(arguments: knownCategories)
  func aKnownCategoryGivesItsCase(wireValue: String, category: ConfigOption.Category) {
    #expect(ConfigOption.Category(wireValue: wireValue) == category)
    #expect(category.wireValue == wireValue)
  }

  @Test func thoughtLevelGivesThoughtLevel() {
    #expect(ConfigOption.Category(wireValue: "thought_level") == .thoughtLevel)
  }

  @Test func anUnknownCategoryGivesUnknown() {
    let category = ConfigOption.Category(wireValue: "other")

    #expect(category == .unknown("other"))
    #expect(category.wireValue == "other")
  }

  @Test func theKnownCategoriesHaveDistinctWireValues() {
    let wireValues = ConfigOption.Category.knownCases.map(\.wireValue)

    #expect(Set(wireValues).count == wireValues.count)
    #expect(wireValues.count == Self.knownCategories.count)
  }

  // MARK: - Decode

  @Test func aFlatSelectDecodesItsFieldsAndChoices() throws {
    let option = try decode(Self.flatSelectFixture)

    #expect(option.id == ConfigOptionID("mode"))
    #expect(option.name == "Mode")
    #expect(option.description == "How the agent asks for permission.")
    #expect(option.category == .mode)
    #expect(
      option.kind
        == .select(
          current: "ask",
          choices: .flat([
            SelectOption(id: "ask", name: "Ask", description: "Ask before each edit."),
            SelectOption(id: "auto", name: "Auto"),
          ])
        )
    )
  }

  @Test func aGroupedSelectDecodesTwoGroupsInOrder() throws {
    let option = try decode(Self.groupedSelectFixture)

    guard case .select(let current, .grouped(let groups)) = option.kind else {
      Issue.record("The kind is not a grouped select: \(option.kind)")
      return
    }
    #expect(current == "sonnet")
    #expect(option.description == nil)
    #expect(groups.map(\.name) == ["Fast", "Deep"])
    #expect(groups.map(\.id) == ["fast", "deep"])
    #expect(groups[0].options.map(\.id) == ["haiku", "sonnet"])
    #expect(
      groups[1].options == [SelectOption(id: "opus", name: "Opus", description: "The largest model.")]
    )
  }

  @Test func aBooleanDecodesItsValue() throws {
    let option = try decode(Self.booleanFixture)

    #expect(option.kind == .boolean(current: true))
    #expect(option.category == .unknown("_custom"))
  }

  @Test func aMissingCategoryGivesNil() throws {
    let option = try decode(Self.unknownTypeFixture)

    #expect(option.category == nil)
  }

  @Test func anUnknownTypeKeepsTheRawPayload() throws {
    let option = try decode(Self.unknownTypeFixture)

    guard case .unknown(let type, let raw) = option.kind else {
      Issue.record("The kind is not unknown: \(option.kind)")
      return
    }
    #expect(type == "_slider")
    #expect(raw["currentValue"] == .number(0.5))
  }

  @Test func anEmptyChoiceListDecodesAsFlat() throws {
    let json = """
      {"configId": "x", "name": "X", "type": "select", "currentValue": "a", "options": []}
      """

    #expect(try decode(json).kind == .select(current: "a", choices: .flat([])))
  }

  // MARK: - Encode

  @Test(arguments: [flatSelectFixture, groupedSelectFixture, booleanFixture, unknownTypeFixture])
  func anOptionRoundTripsThroughJSON(fixture: String) throws {
    let option = try decode(fixture)
    let data = try JSONEncoder().encode(option)

    #expect(try JSONDecoder().decode(ConfigOption.self, from: data) == option)
  }

  @Test func anOptionEncodesTheACPKeys() throws {
    let option = try decode(Self.groupedSelectFixture)
    let json = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(option))

    #expect(json["configId"] == .string("model"))
    #expect(json["type"] == .string("select"))
    #expect(json["currentValue"] == .string("sonnet"))
    #expect(json["category"] == .string("model"))
    #expect(json["options"]?[0]?["groupId"] == .string("fast"))
    #expect(json["options"]?[0]?["options"]?[0]?["value"] == .string("haiku"))
  }

  @Test func aChangedFieldReplacesTheRawValueOfAnUnknownKind() throws {
    var option = try decode(Self.unknownTypeFixture)
    option.name = "Heat"

    let json = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(option))

    #expect(json["name"] == .string("Heat"))
    #expect(json["type"] == .string("_slider"))
    #expect(json["currentValue"] == .number(0.5))
  }

  // MARK: - Value

  @Test func aValueKeepsItsPayload() {
    #expect(ConfigValue.id("auto") != ConfigValue.boolean(true))
    #expect(ConfigValue.id("auto") == ConfigValue.id("auto"))
  }

  @Test func anIDValueEncodesTheACPWireForm() throws {
    let json = try JSONDecoder().decode(
      JSONValue.self, from: JSONEncoder().encode(ConfigValue.id("auto")))

    #expect(json == .object(["type": .string("id"), "value": .string("auto")]))
  }

  @Test func aBooleanValueEncodesTheACPWireForm() throws {
    let json = try JSONDecoder().decode(
      JSONValue.self, from: JSONEncoder().encode(ConfigValue.boolean(false)))

    #expect(json == .object(["type": .string("boolean"), "value": .bool(false)]))
  }

  @Test(arguments: [ConfigValue.id("auto"), .boolean(true), .boolean(false)])
  func aValueRoundTripsThroughJSON(value: ConfigValue) throws {
    let data = try JSONEncoder().encode(value)

    #expect(try JSONDecoder().decode(ConfigValue.self, from: data) == value)
  }

  @Test func aValueWithAnUnknownTypeDoesNotDecode() {
    let json = #"{"type": "_number", "value": 3}"#

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ConfigValue.self, from: Data(json.utf8))
    }
  }

  @Test func flatChoicesGiveTheirOptionsInOrder() {
    let options = [SelectOption(id: "ask", name: "Ask"), SelectOption(id: "auto", name: "Auto")]

    #expect(SelectChoices.flat(options).options == options)
  }

  @Test func groupedChoicesGiveTheOptionsOfEachGroupInOrder() {
    let ask = SelectOption(id: "ask", name: "Ask")
    let plan = SelectOption(id: "plan", name: "Plan")
    let auto = SelectOption(id: "auto", name: "Auto")
    let choices = SelectChoices.grouped([
      SelectGroup(id: "manual", name: "Manual", options: [ask, plan]),
      SelectGroup(id: "empty", name: "Empty", options: []),
      SelectGroup(id: "review", name: "Review", options: [auto]),
    ])

    #expect(choices.options == [ask, plan, auto])
  }
}
