@testable import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
import Foundation
import FoundationModelsACPClient
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
      MessageActions(message: message)
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
      MessageActions(message: message)
        .environment(\.pasteboard, pasteboard)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.copyThread.identifier)

    #expect(pasteboard.copies == [AgentCommandTarget.plainText(of: thread)])
  }

  // MARK: - Retry and edit

  @Test func retrySendsTheLastUserInputBeforeTheMessage() async throws {
    let thread = Self.turnThread()
    let message = try Self.message(Self.assistant, in: thread)
    let actions = NoopThreadActions()
    let harness = threadViewHarness(actions: actions, thread: thread) {
      MessageActions(message: message)
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
        MessageActions(message: message)
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
      MessageActions(message: message)
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

  // MARK: - Session model

  #if DEBUG
  /// The text chunks of the agent message of ``openTurn()``.
  static let answerChunks = ["The README tells ", "how to build."]

  /// The number of entries of ``openTurn()``: a user message and an agent
  /// message.
  static let turnEntryCount = 2

  /// The number of user message entries after one retry.
  static let userEntryCountAfterRetry = 2

  /// The user message entry and the agent message entry of a session.
  struct SessionTurn {
    /// The scripted session.
    let session: ScriptedSession

    /// The user message entry.
    let user: UserMessageEntry

    /// The agent message entry.
    let agent: AgentMessageEntry
  }

  /// Opens a session, and sends a user message and an agent message from the
  /// agent. The agent message has two text chunks.
  ///
  /// - Returns: The session and its two message entries.
  /// - Throws: The error of the transport, or an issue when the model does
  ///   not hold the two entries at the time limit.
  static func openTurn() async throws -> SessionTurn {
    let session = try await ScriptedSession.open()
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("user_message_chunk", messageID: "actions-u", block: WireBlockJSON.makeText(question)))
    for chunk in answerChunks {
      try await session.sendUpdate(
        WireBlockJSON.makeChunk("agent_message_chunk", messageID: "actions-m", block: WireBlockJSON.makeText(chunk)))
    }
    let model = session.model
    _ = await waitUntil {
      model.transcript.count == turnEntryCount && agentEntry(in: model)?.content.count == answerChunks.count
    }
    return SessionTurn(
      session: session, user: try #require(userEntries(in: model).first), agent: try #require(agentEntry(in: model)))
  }

  /// The user message entries of a session model, in transcript order.
  ///
  /// - Parameter model: The session model.
  /// - Returns: The entries.
  static func userEntries(in model: SessionModel) -> [UserMessageEntry] {
    model.transcript.compactMap(SessionTranscriptViewHostedTests.userMessage)
  }

  /// The first agent message entry of a session model.
  ///
  /// - Parameter model: The session model.
  /// - Returns: The entry, or `nil` when the model has none.
  static func agentEntry(in model: SessionModel) -> AgentMessageEntry? {
    model.transcript.lazy.compactMap(BackgroundRunsHostedTests.agentMessage(of:)).first
  }

  /// Shows `content` with the session model of `turn` and a pasteboard.
  ///
  /// - Parameters:
  ///   - turn: The session turn.
  ///   - pasteboard: The pasteboard of the copy buttons.
  ///   - content: The view to show.
  /// - Returns: The harness.
  static func mount(
    _ turn: SessionTurn, pasteboard: FakePasteboard = FakePasteboard(), @ViewBuilder content: () -> some View
  ) -> HostedViewHarness<some View> {
    HostedViewHarness(size: windowSize) {
      content()
        .environment(\.sessionModel, turn.session.model)
        .environment(\.pasteboard, pasteboard)
    }
  }

  @Test func retryOnAnAgentEntrySendsTheContentOfTheEarlierUserEntry() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let model = turn.session.model
    let harness = Self.mount(turn) { MessageActions(entry: turn.agent) }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.retry.identifier)
    await harness.pump(until: Self.waitTimeout) {
      Self.userEntries(in: model).count == Self.userEntryCountAfterRetry
        && !turn.session.agent.messages(method: ScriptedSession.promptMethod).isEmpty
    }

    let prompts = turn.session.agent.messages(method: ScriptedSession.promptMethod)
    #expect(prompts.map(ScriptedWireAgent.promptText(of:)) == [Self.question])
    let users = Self.userEntries(in: model)
    #expect(users.count == Self.userEntryCountAfterRetry)
    #expect(users.last?.content == turn.user.content)
    #expect(users.last?.origin == .local)
  }

  @Test func retryFindsNoUserEntryBeforeTheFirstEntry() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let transcript = turn.session.model.transcript
    let missing = TranscriptEntry.ID.local(UUID())

    #expect(MessageActions.lastUserEntry(before: turn.user.id, in: transcript) == nil)
    #expect(MessageActions.lastUserEntry(before: missing, in: transcript) == nil)
    #expect(MessageActions.lastUserEntry(before: turn.agent.id, in: transcript) === turn.user)
  }

  @Test func eachEntrySenderShowsItsButtons() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let userHarness = Self.mount(turn) { MessageActions(entry: turn.user) }
    userHarness.pump()
    let userActions = Self.shownActions(in: userHarness)
    userHarness.close()
    let agentHarness = Self.mount(turn) { MessageActions(entry: turn.agent) }
    defer { agentHarness.close() }
    agentHarness.pump()

    #expect(userActions == ["message-copy", "message-copy-thread", "message-export", "message-edit"])
    #expect(
      Self.shownActions(in: agentHarness) == ["message-copy", "message-copy-thread", "message-export", "message-retry"])
  }

  @Test func withNoSessionModelAnEntryRowShowsOnlyCopy() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let pasteboard = FakePasteboard()
    let harness = HostedViewHarness(size: Self.windowSize) {
      MessageActions(entry: turn.agent).environment(\.pasteboard, pasteboard)
    }
    defer { harness.close() }
    harness.pump()

    #expect(Self.shownActions(in: harness) == [MessageActions.Action.copy.identifier])
    try harness.press(identifier: MessageActions.Action.copy.identifier)
    #expect(pasteboard.copies == [Self.answerChunks.joined()])
  }

  @Test func copyOnAnEntryWritesTheJoinedTextOfTheEntry() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let pasteboard = FakePasteboard()
    let harness = Self.mount(turn, pasteboard: pasteboard) { MessageActions(entry: turn.agent) }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.copy.identifier)

    #expect(pasteboard.copies == [Self.answerChunks.joined()])
  }

  @Test func copyThreadOnAnEntryWritesTheTextOfTheCopyCommand() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let pasteboard = FakePasteboard()
    let harness = Self.mount(turn, pasteboard: pasteboard) { MessageActions(entry: turn.user) }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.copyThread.identifier)

    let expected = AgentCommandTarget.plainText(of: .session(turn.session.model))
    #expect(!expected.isEmpty)
    #expect(pasteboard.copies == [expected])
  }

  @Test func copyThreadInTheFooterOfAThreadViewRunsTheCopyThreadCommand() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let pasteboard = FakePasteboard()
    let copyThread = MessageActions.Action.copyThread.identifier
    let harness = Self.mount(turn, pasteboard: pasteboard) {
      AgentThreadView(session: turn.session.model, actions: NoopThreadActions())
        .messageFooter { MessageActions(entry: $0) }
    }
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) { Self.shownActions(in: harness).contains(copyThread) }

    try harness.press(identifier: copyThread)

    let expected = AgentCommandTarget.plainText(of: .session(turn.session.model))
    #expect(!expected.isEmpty)
    #expect(pasteboard.copies == [expected])
  }

  @Test func editOnAUserEntrySetsThePromptTextBinding() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let model = PromptInputHostedTestModel()
    let text = Binding(get: { model.text }, set: { model.text = $0 })
    let harness = Self.mount(turn) {
      MessageActions(entry: turn.user).environment(\.promptText, text)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: MessageActions.Action.edit.identifier)

    #expect(model.plainText == Self.question)
  }
  #endif

  // MARK: - Export document

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
