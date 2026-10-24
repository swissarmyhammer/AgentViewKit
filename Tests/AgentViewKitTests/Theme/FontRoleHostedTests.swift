@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorExtensions
import EditorSwiftUI
import FoundationModelsACP
import SwiftUI
import Testing

/// Checks that each kit view draws its text in the font role of its job
/// (``FontRoleExpectations``): the chrome in the `ui` role, the prose and the
/// text a person types in the `display` role, and the code in the `code` role.
@Suite(.serialized, .hostedSerially) @MainActor struct FontRoleHostedTests {
  /// The text of the editors and the fields of the tests.
  static let text = "Hello"

  /// The title of the empty state of the tests.
  static let emptyStateTitle = "Start here"

  /// The longest answer of a text field that shows one line
  /// (``ElicitationTextField/multiLineThreshold``).
  static let oneLineMaximumLength = ElicitationTextField.multiLineThreshold

  /// An elicitation text field of `kind` that edits ``text``.
  ///
  /// - Parameter kind: The text kind of the field.
  /// - Returns: The field.
  static func elicitationField(_ kind: ElicitationFieldSchema.Kind) -> ElicitationTextField {
    let schema = ElicitationTestFields.field(kind)
    return ElicitationTextField(
      context: ElicitationFieldContext(schema: schema, value: .constant(.string(text))),
      model: EditorModel(text))
  }

  // MARK: - ui

  @Test func theMessageHeaderDrawsInTheUIRole() throws {
    try FontRoleExpectations.expectText(
      of: MessageHeader(role: .assistant), identifier: MessageHeader.roleIdentifier, drawsIn: .ui)
  }

  @Test func theTitleOfTheEmptyStateDrawsInTheUIRole() throws {
    try FontRoleExpectations.expectText(
      of: ConversationEmptyState(title: Self.emptyStateTitle, markdown: Self.text),
      identifier: ConversationLayout.emptyStateTitleIdentifier, drawsIn: .ui)
  }

  @Test func theTitleOfAJSONDisclosureDrawsInTheUIRole() throws {
    let identifier = "font-role-json"
    try FontRoleExpectations.expectText(
      of: JSONDisclosure(id: identifier, title: Self.text, json: "{}", identifier: identifier, isExpanded: false),
      identifier: identifier, drawsIn: .ui)
  }

  @Test func aRowOfTheCompletionListDrawsInTheUIRole() throws {
    let item = Completion(label: Self.text, insert: .text(Self.text), kind: .path)
    try FontRoleExpectations.expectText(
      of: PromptCompletionRow(item: item, isSelected: false),
      identifier: EditorKitPromptEditor.completionRowIdentifier, drawsIn: .ui)
  }

  // MARK: - display

  @Test func theProseOfAResponseDrawsInTheDisplayRole() throws {
    try FontRoleExpectations.expectText(
      of: ResponseView(id: "font-role-response", markdown: Self.text),
      identifier: ResponseView.paragraphIdentifier(index: 0), drawsIn: .display)
  }

  @Test func theComposerDrawsInTheDisplayRole() throws {
    let context = PromptEditorContext(
      text: .constant(AttributedString(Self.text)), placeholder: Self.text, onSubmit: {})
    try FontRoleExpectations.expectEditor(in: EditorKitPromptEditor(context: context), drawsIn: .display)
  }

  @Test func theOneLineFieldDrawsInTheDisplayRole() throws {
    let field = AgentOneLineField(model: EditorModel(Self.text), identifier: "font-role-field", placeholder: Self.text)
    try FontRoleExpectations.expectEditor(in: field, drawsIn: .display)
  }

  @Test func aOneLineElicitationFieldDrawsInTheDisplayRole() throws {
    let field = Self.elicitationField(ElicitationTestFields.text(maxLength: Self.oneLineMaximumLength))
    try FontRoleExpectations.expectEditor(in: field, drawsIn: .display)
  }

  @Test func aMultiLineElicitationFieldDrawsInTheDisplayRole() throws {
    let field = Self.elicitationField(ElicitationTestFields.text())
    try FontRoleExpectations.expectEditor(in: field, drawsIn: .display)
  }

  // MARK: - code

  @Test func aCodeBlockDrawsInTheCodeRole() throws {
    try FontRoleExpectations.expectEditor(in: CodeBlockView(code: Self.text, language: "swift"), drawsIn: .code)
  }
}
