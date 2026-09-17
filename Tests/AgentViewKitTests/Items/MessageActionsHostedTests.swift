@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import PackageFileSupport
import SwiftUI
import Testing

/// Tests for the action row of a message in a window: copy, copy thread,
/// retry, edit, the buttons of each sender, and the selection decision.
@Suite(.serialized, .hostedSerially) @MainActor struct MessageActionsHostedTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The size of a window that shows a message and a composer.
  static let windowSize = CGSize(width: 480, height: 480)

  /// The decision that records the selection mode.
  static let decisionPath = "Docs/decisions/text-selection.md"

  /// The prefix of the line that states the selection mode.
  static let modePrefix = "mode:"

  /// The text of the user message.
  static let question = "Read the README."

  /// The user message of ``turnThread()``.
  static let user = "user-1"

  /// The assistant message of ``turnThread()``.
  static let assistant = "assistant-1"

  /// Makes a thread with a user message and an assistant message.
  ///
  /// - Returns: The thread.
  static func turnThread() -> AgentThread {
    let thread = AgentThread()
    let request = ThreadFixtures.message(id: user, text: question)
    thread.apply(.insert(.userMessage(request), after: nil))
    let answer = Message(
      id: assistant,
      blocks: [ContentBlock(text: "The README tells how to build."), ContentBlock(text: "Done.")])
    thread.apply(.insert(.assistantMessage(answer), after: nil))
    return thread
  }

  /// The message of `id` in `thread`.
  ///
  /// - Parameters:
  ///   - id: The identifier of the message.
  ///   - thread: The thread.
  /// - Returns: The message.
  static func message(_ id: String, in thread: AgentThread) throws -> Message {
    switch thread.item(id: id) {
    case .userMessage(let message), .assistantMessage(let message): message
    default: throw MessageNotFound(id: id)
    }
  }

  /// The error of ``message(_:in:)`` when the thread has no message of the id.
  struct MessageNotFound: Error {
    /// The identifier that the test looked for.
    let id: String
  }

  /// The identifiers of the action buttons that the harness shows, in order.
  ///
  /// - Parameter harness: The harness.
  /// - Returns: The identifiers.
  static func shownActions<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
    let identifiers = Set(MessageActions.Action.allCases.map(\.identifier))
    return harness.accessibilityElements().compactMap(\.identifier).filter(identifiers.contains)
  }

  // MARK: - Copy

  @Test func copyWritesTheMarkdownOfTheMessage() throws {
    let thread = Self.turnThread()
    let message = try Self.message(Self.assistant, in: thread)
    let pasteboard = FakePasteboard()
    let harness = threadViewHarness(actions: NoopThreadActions(), thread: thread) {
      AssistantMessageView(message: message)
        .messageFooter { MessageActions(message: $0) }
        .environment(\.pasteboard, pasteboard)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.copy.identifier)

    #expect(pasteboard.copies == ["The README tells how to build.\n\nDone."])
  }

  @Test func copyThreadWithNoScopeWritesTheTextOfTheCommand() throws {
    let thread = Self.turnThread()
    let message = try Self.message(Self.user, in: thread)
    let pasteboard = FakePasteboard()
    let harness = threadViewHarness(actions: NoopThreadActions(), thread: thread) {
      UserMessageView(message: message)
        .messageFooter { MessageActions(message: $0) }
        .environment(\.pasteboard, pasteboard)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.copyThread.identifier)

    #expect(pasteboard.copies == [AgentCommandTarget.plainText(of: thread)])
  }

  @Test func copyThreadInAThreadViewRunsTheCopyThreadCommand() throws {
    let thread = AgentThread()
    thread.apply(.insert(.userMessage(ThreadFixtures.message(id: Self.user)), after: nil))
    let pasteboard = FakePasteboard()
    let harness = threadViewHarness(
      size: Self.windowSize, actions: NoopThreadActions(), thread: thread
    ) {
      AgentThreadView(thread: thread)
        .messageFooter { MessageActions(message: $0) }
        .environment(\.pasteboard, pasteboard)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.copyThread.identifier)

    #expect(pasteboard.copies == ["User:\nHello."])
  }

  // MARK: - Retry and edit

  @Test func retrySendsTheLastUserInputBeforeTheMessage() async throws {
    let thread = Self.turnThread()
    let message = try Self.message(Self.assistant, in: thread)
    let actions = NoopThreadActions()
    let harness = threadViewHarness(actions: actions, thread: thread) {
      AssistantMessageView(message: message)
        .messageFooter { MessageActions(message: $0) }
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.retry.identifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.question))])
  }

  @Test func editPutsTheTextInTheComposerOfTheScope() throws {
    let thread = Self.turnThread()
    let message = try Self.message(Self.user, in: thread)
    let model = PromptInputHostedTestModel()
    let harness = threadViewHarness(
      size: Self.windowSize, actions: NoopThreadActions(), thread: thread
    ) {
      VStack {
        UserMessageView(message: message)
          .messageFooter { MessageActions(message: $0) }
        PromptInputHost(model: model)
      }
      .agentCommandScope(thread: thread)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.edit.identifier)
    harness.pump()

    #expect(model.plainText == Self.question)
  }

  @Test func editWithNoScopeSetsThePromptTextBinding() throws {
    let thread = Self.turnThread()
    let message = try Self.message(Self.user, in: thread)
    let model = PromptInputHostedTestModel()
    let text = Binding(get: { model.text }, set: { model.text = $0 })
    let harness = threadViewHarness(actions: NoopThreadActions(), thread: thread) {
      UserMessageView(message: message)
        .messageFooter { MessageActions(message: $0) }
        .environment(\.promptText, text)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.edit.identifier)

    #expect(model.plainText == Self.question)
  }

  // MARK: - Buttons

  @Test func eachSenderShowsItsButtons() throws {
    let thread = Self.turnThread()
    let user = try Self.message(Self.user, in: thread)
    let assistant = try Self.message(Self.assistant, in: thread)
    let userHarness = threadViewHarness(actions: NoopThreadActions(), thread: thread) {
      MessageActions(message: user)
    }
    userHarness.pump()
    let userActions = Self.shownActions(in: userHarness)
    userHarness.close()
    let assistantHarness = threadViewHarness(actions: NoopThreadActions(), thread: thread) {
      MessageActions(message: assistant)
    }
    defer { assistantHarness.close() }
    assistantHarness.pump()

    #expect(
      userActions == ["message-copy", "message-copy-thread", "message-export", "message-edit"])
    #expect(
      Self.shownActions(in: assistantHarness)
        == ["message-copy", "message-copy-thread", "message-export", "message-retry"])
  }

  @Test func withNoThreadTheRowShowsOnlyCopy() {
    let harness = threadViewHarness(actions: NoopThreadActions()) {
      MessageActions(message: ThreadFixtures.message())
    }
    defer { harness.close() }
    harness.pump()

    #expect(Self.shownActions(in: harness) == [MessageActions.Action.copy.identifier])
    #expect(harness.element(identifier: MessageActions.Action.copy.identifier)?.label == "Copy")
  }

  @Test func aMessageThatTheThreadDoesNotHoldHasNoRetryAndNoEdit() {
    #expect(MessageActions.actions(for: nil) == [.copy, .copyThread, .export])
    let other = ThreadFixtures.message(id: "other")
    #expect(MessageActions.role(of: other, in: Self.turnThread()) == nil)
  }

  @Test func retryFindsNoUserMessageBeforeTheFirstItem() {
    let thread = Self.turnThread()

    #expect(MessageActions.lastUserMessage(before: Self.user, in: thread) == nil)
    #expect(MessageActions.lastUserMessage(before: "missing", in: thread) == nil)
    #expect(MessageActions.lastUserMessage(before: Self.assistant, in: thread)?.id == Self.user)
  }

  @Test func theInputOfAMessageHasItsTextAndItsAttachments() {
    let url = URL(filePath: "/project/README.md")
    let message = Message(
      id: "input",
      blocks: [
        ContentBlock(text: "One."), ContentBlock(content: .attachment(url)),
        ContentBlock(text: "Two."),
      ])

    let expected = UserInput(text: "One.\n\nTwo.", attachments: [url])
    #expect(MessageActions.input(of: message) == expected)
  }

  @Test func theExportDocumentHasTheMarkdownType() {
    let document = MarkdownDocument(text: "# Title")

    #expect(document.text == "# Title")
    #expect(MarkdownDocument.readableContentTypes == [.markdown])
  }

  // MARK: - Selection

  @Test func theSelectionModeEqualsTheDecision() throws {
    let text = try PackageFiles.text(of: Self.decisionPath)
    let lines = text.split(separator: "\n").filter { $0.hasPrefix(Self.modePrefix) }
    #expect(lines.count == 1, "The file must have exactly one \(Self.modePrefix) line.")
    let line = try #require(lines.first)
    let mode = line.dropFirst(Self.modePrefix.count)
      .trimmingCharacters(in: .whitespaces)
      .trimmingCharacters(in: CharacterSet(charactersIn: "`"))

    #expect(MessageActions.selectionMode.rawValue == mode)
  }
}
