@testable import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
import EditorCommandsUI
import EditorTestSupport
import Foundation
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Tests for the action row of a message in a window: copy, copy thread,
/// retry, edit, and the buttons of each sender.
///
/// Each action of a button runs in the press, and the press makes a render
/// pass. Only the retry sends a request, so only the retry test waits, on the
/// model and on the frames of the agent.
@Suite(.serialized, .hostedSerially) @MainActor struct MessageActionsHostedTests {
  /// The size of a window that shows a message and a composer.
  static let windowSize = CGSize(width: 480, height: 480)

  /// The text of the user message.
  static let question = "Read the README."

  /// The identifiers of the action buttons that the harness shows, in order.
  ///
  /// - Parameter harness: The harness.
  /// - Returns: The identifiers.
  static func shownActions<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
    let identifiers = Set(MessageActions.Action.allCases.map(\.identifier))
    return harness.accessibilityElements().compactMap(\.identifier).filter(identifiers.contains)
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
  ///   not hold the two entries.
  static func openTurn() async throws -> SessionTurn {
    let session = try await ScriptedSession.open()
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("user_message_chunk", messageID: "actions-u", block: WireBlockJSON.makeText(question)))
    for chunk in answerChunks {
      try await session.sendUpdate(
        WireBlockJSON.makeChunk("agent_message_chunk", messageID: "actions-m", block: WireBlockJSON.makeText(chunk)))
    }
    let model = session.model
    await ObservationWait.until {
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
    model.transcript.lazy.compactMap(AgentMessageLookup.agentMessage(of:)).first
  }

  /// Shows `content` with the session model of `turn` and a pasteboard, and
  /// makes one render pass.
  ///
  /// - Parameters:
  ///   - turn: The session turn.
  ///   - pasteboard: The pasteboard of the copy buttons, one of
  ///     `NSPasteboard.withIsolated(_:)`, or `nil` for a test that copies
  ///     nothing.
  ///   - requestStartReport: The report that gets the method of each request
  ///     that a view starts, or `nil`.
  ///   - content: The view to show.
  /// - Returns: The harness.
  static func mount(
    _ turn: SessionTurn, pasteboard: NSPasteboard? = nil,
    requestStartReport: ObservationReport<String>? = nil, @ViewBuilder content: () -> some View
  ) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: windowSize) {
      content()
        .environment(\.sessionModel, turn.session.model)
        .transformEnvironment(\.pasteboard) { if let pasteboard { $0 = pasteboard } }
        .environment(\.requestStartReport, requestStartReport)
    }
    harness.render()
    return harness
  }

  @Test func retryOnAnAgentEntrySendsTheContentOfTheEarlierUserEntry() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let model = turn.session.model
    let starts = ReportRecorder<String>()
    let harness = Self.mount(turn, requestStartReport: starts.report) { MessageActions(entry: turn.agent) }
    defer { harness.close() }

    try harness.press(identifier: MessageActions.Action.retry.identifier)
    // The Retry button starts the prompt in the same step as the press, so a
    // press that started nothing stops the test here.
    try #require(starts.values == [ScriptedSession.promptMethod])
    await ObservationWait.until {
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
    let userActions = Self.shownActions(in: userHarness)
    userHarness.close()
    let agentHarness = Self.mount(turn) { MessageActions(entry: turn.agent) }
    defer { agentHarness.close() }

    #expect(userActions == ["message-copy", "message-copy-thread", "message-export", "message-edit"])
    #expect(
      Self.shownActions(in: agentHarness) == ["message-copy", "message-copy-thread", "message-export", "message-retry"])
  }

  @Test func withNoSessionModelAnEntryRowShowsOnlyCopy() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    try NSPasteboard.withIsolated { pasteboard in
      let harness = HostedViewHarness(size: Self.windowSize) {
        MessageActions(entry: turn.agent).environment(\.pasteboard, pasteboard)
      }
      defer { harness.close() }
      harness.render()

      #expect(Self.shownActions(in: harness) == [MessageActions.Action.copy.identifier])
      try pasteboard.expectOneCopy(of: Self.answerChunks.joined()) {
        try harness.press(identifier: MessageActions.Action.copy.identifier)
      }
    }
  }

  @Test func copyOnAnEntryWritesTheJoinedTextOfTheEntry() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    try NSPasteboard.withIsolated { pasteboard in
      let harness = Self.mount(turn, pasteboard: pasteboard) { MessageActions(entry: turn.agent) }
      defer { harness.close() }

      try pasteboard.expectOneCopy(of: Self.answerChunks.joined()) {
        try harness.press(identifier: MessageActions.Action.copy.identifier)
      }
    }
  }

  @Test func copyThreadOnAnEntryWritesTheTextOfTheCopyCommand() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let expected = AgentCommandTarget.plainText(of: turn.session.model)
    #expect(!expected.isEmpty)
    try NSPasteboard.withIsolated { pasteboard in
      let harness = Self.mount(turn, pasteboard: pasteboard) { MessageActions(entry: turn.user) }
      defer { harness.close() }

      try pasteboard.expectOneCopy(of: expected) {
        try harness.press(identifier: MessageActions.Action.copyThread.identifier)
      }
    }
  }

  @Test func copyThreadInTheFooterOfAThreadViewRunsTheCopyThreadCommand() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let expected = AgentCommandTarget.plainText(of: turn.session.model)
    #expect(!expected.isEmpty)
    try NSPasteboard.withIsolated { pasteboard in
      let copyThread = MessageActions.Action.copyThread.identifier
      let harness = Self.mount(turn, pasteboard: pasteboard) {
        AgentThreadView(session: turn.session.model)
          .messageFooter { MessageActions(entry: $0) }
      }
      defer { harness.close() }
      #expect(Self.shownActions(in: harness).contains(copyThread))

      try pasteboard.expectOneCopy(of: expected) {
        try harness.press(identifier: copyThread)
      }
    }
  }

  @Test func editOnAUserEntryPutsTheTextInTheComposerOfTheScope() async throws {
    let turn = try await Self.openTurn()
    defer { turn.session.close() }
    let model = PromptInputHostedTestModel()
    let harness = Self.mount(turn) {
      VStack {
        MessageActions(entry: turn.user)
        PromptInputHost(model: model)
      }
      .agentCommandScope(session: turn.session.model)
    }
    defer { harness.close() }

    try harness.press(identifier: MessageActions.Action.edit.identifier)

    #expect(model.plainText == Self.question)
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
}
