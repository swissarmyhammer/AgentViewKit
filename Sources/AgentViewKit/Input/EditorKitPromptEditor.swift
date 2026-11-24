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
/// The editor hosts an EditorKit `EditorView` that takes the height of its
/// text and grows and shrinks as the text changes, from one line up. It has no
/// height bound and no scroll of its own (EditorKit `style.md`, "A multiline
/// field fits its content"): its host bounds it and scrolls a longer text, as
/// ``PromptInputView`` does. The editor reads the EditorKit theme of the
/// environment. Return calls
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

  /// The smallest height of the editor, in points at the default theme font.
  static let minimumHeight: CGFloat = 36

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

  /// The largest height of the completion list, in points at the default theme
  /// font.
  static let completionListMaximumHeight: CGFloat = 160

  /// The width of the completion list, in points at the default theme font.
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
  @Environment(\.composerMentionSources) private var mentionSources
  @Environment(\.composerMentionResolver) private var resolver
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  /// The scale of the editor, whose text is in the display font.
  @ThemeFontScale(.display) private var editorFontScale

  /// The scale of the completion list, whose rows are in the ui font.
  @ThemeFontScale(.ui) private var completionFontScale

  /// The model and the completion engine of the editor.
  @State private var session: PromptEditorSession

  /// The paths of the accepted file references, relative to the file root.
  @State private var references: Set<String> = []

  /// The accepted mentions, by their token without the `@`. The value is
  /// the link of the row, or `nil` for a row with no link (D199).
  @State private var mentions: [String: URL?] = [:]

  /// The answers of the mention resolver of the host, by token (D199 (h)).
  @State private var mentionStates: [String: ComposerMentionState?] = [:]

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
    .sizedToContent()
    .editorPlaceholder(context.placeholder)
    .editorInlineDecorations([
      EditorSwiftUI.SmartTag(.token, detect: FileReferenceDetector(paths: references)),
      EditorSwiftUI.SmartTag(.token, detect: MentionDetector(tokens: Set(mentions.keys))),
      EditorSwiftUI.SmartTag(.mark, detect: MentionMarkDetector(states: mentionStates)),
    ])
    // The identifier and the label go on the text view that takes typing, so
    // that a UI test finds one element to type into, and VoiceOver names it.
    .editorTextAccessibilityIdentifier(Self.identifier)
    .editorTextAccessibilityLabel(context.placeholder)
    // The prompt is text that a person types, so it draws in the display
    // font of the theme and not in the code font of an `EditorView`.
    .editorFontRole(.display)
    .frame(minHeight: Self.minimumHeight * editorFontScale)
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
          width: Self.completionListWidth * completionFontScale, content: content)
      }
    }
    .onChange(of: context.text.wrappedValue, initial: true) { _, text in
      promptTextDidChange(text, in: model)
    }
    .onChange(of: resolver?.revision) {
      mentionStates = [:]
      session.resetMentionResolution(revision: resolver?.revision)
      resolveMentions(in: model)
    }
    .onChange(of: context.insertions?.count) {
      for text in context.insertions?.take() ?? [] {
        insert(text, in: model)
      }
    }
  }

  /// Inserts `text` at the caret as typed input, so the editor asks for
  /// completions there: an `@` opens the `@` popup
  /// (``AgentCommandVerb/insertMention``).
  ///
  /// - Parameters:
  ///   - text: The text to insert.
  ///   - model: The model of the editor.
  private func insert(_ text: String, in model: EditorModel) {
    let document = model.state.document
    let caret = model.selection.primary.head.utf8Offset
    let inserted = Self.insertion(of: text, after: caretLine(in: model))
    let end = EditorPosition(utf8Offset: caret + inserted.utf8.count, version: document.version.next())
    var annotations = TransactionAnnotations()
    annotations.userEvent = .input
    model.dispatch(
      EditorTransaction(
        changes: ChangeSet(fromLength: document.utf8Count, replacements: [(caret..<caret, inserted)]),
        selection: .cursor(end), annotations: annotations))
  }

  /// Asks the mention resolver of the host about each new `@` token of the
  /// text (D199 (h)).
  ///
  /// The editor asks one time for each token, and not for the token at the
  /// caret. An answer that comes after a change of the revision is dropped.
  /// A resolved token becomes a mention chip with its link.
  ///
  /// - Parameter model: The model of the editor.
  private func resolveMentions(in model: EditorModel) {
    guard let resolver else { return }
    let tokens = ComposerMentionMarks.tokensToResolve(
      in: model.text, caret: model.selection.primary.head.utf8Offset, fileRoot: kitFileRoot,
      chips: references.union(mentions.keys), known: Set(mentionStates.keys).union(session.pendingMentionTokens))
    for token in tokens {
      session.pendingMentionTokens.insert(token)
      let revision = resolver.revision
      Task { @MainActor in
        let state = await resolver.resolve(token)
        guard session.mentionResolverRevision == revision || session.mentionResolverRevision == nil else { return }
        session.pendingMentionTokens.remove(token)
        mentionStates.updateValue(state, forKey: token)
        if case .resolved(let link) = state {
          mentions.updateValue(link, forKey: token)
          push(model.text, references: references, mentions: mentions)
        }
      }
    }
  }

  /// The text that an insert at the caret adds: `text`, after a space when
  /// the character before the caret is not white space.
  ///
  /// - Parameters:
  ///   - text: The text to insert.
  ///   - line: The text of the caret line before the caret.
  /// - Returns: The text to add.
  static func insertion(of text: String, after line: Substring) -> String {
    guard let last = line.last, !last.isWhitespace else { return text }
    return " " + text
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
  /// Each row is EditorKit's `EditorCompletionRow`, the row of EditorKit's own
  /// completion popup, named ``completionRowIdentifier``. The list has the
  /// row's `EditorCompletionRow.listMargin` as its horizontal scroll content
  /// margin, as EditorKit's popup does, so the rows line up with the popup's.
  /// Its vertical scroll content margin is the extra small spacing step, so
  /// the selection surfaces of the first and the last row stand clear of the
  /// top and the bottom edges of the menu.
  ///
  /// - Parameters:
  ///   - completion: The open session.
  ///   - model: The model of the editor.
  /// - Returns: The list, with no glass.
  private func completionList(_ completion: CompletionSessionState, model: EditorModel) -> some View {
    CompletionSuggestionsList(
      items: completion.listedItems, selectedIndex: completion.listedSelectedIndex, id: \.label,
      row: { item, isSelected in
        EditorCompletionRow(item: item, isSelected: isSelected, identifier: Self.completionRowIdentifier)
      },
      onCommit: { item in accept(item, in: model) }
    )
    .scrollContentMargins(EditorCompletionRow.listMargin, edges: .horizontal)
    .scrollContentMargins(\.spacing.xs, edges: .vertical)
    .frame(width: Self.completionListWidth * completionFontScale)
    .frame(maxHeight: Self.completionListMaximumHeight * completionFontScale)
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
      .frame(width: Self.completionListWidth * completionFontScale, alignment: .leading)
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
    push(model.text, references: references, mentions: mentions)
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
    var acceptedReferences: Set<String> = []
    var acceptedMentions: [String: URL?] = [:]
    switch transaction.annotations.userEvent {
    case .input, .delete:
      updateCompletion(in: model)
    case .completionAccept:
      let line = caretLine(in: model)
      if let path = Self.acceptedFile(before: line, root: kitFileRoot) {
        acceptedReferences.insert(path)
      } else if let token = Self.acceptedMentionToken(before: line), let link = session.offeredMention(token) {
        acceptedMentions.updateValue(link, forKey: token)
      }
      didAccept(in: model)
    default:
      break
    }
    // A host composer with an async submit hook clears the prompt after the
    // Return, in a later task. A commit that comes after that clear, and
    // before the change of the prompt reaches the editor, must not give the
    // old text back. So a prompt text that changed outside the editor goes
    // to the editor, and the editor pushes nothing. The file reference or the
    // mention that this commit accepted stays recorded.
    let promptText = context.text.wrappedValue
    guard !session.isChangedOutside(promptText) else {
      pull(promptText, into: model, keeping: acceptedReferences, mentions: acceptedMentions)
      return
    }
    record(acceptedReferences, mentions: acceptedMentions)
    push(model.text, references: references, mentions: mentions)
    resolveMentions(in: model)
  }

  /// Records the file references and the mentions that an accept added.
  ///
  /// - Parameters:
  ///   - acceptedReferences: The paths of the accepted file references.
  ///   - acceptedMentions: The accepted mentions and their links.
  private func record(_ acceptedReferences: Set<String>, mentions acceptedMentions: [String: URL?]) {
    if !acceptedReferences.isEmpty {
      references.formUnion(acceptedReferences)
    }
    if !acceptedMentions.isEmpty {
      mentions.merge(acceptedMentions) { _, accepted in accepted }
    }
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
      caretLine(in: model), reportsCommands: kitCommands != nil, hasAtSource: hasAtSource)
    guard isTrigger || Self.isRouteToken(at: caret, in: editor, routes: routes) else {
      dismissCompletion(in: model)
      return
    }
    session.engine(commands: kitCommands, root: kitFileRoot, routes: routes, mentions: kitMentionSources)
      .request(trigger: .typed, in: editor)
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

  /// The mention sources of the `@` source of the kit (D199).
  ///
  /// - Returns: No source when a route of the host takes the `@`.
  private var kitMentionSources: [ComposerMentionSource] {
    PromptEditorSession.routes(routes, take: FileReferenceSource.trigger) ? [] : mentionSources
  }

  /// Whether the kit answers `@`: it has a file root or a mention source.
  private var hasAtSource: Bool {
    kitFileRoot != nil || !kitMentionSources.isEmpty
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
  ///   - hasAtSource: Whether the kit answers `@`: the editor has a file
  ///     root or a mention source.
  /// - Returns: `true` for a `/` token at the start of the line, or for a run
  ///   that starts with `@` after white space.
  static func isTrigger(_ line: Substring, reportsCommands: Bool, hasAtSource: Bool) -> Bool {
    if reportsCommands, line.hasPrefix(SlashCommandSource.trigger),
      line.dropFirst(SlashCommandSource.trigger.count).allSatisfy(CompletionTokenizer.isWordCharacter)
    {
      return true
    }
    let run = Self.lastRun(of: line)
    return hasAtSource && run.hasPrefix(FileReferenceSource.trigger)
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
  ///   - mentions: The accepted mentions and their links.
  private func push(_ text: String, references: Set<String>, mentions: [String: URL?]) {
    let attributed = Self.attributedText(text, references: references, root: kitFileRoot, mentions: mentions)
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
  /// (``references(in:root:keeping:)``), the inverse of
  /// ``push(_:references:)``. So the next push gives each linked file its
  /// link again.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - model: The model of the editor.
  ///   - keptReferences: The paths of the file references that an accept
  ///     recorded, which stay recorded.
  ///   - keptMentions: The mentions that an accept recorded, which stay
  ///     recorded.
  private func pull(
    _ text: AttributedString, into model: EditorModel, keeping keptReferences: Set<String> = [],
    mentions keptMentions: [String: URL?] = [:]
  ) {
    session.didPull(text)
    references = Self.references(in: text, root: kitFileRoot, keeping: keptReferences)
    mentions = Self.mentions(in: text, root: kitFileRoot, keeping: keptMentions)
    let plain = String(text.characters)
    guard plain != model.text else { return }
    model.replaceAll(plain)
    resolveMentions(in: model)
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

  /// The accepted mentions of a prompt text: the inverse of
  /// ``attributedText(_:references:root:mentions:)`` for the mentions.
  ///
  /// Each `link` attribute on a run of `@` and a token is one mention,
  /// unless the link is a file URL under `root`. A mention with no link has
  /// no attribute, so it does not come back.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - root: The file root, or `nil`.
  /// - Returns: The link of each mention, by its token without the `@`.
  static func mentions(in text: AttributedString, root: URL?) -> [String: URL?] {
    var result: [String: URL?] = [:]
    for run in text.runs {
      guard let link = run.link, root.flatMap({ relativePath(of: link, under: $0) }) == nil else { continue }
      let run = String(text[run.range].characters)
      guard run.hasPrefix(FileReferenceSource.trigger) else { continue }
      result.updateValue(link, forKey: String(run.dropFirst(FileReferenceSource.trigger.count)))
    }
    return result
  }

  /// The accepted file references after the editor takes a prompt text.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - root: The file root, or `nil`.
  ///   - kept: The paths of the file references that an accept recorded.
  ///     They stay when the text has no link for them, for example after a
  ///     clear outside the editor.
  /// - Returns: The references of `text` (``references(in:root:)``) and
  ///   `kept`.
  static func references(in text: AttributedString, root: URL?, keeping kept: Set<String>) -> Set<String> {
    references(in: text, root: root).union(kept)
  }

  /// The accepted mentions after the editor takes a prompt text.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - root: The file root, or `nil`.
  ///   - kept: The mentions that an accept recorded, and their links. They
  ///     stay when the text has no link for them, for example after a clear
  ///     outside the editor.
  /// - Returns: The mentions of `text` (``mentions(in:root:)``) and `kept`.
  ///   A kept link replaces the link of the text for the same token.
  static func mentions(in text: AttributedString, root: URL?, keeping kept: [String: URL?]) -> [String: URL?] {
    mentions(in: text, root: root).merging(kept) { _, accepted in accepted }
  }

  /// The token of the mention that an accept just inserted.
  ///
  /// - Parameter line: The text of the caret line before the caret.
  /// - Returns: The token without the `@`, when the text ends in `@`, a
  ///   token, and a space. `nil` otherwise.
  static func acceptedMentionToken(before line: Substring) -> String? {
    guard line.hasSuffix(" ") else { return nil }
    let run = Self.lastRun(of: line.dropLast())
    guard run.hasPrefix(FileReferenceSource.trigger), run.count > FileReferenceSource.trigger.count else { return nil }
    return String(run.dropFirst(FileReferenceSource.trigger.count))
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
  /// URL. Each accepted mention with a link gets a `link` attribute that
  /// holds that link (D199). A file reference wins over a mention with the
  /// same token.
  ///
  /// - Parameters:
  ///   - text: The text of the editor.
  ///   - references: The paths of the accepted file references.
  ///   - root: The file root, or `nil`.
  ///   - mentions: The accepted mentions and their links.
  /// - Returns: The attributed text.
  static func attributedText(
    _ text: String, references: Set<String>, root: URL?, mentions: [String: URL?] = [:]
  ) -> AttributedString {
    var result = AttributedString(text)
    let fileReferences = root == nil ? [] : references
    guard !fileReferences.isEmpty || !mentions.isEmpty else { return result }
    for reference in FileReferenceDetector.references(in: text) {
      let link: URL?
      if let root, fileReferences.contains(reference.path) {
        link = root.appending(path: reference.path)
      } else if let mention = mentions[reference.path] {
        link = mention
      } else {
        continue
      }
      guard let link else { continue }
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
      result[range].link = link
    }
    return result
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

  /// Whether the engine has mention sources.
  private var engineHasMentions = false

  /// The mention sources of the host.
  ///
  /// The session keeps one list and gives it the newest sources before each
  /// request, so new sources take effect at the next keystroke.
  private let mentions = ComposerMentionSources([])

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
    storedEngine = CompletionEngine(
      sources: Self.sources(commands: nil, root: nil, prefixes: prefixes, mentions: mentions))
  }

  /// The newest text that the editor gave to the text of the prompt, until
  /// the editor takes a text from the prompt.
  private var pushedText: AttributedString?

  /// The newest text that the editor gave to the prompt or took from it, or
  /// `nil` before the first push or pull. A different text of the prompt
  /// comes from a change outside the editor.
  private var syncedText: AttributedString?

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
    syncedText = text
  }

  /// Forgets the newest pushed text, because the editor takes a text from
  /// the prompt.
  ///
  /// - Parameter text: The text that the editor takes from the prompt.
  func didPull(_ text: AttributedString) {
    pushedText = nil
    syncedText = text
  }

  /// Whether the text of the prompt changed outside the editor.
  ///
  /// - Parameter promptText: The text of the prompt.
  /// - Returns: `true` when the editor gave or took a text, and `promptText`
  ///   is not the newest of those texts. `false` before the first push or
  ///   pull.
  func isChangedOutside(_ promptText: AttributedString) -> Bool {
    guard let syncedText else { return false }
    return promptText != syncedText
  }

  /// Whether a text of the prompt is the newest text that the editor gave.
  ///
  /// - Parameter text: The text of the prompt.
  /// - Returns: `true` when the editor gave `text` and took no text from the
  ///   prompt after that.
  func isNewestPush(_ text: AttributedString) -> Bool {
    text == pushedText
  }

  /// The link of the row of the last mention query with `token`.
  ///
  /// - Parameter token: The text after `@`.
  /// - Returns: `nil` when the last query had no row with the token;
  ///   `.some(nil)` for a row with no link.
  func offeredMention(_ token: String) -> URL?? {
    mentions.offered(token)
  }

  /// The tokens that wait for an answer of the mention resolver.
  var pendingMentionTokens: Set<String> = []

  /// The revision of the mention resolver that the answers belong to, or
  /// `nil` before the first change of the revision.
  private(set) var mentionResolverRevision: AnyHashable?

  /// Forgets the tokens that wait for an answer, after a change of the
  /// revision of the resolver.
  ///
  /// - Parameter revision: The new revision.
  func resetMentionResolution(revision: AnyHashable?) {
    pendingMentionTokens = []
    mentionResolverRevision = revision
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

  /// The completion engine for `commands`, `root`, `routes` and `mentions`.
  /// The session makes a new engine when the commands, the root, the sigils
  /// of the routes, or the presence of mention sources change. New providers
  /// of the same sigils and new mention sources need no new engine: the
  /// sources read them at each request.
  ///
  /// - Parameters:
  ///   - commands: The slash commands of the session, or `nil` when the agent
  ///     did not report its commands.
  ///   - root: The file root, or `nil`.
  ///   - routes: The prefix-completion routes of the host.
  ///   - mentions: The mention sources of the `@` source of the kit.
  /// - Returns: The engine.
  func engine(
    commands: [AvailableCommand]?, root: URL?, routes: [PrefixCompletionRoute],
    mentions mentionSources: [ComposerMentionSource] = []
  ) -> CompletionEngine {
    prefixes.routes = routes
    mentions.sources = mentionSources
    let sigils = prefixes.routes.map(\.sigil)
    let hasMentions = !mentionSources.isEmpty
    guard
      engineCommands != commands || engineRoot != root || engineSigils != sigils
        || engineHasMentions != hasMentions
    else { return storedEngine }
    storedEngine = CompletionEngine(
      sources: Self.sources(commands: commands, root: root, prefixes: prefixes, mentions: mentions))
    engineCommands = commands
    engineRoot = root
    engineSigils = sigils
    engineHasMentions = hasMentions
    return storedEngine
  }

  /// The completion sources of an engine: the slash commands, unless a
  /// route takes the `/`; the `@` source of the kit; and the routes of the
  /// host, composed with EditorKit `Autocomplete`.
  ///
  /// The `@` source is the ``FileReferenceSource`` of the root when the
  /// host gives no mention source. With a mention source, it is an
  /// ``AtReferenceSource``: the file rows, when there is a root, then the
  /// mention rows (D199).
  ///
  /// - Parameters:
  ///   - commands: The slash commands of the session, or `nil`.
  ///   - root: The file root, or `nil`.
  ///   - prefixes: The source of the prefix-completion routes of the host.
  ///   - mentions: The mention sources of the host.
  /// - Returns: The sources, in builder order.
  static func sources(
    commands: [AvailableCommand]?, root: URL?, prefixes: PrefixCompletionSource,
    mentions: ComposerMentionSources
  ) -> [any EditorExtensions.CompletionSource] {
    let routes = prefixes.routes
    var sources: [any EditorExtensions.CompletionSource] = []
    if !Self.routes(routes, take: SlashCommandSource.trigger) {
      sources.append(SlashCommandSource(commands: commands))
    }
    let files = root.map(FileReferenceSource.init(root:))
    if !mentions.sources.isEmpty {
      sources.append(AtReferenceSource(files: files, mentions: mentions))
    } else if let files {
      sources.append(files)
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
