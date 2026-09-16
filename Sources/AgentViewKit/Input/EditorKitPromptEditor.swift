import AppKit
import EditorComplete
import EditorCore
import EditorExtensions
import EditorSwiftUI
import SwiftUI

/// The EditorKit editor of ``PromptInputView`` (plan.md §4.1, §9 D).
///
/// A host puts the editor in the `editor:` slot:
///
/// ```swift
/// PromptInputView(text: $draft, onSubmit: {}, editor: EditorKitPromptEditor.init)
///   .promptFileRoot(projectURL)
/// ```
///
/// The editor hosts an EditorKit `EditorView` that grows with its text, in the
/// colors of the ``AgentTheme``. Return calls ``PromptEditorContext/onSubmit``.
/// Command-Return calls ``PromptEditorContext/onSendNow``. Shift-Return
/// inserts a newline. Esc calls ``PromptEditorContext/onCancel`` while the
/// thread runs a turn.
///
/// Two completion sources feed a completion list above the editor:
///
/// - ``SlashCommandSource`` lists ``PromptEditorContext/commands`` after a `/`
///   at the start of a line.
/// - ``FileReferenceSource`` lists the entries under the
///   ``SwiftUI/EnvironmentValues/promptFileRoot`` after an `@`. The source is
///   off when there is no root.
///
/// While the list shows, the arrow keys move the selection, Return accepts
/// the selected row, and Esc closes the list. An accepted file shows as a
/// chip. The text of the prompt marks each chip with a `link` attribute that
/// holds the file URL. ``PromptInputView`` sends each linked file as an
/// attachment, which a source sends as a `resource_link` block.
public struct EditorKitPromptEditor: View {
  /// The accessibility identifier of the editor.
  public static let identifier = "editorkit-prompt-editor"

  /// The accessibility identifier of each row of the completion list.
  public static let completionRowIdentifier = "prompt-completion-row"

  /// The largest height of the completion list, in points.
  static let completionListMaximumHeight: CGFloat = 160

  /// The width of the completion list, in points.
  static let completionListWidth: CGFloat = 280

  /// The values that the composer gives.
  let context: PromptEditorContext

  @Environment(\.promptFileRoot) private var fileRoot
  @Environment(\.agentTheme) private var theme

  /// The model and the completion engine of the editor.
  @State private var session = PromptEditorSession()

  /// The paths of the accepted file references, relative to the file root.
  @State private var references: Set<String> = []

  /// Makes the editor.
  ///
  /// - Parameter context: The values that the composer gives.
  public init(context: PromptEditorContext) {
    self.context = context
  }

  public var body: some View {
    let model = session.model
    let completion = model.state.value(CompletionSessionField.self)
    // The session calls the newest view value, so that each commit and each
    // key press reads the newest context and file root.
    let _ = session.follow(
      onCommit: { transaction in didCommit(transaction, in: model) },
      onSubmit: { modifiers in submit(model: model, modifiers: modifiers) })
    EditorView(
      model: model,
      onEscapeKey: cancel,
      onReturnKey: { submit(model: model) }
    )
    .editorSizingMode(.intrinsic)
    .editorPlaceholder(context.placeholder)
    .editorInlineDecorations([
      EditorSwiftUI.SmartTag(.token, detect: FileReferenceDetector(paths: references))
    ])
    .editorTheme(theme.editorTheme)
    .frame(minHeight: StockPromptEditor.minimumHeight, maxHeight: StockPromptEditor.maximumHeight)
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityLabel(context.placeholder)
    .accessibilityIdentifier(Self.identifier)
    .overlay(alignment: .topLeading) {
      if completion.isOpen, !completion.listedItems.isEmpty {
        completionList(completion, model: model)
          .alignmentGuide(.top) { $0[.bottom] }
      }
    }
    .onKeyPress(.return, phases: .down) { press in
      // SwiftUI sees the press before the text view does.
      session.pressReturn(with: press.modifiers) ? .handled : .ignored
    }
    .onChange(of: context.text.wrappedValue, initial: true) { _, text in
      pull(text, into: model)
    }
  }

  // MARK: - Completion list

