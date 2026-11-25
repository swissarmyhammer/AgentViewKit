import EditorCommandsUI
import EditorStyle
import EditorSwiftUI
import FoundationModelsACPClient
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// The action row of a message (plan.md §9 A, §11 decision 8).
///
/// Make the row for a `UserMessageEntry` or an `AgentMessageEntry` of a
/// `SessionModel` with `init(entry:)`. The row reads the session model from the
/// ``SwiftUI/EnvironmentValues/sessionModel`` environment value, and keeps no
/// copy of the entry or of the transcript. The entry case tells the sender.
///
/// The row has these buttons, in this order:
///
/// - Copy: writes the Markdown of the message
///   (`ThreadExporter.markdown(for:)`) to the `pasteboard` environment value.
/// - Copy thread: the command button of ``AgentCommandVerb/copyThread`` in
///   the agent command scope, whose title, symbol, enabled state and tooltip
///   come from the registry. With no scope, the button writes the same text
///   to the pasteboard (`AgentCommandTarget.plainText(of:)`).
/// - Export: the command button of ``AgentCommandVerb/exportMarkdown`` in the
///   agent command scope, which saves the thread as a Markdown file through a
///   save panel (D202). With no scope, the button makes the same export
///   (`MarkdownExportPresenter.presentExport(of:agentName:)`) and shows the
///   same save panel itself. It is disabled with the same rule and the same
///   reason as the command.
/// - Fork: the command button of ``AgentCommandVerb/forkFromHere`` in the
///   agent command scope, which gives the message to the fork action of the
///   host (D205). The row shows it only when the host gives that action with
///   ``SwiftUI/View/onForkFromHere(unavailableReason:_:)`` and does not turn
///   off ``AgentCommandGroup/fork``, as the registry has the verb only then.
///   With no scope, the button gives the request to the action itself. It is
///   disabled with the same reasons as the command.
/// - Retry, for an agent message only: finds the last `UserMessageEntry`
///   before the message in `SessionModel.transcript`, and sends its content
///   again with `SessionModel.prompt(_:meta:)`.
/// - Edit, for a user message only: puts the text of the message in the
///   composer. The composer must be in the same agent command scope
///   (``SwiftUI/View/agentCommandScope(session:)``). With no scope, the button
///   sets the ``SwiftUI/EnvironmentValues/promptText`` binding.
///
/// With no session model in the environment, the row shows only Copy. For a
/// read-only session (`SessionModel.isReadOnly`, the shared session of
/// TestudoApp D208 (i)), the row shows only Copy, Copy thread and Export:
/// no Fork, Retry or Edit.
///
/// Each button is an EditorKit `EditorToolbarButton` that shows its symbol
/// alone, with its name as its accessibility label and its tooltip.
///
/// Put the row in the footer slot of each message row of the thread view:
///
/// ```swift
/// AgentThreadView(session: session)
///   .messageFooter { entry in MessageActions(entry: entry) }
/// ```
///
/// The text of a message is selectable. The thread has one selection, and a
/// selection does not go across messages (``selectionMode``).
public struct MessageActions: View {
  /// One button of the row.
  public enum Action: String, CaseIterable, Sendable {
    /// Copies the message.
    case copy
    /// Copies the thread.
    case copyThread = "copy-thread"
    /// Saves the thread as a Markdown file: Export as Markdown….
    case export
    /// Gives the message to the fork action of the host: Fork from Here.
    case fork
    /// Sends the last user input again.
    case retry
    /// Puts the text of the user message in the composer.
    case edit

    /// The accessibility identifier of the button, such as `message-copy`.
    public var identifier: String {
      "message-\(rawValue)"
    }

    /// The agent verb whose command button the button is in an agent
    /// command scope, or `nil` when the button runs its action here.
    var verb: AgentCommandVerb? {
      switch self {
      case .copyThread: .copyThread
      case .export: .exportMarkdown
      case .fork: .forkFromHere
      case .copy, .retry, .edit: nil
      }
    }

    /// The name of the button: the title of its ``verb``, when it has one.
    var title: String {
      switch self {
      case .copy: String(localized: "Copy", bundle: .module)
      case .copyThread: AgentCommandVerb.copyThread.title
      case .export: AgentCommandVerb.exportMarkdown.title
      case .fork: AgentCommandVerb.forkFromHere.title
      case .retry: String(localized: "Retry", bundle: .module)
      case .edit: String(localized: "Edit", bundle: .module)
      }
    }

    /// The SF Symbol of the button: the icon of its ``verb``, when it has
    /// one.
    var systemImage: String {
      switch self {
      case .copy: AgentSymbol.copy
      case .copyThread: AgentCommandVerb.copyThread.icon
      case .export: AgentCommandVerb.exportMarkdown.icon
      case .fork: AgentCommandVerb.forkFromHere.icon
      case .retry: EditorSymbol.action(.reload).systemImage
      case .edit: EditorSymbol.tool(.edit).systemImage
      }
    }
  }

