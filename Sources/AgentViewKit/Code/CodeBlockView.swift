import EditorSwiftUI
import EditorText
import SwiftUI

/// A read-only code block on EditorKit (plan.md §4.1, §9).
///
/// The view shows a header with the filename or the language and a Copy
/// button. Below the header, an EditorKit editor shows the code with line
/// numbers. The editor grows to the height of the code. When EditorKit has a
/// grammar for the language, the editor colors the code.
///
/// The Copy button writes the code to the pasteboard of the environment.
/// See `EnvironmentValues.pasteboard`.
public struct CodeBlockView: View {
  /// The accessibility identifier of the code block.
  public static let identifier = "code-block"

  /// The accessibility identifier of the Copy button.
  public static let copyIdentifier = "code-block-copy"

  /// The name of the language in the label when the block has no language.
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

  @Environment(\.agentTheme) private var theme
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
    let model = suppliedModel ?? ownModel.model(code: code)
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      editor(model: model)
    }
    .background(AgentTheme.EditorSystemColors.background)
    .clipShape(RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous)
        .strokeBorder(.separator)
    )
    .editorTheme(theme.editorTheme)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier(Self.identifier)
    .onChange(of: code, initial: true) {
      syncModel(model)
    }
  }

  /// Makes `model` read-only and changes its text to ``code``.
  ///
  /// - Parameter model: The model that the view shows.
  private func syncModel(_ model: EditorModel) {
    // A write to an observed property notifies each observer, also when
    // the value does not change. Thus the view writes only a new value.
    if !model.isReadOnly {
      model.isReadOnly = true
    }
    model.syncStreaming(to: code)
  }

  /// The label that VoiceOver reads for the block.
  var accessibilityLabel: String {
    "\(language ?? Self.plainTextName) code block"
  }

  /// The row with the title and the Copy button.
  private var header: some View {
    HStack(spacing: theme.spacing.s) {
      Text(filename ?? language ?? Self.plainTextName)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: theme.spacing.s)
      Button("Copy code", systemImage: "doc.on.doc") {
        pasteboard.copyText(code)
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .help("Copy code")
      .accessibilityIdentifier(Self.copyIdentifier)
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.xs)
    .background(AgentTheme.EditorSystemColors.barBackground)
  }

  /// The read-only editor that shows `model`.
  ///
  /// - Parameter model: The model to show.
  /// - Returns: The editor.
  @ViewBuilder
  private func editor(model: EditorModel) -> some View {
    let view = EditorView(model: model)
      .editorSizingMode(.intrinsic)
      .editorGutter(LineNumbers())
    if let grammarID {
      view.editorSyntax(grammarID)
    } else {
      view
    }
  }

  /// The id of the EditorKit grammar of ``language``, or `nil` when
  /// EditorKit has no grammar for it.
  private var grammarID: LanguageID? {
    guard let language else { return nil }
    let id = LanguageID(language)
    return GrammarRegistry.grammar(for: id) == nil ? nil : id
  }

  /// `text` with no whitespace at the start or the end, or `nil` when no
  /// other character remains.
  ///
  /// - Parameter text: The text to normalize.
  /// - Returns: The trimmed text, or `nil`.
  private static func normalized(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmed.isEmpty
    else { return nil }
    return trimmed
  }
}

/// The model that a ``CodeBlockView`` keeps when the host gives no model.
///
/// The slot makes the model at the first read. A `@State` value that holds
/// the model directly would make a new model each time SwiftUI makes the
/// view value again.
private final class OwnModelSlot {
  /// The model, or `nil` before the first read.
  private var model: EditorModel?

  /// The model of the slot. The first read makes a read-only model that
  /// holds `code`.
  ///
  /// - Parameter code: The text of a new model.
  /// - Returns: The model.
  func model(code: String) -> EditorModel {
    if let model {
      return model
    }
    let model = EditorModel.makeReadOnly(code)
    self.model = model
    return model
  }
}
