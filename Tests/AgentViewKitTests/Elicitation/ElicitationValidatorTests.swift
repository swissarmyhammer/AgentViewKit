import AgentViewKit
import FoundationModelsACP
import Testing

/// Tests for `ElicitationValidator` (plan.md §13.1).
@Suite struct ElicitationValidatorTests {
  typealias Choice = ElicitationFieldSchema.Choice
  /// The shared field helpers. A field made with no name has the name
  /// `field`, and a multi-choice kind made with no choices has the choices
  /// `a`, `b`, and `c`.
  typealias Fields = ElicitationTestFields

  /// Validates `value` against `schema` and returns whether it is satisfied.
  private func passes(_ value: JSONValue?, _ schema: ElicitationFieldSchema) -> Bool {
    let state = ElicitationValidator.validate(value, against: schema)
    #expect(state.isSatisfied == state.errors.isEmpty)
    return state.isSatisfied
  }

  // MARK: - Required

  @Test(arguments: [nil, JSONValue.null, .string(""), .array([])])
  func aMissingRequiredFieldFails(value: JSONValue?) {
    let state = ElicitationValidator.validate(value, against: Fields.field(Fields.text(), required: true))

    #expect(!state.isSatisfied)
    #expect(state.errors == ["This field is necessary."])
  }

  @Test(arguments: [nil, JSONValue.null, .string(""), .array([])])
  func anEmptyOptionalFieldPasses(value: JSONValue?) {
    let state = ElicitationValidator.validate(value, against: Fields.field(Fields.text(minLength: 3)))

    #expect(state.isSatisfied)
    #expect(state.errors.isEmpty)
  }

  @Test func aRequiredBooleanThatIsFalsePasses() {
    #expect(passes(.bool(false), Fields.field(.boolean, required: true)))
  }

  @Test func theSatisfiedStateHasNoErrors() {
    #expect(FieldValidationState.satisfied.errors.isEmpty)
    #expect(FieldValidationState.satisfied.isSatisfied)
    #expect(!FieldValidationState(errors: ["x"]).isSatisfied)
  }

  // MARK: - Text

  @Test func aTextFieldRejectsAValueThatIsNotAString() {
    let state = ElicitationValidator.validate(.number(1), against: Fields.field(Fields.text()))

    #expect(state.errors == ["The value must be text."])
  }

