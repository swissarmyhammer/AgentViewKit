import EditorSwiftUI
import EditorText
import FoundationModelsACPClient
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
  @Environment(\.sessionModel) private var session

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
      .editorCodeBlockHeader { block in
        if let title = Self.headerTitle(of: block) {
          Text(verbatim: title)
        }
      }
      .editorTextAccessibilityIdentifier(identifier)
      .editorImageSource(FileImageSource(), relativeTo: Self.imageFolder(of: session))
      .sizedToContent()
      .editorSyntax(.markdown)
      .editorPresentation(.rendered)
      .editorFontRole(.display)
      .onChange(of: markdown) {
        Self.sync(model, to: markdown)
      }
  }

  /// The title of the header of a fenced code block: a borderless label
  /// with no controls (D193 (f)). Copy Code Block is a command of the code
  /// block scope (``AgentCommandVerb/copyCodeBlock``), not a button.
  ///
  /// - Parameter block: The block.
  /// - Returns: The file name of the info string, else its language, else
  ///   `nil` for a block with neither.
  static func headerTitle(of block: FencedCodeBlock) -> String? {
    block.fileName ?? block.language
  }

  /// The folder that the images of the Markdown load from: the working
  /// folder of the session (AVK-9.6).
  ///
  /// `FileImageSource` reads only regular files inside this folder. With no
  /// folder, no image loads, and each image shows its alt text. A click on a
  /// link calls the `openURL` action of the environment, so the host decides
  /// what a link opens. The kit opens no URL itself.
  ///
  /// - Parameter session: The session of the view, or `nil`.
  /// - Returns: The folder, or `nil` when the session has no working folder.
  static func imageFolder(of session: SessionModel?) -> URL? {
    session.flatMap(StatusLineView.folder(of:)).map { URL(filePath: $0, directoryHint: .isDirectory) }
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
