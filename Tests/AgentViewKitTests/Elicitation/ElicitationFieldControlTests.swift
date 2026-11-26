import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACP
import SwiftUI
import Testing

@testable import AgentViewKit

/// The controls of the default field views of a form: each one is an
/// EditorKit field control, which takes its look from the theme
/// (Docs/decisions/focus-audit.md, "Raw controls").
///
/// Each test lays out the field in a window that is never ordered in
/// (``ControlProbe``), and reads the accessibility element of the control.
@MainActor @Suite struct ElicitationFieldControlTests {
  /// The property name of the field of each test.
  static let name = "field"

  /// The values of the choices of a menu: more than the largest count of a
  /// radio group, so the field shows a menu.
  static let menuChoiceValues = ["c1", "c2", "c3", "c4", "c5", "c6"]

  /// The accessibility identifier of the control of the field.
  static var controlIdentifier: String { ElicitationFieldView.controlIdentifier(for: name) }

  /// A field context of `kind` that reads and writes `box`.
  ///
  /// - Parameters:
  ///   - kind: The kind of the field.
  ///   - box: The answer of the field.
  /// - Returns: The context.
  static func context(_ kind: ElicitationFieldSchema.Kind, box: AnswerBox = AnswerBox()) -> ElicitationFieldContext {
    ElicitationFieldContext(schema: ElicitationTestFields.field(kind, name: name), value: box.binding)
  }

  /// The maximum of the number fields of the stepper tests.
  static let maximum = 9.0

  /// The steps above ``maximum`` of the typed number of
  /// ``aStepDownFromANumberAboveTheMaximumGoesToTheMaximum()``.
  static let stepsAboveTheMaximum = 5.0

  /// A number field with a maximum and no minimum: the field shows a
  /// stepper.
  ///
  /// - Parameter box: The answer of the field.
  /// - Returns: The field.
  static func stepperField(box: AnswerBox = AnswerBox()) -> ElicitationNumberField {
    ElicitationNumberField(context: context(.number(integer: true, minimum: nil, maximum: maximum), box: box))
  }

  /// The identifier of the up button of the EditorKit `StepperField` of the
  /// field.
  static var increaseIdentifier: String { controlIdentifier + ".increase" }

  /// The identifier of the down button of the EditorKit `StepperField` of
  /// the field.
  static var decreaseIdentifier: String { controlIdentifier + ".decrease" }

  /// A production change that fails this test: the number field shows a
  /// system `Stepper` in place of the EditorKit `StepperField`, which has an
  /// up and a down button.
  @Test func theNumberFieldWithNoRangeShowsTheUpButtonOfAStepperField() async {
    let role = await ControlProbe.read(Self.increaseIdentifier, in: Self.stepperField(), accessibilityRole(of:))

    #expect(role == NSAccessibility.Role.button.rawValue)
  }

  /// A production change that fails this test: the stepper of the number
  /// field draws its chevrons in a font that is not the `ui` face of the
  /// theme.
  @Test func theStepperOfTheNumberFieldTakesTheUIFaceOfTheTheme() async throws {
    let frames = try #require(
      await ControlProbe.frames(of: Self.increaseIdentifier, in: Self.stepperField(), enlarging: .ui))