  /// How far a text selection goes in a thread.
  public enum SelectionMode: String, Sendable {
    /// A selection stays in one message.
    case perMessage
    /// A selection can go across messages.
    case crossMessage
  }

  /// The selection mode of the kit.
  ///
  /// Research R10 records the probe and the result in
  /// `Docs/decisions/text-selection.md`.
  public static let selectionMode = SelectionMode.perMessage

  /// The message entry of the row.
  let entry: MessageEntry

  @Environment(\.sessionModel) private var session
  @Environment(\.pasteboard) private var pasteboard
  @Environment(\.promptText) private var promptText
  @Environment(\.agentCommandTarget) private var commandTarget
  @Environment(\.connectionModel) private var connection
  @Environment(\.forkFromHere) private var forkFromHere
  @Environment(\.agentCommandGroupsOff) private var groupsOff

  /// The report that gets the method of the prompt that Retry starts, or
  /// `nil`.
  @Environment(\.requestStartReport) private var reportRequestStart

  /// The export of the Export button with no scope that waits for the
  /// save panel.
  @State private var markdownExports = MarkdownExportPresenter()

  private let logger = Logger(subsystem: "AgentViewKit", category: "MessageActions")

  /// Makes the action row of a user message entry of a session model.
  ///
  /// - Parameter entry: The entry of `SessionModel.transcript`. The row
  ///   reads its content at each action.
  public init(entry: UserMessageEntry) {
    self.entry = .user(entry)
  }

  /// Makes the action row of an agent message entry of a session model.
  ///
  /// - Parameter entry: The entry of `SessionModel.transcript`. The row
  ///   reads its content at each action.
  public init(entry: AgentMessageEntry) {
    self.entry = .agent(entry)
  }

  /// Makes the action row of a message entry of a session model, such as
  /// the entry that the ``SwiftUI/EnvironmentValues/messageFooter`` slot
  /// gives.
  ///
  /// - Parameter entry: The user message entry or the agent message entry of
  ///   `SessionModel.transcript`. The row reads its content at each action.
  public init(entry: MessageEntry) {
    self.entry = entry
  }

  public var body: some View {
    ControlStack(.horizontal) {
      ForEach(actionsToShow, id: \.self) { action in
        button(for: action)
          .accessibilityIdentifier(action.identifier)
      }
    }
    .editorButtonCaptions(.hidden)
    .modifier(MarkdownExportPresentation(presenter: markdownExports))
  }

  /// The button of `action`: the command button of the ``Action/verb`` of
  /// the action in an agent command scope, else a button that runs the
  /// action here. A button with no scope is disabled with the reason of
  /// ``disabledReason(of:in:)`` as its tooltip, as the command button is.
  ///
  /// - Parameter action: The action of the button.
  /// - Returns: The button.
  @ViewBuilder
  private func button(for action: Action) -> some View {
    if let verb = action.verb, commandTarget != nil {
      EditorToolbarButton(command: verb.id)
        .withoutSystemFocusEffect()
    } else {
      // The row hides the captions, so the tooltip of an enabled button is
      // its title, as the button itself gives it.
      let reason = disabledReason(of: action)
      EditorToolbarButton(action.title, systemImage: action.systemImage) { perform(action) }
        .disabled(reason != nil)
        .help(reason ?? action.title)
        .withoutSystemFocusEffect()
    }
  }

  /// The buttons for the message, in display order.
  private var actionsToShow: [Action] {
    guard let session else { return [.copy] }
    let canFork = forkFromHere != nil && !groupsOff.contains(.fork)
    return Self.actions(for: entry.role, canFork: canFork, isReadOnly: session.isReadOnly)
  }

  /// The reason that the button of `action` with no command scope is
  /// disabled, or `nil` when the button is enabled: the reason of the fork
  /// action for Fork, else ``disabledReason(of:in:)``.
  ///
  /// - Parameter action: The action of the button.
  /// - Returns: The reason, or `nil`.
  private func disabledReason(of action: Action) -> String? {
    if action == .fork { return forkFromHere?.unavailableReason(for: entry) }
    return session.flatMap { Self.disabledReason(of: action, in: $0) }
  }

  /// The Markdown of the message: `ThreadExporter.markdown(for:)`, read at
  /// each call.
  private var markdown: String {
    ThreadExporter.markdown(for: entry.content)
  }

  /// The buttons for a message of `role`, in display order.
  ///
  /// A read-only session (TestudoApp D208 (i)) cannot change, so its row
  /// shows only the buttons that read: Copy, Copy thread and Export. It
  /// shows no Fork, Retry or Edit, because the registry of a read-only
  /// thread has no Fork from Here and the thread has no composer.
  ///
  /// - Parameters:
  ///   - role: The sender of the message.
  ///   - canFork: Tells if the row shows Fork, after Export: the host gives
  ///     the fork action, so the registry has the verb.
  ///   - isReadOnly: Tells if the session of the message is read-only
  ///     (`SessionModel.isReadOnly`).
  /// - Returns: The buttons.
  static func actions(for role: MessageRole, canFork: Bool, isReadOnly: Bool) -> [Action] {
    let read: [Action] = [.copy, .copyThread, .export]
    guard !isReadOnly else { return read }
    let fork: [Action] = canFork ? [.fork] : []
    switch role {
    case .user: return read + fork + [.edit]
    case .assistant: return read + fork + [.retry]
    }
  }

