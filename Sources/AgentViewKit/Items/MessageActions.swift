import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// The action row of a message item (plan.md §9 A, §11 decision 8).
///
/// Put the row in the footer slot of the message views:
///
/// ```swift
/// AgentThreadView(thread: thread)
///   .messageFooter { message in MessageActions(message: message) }
/// ```
///
/// The row has these buttons, in this order:
///
/// - Copy: writes the Markdown of the message (the message form of
///   `ThreadExporter.markdown(for:)`) to the `pasteboard` environment value.
/// - Copy thread: runs ``AgentCommandVerb/copyThread`` in the agent command
///   scope. With no scope, the button writes the same text to the
///   pasteboard.
/// - Export: saves the thread as a Markdown file (the thread form of
///   `ThreadExporter.markdown(for:)`).
/// - Retry, for an assistant message only: sends the last user message
///   before the message again, through the `threadActions` environment value.
/// - Edit, for a user message only: puts the text of the message in the
///   composer. The composer must be in the same agent command scope
///   (``SwiftUI/View/agentCommandScope(thread:)``). With no scope, the button
///   sets the ``SwiftUI/EnvironmentValues/promptText`` binding.
///
/// The row reads the thread from the `agentThread` environment value. The
/// thread tells the sender of the message. With no thread, the row shows only
/// Copy.
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

  /// The message of the row.
  let message: Message

  @Environment(\.agentThread) private var thread
  @Environment(\.threadActions) private var actions
  @Environment(\.pasteboard) private var pasteboard
  @Environment(\.promptText) private var promptText
  @Environment(\.agentCommandTarget) private var commandTarget

  @State private var exportDocument: MarkdownDocument?

  private let logger = Logger(subsystem: "AgentViewKit", category: "MessageActions")

  /// Makes the action row of a message.
  ///
  /// - Parameter message: The message of the row.
  public init(message: Message) {
    self.message = message
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
    guard let thread else { return [.copy] }
    return Self.actions(for: Self.role(of: message, in: thread))
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
      case .image, .audio, .resourceLink, .resource, .structured, .unknown: break
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

  /// Runs the action of a button.
  ///
  /// - Parameter action: The button.
  private func perform(_ action: Action) {
    switch action {
    case .copy: pasteboard.copyText(ThreadExporter.markdown(for: message))
    case .copyThread: copyThread()
    case .export: export()
    case .retry: retry()
    case .edit: edit()
    }
  }

  /// Copies the thread through the command scope, or directly when there is
  /// no scope.
  private func copyThread() {
    guard let thread, commandTarget?.perform(.copyThread) != true else { return }
    pasteboard.copyText(AgentCommandTarget.plainText(of: thread))
  }

  /// Shows the file exporter with the Markdown of the thread.
  private func export() {
    guard let thread else { return }
    exportDocument = MarkdownDocument(text: ThreadExporter.markdown(for: thread))
  }

  /// Sends the last user message before this message again.
  private func retry() {
    guard let thread, let user = Self.lastUserMessage(before: message.id, in: thread) else {
      logger.error("Retry found no user message before \(message.id, privacy: .private).")
      return
    }
    actions.startSend(Self.input(of: user))
  }

  /// Puts the text of this message in the composer.
  private func edit() {
    let text = Self.input(of: message).text
    if let composer = commandTarget?.composer {
      composer.load(text)
      _ = composer.focus()
    } else if let promptText {
      promptText.wrappedValue = AttributedString(text)
    } else {
      logger.error("Edit found no composer for \(message.id, privacy: .private).")
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