  /// The list of the open completion session.
  ///
  /// - Parameters:
  ///   - completion: The open session.
  ///   - model: The model of the editor.
  /// - Returns: The list, in a glass panel.
  private func completionList(_ completion: CompletionSessionState, model: EditorModel) -> some View {
    CompletionSuggestionsList(
      items: completion.listedItems, selectedIndex: completion.listedSelectedIndex, id: \.label,
      row: { item, isSelected in PromptCompletionRow(item: item, isSelected: isSelected) },
      onCommit: { item in accept(item, in: model) }
    )
    .frame(width: Self.completionListWidth)
    .frame(maxHeight: Self.completionListMaximumHeight)
    .fixedSize(horizontal: false, vertical: true)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.m))
  }

  // MARK: - Keys

  /// Submits the prompt for a Return press.
  ///
  /// - Parameters:
  ///   - model: The model of the editor.
  ///   - modifiers: The modifier keys of the press, or `nil` to read them
  ///     from the session or from the current event.
  /// - Returns: `false` for Shift-Return, so that the editor inserts a
  ///   newline. `true` otherwise.
  private func submit(model: EditorModel, modifiers: EventModifiers? = nil) -> Bool {
    let modifiers =
      modifiers ?? session.takeReturnModifiers() ?? Self.modifiers(of: NSApp.currentEvent)
    guard let action = StockPromptEditor.returnAction(for: modifiers, in: context) else {
      return false
    }
    push(model.text, references: references)
    action()
    // A submit clears the text of the prompt. The editor takes the change at
    // once, so that a commit that the stream still holds cannot give the old
    // text back to the prompt.
    pull(context.text.wrappedValue, into: model)
    return true
  }

  /// Stops the current turn for an Esc press.
  ///
  /// - Returns: `false` while the thread does not run a turn.
  private func cancel() -> Bool {
    guard let cancel = context.onCancel else { return false }
    cancel()
    return true
  }

  /// The SwiftUI modifiers of a key event.
  ///
  /// The editor reads the current event when SwiftUI did not report the
  /// press first.
  ///
  /// - Parameter event: The event, or `nil`.
  /// - Returns: The Shift and Command modifiers of the event.
  static func modifiers(of event: NSEvent?) -> EventModifiers {
    guard let flags = event?.modifierFlags else { return [] }
    var modifiers: EventModifiers = []
    if flags.contains(.shift) { modifiers.insert(.shift) }
    if flags.contains(.command) { modifiers.insert(.command) }
    return modifiers
  }

  // MARK: - Commits

  /// Follows one committed transaction of the editor.
  ///
  /// Typing in a trigger token asks for completions. Typing out of a trigger
  /// token closes the list. An accepted file becomes a chip. Then the text of
  /// the prompt gets the text of the editor.
  ///
  /// - Parameters:
  ///   - transaction: The committed transaction.
  ///   - model: The model of the editor.
  private func didCommit(_ transaction: EditorTransaction, in model: EditorModel) {
    var references = references
    switch transaction.annotations.userEvent {
    case .input, .delete:
      updateCompletion(in: model)
    case .completionAccept:
      if let path = Self.acceptedFile(before: caretLine(in: model), root: fileRoot) {
        references.insert(path)
        self.references = references
      }
      // An accepted directory ends in `/`. List its entries.
      updateCompletion(in: model)
    default:
      break
    }
    push(model.text, references: references)
  }

  /// Asks for completions when the caret is in a trigger token, and closes
  /// the list otherwise.
  ///
  /// - Parameter model: The model of the editor.
  private func updateCompletion(in model: EditorModel) {
    let editor = Self.editorContext(of: model)
    if Self.isTrigger(caretLine(in: model), hasCommands: !context.commands.isEmpty, hasRoot: fileRoot != nil) {
      session.engine(commands: context.commands, root: fileRoot).request(trigger: .typed, in: editor)
    } else if let dismiss = CompletionCommands.dismissTransaction(in: editor.state) {
      model.dispatch(dismiss)
    }
  }

  /// Accepts a row of the completion list.
  ///
  /// The model dispatches the transaction, so that the caret moves and the
  /// commit reaches ``didCommit(_:in:)``.
  ///
  /// - Parameters:
  ///   - item: The row.
  ///   - model: The model of the editor.
  private func accept(_ item: Completion, in model: EditorModel) {
    let state = Self.editorContext(of: model).state
    guard let transaction = CompletionCommands.acceptTransaction(item, in: state) else { return }
    model.dispatch(transaction)
  }

  /// The text of the caret line before the caret.
  ///
  /// - Parameter model: The model of the editor.
  /// - Returns: The text, or an empty string when the caret is not valid.
  private func caretLine(in model: EditorModel) -> Substring {
    let editor = Self.editorContext(of: model)
    let caret = model.selection.primary.head
    let line = editor.line(containing: caret)
    guard let index = CompletionTokenizer.caretIndex(in: line, caret: caret) else { return "" }
    return line.text[..<index]
  }

  /// The editor context of the model, with the selection of this view.
  ///
  /// - Parameter model: The model of the editor.
  /// - Returns: The context.
  static func editorContext(of model: EditorModel) -> EditorContext {
    EditorContext(model.state.withSelection(model.selection))
  }

  /// Whether the text before the caret ends in a trigger token.
  ///
  /// - Parameters:
  ///   - line: The text of the caret line before the caret.
  ///   - hasCommands: Whether the thread has slash commands.
  ///   - hasRoot: Whether the editor has a file root.
  /// - Returns: `true` for a `/` token at the start of the line, or for a run
  ///   that starts with `@` after white space.
  static func isTrigger(_ line: Substring, hasCommands: Bool, hasRoot: Bool) -> Bool {
    if hasCommands, line.hasPrefix(SlashCommandSource.trigger),
      line.dropFirst(SlashCommandSource.trigger.count).allSatisfy(CompletionTokenizer.isWordCharacter)
    {
      return true
    }
    let run = Self.lastRun(of: line)
    return hasRoot && run.hasPrefix(FileReferenceSource.trigger)
  }

  /// The run of characters after the last white space of `line`.
  ///
  /// - Parameter line: The text to read.
  /// - Returns: The last run, or all of `line` when it has no white space.
  static func lastRun(of line: Substring) -> Substring {
    guard let space = line.lastIndex(where: \.isWhitespace) else { return line }
    return line[line.index(after: space)...]
  }

  /// The path of the file reference that an accept just inserted.
  ///
  /// - Parameters:
  ///   - line: The text of the caret line before the caret.
  ///   - root: The file root, or `nil`.
  /// - Returns: The path, when the text ends in `@`, a path, and a space, and
  ///   the path names a file under the root. `nil` otherwise.
  static func acceptedFile(before line: Substring, root: URL?) -> String? {
    guard let root, line.hasSuffix(" ") else { return nil }
    let run = Self.lastRun(of: line.dropLast())
    guard run.hasPrefix(FileReferenceSource.trigger) else { return nil }
    let path = String(run.dropFirst(FileReferenceSource.trigger.count))
    guard FileReferenceSource.isSafe(path) else { return nil }
    var isDirectory: ObjCBool = false
    let url = root.appending(path: path)
    guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory),
      !isDirectory.boolValue
    else {
      return nil
    }
    return path
  }

  // MARK: - Text

  /// Gives the text of the editor to the text of the prompt.
  ///
  /// - Parameters:
  ///   - text: The text of the editor.
  ///   - references: The paths of the accepted file references.
  private func push(_ text: String, references: Set<String>) {
    let attributed = Self.attributedText(text, references: references, root: fileRoot)
    if context.text.wrappedValue != attributed {
      context.text.wrappedValue = attributed
    }
  }

  /// Gives a changed text of the prompt to the editor, for example the empty
  /// text after a submit.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - model: The model of the editor.
  private func pull(_ text: AttributedString, into model: EditorModel) {
    let plain = String(text.characters)
    guard plain != model.text else { return }
    model.replaceAll(plain)
    if plain.isEmpty {
      references = []
    }
  }

  /// The prompt text of the editor text.
  ///
  /// Each accepted file reference gets a `link` attribute that holds the file
  /// URL.
  ///
  /// - Parameters:
  ///   - text: The text of the editor.
  ///   - references: The paths of the accepted file references.
  ///   - root: The file root, or `nil`.
  /// - Returns: The attributed text.
  static func attributedText(_ text: String, references: Set<String>, root: URL?) -> AttributedString {
    var result = AttributedString(text)
    guard let root, !references.isEmpty else { return result }
    for reference in FileReferenceDetector.references(in: text) where references.contains(reference.path) {
      let utf8 = text.utf8
      let lower = utf8.index(utf8.startIndex, offsetBy: reference.range.lowerBound)
      let upper = utf8.index(utf8.startIndex, offsetBy: reference.range.upperBound)
      guard let range = Range(lower..<upper, in: result) else { continue }
      result[range].link = root.appending(path: reference.path)
    }
    return result
  }
}

