import EditorSwiftUI
import EditorText
import SwiftUI

/// A read-only code block on EditorKit (plan.md §4.1, §9).
///
/// The view shows a header with a code symbol, the filename or the language
/// and a Copy button, in a ``BlockHeader``. Below the header, an EditorKit editor shows the code with line
/// numbers. The editor takes the height of the code and wraps a long line to
/// its width, with no scroll of its own, so its host scrolls the block
/// (`EditorView.sizedToContent()`). When EditorKit has a
/// tree-sitter grammar for the language, the editor colors the code with it.
/// If not, and ``GrammarBundle`` ships a TextMate grammar for the language,
/// the editor colors the code with that grammar.
///
/// The editor, the frame and the header read the EditorKit theme of the
/// environment. The view sets no theme of its own.
///
/// The Copy button writes the code to the pasteboard of the environment.
/// See `EnvironmentValues.pasteboard`.
public struct CodeBlockView: View {
  /// The accessibility identifier of the code block.
  public static let identifier = "code-block"

  /// The accessibility identifier of the Copy button.
  public static let copyIdentifier = "code-block-copy"

  /// The accessibility identifier of the title of the header: the filename,
  /// the language, or ``plainTextName``.
  public static let titleIdentifier = "code-block-title"

  /// The name of the language in the header when the block has no language.
  public static let plainTextName = "plain text"

  /// The code to show.
  let code: String
  /// The language, with no whitespace at the start or the end, or `nil`.
  let language: String?
  /// The filename to show in the header, or `nil`.
  let filename: String?
  /// The model that the host gives, or `nil` when the view keeps its own.
  let suppliedModel: EditorModel?

  /// The model that the view keeps when the host gives no model.
  @State private var ownModel = OwnModelSlot()

  @Environment(\.pasteboard) private var pasteboard

  /// Makes a code block that keeps its own model.
  ///
  /// - Parameters:
  ///   - code: The code to show.
  ///   - language: The language of the code, such as `swift`, or `nil`.
  ///   - filename: The filename to show in the header, or `nil`.
  public init(code: String, language: String?, filename: String? = nil) {
    self.init(code: code, language: language, filename: filename, model: nil)
  }

  /// Makes a code block that shows `model`.
  ///
  /// The view makes `model` read-only, and changes its text to `code` with
  /// `EditorModel.syncStreaming(to:)` when `code` changes. A
  /// host gives a model from a ``CodeBlockModelCache``, so that a settled
  /// block keeps its layout.
  ///
  /// - Parameters:
  ///   - code: The code to show.
  ///   - language: The language of the code, such as `swift`, or `nil`.
  ///   - filename: The filename to show in the header, or `nil`.
  ///   - model: The model to show, or `nil` to keep an own model.
  public init(code: String, language: String?, filename: String? = nil, model: EditorModel?) {
    self.code = code
    self.language = Self.normalized(language)
    self.filename = Self.normalized(filename)
    self.suppliedModel = model
  }

