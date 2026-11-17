import EditorSwiftUI
import EditorText
import SwiftUI

/// Static Markdown in the rendered form of EditorKit (D185, AVK-9).
///
/// The view shows the text in a read-only `EditorView` with the Markdown
/// grammar, in the rendered presentation and the display font role. The
/// editor takes the height of its rows and wraps to its width, so it has no
/// scroll of its own (``EditorKit/EditorView/sizedToContent()``).
///
/// The view keeps one model in its state. A new text replaces the text of
/// that model. The Markdown of an attachment and the empty state of a
/// conversation show in it. The text of an agent message moves to it when
/// EditorKit can append a stream (AVK-9.7).
struct RenderedMarkdownView: View {
  /// The accessibility identifier of the text view when the caller gives
  /// none.
  static let identifier = "rendered-markdown"

  /// The Markdown text.
  let markdown: String

  /// The accessibility identifier of the text view. The value of that
  /// element is the Markdown text.
  let identifier: String

  @State private var ownModel = OwnModelSlot()

  /// Makes the view of Markdown text.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown text.
  ///   - identifier: The accessibility identifier of the text view.
  init(_ markdown: String, identifier: String = RenderedMarkdownView.identifier) {
    self.markdown = markdown
    self.identifier = identifier
  }

  var body: some View {
    let model = ownModel.model(text: markdown, make: Self.makeModel)
    EditorView(model: model)
      .editorTextAccessibilityIdentifier(identifier)
      .sizedToContent()
      .editorSyntax(.markdown)
      .editorPresentation(.rendered)
      .editorFontRole(.display)
      .onChange(of: markdown) {
        Self.sync(model, to: markdown)
      }
  }

  /// Makes the read-only model of Markdown text, in the rendered
  /// presentation.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The model.
  static func makeModel(_ markdown: String) -> EditorModel {
    let model = EditorModel.makeReadOnly(markdown)
    model.presentation = .rendered
    return model
  }

  /// Gives a model a new text, and keeps it read-only.
  ///
  /// - Parameters:
  ///   - model: The model.
  ///   - markdown: The new Markdown text.
  static func sync(_ model: EditorModel, to markdown: String) {
    model.syncReadOnly(to: markdown)
  }
}
