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
/// - Copy: writes the Markdown of the message (the content form of
///   `ThreadExporter.markdown(for:)`) to the `pasteboard` environment value.
/// - Copy thread: runs ``AgentCommandVerb/copyThread`` in the agent command
///   scope. With no scope, the button writes the same text to the
///   pasteboard (`AgentCommandTarget.plainText(of:)`).
/// - Export: saves the message entries of `SessionModel.transcript` as a
///   Markdown file (the transcript form of `ThreadExporter.markdown(for:)`).
/// - Retry, for an agent message only: finds the last `UserMessageEntry`
///   before the message in `SessionModel.transcript`, and sends its content
///   again with `SessionModel.prompt(_:meta:)`.
/// - Edit, for a user message only: puts the text of the message in the
///   composer. The composer must be in the same agent command scope
///   (``SwiftUI/View/agentCommandScope(thread:)``). With no scope, the button
///   sets the ``SwiftUI/EnvironmentValues/promptText`` binding.
///
/// With no session model in the environment, the row shows only Copy.
///
/// The deprecated thread path makes the row for a kit message with
/// ``init(message:)``, in the footer slot of the message views:
///
/// ```swift
/// AgentThreadView(thread: thread, actions: actions)
///   .messageFooter { message in MessageActions(message: message) }
/// ```
///
/// That row reads the `agentThread` and `threadActions` environment values in
/// the same way, and goes away with the kit session model.
///
/// The text of a message is selectable, one message at a time
/// (``selectionMode``).
public struct MessageActions: View {
  /// One button of the row.
  public enum Action: String, CaseIterable, Sendable {
    /// Copies the message.
    case copy
    /// Copies the thread.
    case copyThread = "copy-thread"
    /// Saves the thread as a Markdown file.
    case export
    /// Sends the last user input again.
    case retry
    /// Puts the text of the user message in the composer.
    case edit

    /// The accessibility identifier of the button, such as `message-copy`.
    public var identifier: String {
      "message-\(rawValue)"
    }

    /// The name of the button.
    var title: String {
      switch self {
      case .copy: String(localized: "Copy")
      case .copyThread: String(localized: "Copy Thread")
      case .export: String(localized: "Export Thread")
      case .retry: String(localized: "Retry")
      case .edit: String(localized: "Edit")
      }
    }

