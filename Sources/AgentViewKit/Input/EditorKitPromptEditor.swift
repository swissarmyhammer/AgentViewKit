import EditorComplete
import EditorCore
import EditorExtensions
import EditorStyle
import EditorSwiftUI
import EditorText
import EditorTheme
import FoundationModelsACP
import SwiftUI
import os

/// The editor of ``PromptInputView`` (plan.md §4.1, §9 D).
///
/// The short initializer of ``PromptInputView`` uses this editor. Set the
/// file root of the `@file` completion on the composer:
///
/// ```swift
/// PromptInputView(text: $draft) {}
///   .promptFileRoot(projectURL)
/// ```
///
/// The editor hosts an EditorKit `EditorView` that grows with its text. The
/// editor reads the EditorKit theme of the environment. Return calls
/// ``PromptEditorContext/onSubmit``.
/// Command-Return calls ``PromptEditorContext/onSendNow``. Shift-Return
/// inserts a newline. Esc calls ``PromptEditorContext/onCancel`` while the
/// user can cancel the work of the session.
///
/// The completion sources feed a completion list. ``PromptInputView`` shows
/// the list above its field, on its own glass, because the editor is in the
/// field glass (D110 (c)). The leading edge of the list is at the caret:
///
/// - ``SlashCommandSource`` lists ``PromptEditorContext/commands`` after a `/`
///   at the start of a line.
/// - ``FileReferenceSource`` lists the entries under the
///   ``SwiftUI/EnvironmentValues/promptFileRoot`` after an `@`. The source is
///   off when there is no root.
/// - The prefix-completion routes of the host
///   (``SwiftUI/View/composerCompletions(_:)``) list the rows of the route
///   whose sigil opens the token at the caret. A `/` route replaces the
///   ``SlashCommandSource``, and an `@` route replaces the
///   ``FileReferenceSource``.
///
/// While the list shows, the arrow keys move the selection, Return and Tab
/// accept the selected row, and Esc closes the list. An accepted file shows as a
/// chip. The text of the prompt marks each chip with a `link` attribute that
/// holds the file URL. ``PromptInputView`` sends each linked file as an
/// attachment, which a source sends as a `resource_link` block.
public struct EditorKitPromptEditor: View {
  /// The accessibility identifier of the editor: the text area that takes
  /// typing. It is also the name of the focus target of the editor slot of
  /// ``PromptInputView``.
  public static let identifier = "prompt-editor"

  /// The smallest height of the editor, in points.
  static let minimumHeight: CGFloat = 36

  /// The largest height of the editor, in points. Longer text scrolls.
  static let maximumHeight: CGFloat = 200

  /// The accessibility identifier of the completion list.
  public static let completionListIdentifier = "prompt-completion-list"

  /// The accessibility identifier of each row of the completion list.
  public static let completionRowIdentifier = "prompt-completion-row"

  /// The accessibility identifier of the note that the menu shows when the
  /// agent reports an empty command list.
  public static let noCommandsIdentifier = "prompt-no-commands"

  /// The text of the note that the menu shows when the agent reports an
  /// empty command list.
  public static var noCommandsNote: String {
    String(localized: "No commands", bundle: .module)
  }

  /// The largest height of the completion list, in points.
  static let completionListMaximumHeight: CGFloat = 160

  /// The width of the completion list, in points.
  static let completionListWidth: CGFloat = 280

  /// The text that ends an accepted directory, so that the list goes on into
  /// the directory.
  static let directorySeparator = "/"

  /// The log of the editor.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "EditorKitPromptEditor")

  /// The values that the composer gives.
  let context: PromptEditorContext

  @Environment(\.promptFileRoot) private var fileRoot
  @Environment(\.composerCompletionRoutes) private var routes
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  /// The model and the completion engine of the editor.
  @State private var session: PromptEditorSession

  /// The paths of the accepted file references, relative to the file root.
  @State private var references: Set<String> = []

  /// Makes the editor.
  ///
  /// - Parameter context: The values that the composer gives.
  public init(context: PromptEditorContext) {
    self.init(context: context, session: PromptEditorSession())
  }

