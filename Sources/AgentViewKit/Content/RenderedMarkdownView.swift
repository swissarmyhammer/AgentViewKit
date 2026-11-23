import EditorSwiftUI
import EditorText
import FoundationModelsACPClient
import SwiftUI

/// Markdown in the rendered form of EditorKit (D185, AVK-9).
///
/// The view shows the text in a read-only `EditorView` with the Markdown
/// grammar, in the rendered presentation and the display font role. The
/// editor takes the height of its rows and wraps to its width, so it has no
/// scroll of its own (``EditorKit/EditorView/sizedToContent()``).
///
/// The view keeps one model in its state, or shows the model that the host
/// gives. A new text goes into that model with `syncStreaming(to:)`: a text
/// that starts with the old text adds only its new end, as a stream does, and
/// another text replaces the text of the model. The Markdown of an
/// attachment, the empty state of a conversation and the prose of an agent
/// answer (``ResponseView``) show in it.
///
/// EditorKit shows math (`$…$`, `$$…$$`) with iosMath. Each formula is an
/// accessibility element whose value is its TeX source. The value of the text
/// element is the text, with each formula at its place as EditorKit speaks
/// it: the label "Math" and the TeX source ("Math, x^2").
///
/// The text view joins the linked reading group of the environment
/// (``SwiftUI/EnvironmentValues/accessibilityEditorTextReadingGroup``), so
/// VoiceOver moves from the text of one block of a message to the text of
/// the next block. The SwiftUI linked group does not reach the text view.
///
/// The text view is no focus target of the command scope that holds it
/// (`editorTakesScopeFocus(false)`). A `nav.*` move or a jump to the item of
/// a message thus gives the first responder to the beacon of the item scope,
/// and the item shows its focus ring. A click in the text still selects
/// text.
///
/// In the row of an entry with a search hit, the view draws the find marks
/// of the matched words of the hit (``TranscriptSearchMatches``).
///
/// The view shows a citation chip at the offset of each ``EditorCitation``.
/// A press on a chip selects its source in the ``CitationSelection`` of the
/// environment, as a press on an ``InlineCitation`` pill does.
struct RenderedMarkdownView: View {
  /// The accessibility identifier of the text view when the caller gives
  /// none.
  static let identifier = "rendered-markdown"

  /// The Markdown text.
  let markdown: String

  /// The accessibility identifier of the text view. The value of that
  /// element is the Markdown text.
  let identifier: String

  /// The citation chips of the text.
  let citations: [EditorCitation]

  /// The model that the host keeps for the text, or `nil` when the view keeps
  /// its own model.
  let hostModel: EditorModel?

  @State private var ownModel = OwnModelSlot()
  @Environment(\.sessionModel) private var session
  @Environment(\.citationSelection) private var citationSelection

  /// The search mark of the row around the view, or `nil`.
  @Environment(\.transcriptSearchMark) private var searchMark

  /// The linked reading group that the text view joins, or `nil`.
  @Environment(\.accessibilityEditorTextReadingGroup) private var readingGroup

  /// Makes the view of Markdown text.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown text.
  ///   - identifier: The accessibility identifier of the text view.
  ///   - citations: The citation chips of the text.
  ///   - model: The model that the host keeps for the text, or `nil` to keep
  ///     a model in the state of the view. The view gives the text to the
  ///     model.
  init(
    _ markdown: String, identifier: String = RenderedMarkdownView.identifier,
    citations: [EditorCitation] = [],
    model: EditorModel? = nil
  ) {
    self.markdown = markdown
    self.identifier = identifier
    self.citations = citations
    self.hostModel = model
  }