  /// The reason that the button of `action` with no command scope is
  /// disabled, or `nil` when the button is enabled.
  ///
  /// The rule and the reason are the same as for the command of the
  /// ``Action/verb`` of the action in a scope. Export is disabled when the
  /// session has no history (``SessionMarkdownExport/hasHistory(_:)``),
  /// with ``SessionMarkdownExport/noHistoryReason``. Fork reads the fork
  /// action of the host and not the session, so this call gives no reason
  /// for it. The other buttons are always enabled.
  ///
  /// - Parameters:
  ///   - action: The action of the button.
  ///   - session: The session model of the row.
  /// - Returns: The reason, or `nil`.
  static func disabledReason(of action: Action, in session: SessionModel) -> String? {
    switch action {
    case .export:
      SessionMarkdownExport.hasHistory(session) ? nil : SessionMarkdownExport.noHistoryReason
    case .copy, .copyThread, .fork, .retry, .edit: nil
    }
  }

  /// The last user message entry before the entry of `id` in a transcript.
  ///
  /// - Parameters:
  ///   - id: The identity of an entry.
  ///   - transcript: The entries of `SessionModel.transcript`.
  /// - Returns: The user message entry, or `nil` when the transcript does
  ///   not hold the entry of `id`, or holds no user message entry before it.
  static func lastUserEntry(
    before id: TranscriptEntry.ID, in transcript: [TranscriptEntry]
  ) -> UserMessageEntry? {
    guard let position = transcript.firstIndex(where: { $0.id == id }) else { return nil }
    return transcript[..<position].reversed().lazy.compactMap { entry -> UserMessageEntry? in
      guard case .userMessage(let user) = entry else { return nil }
      return user
    }.first
  }

  /// Runs the action of a button.
  ///
  /// - Parameter action: The button.
  private func perform(_ action: Action) {
    switch action {
    case .copy: pasteboard.copyText(markdown)
    case .copyThread: copyThread()
    case .export: export()
    case .fork: fork()
    case .retry: retry()
    case .edit: edit()
    }
  }

  /// Copies the thread directly, with the same text as the command, for a
  /// row in no command scope.
  private func copyThread() {
    guard let session else { return }
    pasteboard.copyText(AgentCommandTarget.plainText(of: session))
  }

  /// Shows the save panel with the same export as
  /// ``AgentCommandVerb/exportMarkdown``, for a row in no command scope.
  /// The button is disabled when the thread has no history
  /// (``disabledReason(of:in:)``).
  private func export() {
    guard let session else { return }
    markdownExports.presentExport(of: session, agentName: connection?.agentName)
  }

  /// Gives the request of this message to the fork action of the host, for
  /// a row in no command scope. The button is disabled when the action
  /// gives a reason (``ForkFromHereAction/unavailableReason(for:)``).
  private func fork() {
    guard let forkFromHere, let request = ForkFromHereRequest(entry: entry) else {
      logger.error("Fork from Here found no fork action or no message ID for \(entry.id.rowKey, privacy: .private).")
      return
    }
    forkFromHere.perform(request)
  }

  /// Sends the content of the last user message entry before the entry of
  /// this row again, with `SessionModel.prompt(_:meta:)`.
  private func retry() {
    let id = entry.id
    guard let session, let user = Self.lastUserEntry(before: id, in: session.transcript) else {
      logger.error("Retry found no user message entry before \(id.rowKey, privacy: .private).")
      return
    }
    session.startPrompt(content: user.content, reporting: reportRequestStart)
  }

  /// Puts the text of this message in the composer.
  private func edit() {
    let text = markdown
    if let composer = commandTarget?.composer {
      composer.load(text)
      _ = composer.focus()
    } else if let promptText {
      promptText.wrappedValue = AttributedString(text)
    } else {
      logger.error("Edit found no composer for \(entry.id.rowKey, privacy: .private).")
    }
  }
}

/// A Markdown document for the file exporter.
nonisolated struct MarkdownDocument: ExportOnlyDocument {
  /// The type of the document.
  static let contentType = UTType.markdown

  /// The exporter does not read documents.
  static let readableContentTypes: [UTType] = [contentType]

  /// The text of the document.
  let text: String

  /// Makes a document with `text`.
  ///
  /// - Parameter text: The Markdown text.
  init(text: String) {
    self.text = text
  }

  /// Writes the text as UTF-8.
  ///
  /// - Parameter configuration: The write configuration.
  /// - Returns: A file wrapper with the text.
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(text.utf8))
  }
}

#Preview("Message actions") {
  let session = SessionModel.previewSample
  if let entry = PreviewFixtures.firstEntry(in: session, as: AgentMessageEntry.self) {
    MessageActions(entry: entry)
      .environment(\.sessionModel, session)
  }
}
