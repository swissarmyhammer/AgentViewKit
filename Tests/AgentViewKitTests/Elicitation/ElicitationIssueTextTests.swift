@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// Tests for the kit text of a validation issue at Submit
/// (`ElicitationView.failureText(for:requestedSchema:)`).
///
/// Each issue is made with `PendingElicitation.ValidationIssue(field:kind:)`.
/// The tests compare the English text of the string catalog of the kit.
@Suite struct ElicitationIssueTextTests {
  typealias Issue = PendingElicitation.ValidationIssue
  typealias Kind = PendingElicitation.ValidationIssue.Kind
  /// The shared field helpers.
  typealias Fields = ElicitationTestFields

  /// The requested schema of the tests. The `name` property has the title
  /// `Name`. The `code` property has no title.
  static let requestedSchema = JSONValue.object([
    "type": .string("object"),
    "properties": .object([
      "name": .object(["type": .string("string"), "title": .string("Name")]),
      "code": .object(["type": .string("string")]),
    ]),
  ])

  /// The text of an issue of the `name` field.
  ///
  /// - Parameter kind: The rule that the answer breaks.
  /// - Returns: The text that Submit shows.
  static func nameText(_ kind: Kind) -> String {
    ElicitationView.failureText(for: Issue(field: "name", kind: kind), requestedSchema: requestedSchema)
  }

  // MARK: - One text for each kind

  /// One kind of issue and the English text that Submit shows for it.
  nonisolated struct KindCase: Sendable, CustomTestStringConvertible {
    /// The rule that the answer breaks.
    let kind: Kind
    /// The English text that Submit shows for an issue of the `name` field.
    let text: String

    var testDescription: String { String(describing: kind) }
  }

  /// One case for each kind, and for each expected value and each format.
  ///
  /// `@Test(arguments:)` reads the list outside the main actor.
  nonisolated static let kindCases: [KindCase] = [
    KindCase(kind: .requiredFieldMissing, text: "This field is necessary."),
    KindCase(kind: .fieldNotInSchema, text: "The form does not have this field."),
    KindCase(kind: .wrongType(expected: .string), text: "The value must be text."),
    KindCase(kind: .wrongType(expected: .number), text: "The value must be a number."),
    KindCase(kind: .wrongType(expected: .wholeNumber), text: "The value must be a whole number."),
    KindCase(kind: .wrongType(expected: .boolean), text: "The value must be true or false."),
    KindCase(kind: .wrongType(expected: .stringList), text: "The value must be a list of choices."),
    KindCase(kind: .tooShort(minLength: 3), text: "The text must have 3 or more characters."),
    KindCase(kind: .tooLong(maxLength: 8), text: "The text must have 8 or fewer characters."),
    KindCase(kind: .patternMismatch(pattern: "^a+$"), text: "The text does not match the necessary pattern."),
    KindCase(kind: .invalidPattern(pattern: "("), text: "The pattern of this field is not correct."),
    KindCase(kind: .invalidFormat(.email), text: "The value must be an email address."),
    KindCase(kind: .invalidFormat(.uri), text: "The value must be a URI."),
    KindCase(kind: .invalidFormat(.date), text: "The value must be a date in the format YYYY-MM-DD."),
    KindCase(kind: .invalidFormat(.dateTime), text: "The value must be a date and time in RFC 3339 format."),
    KindCase(kind: .belowMinimum(3), text: "The value must be 3 or more."),
    KindCase(kind: .aboveMaximum(2.5), text: "The value must be 2.5 or less."),
    KindCase(kind: .valueNotAllowed(allowed: ["red", "blue"]), text: "The value must be one of the choices."),
    KindCase(kind: .itemNotAllowed(value: "z", allowed: ["a", "b"]), text: "Each item must be one of the choices."),
    KindCase(kind: .tooFewItems(minItems: 2), text: "Select 2 or more items."),
    KindCase(kind: .tooManyItems(maxItems: 1), text: "Select 1 or fewer items."),
  ]

  @Test(arguments: kindCases)
  func theTextOfAnIssueNamesTheFieldTitleAndTheRule(_ kindCase: KindCase) {
    #expect(Self.nameText(kindCase.kind) == "The agent cannot accept the answer for “Name”: \(kindCase.text)")
  }

  // MARK: - Field name

  @Test func anIssueWithNoFieldHasNoFieldName() {
    let text = ElicitationView.failureText(
      for: Issue(field: nil, kind: .requiredFieldMissing), requestedSchema: Self.requestedSchema)

    #expect(text == "The agent cannot accept this answer: This field is necessary.")
  }

  @Test func aFieldWithNoTitleShowsItsName() {
    let text = ElicitationView.failureText(
      for: Issue(field: "code", kind: .requiredFieldMissing), requestedSchema: Self.requestedSchema)

    #expect(text == "The agent cannot accept the answer for “code”: This field is necessary.")
  }