  @Test func minLengthIsApplied() {
    let schema = Fields.field(Fields.text(minLength: 3))

    #expect(!passes(.string("ab"), schema))
    #expect(passes(.string("abc"), schema))
    #expect(
      ElicitationValidator.validate(.string("ab"), against: schema).errors
        == ["The text must have 3 or more characters."])
  }

  @Test func maxLengthIsApplied() {
    let schema = Fields.field(Fields.text(maxLength: 3))

    #expect(passes(.string("abc"), schema))
    #expect(!passes(.string("abcd"), schema))
    #expect(
      ElicitationValidator.validate(.string("abcd"), against: schema).errors
        == ["The text must have 3 or fewer characters."])
  }

  @Test func aPrecomposedLetterIsOneCodePoint() {
    // U+00E9 is one Unicode code point.
    #expect(passes(.string("\u{E9}"), Fields.field(Fields.text(maxLength: 1))))
  }

  @Test func aLetterWithACombiningMarkIsTwoCodePoints() {
    // "e" and U+0301 are two Unicode code points and one character.
    let state = ElicitationValidator.validate(
      .string("e\u{301}"), against: Fields.field(Fields.text(maxLength: 1)))

    #expect(state.errors == ["The text must have 1 or fewer characters."])
  }

  @Test func anEmojiIsOneCodePoint() {
    // U+1F44D is one Unicode code point and two UTF-16 code units.
    #expect(passes(.string("👍"), Fields.field(Fields.text(maxLength: 1))))
  }

  @Test func aFlagIsTwoCodePoints() {
    // A flag is two regional indicator code points and one character.
    let flag = JSONValue.string("🇨🇭")

    #expect(passes(flag, Fields.field(Fields.text(minLength: 2))))
    #expect(
      ElicitationValidator.validate(flag, against: Fields.field(Fields.text(maxLength: 1))).errors
        == ["The text must have 1 or fewer characters."])
  }

  @Test func aPatternIsASearchInTheText() {
    let schema = Fields.field(Fields.text(pattern: "[a-z]+"))

    #expect(passes(.string("abc"), schema))
    #expect(passes(.string("abc1"), schema))
    #expect(passes(.string("1abc"), schema))
    #expect(
      ElicitationValidator.validate(.string("123"), against: schema).errors
        == ["The text does not match the necessary pattern."])
  }

  @Test func aPatternMatchesAPartOfTheText() {
    #expect(passes(.string("zip 12345"), Fields.field(Fields.text(pattern: "[0-9]{5}"))))
  }

  @Test func anAnchoredPatternMustMatchTheFullText() {
    let schema = Fields.field(Fields.text(pattern: "^[a-z]+$"))

    #expect(passes(.string("abc"), schema))
    #expect(!passes(.string("abc1"), schema))
  }

  @Test func anArabicIndicDigitIsNotADigit() {
    // ECMA-262 \d is [0-9]. U+0663 is the Arabic-Indic digit three.
    let state = ElicitationValidator.validate(
      .string("\u{663}"), against: Fields.field(Fields.text(pattern: #"^\d$"#)))

    #expect(state.errors == ["The text does not match the necessary pattern."])
  }

  @Test func aPatternThatDoesNotCompileFailsTheField() {
    let state = ElicitationValidator.validate(
      .string("abc"), against: Fields.field(Fields.text(pattern: "[a-")))

    #expect(state.errors == ["The pattern of this field is not correct."])
  }

  @Test(arguments: [
    ("person@example.com", true),
    ("first.last+tag@mail.example.org", true),
    ("person", false),
    ("person@", false),
    ("@example.com", false),
    ("per son@example.com", false),
    ("person@example", false),
  ])
  func emailFormatIsApplied(value: String, isValid: Bool) {
    let schema = Fields.field(Fields.text(format: .email))

    #expect(passes(.string(value), schema) == isValid)
    if !isValid {
      #expect(
        ElicitationValidator.validate(.string(value), against: schema).errors
          == ["The value must be an email address."])
    }
  }

  @Test(arguments: [
    ("https://example.com/path?q=1", true),
    ("mailto:person@example.com", true),
    ("example.com", false),
    ("https://exa mple.com", false),
    ("not a uri", false),
  ])
  func uriFormatIsApplied(value: String, isValid: Bool) {
    let schema = Fields.field(Fields.text(format: .uri))

    #expect(passes(.string(value), schema) == isValid)
    if !isValid {
      #expect(
        ElicitationValidator.validate(.string(value), against: schema).errors
          == ["The value must be a URI."])
    }
  }

  @Test func anUnknownFormatIsIgnored() {
    #expect(passes(.string("anything"), Fields.field(Fields.text(format: .unknown("hostname")))))
  }

  @Test func aTextFieldReportsEachFailedConstraint() {
    let state = ElicitationValidator.validate(
      .string("A"),
      against: Fields.field(Fields.text(minLength: 2, pattern: "[a-z]+", format: .email))
    )

    #expect(
      state.errors == [
        "The text must have 2 or more characters.",
        "The text does not match the necessary pattern.",
        "The value must be an email address.",
      ])
  }

  // MARK: - Date

  @Test(arguments: [
    ("2026-09-16", true),
    ("2024-02-29", true),
    ("2026-02-30", false),
    ("2026-13-01", false),
    ("2026-00-10", false),
    ("2026-09-00", false),
    ("2026-09-31", false),
    ("2026-9-16", false),
    ("16/09/2026", false),
    ("2026-09-16T10:00:00Z", false),
  ])
  func dateFormatIsApplied(value: String, isValid: Bool) {
    let schema = Fields.field(.date(dateTime: false))

    #expect(passes(.string(value), schema) == isValid)
    if !isValid {
      #expect(
        ElicitationValidator.validate(.string(value), against: schema).errors
          == ["The value must be a date in the format YYYY-MM-DD."])
    }
  }

  @Test(arguments: [
    ("2026-09-16T10:00:00Z", true),
    ("2026-09-16T10:00:00.250Z", true),
    ("2026-09-16T10:00:00+02:00", true),
    ("2026-12-31T23:59:60Z", true),
    ("2026-09-16T10:60:00Z", false),
    ("2026-09-16T10:00:61Z", false),
    ("2026-09-16T10:00:00+24:00", false),
    ("2026-09-16T10:00:00-02:60", false),
    ("2026-02-29T10:00:00Z", false),
    ("2026-09-16", false),
    ("2026-09-16T25:00:00Z", false),
    ("2026-09-16T10:00:00", false),
    ("yesterday", false),
  ])
  func dateTimeFormatIsApplied(value: String, isValid: Bool) {
    let schema = Fields.field(.date(dateTime: true))

    #expect(passes(.string(value), schema) == isValid)
    if !isValid {
      #expect(
        ElicitationValidator.validate(.string(value), against: schema).errors
          == ["The value must be a date and time in RFC 3339 format."])
    }
  }

  @Test func aDateFieldRejectsAValueThatIsNotAString() {
    #expect(
      ElicitationValidator.validate(.number(1), against: Fields.field(.date(dateTime: false))).errors
        == ["The value must be text."])
  }

  // MARK: - Number

  @Test func minimumIsApplied() {
    let schema = Fields.field(.number(integer: false, minimum: 1.5, maximum: nil))

    #expect(passes(.number(1.5), schema))
    #expect(!passes(.number(1.4), schema))
    #expect(
      ElicitationValidator.validate(.number(1), against: schema).errors
        == ["The value must be 1.5 or more."])
  }

  @Test func maximumIsApplied() {
    let schema = Fields.field(.number(integer: false, minimum: nil, maximum: 10))

    #expect(passes(.number(10), schema))
    #expect(!passes(.number(10.5), schema))
    #expect(
      ElicitationValidator.validate(.number(11), against: schema).errors
        == ["The value must be 10 or less."])
  }

  @Test func anIntegerFieldRejectsAFraction() {
    let schema = Fields.field(.number(integer: true, minimum: nil, maximum: nil))

    #expect(passes(.number(3), schema))
    #expect(
      ElicitationValidator.validate(.number(3.5), against: schema).errors
        == ["The value must be a whole number."])
  }

  @Test func aNumberFieldRejectsAValueThatIsNotANumber() {
    let schema = Fields.field(.number(integer: false, minimum: nil, maximum: nil))

    #expect(
      ElicitationValidator.validate(.string("3"), against: schema).errors
        == ["The value must be a number."])
    #expect(!passes(.number(.nan), schema))
  }

  // MARK: - Boolean

  @Test func aBooleanFieldRejectsAValueThatIsNotABoolean() {
    #expect(passes(.bool(true), Fields.field(.boolean)))
    #expect(
      ElicitationValidator.validate(.string("true"), against: Fields.field(.boolean)).errors
        == ["The value must be true or false."])
  }

  // MARK: - Single choice

  @Test func aSingleChoiceMustBeOneOfTheChoices() {
    let schema = Fields.field(.singleChoice([Choice(const: "a", title: "A")]))

    #expect(passes(.string("a"), schema))
    #expect(
      ElicitationValidator.validate(.string("A"), against: schema).errors
        == ["The value must be one of the choices."])
    #expect(
      ElicitationValidator.validate(.bool(true), against: schema).errors
        == ["The value must be one of the choices."])
  }

  // MARK: - Multi choice

  @Test func minItemsIsApplied() {
    let schema = Fields.field(Fields.multiChoice(minItems: 2))

    #expect(passes(.array([.string("a"), .string("b")]), schema))
    #expect(
      ElicitationValidator.validate(.array([.string("a")]), against: schema).errors
        == ["Select 2 or more items."])
  }

  @Test func maxItemsIsApplied() {
    let schema = Fields.field(Fields.multiChoice(maxItems: 1))

    #expect(passes(.array([.string("a")]), schema))
    #expect(
      ElicitationValidator.validate(.array([.string("a"), .string("b")]), against: schema).errors
        == ["Select 1 or fewer items."])
  }

  @Test func eachItemMustBeOneOfTheChoices() {
    let schema = Fields.field(Fields.multiChoice())

    #expect(
      ElicitationValidator.validate(.array([.string("a"), .string("z")]), against: schema).errors
        == ["Each item must be one of the choices."])
    #expect(
      ElicitationValidator.validate(.array([.number(1)]), against: schema).errors
        == ["Each item must be one of the choices."])
  }

  @Test func aMultiChoiceRejectsAValueThatIsNotAList() {
    #expect(
      ElicitationValidator.validate(.string("a"), against: Fields.field(Fields.multiChoice())).errors
        == ["The value must be a list of choices."])
  }

  // MARK: - Completeness

  @Test func aFormIsCompleteWhenEachFieldIsSatisfied() {
    let name = Fields.field(Fields.text(minLength: 1), name: "name", title: "Name", required: true)
    let age = Fields.field(.number(integer: true, minimum: 0, maximum: nil), name: "age", title: "Age")
    let schemas = [name, age]

    #expect(ElicitationValidator.isComplete(values: ["name": .string("Ada")], schemas: schemas))
    #expect(
      ElicitationValidator.isComplete(
        values: ["name": .string("Ada"), "age": .number(36)], schemas: schemas))
    #expect(!ElicitationValidator.isComplete(values: [:], schemas: schemas))
    #expect(
      !ElicitationValidator.isComplete(
        values: ["name": .string("Ada"), "age": .number(-1)], schemas: schemas))
    #expect(ElicitationValidator.isComplete(values: [:], schemas: []))
  }

  // MARK: - Answered

  @Test func onlyAValidAnswerThatIsNotEmptyIsAnswered() {
    let age = Fields.field(.number(integer: true, minimum: 1, maximum: 9))

    #expect(!ElicitationValidator.hasValidAnswer(value: nil, against: age))
    #expect(!ElicitationValidator.hasValidAnswer(value: .null, against: age))
    #expect(!ElicitationValidator.hasValidAnswer(value: .number(12), against: age))
    #expect(ElicitationValidator.hasValidAnswer(value: .number(3), against: age))
  }

  @Test func anEmptyListIsNotAnsweredAndFalseIsAnswered() {
    let tags = Fields.field(Fields.multiChoice())

    #expect(!ElicitationValidator.hasValidAnswer(value: .array([]), against: tags))
    #expect(ElicitationValidator.hasValidAnswer(value: .array([.string("a")]), against: tags))
    #expect(ElicitationValidator.hasValidAnswer(value: .bool(false), against: Fields.field(.boolean)))
  }
}