  /// Makes the editor over a session that the caller holds, for example a
  /// test that reads the model of the session.
  ///
  /// - Parameters:
  ///   - context: The values that the composer gives.
  ///   - session: The model and the completion engine of the editor.
  init(context: PromptEditorContext, session: PromptEditorSession) {
    self.context = context
    _session = State(initialValue: session)
  }

  public var body: some View {
    // The model starts with the text of the prompt, for example a restored
    // draft. A first text that the editor took through `replaceAll` would be
    // an edit, and thus an undo entry of the window that the person never
    // made (^m1wgq3k).
    let model = session.model(startingWith: String(context.text.wrappedValue.characters))
    let completion = model.state.value(CompletionSessionField.self)
    // The session calls the newest view value, so that each commit reads the
    // newest context and file root.
    let _ = session.follow(onCommit: { transaction in didCommit(transaction, in: model) })
    EditorView(
      model: model,
      onEscapeKey: cancel,
      onReturnKey: { modifiers in submit(model: model, modifiers: modifiers) }
    )
    .editorSizingMode(.intrinsic)
    .editorPlaceholder(context.placeholder)
    .editorInlineDecorations([
      EditorSwiftUI.SmartTag(.token, detect: FileReferenceDetector(paths: references))
    ])
    // The identifier and the label go on the text view that takes typing, so
    // that a UI test finds one element to type into, and VoiceOver names it.
    .editorTextAccessibilityIdentifier(Self.identifier)
    .editorTextAccessibilityLabel(context.placeholder)
    // The prompt is text that a person types, so it draws in the display
    // font of the theme and not in the code font of an `EditorView`.
    .editorFontRole(.display)
    .frame(minHeight: Self.minimumHeight, maxHeight: Self.maximumHeight)
    .fixedSize(horizontal: false, vertical: true)
    // The probe finds the caret of the text view, so that the menu starts at
    // the caret.
    .background(PromptCaretProbe(locator: session.caretLocator))
    // The editor is in the field glass of the composer. So the composer
    // shows the menu on its own glass above the field (D110 (c)).
    .anchorPreference(key: PromptEditorMenuKey.self, value: .bounds) { anchor in
      menu(completion, model: model).map { content in
        PromptEditorMenu(
          anchor: anchor, caretOffset: session.caretLocator.caretOffset() ?? 0,
          width: Self.completionListWidth, content: content)
      }
    }
    .onChange(of: context.text.wrappedValue, initial: true) { _, text in
      promptTextDidChange(text, in: model)
    }
  }

  // MARK: - Completion list

  /// The menu that the composer shows above the field: the completion list,
  /// the "no commands" note, or nothing.
  ///
  /// The menu has no glass. The composer puts it on its glass.
  ///
  /// - Parameters:
  ///   - completion: The completion session of the editor.
  ///   - model: The model of the editor.
  /// - Returns: The menu, or `nil` when the editor shows no menu.
  private func menu(_ completion: CompletionSessionState, model: EditorModel) -> AnyView? {
    if completion.isOpen, !completion.listedItems.isEmpty {
      return AnyView(completionList(completion, model: model))
    }
    guard Self.showsNoCommandsNote(completion, commands: kitCommands) else { return nil }
    return AnyView(noCommandsNote)
  }