  @Test func aFieldThatIsNotInTheSchemaShowsItsName() {
    let text = ElicitationView.failureText(
      for: Issue(field: "extra", kind: .fieldNotInSchema), requestedSchema: Self.requestedSchema)

    #expect(text == "The agent cannot accept the answer for “extra”: The form does not have this field.")
  }

  @Test func theTextIsNotTheEnglishTextOfExtras() {
    let issue = Issue(field: "name", kind: .tooShort(minLength: 3))

    #expect(!Self.nameText(issue.kind).contains(issue.failureText))
  }

  // MARK: - One text for one rule

  /// A kind of issue, and an answer that fails the field check with the same
  /// rule.
  nonisolated struct SharedRuleCase: Sendable, CustomTestStringConvertible {
    /// The rule that the answer breaks at Submit.
    let kind: Kind
    /// The answer, or `nil` for no answer.
    let value: JSONValue?
    /// The kind of the field of the field check.
    let fieldKind: ElicitationFieldSchema.Kind
    /// Whether the field is required.
    var required = false

    var testDescription: String { String(describing: kind) }

    /// The field schema of the field check.
    var field: ElicitationFieldSchema {
      Fields.field(fieldKind, name: "name", title: "Name", required: required)
    }
  }

  /// The values of the choices of the choice fields.
  nonisolated static let choiceValues = ["a", "b"]

  /// One case for each kind that the field check also has.
  ///
  /// `@Test(arguments:)` reads the list outside the main actor.
  nonisolated static let sharedRuleCases: [SharedRuleCase] = [
    SharedRuleCase(kind: .requiredFieldMissing, value: nil, fieldKind: Fields.text(), required: true),
    SharedRuleCase(kind: .wrongType(expected: .string), value: .number(1), fieldKind: Fields.text()),
    SharedRuleCase(
      kind: .wrongType(expected: .number), value: .string("x"),
      fieldKind: .number(integer: false, minimum: nil, maximum: nil)),
    SharedRuleCase(
      kind: .wrongType(expected: .wholeNumber), value: .number(1.5),
      fieldKind: .number(integer: true, minimum: nil, maximum: nil)),
    SharedRuleCase(kind: .wrongType(expected: .boolean), value: .string("x"), fieldKind: .boolean),
    SharedRuleCase(
      kind: .wrongType(expected: .stringList), value: .string("a"),
      fieldKind: Fields.multiChoice(choices: choiceValues)),
    SharedRuleCase(kind: .tooShort(minLength: 3), value: .string("ab"), fieldKind: Fields.text(minLength: 3)),
    SharedRuleCase(kind: .tooLong(maxLength: 2), value: .string("abc"), fieldKind: Fields.text(maxLength: 2)),
    SharedRuleCase(
      kind: .patternMismatch(pattern: "^a+$"), value: .string("b"), fieldKind: Fields.text(pattern: "^a+$")),
    SharedRuleCase(kind: .invalidPattern(pattern: "("), value: .string("b"), fieldKind: Fields.text(pattern: "(")),
    SharedRuleCase(kind: .invalidFormat(.email), value: .string("x"), fieldKind: Fields.text(format: .email)),
    SharedRuleCase(kind: .invalidFormat(.uri), value: .string("x"), fieldKind: Fields.text(format: .uri)),
    SharedRuleCase(kind: .invalidFormat(.date), value: .string("x"), fieldKind: .date(dateTime: false)),
    SharedRuleCase(kind: .invalidFormat(.dateTime), value: .string("x"), fieldKind: .date(dateTime: true)),
    SharedRuleCase(
      kind: .belowMinimum(2.5), value: .number(1), fieldKind: .number(integer: false, minimum: 2.5, maximum: nil)),
    SharedRuleCase(
      kind: .aboveMaximum(3), value: .number(4), fieldKind: .number(integer: false, minimum: nil, maximum: 3)),
    SharedRuleCase(
      kind: .valueNotAllowed(allowed: choiceValues), value: .string("z"),
      fieldKind: .singleChoice(Fields.choices(choiceValues))),
    SharedRuleCase(
      kind: .itemNotAllowed(value: "z", allowed: choiceValues), value: .array([.string("z")]),
      fieldKind: Fields.multiChoice(choices: choiceValues)),
    SharedRuleCase(
      kind: .tooFewItems(minItems: 2), value: .array([.string("a")]),
      fieldKind: Fields.multiChoice(choices: choiceValues, minItems: 2)),
    SharedRuleCase(
      kind: .tooManyItems(maxItems: 1), value: .array([.string("a"), .string("b")]),
      fieldKind: Fields.multiChoice(choices: choiceValues, maxItems: 1)),
  ]

  @Test(arguments: sharedRuleCases)
  func submitAndTheFieldCheckShowOneTextForOneRule(_ ruleCase: SharedRuleCase) throws {
    let fieldErrors = ElicitationValidator.validate(ruleCase.value, against: ruleCase.field).errors
    try #require(fieldErrors.count == 1)
    let fieldText = try #require(fieldErrors.first)

    #expect(Self.nameText(ruleCase.kind) == "The agent cannot accept the answer for “Name”: \(fieldText)")
  }
}
