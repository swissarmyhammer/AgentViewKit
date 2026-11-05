import EditorCore
import EditorStyle
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
  let onSubmit: (String) -> Void

  /// Makes a field that edits the text of `model`.
  ///
  /// - Parameters:
  ///   - model: The model of the text of the field.
  ///   - identifier: The accessibility identifier of the text view, and the
  ///     id of the `editor:` scope of the field.
  ///   - placeholder: The text that the empty field shows, and the
  ///     accessibility label of the text view.
  ///   - onSubmit: The action that Return and Command-Return call with the
  ///     text of the field. The default does nothing.
  init(
    model: EditorModel, identifier: String, placeholder: String,
    onSubmit: @escaping (String) -> Void = { _ in }
  ) {
    self.model = model
    self.identifier = identifier
    self.placeholder = placeholder
    self.onSubmit = onSubmit
  }

  /// The field, with the slots of a one-line input of the kit
  /// (``EditorSlotComposing/agentOneLineInput(identifier:placeholder:onSubmit:)``),
  /// in the edge of a kit text input.
  ///
  /// EditorKit holds the commit callback in the mounted view, not in the
  /// model of the field. So `onSubmit` can capture the view that shows the
  /// field, and the state of that view that keeps the model
  /// (``OwnModelSlot``): the model still goes when the field leaves the
  /// window, and its entries leave the window undo stack.
  var body: some View {
    SingleLineField(model: model, id: identifier)
      .agentOneLineInput(identifier: identifier, placeholder: placeholder, onSubmit: onSubmit)
      .agentTextInputEdge()
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

extension EditorCommit {
  /// The text that this end of an edit submits, or `nil` when it submits
  /// nothing (`EditorCommitReason.submitsField`).
  ///
  /// Return and Command-Return submit the text of the commit, also when the
  /// edit changed nothing. Esc and a focus loss submit nothing.
  var submittedText: String? {
    reason.submitsField ? text : nil
  }
}

extension EditorSlotComposing {
  /// This field, with `action` as the action of the commits that submit it:
  /// the one submit-on-commit rule of the one-line fields of the kit
  /// (`EditorCommit.submittedText`).
  ///
  /// Return and Command-Return call `action` with the text of the field.
  /// Esc and a focus loss end the edit, keep the text, and call nothing, so
  /// Esc in a field never answers a request. The mounted view holds the
  /// callback, not the model of the field (`onEditorCommit(_:)`).
  ///
  /// - Parameter action: The action that a submit calls with the text of the
  ///   field.
  /// - Returns: The same field, with its commit callback set.
  func onFieldSubmit(_ action: @escaping (String) -> Void) -> Self {
    onEditorCommit { commit in
      guard let text = commit.submittedText else { return }
      action(text)
    }
  }

  /// This EditorKit one-line field (a `SingleLineField`, a `NumberField` or
  /// a `DateField`) with the slots of a one-line input of the kit: it sizes
  /// to its content, shows `placeholder` while it is empty, and its text view
  /// carries `identifier` and `placeholder` as its label. Return and
  /// Command-Return call `onSubmit` (``onFieldSubmit(_:)``).
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the text view.
  ///   - placeholder: The text that the empty field shows, and the
  ///     accessibility label of the text view.
  ///   - onSubmit: The action that Return and Command-Return call with the
  ///     text of the field.
  /// - Returns: The same field, with the slots set.
  func agentOneLineInput(
    identifier: String, placeholder: String, onSubmit: @escaping (String) -> Void
  ) -> Self {
    onFieldSubmit(onSubmit)
      .editorSizingMode(.intrinsic)
      .editorPlaceholder(placeholder)
      .editorTextAccessibilityIdentifier(identifier)
      .editorTextAccessibilityLabel(placeholder)
  }
}

extension View {
  /// Puts this text input in the edge of a kit text input: an inset from
  /// the edge, and the content edge with the small corners of
  /// `\.editorStyle`.
  ///
  /// - Returns: The input in its edge.
  func agentTextInputEdge() -> some View {
    modifier(AgentTextInputEdge())
  }
}

/// The edge of a kit text input: an inset of the text from the edge, and
/// `.inlineEdge(radius:)` with the small radius of the scale.
///
/// An EditorKit text input is bare (EditorKit `style.md`, rule 10): its
/// first glyph stands at its leading edge, with no text inset of its own
/// (EditorKit ^zycpt0j). So the edge gives the space around the input: the
/// control spacing of EditorKit (`.editorControlSpacing(_:)`) at the sides,
/// and the extra-small spacing of `\.editorStyle` above and below the line.
struct AgentTextInputEdge: ViewModifier {
  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
    content
      .editorControlSpacing(.horizontal)
      .padding(.vertical, editorStyle.spacing.xs)
      .inlineEdge(radius: editorStyle.radii.s)
  }
}

#Preview("One-line field") {
  AgentOneLineField(model: EditorModel(""), identifier: "preview-field", placeholder: "Search")
    .padding()
}
