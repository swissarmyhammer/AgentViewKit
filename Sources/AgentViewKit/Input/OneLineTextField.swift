import EditorSwiftUI
import SwiftUI

/// A one-line text input of the kit: an EditorKit `SingleLineField` that
/// edits a `String` binding (^8zmkh1a).
///
/// The comment field of ``PermissionView`` and the search field of
/// ``SessionListView`` use this input. The input keeps its own `EditorModel`.
/// It writes each edit of the model to the binding, and it gives a change of
/// the binding to the model.
///
/// The input has the keys of an EditorKit field:
///
/// - Return and Command-Return commit the edit, and the input calls
///   ``onSubmit`` with the text.
/// - Esc commits the edit, and the focus moves out to the enclosing command
///   scope. No key discards the text.
/// - Revert Field (Control-Command-Z) puts back the text that the edit
///   started from.
/// - A paste puts each line of the pasted text on the one line.
///
/// Under the root `.commandScope` of a window, each edit is an entry on the
/// undo stack of the window.
///
/// The input has its own `editor:` command scope, with ``identifier`` as its
/// id. A focus that lands on an enclosing scope, such as the item scope of a
/// request card, focuses that scope and not the input. A focus that lands on
/// the scope of the input focuses the input.
///
/// The text view of the input carries ``identifier`` as its accessibility
/// identifier and ``prompt`` as its accessibility label. While the input is
/// empty, it shows ``prompt`` as its placeholder.
struct OneLineTextField: View {
  /// The reasons of a commit that submits the text: Return and
  /// Command-Return.
  static let submitReasons: Set<EditorCommitReason> = [.submit, .submitNow]

  /// The text of the input.
  @Binding var text: String

  /// The placeholder and the accessibility label of the input.
  let prompt: String

  /// The accessibility identifier of the text view, and the id of the
  /// command scope of the input.
  let identifier: String

  /// The action that gets the text for Return, or `nil` for no action.
  var onSubmit: ((String) -> Void)?

  /// The model of the input.
  @State private var ownModel = OwnModelSlot.makeEditable()

  var body: some View {
    let model = ownModel.model(text: text)
    SingleLineField(model: model, id: identifier)
      .editorSizingMode(.intrinsic)
      .editorPlaceholder(prompt)
      .editorTextAccessibilityIdentifier(identifier)
      .editorTextAccessibilityLabel(prompt)
      .onEditorCommit(didCommit)
      .textInputOutline()
      .onChange(of: text) { _, newText in
        if model.text != newText {
          model.replaceAll(newText)
        }
      }
      .onChange(of: model.text) { _, newText in
        if text != newText {
          text = newText
        }
      }
  }

  /// Calls ``onSubmit`` with the text of a commit that submits it.
  ///
  /// - Parameter commit: One end of an edit of the input.
  private func didCommit(_ commit: EditorCommit) {
    guard Self.submitReasons.contains(commit.reason) else { return }
    onSubmit?(commit.text)
  }
}

/// The outline of a text input of the kit: a space of the extra small
/// spacing of the theme around the input, and a separator stroke with the
/// small corner radius of the theme.
struct TextInputOutline: ViewModifier {
  @Environment(\.agentTheme) private var theme

  func body(content: Content) -> some View {
    content
      .padding(theme.spacing.xs)
      .overlay(
        AgentSurface.shape(radius: theme.radii.s)
          .stroke(.separator)
      )
  }
}

extension View {
  /// Puts the outline of a text input of the kit around this view.
  ///
  /// - Returns: The view in a ``TextInputOutline``.
  func textInputOutline() -> some View {
    modifier(TextInputOutline())
  }
}

#Preview("One-line text field") {
  @Previewable @State var text = ""
  OneLineTextField(text: $text, prompt: "Search", identifier: "preview-search")
    .padding()
}
