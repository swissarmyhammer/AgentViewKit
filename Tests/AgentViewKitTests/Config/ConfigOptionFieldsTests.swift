import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// Checks the values that the inspector rows of ``ConfigOptionsView`` read
/// from the config options of a session, with no view.
@Suite struct ConfigOptionFieldsTests {
  /// The id of the model option.
  private static let modelID = SessionConfigId(rawValue: "model")

  /// The id of the web search option.
  private static let webID = SessionConfigId(rawValue: "web")

  /// A model option with its values in two groups, `deep-1` selected.
  private static let groupedModel = SessionConfigOption(
    configId: modelID, name: "Model", category: .model,
    type: .select(
      SessionConfigSelect(
        currentValue: SessionConfigValueId(rawValue: "deep-1"),
        options: .array([
          group(id: "fast", name: "Fast Models", values: [("fast-1", "Fast One")]),
          group(id: "deep", name: "Deep Models", values: [("deep-1", "Deep One")]),
        ]))))

  /// A boolean option, set on.
  private static let web = SessionConfigOption(
    configId: webID, name: "Web Search", type: .boolean(SessionConfigBoolean(currentValue: true)))

  /// The options of the tests.
  private static let options = [groupedModel, web]

  /// Makes the JSON value of one group of select values.
  ///
  /// - Parameters:
  ///   - id: The id of the group.
  ///   - name: The name of the group.
  ///   - values: The id and the name of each value.
  /// - Returns: The JSON object of the group.
  private static func group(id: String, name: String, values: [(String, String)]) -> JSONValue {
    .object([
      "groupId": .string(id), "name": .string(name),
      "options": .array(values.map { .object(["value": .string($0.0), "name": .string($0.1)]) }),
    ])
  }

  @Test func theChoicesOfAGroupedSelectNameTheirGroup() {
    let names = ConfigOptionFields.choices(of: Self.modelID, in: Self.options).map(\.description)

    #expect(names == ["Fast One (Fast Models)", "Deep One (Deep Models)"])
  }

  @Test func theChoiceOfASelectIsItsCurrentValue() {
    let choice = ConfigOptionFields.choice(of: Self.modelID, in: Self.options)

    #expect(choice?.value == SessionConfigValueId(rawValue: "deep-1"))
  }

  @Test func theValueOfABooleanIsItsCurrentValue() {
    #expect(ConfigOptionFields.isOn(Self.webID, in: Self.options) == true)
  }

  @Test func anOptionThatIsGoneHasNoChoice() {
    #expect(ConfigOptionFields.choice(of: Self.modelID, in: [Self.web]) == nil)
  }
}
