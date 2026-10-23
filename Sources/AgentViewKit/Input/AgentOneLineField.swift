import EditorCore
import EditorSwiftUI
import SwiftUI

/// A one-line text input of the kit: the EditorKit one-line field
/// (`SingleLineField`) in the edge of a kit text input.
///
/// The field edits in place (EditorKit `EditSession.swift`). Return and
/// Command-Return commit the edit and call `onSubmit` with the text of the
/// field, and insert no line. Esc commits the edit, keeps the text, and then
/// runs the `nav.drillOut` of the host. A focus loss commits the edit and
/// keeps the text. Esc and a focus loss call no `onSubmit`. Revert Field
/// (`editor.revertField`, ⌃⌘Z) puts back the text that the edit started
/// from: the text when the field got the focus, or at the last commit. A
/// paste puts its lines on one line.
///
/// The field has its own `editor:` command scope, whose id is the
/// accessibility identifier. A focus that lands on a scope around the field
/// stays on that scope, and a focus that lands on the scope of the field
/// goes into the field.
///
/// The text view of the field carries the accessibility identifier, so a
/// test finds one element to type into, and the placeholder as its
/// accessibility label. While the field is empty, EditorKit gives the text
/// view the placeholder as its accessibility hint too.
struct AgentOneLineField: View {
  /// The model of the text of the field.
  let model: EditorModel

  /// The accessibility identifier of the text view, and the id of the
  /// `editor:` scope of the field.
  let identifier: String

  /// The text that the empty field shows, the accessibility label of the
  /// text view of the field, and its accessibility hint while it is empty.
  let placeholder: String

  /// The action that Return and Command-Return call with the text of the
  /// field.
  var onSubmit: (String) -> Void = { _ in }

  var body: some View {
    SingleLineField(model: model, id: identifier)
      .onEditorCommit { commit in didCommit(commit) }
      .editorSizingMode(.intrinsic)
      .editorPlaceholder(placeholder)
      .editorTextAccessibilityIdentifier(identifier)
      .editorTextAccessibilityLabel(placeholder)
      .agentTextInputEdge()
  }

  /// Calls ``onSubmit`` with the text of `commit` when the commit submits
  /// the field (`EditorCommitReason.submitsField`).
  ///
  /// - Parameter commit: One end of an edit of the field.
  private func didCommit(_ commit: EditorCommit) {
    guard commit.reason.submitsField else { return }
    onSubmit(commit.text)
  }
}

extension EditorCommitReason {
  /// Whether this end of an edit submits a one-line field of the kit.
  ///
  /// Return (`.submit`) and Command-Return (`.submitNow`) submit the field.
  /// Esc (`.leave`) and a focus loss (`.focusLoss`) end the edit and keep
  /// the text, and submit nothing: so Esc in a field never answers a
  /// request.
  var submitsField: Bool {
    switch self {
    case .submit, .submitNow: true
    case .leave, .focusLoss: false
    }
  }
}

extension View {
  /// Puts this text input in the edge of a kit text input: a small inset
  /// and the content edge with the small corners of the theme.
  ///
  /// - Returns: The input in its edge.
  func agentTextInputEdge() -> some View {
    modifier(AgentTextInputEdge())
  }
}

/// The edge of a kit text input: the extra-small spacing of the theme as
/// an inset, and ``AgentContentEdge`` with ``AgentTheme/Radii/s``.
struct AgentTextInputEdge: ViewModifier {
  @Environment(\.agentTheme) private var theme

  func body(content: Content) -> some View {
    content
      .padding(theme.spacing.xs)
      .agentContentEdge(radius: theme.radii.s)
  }
}

#Preview("One-line field") {
  AgentOneLineField(model: EditorModel(""), identifier: "preview-field", placeholder: "Search")
    .padding()
}
