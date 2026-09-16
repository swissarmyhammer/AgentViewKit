import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorSwiftUI
import SwiftUI
import Testing

/// Holds the answer of one hosted field.
@Observable
final class AnswerBox {
  /// The current answer.
  var value: JSONValue?

  /// Makes a box.
  ///
  /// - Parameter value: The first answer.
  init(_ value: JSONValue? = nil) {
    self.value = value
  }

  /// A binding to ``value``.
  var binding: Binding<JSONValue?> {
    Binding(get: { self.value }, set: { self.value = $0 })
  }
}

/// Shows one field for a box. The body makes the context again on each
/// change, so that the validation state is current.
struct HostedField: View {
  let schema: ElicitationFieldSchema
  let box: AnswerBox

  var body: some View {
    ElicitationFieldView(context: ElicitationFieldContext(schema: schema, value: box.binding))
  }
}

/// Shows one text field with a model that the test gives. The body makes
/// the context again on each change, as a form does.
struct HostedTextField: View {
  let schema: ElicitationFieldSchema
  let box: AnswerBox
  let model: EditorModel

  var body: some View {
    ElicitationTextField(
      context: ElicitationFieldContext(schema: schema, value: box.binding), model: model)
  }
}

@Suite(.serialized) @MainActor struct ElicitationFieldViewsHostedTests {
  /// The size of a hosted field.
  static let fieldSize = CGSize(width: 480, height: 400)

  /// Makes a field schema.
  static func field(
    _ name: String,
    _ kind: ElicitationFieldSchema.Kind,
    required: Bool = false
  ) -> ElicitationFieldSchema {
    ElicitationFieldSchema(
      name: name, title: name.capitalized, description: nil, required: required, kind: kind,
      defaultValue: nil)
  }

  /// Makes `count` choices with the values `c0`, `c1`, and so on.
  static func choices(_ count: Int) -> [ElicitationFieldSchema.Choice] {
    (0..<count).map { .init(value: "c\($0)", title: "Choice \($0)") }
  }

  /// Mounts one field.
  static func mount(_ schema: ElicitationFieldSchema, box: AnswerBox)
    -> HostedViewHarness<HostedField>
  {
    let harness = HostedViewHarness(HostedField(schema: schema, box: box), size: fieldSize)
    harness.pump()
    return harness
  }

  // MARK: - Text

  @Test func theTextFieldWritesAnEditToTheBinding() {
    let schema = Self.field("name", .text(minLength: nil, maxLength: 40, pattern: nil, format: nil))
    let box = AnswerBox()
    let model = EditorModel("")
    let harness = HostedViewHarness(
      HostedTextField(schema: schema, box: box, model: model), size: Self.fieldSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ElicitationFieldView.controlIdentifier(for: "name")) != nil)
    model.replaceAll("Ada")
    harness.pump()
    #expect(box.value == .string("Ada"))

