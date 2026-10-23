import EditorCore
import EditorSwiftUI
import SwiftUI

/// A one-line text input of the kit: the EditorKit one-line field
/// (`SingleLineField`) in the edge of a kit text input.
///
/// Return calls `onSubmit` with the text of the field, and inserts no line.
/// Esc takes back each edit since the field got the focus, then moves the
/// focus out of the field. A paste puts its lines on one line.
///
/// The field has its own `editor:` command scope, whose id is the
/// accessibility identifier. A focus that lands on a scope around the field
/// stays on that scope, and a focus that lands on the scope of the field
/// goes into the field.
///
/// The text view of the field carries the accessibility identifier, so a
/// test finds one element to type into, and the placeholder as its
/// accessibility placeholder and its accessibility label.
struct AgentOneLineField: View {
  /// The model of the text of the field.
  let model: EditorModel

  /// The accessibility identifier of the text view, and the id of the
  /// `editor:` scope of the field.
  let identifier: String

  /// The text that the empty field shows, and the accessibility label of
  /// the text view of the field.
  let placeholder: String

  /// The action that Return calls with the text of the field.
  var onSubmit: (String) -> Void = { _ in }

  var body: some View {
    SingleLineField(model: model, id: identifier, onSubmit: onSubmit)
      .editorSizingMode(.intrinsic)
      .editorPlaceholder(placeholder)
      .editorTextAccessibilityIdentifier(identifier)
      .editorTextAccessibilityLabel(placeholder)
      .agentTextInputEdge()
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

/// The model of a text input that a view keeps in its state.
///
/// The slot makes the model at the first read. A `@State` value that holds
/// the model directly would make a new model each time SwiftUI makes the
/// view value again.
final class EditorModelSlot {
  /// The model, or `nil` before the first read.
  private var model: EditorModel?

  /// The model of the slot. The first read makes a model that holds `text`.
  ///
  /// - Parameter text: The text of a new model.
  /// - Returns: The model.
  func model(text: String) -> EditorModel {
    if let model {
      return model
    }
    let model = EditorModel(text)
    self.model = model
    return model
  }
}

#Preview("One-line field") {
  AgentOneLineField(model: EditorModel(""), identifier: "preview-field", placeholder: "Search")
    .padding()
}