/// One row of the completion list of ``EditorKitPromptEditor``.
struct PromptCompletionRow: View {
  /// The completion of the row.
  let item: Completion

  /// Whether the row is the selected row.
  let isSelected: Bool

  @Environment(\.agentTheme) private var theme

  var body: some View {
    HStack(spacing: theme.spacing.s) {
      Text(item.label)
        .font(theme.codeFont)
        .lineLimit(1)
      Spacer(minLength: theme.spacing.s)
      if let detail = item.detail {
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, theme.spacing.s)
    .padding(.vertical, theme.spacing.xs)
    .background(isSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(item.label)
    .accessibilityValue(item.detail ?? "")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier(EditorKitPromptEditor.completionRowIdentifier)
  }
}

/// The model and the completion engine of an ``EditorKitPromptEditor``.
///
/// A `@State` value that holds a model directly would make a new model each
/// time SwiftUI makes the view value again. So the session makes the model at
/// the first read, as ``OwnModelSlot`` does.
final class PromptEditorSession {
  /// The model, or `nil` before the first read.
  private var storedModel: EditorModel?

  /// The engine, or `nil` before the first completion request.
  private var storedEngine: CompletionEngine?

  /// The commands and the root of the engine.
  private var engineKey: EngineKey?

  /// The closure that gets each committed transaction of the model.
  private var onCommit: ((EditorTransaction) -> Void)?

  /// The modifier keys of the newest Return press, until the Return seam of
  /// the editor takes them.
  private var returnModifiers: EventModifiers?

  /// The closure that submits the prompt for a Return press with the given
  /// modifier keys.
  private var onSubmit: ((EventModifiers) -> Bool)?

  /// The task that reads the committed transactions of the model.
  ///
  /// The task holds only the stream, so it ends when the model goes away.
  private var commitTask: Task<Void, Never>?

  deinit {
    commitTask?.cancel()
  }

  /// The values that the sources of an engine read.
  private struct EngineKey: Equatable {
    let commands: [SlashCommand]
    let root: URL?
  }

  /// The model of the editor. The model registers the completion session
  /// field, so that the completion effects apply.
  var model: EditorModel {
    if let storedModel {
      return storedModel
    }
    let model = EditorModel(engine: EditorEngine("", fields: [.field(CompletionSessionField.self)]))
    storedModel = model
    let transactions = model.transactions
    commitTask = Task { [weak self] in
      for await transaction in transactions {
        self?.onCommit?(transaction)
      }
    }
    return model
  }

  /// Follows a Return press that SwiftUI reports before the text view.
  ///
  /// The text view does not send Command-Return to its Return seam, so the
  /// session submits the prompt for it. For each other press, the session
  /// keeps the modifier keys for the Return seam, which has none.
  ///
  /// - Parameter modifiers: The modifier keys of the press.
  /// - Returns: `true` when the session takes the press to submit the prompt.
  func pressReturn(with modifiers: EventModifiers) -> Bool {
    guard modifiers.contains(.command) else {
      returnModifiers = modifiers
      return false
    }
    // A binding read in a SwiftUI key press handler gives the value of the
    // last view update. The submit runs after the handler, so that it reads
    // the newest text.
    Task { [weak self] in
      _ = self?.onSubmit?(modifiers)
    }
    return true
  }

  /// Takes the modifier keys of the newest Return press.
  ///
  /// - Returns: The modifiers, or `nil` when no press is waiting.
  func takeReturnModifiers() -> EventModifiers? {
    defer { returnModifiers = nil }
    return returnModifiers
  }

  /// Sets the closures of the newest view value.
  ///
  /// SwiftUI can keep a key press closure of an older view value. That
  /// closure calls the session, and the session calls these closures.
  ///
  /// - Parameters:
  ///   - onCommit: The closure that gets each committed transaction.
  ///   - onSubmit: The closure that submits the prompt for a Return press.
  func follow(
    onCommit: @escaping (EditorTransaction) -> Void,
    onSubmit: @escaping (EventModifiers) -> Bool
  ) {
    self.onCommit = onCommit
    self.onSubmit = onSubmit
  }

  /// The completion engine for `commands` and `root`. The session makes a new
  /// engine when either value changes.
  ///
  /// - Parameters:
  ///   - commands: The slash commands of the thread.
  ///   - root: The file root, or `nil`.
  /// - Returns: The engine.
  func engine(commands: [SlashCommand], root: URL?) -> CompletionEngine {
    let key = EngineKey(commands: commands, root: root)
    if let storedEngine, engineKey == key {
      return storedEngine
    }
    var sources: [any EditorExtensions.CompletionSource] = [SlashCommandSource(commands: commands)]
    if let root {
      sources.append(FileReferenceSource(root: root))
    }
    let engine = CompletionEngine(sources: sources)
    storedEngine = engine
    engineKey = key
    return engine
  }
}

extension EnvironmentValues {
  /// The directory that the `@file` references of an
  /// ``EditorKitPromptEditor`` are relative to, or `nil` for no `@file`
  /// completion.
  @Entry public var promptFileRoot: URL? = nil
}

extension View {
  /// Sets the directory that the `@file` references of an
  /// ``EditorKitPromptEditor`` are relative to.
  ///
  /// - Parameter root: The directory, or `nil` for no `@file` completion.
  /// - Returns: A view with the file root in its environment.
  public func promptFileRoot(_ root: URL?) -> some View {
    environment(\.promptFileRoot, root)
  }
}
