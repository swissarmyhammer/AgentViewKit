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
///   (``SwiftUI/View/agentCommandScope(session:)``). With no scope, the button
///   sets the ``SwiftUI/EnvironmentValues/promptText`` binding.
///
/// With no session model in the environment, the row shows only Copy.
///
/// Put the row in the footer slot of each message row of the thread view:
///
/// ```swift
/// AgentThreadView(session: session)
///   .messageFooter { entry in MessageActions(entry: entry) }
/// ```
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

  /// The message entry of the row.
  let entry: MessageEntry

  @Environment(\.sessionModel) private var session
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
    guard session != nil else { return [.copy] }
    return Self.actions(for: entry.role)
  }

  /// The Markdown of the message: the content form of
  /// `ThreadExporter.markdown(for:)`, read at each call.
  private var markdown: String {
    ThreadExporter.markdown(for: entry.content)
  }

  /// The buttons for a message of `role`, in display order.
  ///
  /// - Parameter role: The sender of the message.
  /// - Returns: The buttons.
  static func actions(for role: MessageRole) -> [Action] {
    switch role {
    case .user: [.copy, .copyThread, .export, .edit]
    case .assistant: [.copy, .copyThread, .export, .retry]
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
    case .retry: retry()
    case .edit: edit()
    }
  }

  /// Copies the thread through the command scope, or directly when there is
  /// no scope, with the same text as the command.
  ///
  /// `AgentCommandTarget.plainText(of:)` reads the same session model that
  /// ``export()`` gives to `ThreadExporter.markdown(for:)`.
  private func copyThread() {
    guard let session, commandTarget?.perform(.copyThread) != true else { return }
    pasteboard.copyText(AgentCommandTarget.plainText(of: session))
  }

  /// Shows the file exporter with the Markdown of the message entries of the
  /// transcript of the session model.
  private func export() {
    guard let session else { return }
    exportDocument = MarkdownDocument(text: ThreadExporter.markdown(for: session.transcript))
  }

  /// Sends the content of the last user message entry before the entry of
  /// this row again, with `SessionModel.prompt(_:meta:)`.
  private func retry() {
    let id = entry.id
    guard let session, let user = Self.lastUserEntry(before: id, in: session.transcript) else {
      logger.error("Retry found no user message entry before \(id.rowKey, privacy: .private).")
      return
    }
    session.startPrompt(content: user.content)
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
