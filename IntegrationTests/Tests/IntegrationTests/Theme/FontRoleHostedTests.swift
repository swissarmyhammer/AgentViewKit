@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorExtensions
import EditorSwiftUI
import EditorTestSupport
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

  // MARK: - ui face family

  /// The name of the agent of the family test: long enough that the widths
  /// of two families differ by many points.
  static let familyProbeName = "The quick brown fox jumps over the lazy dog"

  /// The largest difference between the drawn width of a text and the width
  /// that a font gives it, in points: the frame of a text is rounded to the
  /// pixel grid.
  static let familyWidthTolerance: CGFloat = 1

  @Test func theHeadlineOfTheAgentNameDrawsInTheFamilyOfTheUIFace() throws {
    let row = AgentBreadcrumb(agent: Self.familyProbeName, version: Self.text, sessionTitle: nil)
    let familyFont = try #require(
      NSFont(name: UIFamilyTheme.family, size: NSFont.preferredFont(forTextStyle: .headline).pointSize))
    let familyWidth = NSAttributedString(string: Self.familyProbeName, attributes: [.font: familyFont]).size().width

    let systemDrawn = try Self.frameWidth(of: row)
    let familyDrawn = try Self.frameWidth(of: row.editorTheme(UIFamilyTheme()))

    #expect(abs(systemDrawn - familyWidth) > Self.familyWidthTolerance)
    #expect(abs(familyDrawn - familyWidth) <= Self.familyWidthTolerance)
  }

  /// Mounts `view` and gives the width of its agent name.
  ///
  /// - Parameter view: The view that holds an ``AgentBreadcrumb``.
  /// - Returns: The width of the agent name, in points.
  /// - Throws: An issue when the view shows no agent name.
  static func frameWidth(of view: some View) throws -> CGFloat {
    let harness = HostedViewHarness(view)
    defer { harness.close() }
    harness.render()
    return try #require(harness.frame(identifier: AgentBreadcrumb.agentIdentifier)).width
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

  @Test func theNumberInputOfAnElicitationNumberFieldDrawsInTheDisplayRole() throws {
    let schema = ElicitationTestFields.field(.number(integer: true, minimum: nil, maximum: nil))
    let field = ElicitationNumberField(
      context: ElicitationFieldContext(schema: schema, value: .constant(.number(3))))
    try FontRoleExpectations.expectEditor(in: field, drawsIn: .display)
  }

  // MARK: - code

  @Test func aCodeBlockDrawsInTheCodeRole() throws {
    try FontRoleExpectations.expectEditor(in: CodeBlockView(code: Self.text, language: "swift"), drawsIn: .code)
  }
}
