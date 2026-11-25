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