    /// The SF Symbol of the button.
    var systemImage: String {
      switch self {
      case .copy: "doc.on.doc"
      case .copyThread: "doc.on.clipboard"
      case .export: "square.and.arrow.up"
      case .retry: "arrow.clockwise"
      case .edit: "pencil"
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

  /// The name of an exported file, with no extension.
  static var exportFilename: String {
    String(localized: "Thread")
  }

  /// The message of a row.
  enum Subject {
    /// A kit message of a deprecated thread.
    case message(Message)

    /// A user message entry of a session model.
    case user(UserMessageEntry)

    /// An agent message entry of a session model.
    case agent(AgentMessageEntry)
  }

  /// The message of the row.
  let subject: Subject

  @Environment(\.sessionModel) private var session
  @Environment(\.agentThread) private var thread
  @Environment(\.threadActions) private var actions
  @Environment(\.pasteboard) private var pasteboard
  @Environment(\.promptText) private var promptText
  @Environment(\.agentCommandTarget) private var commandTarget

  @State private var exportDocument: MarkdownDocument?

  private let logger = Logger(subsystem: "AgentViewKit", category: "MessageActions")

  /// Makes the action row of a user message entry of a session model.
  ///
  /// - Parameter entry: The entry of `SessionModel.transcript`. The row
  ///   reads its content at each action.
  public init(entry: UserMessageEntry) {
    subject = .user(entry)
  }

  /// Makes the action row of an agent message entry of a session model.
  ///
  /// - Parameter entry: The entry of `SessionModel.transcript`. The row
  ///   reads its content at each action.
  public init(entry: AgentMessageEntry) {
    subject = .agent(entry)
  }

  /// Makes the action row of a kit message of a deprecated thread.
  ///
  /// - Parameter message: The message of the row.
  public init(message: Message) {
    subject = .message(message)
  }

  public var body: some View {
    HStack {
      ForEach(actionsToShow, id: \.self) { action in
        Button(action.title, systemImage: action.systemImage) { perform(action) }
          .help(action.title)
          .accessibilityIdentifier(action.identifier)
      }
    }
    .labelStyle(.iconOnly)
    .buttonStyle(.glass)
    .foregroundStyle(.secondary)
    .fileExporter(
      isPresented: Binding(
        get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
      document: exportDocument,
      contentType: MarkdownDocument.contentType,
      defaultFilename: Self.exportFilename,
      onCompletion: { FileExportLog.record($0, of: Self.exportFilename, to: logger) }
    )
  }

  /// The buttons for the message, in display order.
  private var actionsToShow: [Action] {
    guard source != nil else { return [.copy] }
    return Self.actions(for: role)
  }

  /// The model that holds the message: the session model of the environment
  /// for an entry, or the thread of the environment for a kit message.
  private var source: ConversationSource? {
    switch subject {
    case .user, .agent: session.map(ConversationSource.session)
    case .message: thread.map(ConversationSource.thread)
    }
  }

  /// The sender of the message: the entry case, or the item case of the kit
  /// message in the thread.
  private var role: MessageRole? {
    switch subject {
    case .user: .user
    case .agent: .assistant
    case .message(let message): thread.flatMap { Self.role(of: message, in: $0) }
    }
  }

  /// The Markdown of the message: the content form of
  /// `ThreadExporter.markdown(for:)` for an entry, read at each call.
  private var markdown: String {
    switch subject {
    case .user(let entry): ThreadExporter.markdown(for: entry.content)
    case .agent(let entry): ThreadExporter.markdown(for: entry.content)
    case .message(let message): ThreadExporter.markdown(for: message)
    }
  }

  /// The text that Edit puts in the composer: the Markdown of an entry, or
  /// the text blocks of a kit message.
  private var editText: String {
    guard case .message(let message) = subject else { return markdown }
    return Self.input(of: message).text
  }

  /// The identity of the message in the log: the row key of an entry, or the
  /// id of a kit message.
  private var logKey: String {
    switch subject {
    case .user(let entry): entry.id.rowKey
    case .agent(let entry): entry.id.rowKey
    case .message(let message): message.id
    }
  }

  /// The buttons for a message of `role`, in display order.
  ///
  /// - Parameter role: The sender of the message, or `nil` when the thread
  ///   does not hold the message.
  /// - Returns: The buttons.
  static func actions(for role: MessageRole?) -> [Action] {
    switch role {
    case .user: [.copy, .copyThread, .export, .edit]
    case .assistant: [.copy, .copyThread, .export, .retry]
    case nil: [.copy, .copyThread, .export]
    }
  }

  /// The sender of `message` in `thread`.
  ///
  /// - Parameters:
  ///   - message: The message.
  ///   - thread: The thread.
  /// - Returns: The sender, or `nil` when the thread does not hold the message.
  static func role(of message: Message, in thread: AgentThread) -> MessageRole? {
    switch thread.item(id: message.id) {
    case .userMessage: .user
    case .assistantMessage: .assistant
    default: nil
    }
  }

  /// The input of a user message: its text blocks and its attachments.
  ///
  /// - Parameter message: The user message.
  /// - Returns: The input. A blank line separates two text blocks.
  static func input(of message: Message) -> UserInput {
    var texts: [String] = []
    var attachments: [URL] = []
    for block in message.blocks {
      switch block.content {
      case .text(let text): texts.append(text)
      case .attachment(let url): attachments.append(url)
      case .image, .audio, .resourceLink, .resource, .unknown: break
      }
    }
    return UserInput(text: texts.joined(separator: "\n\n"), attachments: attachments)
  }

  /// The last user message before the message of `id` in `thread`.
  ///
  /// - Parameters:
  ///   - id: The identifier of the message.
  ///   - thread: The thread.
  /// - Returns: The user message, or `nil` when there is none.
  static func lastUserMessage(before id: String, in thread: AgentThread) -> Message? {
    guard let position = thread.position(of: id) else { return nil }
    return thread.items[..<position].reversed().lazy.compactMap { item -> Message? in
      guard case .userMessage(let message) = item else { return nil }
      return message
    }.first
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
    case .retry: retry()
    case .edit: edit()
    }
  }

  /// Copies the thread through the command scope, or directly when there is
  /// no scope, with the same text as the command.
  private func copyThread() {
    guard let source, commandTarget?.perform(.copyThread) != true else { return }
    pasteboard.copyText(AgentCommandTarget.plainText(of: source))
  }

  /// Shows the file exporter with the Markdown of the model: the message
  /// entries of the transcript of a session model, or the items of a thread.
  private func export() {
    let text: String
    switch source {
    case .session(let session): text = ThreadExporter.markdown(for: session.transcript)
    case .thread(let thread): text = ThreadExporter.markdown(for: thread)
    case nil: return
    }
    exportDocument = MarkdownDocument(text: text)
  }

  /// Sends the last user message before this message again.
  ///
  /// For an entry, the content of the last `UserMessageEntry` before the
  /// entry goes out with `SessionModel.prompt(_:meta:)`. For a kit message,
  /// the input goes through the thread actions.
  private func retry() {
    switch subject {
    case .user(let entry): retryEntry(before: entry.id)
    case .agent(let entry): retryEntry(before: entry.id)
    case .message(let message): retryMessage(before: message.id)
    }
  }

  /// Sends the content of the last user message entry before the entry of
  /// `id` again.
  ///
  /// - Parameter id: The identity of the entry of the row.
  private func retryEntry(before id: TranscriptEntry.ID) {
    guard let session, let user = Self.lastUserEntry(before: id, in: session.transcript) else {
      logger.error("Retry found no user message entry before \(id.rowKey, privacy: .private).")
      return
    }
    session.startPrompt(content: user.content)
  }

  /// Sends the input of the last user message before the kit message of `id`
  /// again, through the thread actions.
  ///
  /// - Parameter id: The id of the kit message of the row.
  private func retryMessage(before id: String) {
    guard let thread, let user = Self.lastUserMessage(before: id, in: thread) else {
      logger.error("Retry found no user message before \(id, privacy: .private).")
      return
    }
    actions?.startSend(Self.input(of: user))
  }

  /// Puts the text of this message in the composer.
  private func edit() {
    let text = editText
    if let composer = commandTarget?.composer {
      composer.load(text)
      _ = composer.focus()
    } else if let promptText {
      promptText.wrappedValue = AttributedString(text)
    } else {
      logger.error("Edit found no composer for \(logKey, privacy: .private).")
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