  /// The list of the open completion session.
  ///
  /// - Parameters:
  ///   - completion: The open session.
  ///   - model: The model of the editor.
  /// - Returns: The list, with no glass.
  private func completionList(_ completion: CompletionSessionState, model: EditorModel) -> some View {
    CompletionSuggestionsList(
      items: completion.listedItems, selectedIndex: completion.listedSelectedIndex, id: \.label,
      row: { item, isSelected in PromptCompletionRow(item: item, isSelected: isSelected) },
      onCommit: { item in accept(item, in: model) }
    )
    .frame(width: Self.completionListWidth)
    .frame(maxHeight: Self.completionListMaximumHeight)
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.completionListIdentifier)
  }

  /// The empty command menu: a short note that the agent reported no
  /// command. The note has no glass.
  private var noCommandsNote: some View {
    Text(Self.noCommandsNote)
      .font(editorTheme.font(for: .ui, style: .caption))
      .foregroundStyle(.secondary)
      .padding(.horizontal, editorStyle.spacing.s)
      .padding(.vertical, editorStyle.spacing.xs)
      .frame(width: Self.completionListWidth, alignment: .leading)
      .accessibilityIdentifier(Self.noCommandsIdentifier)
  }

  /// Whether the menu shows the "no commands" note.
  ///
  /// - Parameters:
  ///   - completion: The completion session of the editor.
  ///   - commands: The slash commands of the session.
  /// - Returns: `true` when a slash token opened the session, the session
  ///   lists no row, and the agent reported an empty command list.
  private static func showsNoCommandsNote(_ completion: CompletionSessionState, commands: [AvailableCommand]?) -> Bool {
    guard completion.isOpen, completion.listedItems.isEmpty, commands?.isEmpty == true else { return false }
    return completion.prefix.hasPrefix(SlashCommandSource.trigger)
  }

  // MARK: - Keys

  /// Submits the prompt for a Return press.
  ///
  /// The Return hook of the editor calls this function. An open completion
  /// list gets the press before the hook.
  ///
  /// - Parameters:
  ///   - model: The model of the editor.
  ///   - modifiers: The modifier keys of the press.
  /// - Returns: `false` for Shift-Return, so that the editor inserts a
  ///   newline. `true` otherwise.
  private func submit(model: EditorModel, modifiers: ReturnKeyModifiers) -> Bool {
    guard let action = Self.returnAction(for: Self.eventModifiers(of: modifiers), in: context) else {
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

  /// Cancels the work of the session for an Esc press.
  ///
  /// - Returns: `false` while the context has no cancel closure, because
  ///   the user cannot cancel now.
  private func cancel() -> Bool {
    guard let cancel = context.onCancel else { return false }
    cancel()
    return true
  }

  /// The closure that a Return press calls.
  ///
  /// - Parameters:
  ///   - modifiers: The modifier keys of the press.
  ///   - context: The values that the composer gives.
  /// - Returns: `nil` when the press holds Shift, so that the editor inserts a
  ///   newline. ``PromptEditorContext/onSendNow`` when the press holds
  ///   Command. ``PromptEditorContext/onSubmit`` otherwise.
  static func returnAction(
    for modifiers: EventModifiers, in context: PromptEditorContext
  ) -> PromptEditorContext.Submit? {
    if modifiers.contains(.shift) { return nil }
    return modifiers.contains(.command) ? context.onSendNow : context.onSubmit
  }

  /// The SwiftUI modifiers of the modifier keys of a Return press.
  ///
  /// - Parameter modifiers: The modifier keys that the editor gives.
  /// - Returns: The same modifier keys as SwiftUI modifiers.
  static func eventModifiers(of modifiers: ReturnKeyModifiers) -> EventModifiers {
    let pairs: [(ReturnKeyModifiers, EventModifiers)] = [
      (.shift, .shift), (.control, .control), (.option, .option), (.command, .command),
    ]
    return EventModifiers(pairs.filter { modifiers.contains($0.0) }.map(\.1))
  }

  // MARK: - Commits

  /// Follows one committed transaction of the editor.
  ///
  /// Typing in a trigger token or in a route token asks for completions.
  /// Typing out of those tokens closes the list. An accepted file becomes a
  /// chip. Then the text of the prompt gets the text of the editor.
  ///
  /// - Parameters:
  ///   - transaction: The committed transaction.
  ///   - model: The model of the editor.
  private func didCommit(_ transaction: EditorTransaction, in model: EditorModel) {
    // The commit stream delivers a commit later than its dispatch. By then the
    // text of the prompt can be newer than the text that the editor took from
    // it, for example the next transcript of a dictation. So the commit of a
    // taken text gives nothing back to the prompt.
    guard !Self.isPull(transaction) else { return }
    var references = references
    switch transaction.annotations.userEvent {
    case .input, .delete:
      updateCompletion(in: model)
    case .completionAccept:
      if let path = Self.acceptedFile(before: caretLine(in: model), root: kitFileRoot) {
        references.insert(path)
        self.references = references
      }
      didAccept(in: model)
    default:
      break
    }
    push(model.text, references: references)
  }

  /// Whether a transaction is the change of a text that the editor took from
  /// the prompt (`pull(_:into:)`).
  ///
  /// - Parameter transaction: The committed transaction.
  /// - Returns: `true` for an external reload that is no undo and no redo:
  ///   an undo or a redo of a taken text is a change of the person, which the
  ///   prompt gets.
  static func isPull(_ transaction: EditorTransaction) -> Bool {
    transaction.annotations.origin == .externalReload && !PromptEditorSession.isUndoOrRedo(transaction)
  }

  /// Asks for completions when the caret is in a trigger token or in a route
  /// token, and closes the list otherwise.
  ///
  /// - Parameter model: The model of the editor.
  private func updateCompletion(in model: EditorModel) {
    let editor = Self.editorContext(of: model)
    let caret = model.selection.primary.head
    let isTrigger = Self.isTrigger(
      caretLine(in: model), reportsCommands: kitCommands != nil, hasRoot: kitFileRoot != nil)
    guard isTrigger || Self.isRouteToken(at: caret, in: editor, routes: routes) else {
      dismissCompletion(in: model)
      return
    }
    session.engine(commands: kitCommands, root: kitFileRoot, routes: routes).request(trigger: .typed, in: editor)
  }

  /// Follows an accept of a row of the completion list.
  ///
  /// An accepted directory ends in `/`, so the list shows its entries. Any
  /// other accept closes the list, so that the next Return sends the prompt.
  /// A route row can leave the caret in its token, for example
  /// `^a1b2c3d`, and a new request there would show the list again.
  ///
  /// - Parameter model: The model of the editor.
  private func didAccept(in model: EditorModel) {
    guard caretLine(in: model).hasSuffix(Self.directorySeparator) else {
      dismissCompletion(in: model)
      return
    }
    updateCompletion(in: model)
  }

  /// Closes the completion list when it is open.
  ///
  /// - Parameter model: The model of the editor.
  private func dismissCompletion(in model: EditorModel) {
    guard let dismiss = CompletionCommands.dismissTransaction(in: Self.editorContext(of: model).state) else {
      return
    }
    model.dispatch(dismiss)
  }

  /// The slash commands of the ``SlashCommandSource`` of the kit.
  ///
  /// - Returns: `nil` when the agent did not report its commands, or when a
  ///   route of the host takes the `/`.
  private var kitCommands: [AvailableCommand]? {
    PromptEditorSession.routes(routes, take: SlashCommandSource.trigger) ? nil : context.commands
  }

  /// The file root of the ``FileReferenceSource`` of the kit.
  ///
  /// - Returns: `nil` when there is no file root, or when a route of the
  ///   host takes the `@`.
  private var kitFileRoot: URL? {
    PromptEditorSession.routes(routes, take: FileReferenceSource.trigger) ? nil : fileRoot
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
  ///   - reportsCommands: Whether the agent reported its slash commands. An
  ///     empty list counts as reported.
  ///   - hasRoot: Whether the editor has a file root.
  /// - Returns: `true` for a `/` token at the start of the line, or for a run
  ///   that starts with `@` after white space.
  static func isTrigger(_ line: Substring, reportsCommands: Bool, hasRoot: Bool) -> Bool {
    if reportsCommands, line.hasPrefix(SlashCommandSource.trigger),
      line.dropFirst(SlashCommandSource.trigger.count).allSatisfy(CompletionTokenizer.isWordCharacter)
    {
      return true
    }
    let run = Self.lastRun(of: line)
    return hasRoot && run.hasPrefix(FileReferenceSource.trigger)
  }

  /// Whether a route of the host opens the token at the caret.
  ///
  /// - Parameters:
  ///   - caret: The caret.
  ///   - editor: The editor context of the model.
  ///   - routes: The prefix-completion routes of the host.
  /// - Returns: `true` when the sigil of a route opens a token that runs to
  ///   the caret, where the anchor of the route lets it stand.
  static func isRouteToken(at caret: EditorPosition, in editor: EditorContext, routes: [PrefixCompletionRoute]) -> Bool {
    let line = editor.line(containing: caret)
    return routes.contains { CompletionTokenizer.openedToken(line: line, caret: caret, opening: $0.opening) != nil }
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
    let attributed = Self.attributedText(text, references: references, root: kitFileRoot)
    if context.text.wrappedValue != attributed {
      session.didPush(attributed)
      context.text.wrappedValue = attributed
    }
  }

  /// Follows a change of the text of the prompt.
  ///
  /// SwiftUI can report a pushed text after the model took newer input, for
  /// example a Shift-Return newline. That text is not a change. Any other
  /// text goes to the editor.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - model: The model of the editor.
  private func promptTextDidChange(_ text: AttributedString, in model: EditorModel) {
    guard !session.isNewestPush(text) else { return }
    pull(text, into: model)
  }

  /// Gives a changed text of the prompt to the editor, for example the empty
  /// text after a submit, or a restored draft.
  ///
  /// The file links of the text become the accepted file references
  /// (``references(in:root:)``), the inverse of ``push(_:references:)``. So
  /// the next push gives each linked file its link again.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - model: The model of the editor.
  private func pull(_ text: AttributedString, into model: EditorModel) {
    session.didPull()
    references = Self.references(in: text, root: kitFileRoot)
    let plain = String(text.characters)
    guard plain != model.text else { return }
    model.replaceAll(plain)
  }

  /// The accepted file references of a prompt text: the inverse of
  /// ``attributedText(_:references:root:)``.
  ///
  /// Each `link` attribute that holds a file URL under `root` is one
  /// reference, as its path relative to `root`.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - root: The file root, or `nil`.
  /// - Returns: The paths, relative to `root`, of the linked files under
  ///   `root`. No path when there is no root.
  static func references(in text: AttributedString, root: URL?) -> Set<String> {
    guard let root else { return [] }
    return Set(text.runs.compactMap(\.link).compactMap { relativePath(of: $0, under: root) })
  }

  /// The path of a linked file relative to the file root.
  ///
  /// - Parameters:
  ///   - link: The URL of a `link` attribute.
  ///   - root: The file root.
  /// - Returns: The path below `root`, or `nil` when `link` is no file URL
  ///   under `root`.
  static func relativePath(of link: URL, under root: URL) -> String? {
    guard link.isFileURL else { return nil }
    let rootPath = root.path(percentEncoded: false)
    let base = rootPath.hasSuffix(directorySeparator) ? rootPath : rootPath + directorySeparator
    let path = link.path(percentEncoded: false)
    guard path.hasPrefix(base) else { return nil }
    return String(path.dropFirst(base.count))
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
      guard let range = Range(lower..<upper, in: result) else {
        // The detector reads the same text, so each of its ranges has a range
        // in the text. A miss is a defect, and the file goes out with no link.
        assertionFailure("The file reference \(reference.path) has no range in the prompt text.")
        logger.error("The prompt text drops the link of an accepted file reference.")
        continue
      }
      result[range].link = root.appending(path: reference.path)
    }
    return result
  }
}

/// One row of the completion list of ``EditorKitPromptEditor``.
///
/// The selected row sits on the shared selection surface of EditorKit, in
/// the small radius and inset from the edges of the list, as the completion
/// row of EditorKit does.
struct PromptCompletionRow: View {
  /// The radius step of the selection surface: the small radius of a row in
  /// a list.
  static let selectionRadius = EditorStyle.Radius.small

  /// The horizontal inset of the selection surface inside the row: the inset
  /// of the completion row of EditorKit.
  static let selectionHorizontalInset: CGFloat = 2

  /// The completion of the row.
  let item: Completion

  /// Whether the row is the selected row.
  let isSelected: Bool

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    HStack(spacing: editorStyle.spacing.s) {
      Text(item.label)
        .font(editorTheme.uiFont)
        .lineLimit(1)
      Spacer(minLength: editorStyle.spacing.s)
      if let detail = item.detail {
        Text(detail)
          .font(editorTheme.font(for: .ui, style: .caption))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, editorStyle.spacing.s)
    .padding(.vertical, editorStyle.spacing.xs)
    .selectionSurface(isSelected, radius: Self.selectionRadius)
    .padding(.horizontal, Self.selectionHorizontalInset)
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
/// the first read, as ``OwnModelSlot`` does: the first text of the model is
/// the text of the prompt at the first draw, and the model, its observer and
/// its commit task exist only from then on. The completion engine does not
/// wait for a read: the session makes it at once, for no commands, no file
/// root and no route.
final class PromptEditorSession {
  /// The model, or `nil` before the first read (see the type).
  private var storedModel: EditorModel?

  /// The engine for ``engineCommands``, ``engineRoot`` and ``engineSigils``.
  private var storedEngine: CompletionEngine

  /// The slash commands that the sources of the engine read, or `nil` when
  /// the agent did not report its commands.
  private var engineCommands: [AvailableCommand]?

  /// The file root that the sources of the engine read.
  private var engineRoot: URL?

  /// The sigils of the routes that the sources of the engine read.
  private var engineSigils: [String] = []

  /// The source of the prefix-completion routes of the host.
  ///
  /// The session keeps one source and gives it the newest routes before each
  /// request, so a new list of routes takes effect at the next keystroke.
  private let prefixes: PrefixCompletionSource

  /// Finds the caret of the text view of the editor, so that the menu starts
  /// at the caret.
  let caretLocator = PromptCaretLocator()

  /// The closure that gets each committed transaction of the model. It does
  /// nothing until the first view value sets it (``follow(onCommit:)``).
  private var onCommit: (EditorTransaction) -> Void = { _ in }

  /// Makes a session, with the engine for no commands, no file root and no
  /// route.
  init() {
    let prefixes = PrefixCompletionSource(routes: [])
    self.prefixes = prefixes
    storedEngine = CompletionEngine(sources: Self.sources(commands: nil, root: nil, prefixes: prefixes))
  }

  /// The newest text that the editor gave to the text of the prompt, until
  /// the editor takes a text from the prompt.
  private var pushedText: AttributedString?

  /// The task that reads the committed transactions of the model.
  ///
  /// The task holds only the stream, so it ends when the model goes away.
  private var commitTask: Task<Void, Never>?

  deinit {
    commitTask?.cancel()
  }

  /// The model of the editor, or a new empty model before the first read.
  var model: EditorModel {
    model(startingWith: "")
  }

  /// The model of the editor. The first read makes the model with `text`;
  /// a later read gives the same model and ignores `text`.
  ///
  /// The caret of a new model is at the end of `text`, so that the person
  /// types on after a restored draft (^f41brfh). The move changes only the
  /// selection, so it is no edit and leaves no undo entry (^m1wgq3k).
  ///
  /// The model registers the completion session field, so that the
  /// completion effects apply. The commit closure gets each transaction that
  /// the model commits, and each undo and redo of the engine: the window
  /// undo stack runs those on the engine, so they do not reach the
  /// `transactions` stream of the model.
  ///
  /// - Parameter text: The first text of a new model. The session reads it
  ///   only when it makes the model.
  /// - Returns: The model.
  func model(startingWith text: @autoclosure () -> String) -> EditorModel {
    if let storedModel {
      return storedModel
    }
    let engine = EditorEngine(text(), fields: [.field(CompletionSessionField.self)])
    let model = EditorModel(engine: engine)
    storedModel = model
    Self.moveCaretToEnd(of: model)
    // The model registers its own dispatch observer first, so its text is
    // the new text when this observer runs.
    engine.addDispatchObserver { [weak self] transaction, _, _ in
      self?.engineDidDispatch(transaction)
    }
    let transactions = model.transactions
    commitTask = Task { [weak self] in
      await Self.forward(transactions) { self?.onCommit($0) }
    }
    return model
  }

  /// Gives an undo or a redo of the engine to the commit closure.
  ///
  /// The window undo stack runs undo and redo on the engine, so they do not
  /// reach the `transactions` stream of the model. Each other dispatch
  /// reaches the commit closure through that stream.
  ///
  /// - Parameter transaction: The dispatched transaction.
  private func engineDidDispatch(_ transaction: EditorTransaction) {
    guard Self.isUndoOrRedo(transaction) else { return }
    onCommit(transaction)
  }

  /// Gives each committed transaction of a stream to `commit`, until the
  /// stream ends.
  ///
  /// - Parameters:
  ///   - transactions: The `transactions` stream of the model.
  ///   - commit: The function that gets each transaction.
  private static func forward(
    _ transactions: AsyncStream<EditorTransaction>, to commit: (EditorTransaction) -> Void
  ) async {
    for await transaction in transactions {
      commit(transaction)
    }
  }

  /// Puts the caret of `model` at the end of its text with a transaction
  /// that changes only the selection.
  ///
  /// - Parameter model: The model of the editor.
  private static func moveCaretToEnd(of model: EditorModel) {
    let end = EditorKitPromptEditor.editorContext(of: model).documentEnd
    model.dispatch(EditorTransaction(changes: .identity(length: model.text.utf8.count), selection: .cursor(end)))
  }

  /// Whether a transaction is an undo or a redo of the engine.
  ///
  /// - Parameter transaction: The dispatched transaction.
  /// - Returns: `true` when the transaction undoes or redoes an undo group.
  static func isUndoOrRedo(_ transaction: EditorTransaction) -> Bool {
    transaction.annotations.isUndo != nil || transaction.annotations.isRedo != nil
  }

  /// Sets the commit closure of the newest view value.
  ///
  /// The commit task of the session lives longer than one view value, so it
  /// calls the closure that this function sets.
  ///
  /// - Parameter onCommit: The closure that gets each committed transaction.
  func follow(onCommit: @escaping (EditorTransaction) -> Void) {
    self.onCommit = onCommit
  }

  /// Records a text that the editor gave to the text of the prompt.
  ///
  /// - Parameter text: The text.
  func didPush(_ text: AttributedString) {
    pushedText = text
  }

  /// Forgets the newest pushed text, because the editor takes a text from
  /// the prompt.
  func didPull() {
    pushedText = nil
  }

  /// Whether a text of the prompt is the newest text that the editor gave.
  ///
  /// - Parameter text: The text of the prompt.
  /// - Returns: `true` when the editor gave `text` and took no text from the
  ///   prompt after that.
  func isNewestPush(_ text: AttributedString) -> Bool {
    text == pushedText
  }

  /// Whether a route of `routes` takes `sigil` from a completion source of
  /// the kit.
  ///
  /// - Parameters:
  ///   - routes: The prefix-completion routes of the host.
  ///   - sigil: The trigger of a kit source, such as `/` or `@`.
  /// - Returns: `true` when a route has `sigil` as its sigil.
  static func routes(_ routes: [PrefixCompletionRoute], take sigil: String) -> Bool {
    routes.contains { $0.sigil == sigil }
  }

  /// The completion engine for `commands`, `root` and `routes`. The session
  /// makes a new engine when the commands, the root or the sigils of the
  /// routes change. New providers of the same sigils need no new engine:
  /// the prefix source reads its routes at each request.
  ///
  /// - Parameters:
  ///   - commands: The slash commands of the session, or `nil` when the agent
  ///     did not report its commands.
  ///   - root: The file root, or `nil`.
  ///   - routes: The prefix-completion routes of the host.
  /// - Returns: The engine.
  func engine(commands: [AvailableCommand]?, root: URL?, routes: [PrefixCompletionRoute]) -> CompletionEngine {
    prefixes.routes = routes
    let sigils = prefixes.routes.map(\.sigil)
    guard engineCommands != commands || engineRoot != root || engineSigils != sigils else { return storedEngine }
    storedEngine = CompletionEngine(sources: Self.sources(commands: commands, root: root, prefixes: prefixes))
    engineCommands = commands
    engineRoot = root
    engineSigils = sigils
    return storedEngine
  }

  /// The completion sources of an engine: the slash commands, unless a
  /// route takes the `/`; the file references, when there is a root; and the
  /// routes of the host, composed with EditorKit `Autocomplete`.
  ///
  /// - Parameters:
  ///   - commands: The slash commands of the session, or `nil`.
  ///   - root: The file root, or `nil`.
  ///   - prefixes: The source of the prefix-completion routes of the host.
  /// - Returns: The sources, in builder order.
  private static func sources(
    commands: [AvailableCommand]?, root: URL?, prefixes: PrefixCompletionSource
  ) -> [any EditorExtensions.CompletionSource] {
    let routes = prefixes.routes
    var sources: [any EditorExtensions.CompletionSource] = []
    if !Self.routes(routes, take: SlashCommandSource.trigger) {
      sources.append(SlashCommandSource(commands: commands))
    }
    if let root {
      sources.append(FileReferenceSource(root: root))
    }
    if !routes.isEmpty {
      sources += editorExtensions { Autocomplete(sources: [.prefixed(prefixes)]) }.completionSources
    }
    return sources
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

#Preview("EditorKit prompt editor") {
  @Previewable @State var text = AttributedString("Why does the build fail?")
  EditorKitPromptEditor(context: PromptEditorContext(text: $text, placeholder: "Ask the agent", onSubmit: {}))
}