  var body: some View {
    let model = hostModel ?? ownModel.model(text: markdown, make: Self.makeModel)
    let selection = citationSelection
    EditorView(model: model)
      // A right click on the text gives the menu of the row, not the text
      // menu of AppKit (D108, D193 (f)).
      .editorTextMenu(.ancestor)
      .editorCodeBlockHeader { block in
        if let title = Self.headerTitle(of: block) {
          Text(verbatim: title)
        }
      }
      .citing(citations) { citation in selection?.select(citation.number) }
      .transcriptSearchMarks(searchMark)
      .editorTextAccessibilityIdentifier(identifier)
      .linkingText(in: readingGroup)
      // The beacon of the item scope takes the focus of a nav move or a
      // jump, so the item shows its ring.
      .editorTakesScopeFocus(false)
      .editorImageSource(FileImageSource(), relativeTo: Self.imageFolder(of: session))
      .sizedToContent()
      .editorSyntax(.markdown)
      .editorPresentation(.rendered)
      .editorFontRole(.display)
      // The first sync gives a model of the host the text of this view.
      .onChange(of: markdown, initial: true) {
        Self.sync(model, to: markdown)
      }
  }

  /// The title of the header of a fenced code block: a borderless label
  /// with no controls. Copy Code Block is a command of the code block scope
  /// (``AgentCommandVerb/copyCodeBlock``), not a button. An answer does not
  /// show its fences here: ``ResponseView`` shows each fence in a
  /// ``CodeBlockView``, with a Copy button (task ^4g2xbx1, which replaces
  /// D193 (f) for an answer).
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
    session.flatMap(StatusLineView.folder(of:)).map {
      URL(filePath: $0, directoryHint: .isDirectory)
    }
  }

  /// The start of the ``BodyEvaluationCounter`` key of each model that
  /// ``makeModel(_:)`` makes.
  static let modelCounterKeyPrefix = "rendered-markdown-model-"

  /// The ``BodyEvaluationCounter`` key of the models that ``makeModel(_:)``
  /// makes for the text `markdown`.
  ///
  /// A test counts the models that the view makes for one text. The key
  /// holds the whole text, so a test that uses texts of its own does not
  /// see the models of other tests.
  ///
  /// - Parameter markdown: The Markdown text of the model.
  /// - Returns: `rendered-markdown-model-<markdown>`.
  static func modelCounterKey(for markdown: String) -> String {
    EditorModel.readOnlyCounterKey(for: markdown, keyPrefix: modelCounterKeyPrefix)
  }

  /// Makes the read-only model of Markdown text, in the rendered
  /// presentation.
  ///
  /// In a debug build, each call adds one count to the key
  /// ``modelCounterKey(for:)`` of `markdown`.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The model.
  static func makeModel(_ markdown: String) -> EditorModel {
    let model = EditorModel.makeCountedReadOnly(markdown, keyPrefix: modelCounterKeyPrefix)
    model.presentation = .rendered
    return model
  }

  /// Gives a model a new text, and keeps it read-only. A text that starts
  /// with the old text adds only its new end.
  ///
  /// - Parameters:
  ///   - model: The model.
  ///   - markdown: The new Markdown text.
  static func sync(_ model: EditorModel, to markdown: String) {
    model.syncReadOnly(to: markdown)
  }
}

extension EditorSlotComposing {
  /// Shows `citations` as chips in the text, or adds nothing when there is
  /// no citation.
  ///
  /// The chips read the document of the model when the view is made, so a
  /// view with chips evaluates again after each change of the text. A view
  /// with no chip adds no provider, and does not evaluate again.
  ///
  /// - Parameters:
  ///   - citations: The citation chips.
  ///   - onActivate: What a press on a chip does, with the citation of that
  ///     chip.
  /// - Returns: The same view value, with the chips when there are some.
  func citing(_ citations: [EditorCitation], onActivate: @escaping (EditorCitation) -> Void) -> Self
  {
    citations.isEmpty ? self : editorCitations(citations, onActivate: onActivate)
  }

  /// Puts the text view in the linked reading group `group`, or adds
  /// nothing when there is no group.
  ///
  /// - Parameter group: The linked reading group, or `nil`.
  /// - Returns: The same view value, with the group when there is one.
  func linkingText(in group: AccessibilityReadingGroup?) -> Self {
    guard let group else { return self }
    return editorAccessibilityLinkedGroup(id: group.id, in: group.namespace)
  }
}
