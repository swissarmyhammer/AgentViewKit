import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTheme
import SwiftUI
import Testing

/// Tests for ``FontRoleExpectations``.
@Suite(.serialized, .hostedSerially) @MainActor struct FontRoleExpectationsTests {
  /// The accessibility identifier of the text of each view of the tests.
  static let identifier = "font-role-text"

  /// The text of each view of the tests.
  static let text = "Height"

  /// A text in the display font of the EditorKit theme in the environment.
  struct DisplayText: View {
    /// The EditorKit theme in the environment.
    @Environment(\.editorTheme) private var theme

    var body: some View {
      Text(FontRoleExpectationsTests.text)
        .font(theme.displayFont)
        .accessibilityIdentifier(FontRoleExpectationsTests.identifier)
    }
  }

  @Test func aTextInTheRolePasses() throws {
    try FontRoleExpectations.expectText(of: DisplayText(), identifier: Self.identifier, drawsIn: .display)
  }

  @Test func aTextInAnotherRoleFails() throws {
    try withKnownIssue {
      try FontRoleExpectations.expectText(of: DisplayText(), identifier: Self.identifier, drawsIn: .code)
    } matching: { issue in
      issue.error == nil
    }
  }

  @Test func aTextThatIgnoresTheThemeFails() throws {
    let fixed = Text(Self.text).font(.body).accessibilityIdentifier(Self.identifier)

    try withKnownIssue {
      try FontRoleExpectations.expectText(of: fixed, identifier: Self.identifier, drawsIn: .ui)
    } matching: { issue in
      issue.error == nil
    }
  }

  @Test func anEditorInTheRolePasses() throws {
    try FontRoleExpectations.expectEditor(in: EditorView(model: EditorModel(Self.text)), drawsIn: .code)
  }

  @Test func anEditorInAnotherRoleFails() throws {
    try withKnownIssue {
      try FontRoleExpectations.expectEditor(in: EditorView(model: EditorModel(Self.text)), drawsIn: .display)
    } matching: { issue in
      issue.error == nil
    }
  }
}