  public var body: some View {
    let model = suppliedModel ?? ownModel.model(text: code, make: Self.makeModel)
    ContentTileStack {
      header
    } body: {
      // In the static form of a thread row, the code shows the picture
      // that the height cache drew of it, or else SwiftUI `Text` with no
      // syntax colors (card ^9ync5h3).
      StaticEditorSlot(picturePart: TranscriptTextPart(text: code, style: .code(language: language))) {
        editor(model: model)
      } still: {
        StaticCodeText(code, showsLineNumbers: true)
      }
    }
    .contentTile()
    .editorBlockFrame()
    .accessibilityElement(children: .contain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier(Self.identifier)
    .onChange(of: code, initial: true) {
      model.syncReadOnly(to: code)
    }
  }

  /// The start of the ``BodyEvaluationCounter`` key of each model that
  /// ``makeModel(_:)`` makes.
  static let modelCounterKeyPrefix = "code-block-model-"

  /// The ``BodyEvaluationCounter`` key of the models that ``makeModel(_:)``
  /// makes for `code`.
  ///
  /// A test counts the models of one code text. The key holds the whole
  /// code, so a test that uses codes of its own does not see the models of
  /// other tests.
  ///
  /// - Parameter code: The code of the model.
  /// - Returns: `code-block-model-<code>`.
  static func modelCounterKey(for code: String) -> String {
    EditorModel.readOnlyCounterKey(for: code, keyPrefix: modelCounterKeyPrefix)
  }

  /// Makes the read-only model of a code block: the model that the view
  /// keeps when the host gives no model, and the model of a code block in a
  /// ``CodeBlockModelCache``.
  ///
  /// In a debug build, each call adds one count to the key
  /// ``modelCounterKey(for:)`` of `code`.
  ///
  /// - Parameter code: The code.
  /// - Returns: The read-only model.
  static func makeModel(_ code: String) -> EditorModel {
    EditorModel.makeCountedReadOnly(code, keyPrefix: modelCounterKeyPrefix)
  }

  /// The label that VoiceOver reads for the block.
  var accessibilityLabel: String {
    guard let language else {
      return String(
        localized: "plain text code block", bundle: .module,
        comment: "The VoiceOver label of a code block that names no language.")
    }
    return String(
      localized: "\(language) code block", bundle: .module,
      comment: "The VoiceOver label of a code block: the name of its language, such as swift.")
  }

  /// The header with the symbol, the title and the Copy button: a
  /// ``BlockHeader``.
  ///
  /// The symbol (``AgentSymbol/codeBlock``) is the same for each language.
  /// It is in the symbol column, as the symbol of the header of
  /// ``TerminalView`` is, so the title starts at the x of the command of a
  /// terminal. The ``BlockHeader`` gives the symbol the color of the title,
  /// and the small spacing of the style between the symbol and the title.
  private var header: some View {
    BlockHeader {
      Image(systemName: AgentSymbol.codeBlock)
        .symbolColumn()
        .accessibilityHidden(true)
      Text(filename ?? language ?? Self.plainTextName)
        .accessibilityIdentifier(Self.titleIdentifier)
    } actions: {
      EditorToolbarButton(
        String(localized: "Copy code", bundle: .module), systemImage: AgentSymbol.copy
      ) {
        pasteboard.copyText(code)
      }
      .editorButtonCaptions(.hidden)
      .accessibilityIdentifier(Self.copyIdentifier)
    }
  }

  /// The read-only editor that shows `model`.
  ///
  /// - Parameter model: The model to show.
  /// - Returns: The editor.
  @ViewBuilder
  private func editor(model: EditorModel) -> some View {
    // A right click on the code gives the menu of the row, not the text
    // menu of AppKit (D108, D193 (f)).
    let view = EditorView(model: model)
      .editorTextMenu(.ancestor)
      .sizedToContent()
      .editorGutter(LineNumbers())
    switch Self.grammar(of: language) {
    case .treeSitter(let id): view.editorSyntax(id)
    case .textMate(let grammar): view.editorSyntax(textMate: grammar)
    case .plainText: view
    }
  }

  /// The grammar that colors the code of a language: the EditorKit
  /// tree-sitter grammar of the language, else the TextMate grammar that
  /// ``GrammarBundle`` ships for it, else no grammar.
  ///
  /// A tree-sitter grammar gives better colors, so it is the first choice.
  /// The editor of the block and the height measure of the block
  /// (``EditorLayoutTranscriptTextMeasure``) use this one choice, so the
  /// measure breaks the lines with the font runs of the grammar of the
  /// editor.
  ///
  /// - Parameter language: The language of the code, with no whitespace at
  ///   the start or the end, or `nil`.
  /// - Returns: The grammar.
  nonisolated static func grammar(of language: String?) -> EditorLayoutMeasure.CodeGrammar {
    guard let language else { return .plainText }
    let id = LanguageID(language)
    if GrammarRegistry.grammar(for: id) != nil {
      return .treeSitter(id)
    }
    guard let textMateID = GrammarBundle.languageID(forFenceTag: language),
      let textMate = GrammarBundle.registry.grammar(for: textMateID)
    else { return .plainText }
    return .textMate(textMate)
  }

  /// `text` with no whitespace at the start or the end, or `nil` when no
  /// other character remains.
  ///
  /// - Parameter text: The text to normalize.
  /// - Returns: The trimmed text, or `nil`.
  nonisolated static func normalized(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmed.isEmpty
    else { return nil }
    return trimmed
  }
}

#Preview("Code block") {
  CodeBlockView(
    code: PreviewFixtures.codeSample, language: PreviewFixtures.codeSampleLanguage,
    filename: PreviewFixtures.codeSampleFilename)
}