    model.replaceAll("")
    harness.pump()
    #expect(box.value == nil)
  }

  @Test func theTextFieldShowsAChangeOfTheBinding() {
    let schema = Self.field("name", .text(minLength: nil, maxLength: 40, pattern: nil, format: nil))
    let box = AnswerBox(.string("first"))
    let model = EditorModel("")
    let harness = HostedViewHarness(
      HostedTextField(schema: schema, box: box, model: model), size: Self.fieldSize)
    defer { harness.close() }
    harness.pump()
    #expect(model.text == "first")

    box.value = .string("second")
    harness.pump()
    #expect(model.text == "second")
  }

  @Test func theDefaultTextFieldMountsItsControl() {
    let schema = Self.field("bio", .text(minLength: nil, maxLength: nil, pattern: nil, format: nil))
    let harness = Self.mount(schema, box: AnswerBox())
    defer { harness.close() }

    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "bio")) != nil)
    #expect(harness.element(identifier: ElicitationFieldView.controlIdentifier(for: "bio")) != nil)
  }

  @Test func onlyALongOrUnboundedTextIsMultiLine() {
    func kind(_ maxLength: Int?) -> ElicitationFieldSchema.Kind {
      .text(minLength: nil, maxLength: maxLength, pattern: nil, format: nil)
    }
    #expect(ElicitationTextField.isMultiLine(kind(nil)))
    #expect(ElicitationTextField.isMultiLine(kind(201)))
    #expect(!ElicitationTextField.isMultiLine(kind(200)))
    #expect(!ElicitationTextField.isMultiLine(.boolean))
  }

  // MARK: - Number

  @Test func theStepperShowsTheAnswer() {
    // The harness does not increment a stepper. See
    // `HostedViewHarness.increment(identifier:)`. The slider test covers the
    // write through the shared number binding.
    let schema = Self.field("count", .number(integer: true, minimum: nil, maximum: nil))
    let harness = Self.mount(schema, box: AnswerBox(.number(3)))
    defer { harness.close() }

    let control = harness.element(identifier: ElicitationFieldView.controlIdentifier(for: "count"))
    #expect(control?.role == NSAccessibility.Role.incrementor.rawValue)
    #expect(control?.value == "3")
  }

  @Test func theSliderWritesANumberInItsBounds() throws {
    let schema = Self.field("level", .number(integer: true, minimum: 2, maximum: 10))
    let box = AnswerBox()
    let harness = Self.mount(schema, box: box)
    defer { harness.close() }

    let control = harness.element(identifier: ElicitationFieldView.controlIdentifier(for: "level"))
    #expect(control?.role == NSAccessibility.Role.slider.rawValue)
    try harness.increment(identifier: ElicitationFieldView.controlIdentifier(for: "level"))
    let number = try #require(box.value?.doubleValue)
    #expect(number > 2 && number <= 10)
    #expect(number == number.rounded())
  }

  // MARK: - Toggle

  @Test func theToggleWritesABoolean() throws {
    let box = AnswerBox()
    let harness = Self.mount(Self.field("agree", .boolean), box: box)
    defer { harness.close() }

    try harness.press(identifier: ElicitationFieldView.controlIdentifier(for: "agree"))
    #expect(box.value == .bool(true))
  }

  // MARK: - Date

  @Test func theDateButtonWritesAFullDateAndTheClearButtonRemovesIt() throws {
    let box = AnswerBox()
    let harness = Self.mount(Self.field("day", .date(dateTime: false)), box: box)
    defer { harness.close() }

    try harness.press(identifier: ElicitationFieldView.controlIdentifier(for: "day"))
    let text = try #require(box.value?.stringValue)
    #expect(text.wholeMatch(of: #/\d{4}-\d{2}-\d{2}/#) != nil)
    #expect(harness.element(identifier: ElicitationFieldView.controlIdentifier(for: "day")) != nil)

    try harness.press(identifier: ElicitationDateField.clearIdentifier(for: "day"))
    #expect(box.value == nil)
  }

  @Test func theDateTimeButtonWritesAValidDateTime() throws {
    let schema = Self.field("when", .date(dateTime: true))
    let box = AnswerBox()
    let harness = Self.mount(schema, box: box)
    defer { harness.close() }

    try harness.press(identifier: ElicitationFieldView.controlIdentifier(for: "when"))
    #expect(box.value != nil)
    #expect(ElicitationValidator.validate(box.value, against: schema).isSatisfied)
  }

  // MARK: - Single choice

  @Test func fiveChoicesRenderRadiosThatWriteTheValue() throws {
    let box = AnswerBox()
    let harness = Self.mount(Self.field("color", .singleChoice(Self.choices(5))), box: box)
    defer { harness.close() }

    #expect(
      harness.element(identifier: ElicitationSingleChoiceField.radioGroupIdentifier(for: "color"))
        != nil)
    #expect(
      harness.element(identifier: ElicitationSingleChoiceField.menuIdentifier(for: "color")) == nil)
    try harness.press(identifier: ElicitationFieldView.choiceIdentifier(for: "color", value: "c3"))
    #expect(box.value == .string("c3"))
  }

  @Test func sixChoicesRenderAMenu() {
    let harness = Self.mount(Self.field("color", .singleChoice(Self.choices(6))), box: AnswerBox())
    defer { harness.close() }

    let menu = harness.element(
      identifier: ElicitationSingleChoiceField.menuIdentifier(for: "color"))
    #expect(menu?.role == NSAccessibility.Role.popUpButton.rawValue)
    #expect(
      harness.element(identifier: ElicitationSingleChoiceField.radioGroupIdentifier(for: "color"))
        == nil)
  }

  // MARK: - Multi choice

  @Test func checksWriteTheValuesInChoiceOrder() throws {
    let kind = ElicitationFieldSchema.Kind.multiChoice(
      Self.choices(3), minItems: nil, maxItems: nil)
    let box = AnswerBox()
    let harness = Self.mount(Self.field("tags", kind), box: box)
    defer { harness.close() }

    try harness.press(identifier: ElicitationFieldView.choiceIdentifier(for: "tags", value: "c2"))
    try harness.press(identifier: ElicitationFieldView.choiceIdentifier(for: "tags", value: "c0"))
    #expect(box.value == .array([.string("c0"), .string("c2")]))

    try harness.press(identifier: ElicitationFieldView.choiceIdentifier(for: "tags", value: "c2"))
    #expect(box.value == .array([.string("c0")]))
  }

  @Test func aFurtherCheckIsDisabledAtMaxItems() throws {
    let kind = ElicitationFieldSchema.Kind.multiChoice(Self.choices(3), minItems: nil, maxItems: 2)
    let box = AnswerBox(.array([.string("c0"), .string("c1")]))
    let harness = Self.mount(Self.field("tags", kind), box: box)
    defer { harness.close() }

    let third = ElicitationFieldView.choiceIdentifier(for: "tags", value: "c2")
    let first = ElicitationFieldView.choiceIdentifier(for: "tags", value: "c0")
    #expect(harness.element(identifier: third)?.isEnabled == false)
    #expect(harness.element(identifier: first)?.isEnabled == true)
    _ = try? harness.press(identifier: third)
    #expect(box.value == .array([.string("c0"), .string("c1")]))

    try harness.press(identifier: first)
    #expect(box.value == .array([.string("c1")]))
    #expect(harness.element(identifier: third)?.isEnabled == true)
  }

  // MARK: - Chrome

  @Test func aRequiredEmptyFieldShowsItsError() {
    let harness = Self.mount(Self.field("agree", .boolean, required: true), box: AnswerBox())
    defer { harness.close() }

    let errors = harness.element(identifier: ElicitationFieldView.errorsIdentifier(for: "agree"))
    #expect(errors?.label?.contains("This field is necessary.") == true)
  }

  @Test func aValidFieldShowsNoError() {
    let harness = Self.mount(
      Self.field("agree", .boolean, required: true), box: AnswerBox(.bool(false)))
    defer { harness.close() }

    #expect(harness.element(identifier: ElicitationFieldView.errorsIdentifier(for: "agree")) == nil)
  }

  // MARK: - Overrides

  @Test func anOverrideForOneKindReplacesOnlyThatKind() {
    let toggle = Self.field("agree", .boolean)
    let number = Self.field("count", .number(integer: true, minimum: nil, maximum: nil))
    let toggleBox = AnswerBox()
    let numberBox = AnswerBox()
    let harness = HostedViewHarness(
      VStack {
        HostedField(schema: toggle, box: toggleBox)
        HostedField(schema: number, box: numberBox)
      }
      .elicitationToggleField { context in
        Text("Custom \(context.schema.title)")
          .accessibilityIdentifier("custom-toggle")
      },
      size: Self.fieldSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: "custom-toggle")?.label == "Custom Agree")
    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "agree")) != nil)
    #expect(
      harness.element(identifier: ElicitationFieldView.controlIdentifier(for: "agree")) == nil)
    #expect(
      harness.element(identifier: ElicitationFieldView.controlIdentifier(for: "count")) != nil)
  }

  @Test func eachKindHasItsOwnSlot() {
    let kinds: [ElicitationFieldSchema.Kind] = [
      .text(minLength: nil, maxLength: nil, pattern: nil, format: nil),
      .number(integer: false, minimum: nil, maximum: nil),
      .boolean,
      .date(dateTime: false),
      .singleChoice(Self.choices(1)),
      .multiChoice(Self.choices(1), minItems: nil, maxItems: nil),
    ]
    #expect(Set(kinds.map(ElicitationFieldSlot.init)) == Set(ElicitationFieldSlot.allCases))
  }
}
