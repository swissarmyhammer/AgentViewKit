@testable import AgentViewKit
import FoundationModelsACP
import Testing

/// Tests for `ElicitationView.answerContent(values:)`.
///
/// The agent validates each key of the content against its property. An
/// empty value of an optional field fails a constraint such as `minLength`,
/// and JSON `null` does not decode, so the content must not contain them.
@Suite struct ElicitationAnswerContentTests {
  @Test(arguments: [JSONValue.null, .string(""), .array([])])
  func anEmptyValueIsRemoved(value: JSONValue) {
    let content = ElicitationView.answerContent(values: ["note": value, "color": .string("red")])

    #expect(content == ["color": .string("red")])
  }

  @Test func aValueThatIsNotEmptyStays() {
    // `false` and `0` are answers, not empty values.
    let values: [String: JSONValue] = [
      "agree": .bool(false),
      "count": .number(0),
      "name": .string("Ada"),
      "tags": .array([.string("a")]),
    ]

    #expect(ElicitationView.answerContent(values: values) == values)
  }

  @Test func noValuesGiveNoContent() {
    #expect(ElicitationView.answerContent(values: [:]).isEmpty)
  }
}