    #expect(frames.themed.width > frames.plain.width)
  }

  /// A production change that fails this test: the stepper clamps a number
  /// above the maximum before it steps (`typedValues: .clamp`), so a step
  /// down goes one below the maximum. With `typedValues: .keep`, a typed
  /// number above the maximum stays, the validator shows its error, and a
  /// step down goes to the maximum.
  @Test func aStepDownFromANumberAboveTheMaximumGoesToTheMaximum() async {
    let box = AnswerBox(.number(Self.maximum + Self.stepsAboveTheMaximum))

    _ = await ControlProbe.read(Self.decreaseIdentifier, in: Self.stepperField(box: box)) {
      try? performAccessibilityPress(on: $0)
    }

    #expect(box.value == .number(Self.maximum))
  }

  /// The bounds of the number field of
  /// ``theSliderOfAFieldWithARangeShowsNoSystemFocusEffect()``.
  static let sliderRange = 0.0...10.0

  /// A production change that fails this test: the slider of a number field
  /// with a range is a system `Slider` in place of the EditorKit
  /// `SliderField`, so AppKit draws the system focus ring of the slider and
  /// not the one focus ring of EditorKit.
  @Test func theSliderOfAFieldWithARangeShowsNoSystemFocusEffect() {
    let field = ElicitationNumberField(
      context: Self.context(
        .number(integer: false, minimum: Self.sliderRange.lowerBound, maximum: Self.sliderRange.upperBound)))

    let hosting = StyleViewHost.host(field, size: ControlProbe.hostSize)

    #expect(SystemFocusEffects.census(under: hosting).isEmpty)
  }

  /// A production change that fails this test: the switch of a boolean
  /// field has no accessibility label, or a label that is not the title of
  /// the field. The hidden label of the switch must not hide its
  /// accessibility label.
  @Test func theSwitchOfABooleanFieldHasTheTitleOfTheFieldAsItsLabel() async {
    let field = ElicitationToggleField(context: Self.context(.boolean))

    let label = await ControlProbe.read(Self.controlIdentifier, in: field, accessibilityLabel(of:))

    #expect(label == ElicitationTestFields.field(.boolean).title)
  }

  /// A production change that fails this test: the check box of a choice of
  /// a multi-choice field draws its title in a font that is not the `ui`
  /// face of the theme.
  @Test func theCheckBoxOfAChoiceTakesTheUIFaceOfTheTheme() async throws {
    let field = ElicitationMultiChoiceField(context: Self.context(ElicitationTestFields.multiChoice()))
    let choice = ElicitationFieldView.choiceIdentifier(
      for: Self.name, value: ElicitationTestFields.defaultChoiceValues[0])

    let frames = try #require(await ControlProbe.frames(of: choice, in: field, enlarging: .ui))

    #expect(frames.themed.width > frames.plain.width)
  }

  /// A production change that fails this test: the radio button of a
  /// choice of a single-choice field is a plain system `Button` in place of
  /// the EditorKit `EditorPlainButton`, so its title does not take the
  /// caption style of the button tokens of the theme.
  @Test func theRadioButtonOfAChoiceTakesTheCaptionStyleOfTheButtonTokens() async throws {
    let field = ElicitationSingleChoiceField(
      context: Self.context(.singleChoice(ElicitationTestFields.choices(ElicitationTestFields.defaultChoiceValues))))
    let choice = ElicitationFieldView.choiceIdentifier(
      for: Self.name, value: ElicitationTestFields.defaultChoiceValues[0])

    let frames = try #require(await ControlProbe.framesWithLargeButtonCaptions(of: choice, in: field))

    #expect(frames.themed.width > frames.plain.width)
  }

  /// A menu field over ``menuChoiceValues`` that reads and writes `box`.
  ///
  /// - Parameter box: The answer of the field.
  /// - Returns: The field.
  static func menuField(box: AnswerBox = AnswerBox()) -> ElicitationSingleChoiceField {
    ElicitationSingleChoiceField(
      context: context(.singleChoice(ElicitationTestFields.choices(menuChoiceValues)), box: box))
  }

  /// The accessibility identifier of the menu of the menu field.
  static var menuIdentifier: String { ElicitationSingleChoiceField.menuIdentifier(for: name) }

  /// A production change that fails this test: the menu of a single-choice
  /// field is a system `Picker` in place of the EditorKit `ChoiceField`,
  /// which names the item of no selection and each choice as an
  /// accessibility action.
  @Test func theMenuNamesTheItemOfNoSelectionAndEachChoiceAsAnAction() async {
    let names = await ControlProbe.read(Self.menuIdentifier, in: Self.menuField(), accessibilityCustomActionNames(of:))

    #expect(names == [ElicitationSingleChoiceField.noSelectionTitle] + Self.menuChoiceValues)
  }

  /// A production change that fails this test: the action of a choice of
  /// the menu does not write the value of the choice.
  @Test func theActionOfAChoiceWritesItsValue() async {
    let box = AnswerBox()
    let choice = Self.menuChoiceValues[1]

    _ = await ControlProbe.read(Self.menuIdentifier, in: Self.menuField(box: box)) {
      performAccessibilityCustomAction(named: choice, on: $0)
    }

    #expect(box.value == .string(choice))
  }

  /// A production change that fails this test: the item of no selection
  /// does not remove the answer, so a person cannot clear an optional
  /// choice.
  @Test func theActionOfNoSelectionRemovesTheAnswer() async {
    let box = AnswerBox(.string(Self.menuChoiceValues[0]))

    _ = await ControlProbe.read(Self.menuIdentifier, in: Self.menuField(box: box)) {
      performAccessibilityCustomAction(named: ElicitationSingleChoiceField.noSelectionTitle, on: $0)
    }

    #expect(box.value == nil)
  }
}
