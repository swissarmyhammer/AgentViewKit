import AgentViewKitTestSupport
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The lookup of the entry of a search hit through the model:
/// `SessionModel.entry(forWireID:)` (D207 (f)).
///
/// The model gives the entry of a wire id, or `nil`. The search skips a hit
/// with no entry: an unknown wire id (see
/// ``TranscriptSearchTests/aWireIDThatTheModelDoesNotHaveIsSkipped()``), the
/// echo of a prompt that the model holds until the answer of the prompt, and
/// an entry that a rollback of a failed replay removed.
@MainActor @Suite struct TranscriptSearchLookupTests {
  /// The text of the prompt of these tests.
  static let promptText = "Why does the parser fail?"

  /// The raw message id of the echo that the model holds.
  static let heldEchoID = "echo-1"

  /// The raw message id of the agent message that only the failed replay
  /// gives.
  static let replayOnlyID = "agent-replay"

  /// The raw message id of the agent message that the scripted session gets
  /// live, before the replay.
  static let liveAnswerID = "agent-live"

  /// The method of the resume request whose replay fails.
  static let resumeMethod = "session/resume"

  /// Starts a prompt that the sender of `session` never answers, and waits
  /// until the transcript holds its local user message.
  ///
  /// - Parameter session: A preview model with a sender that never answers.
  /// - Returns: The task of the prompt. Cancel it at the end of the test.
  static func startOpenPrompt(on session: SessionModel) async -> Task<Void, Never> {
    let count = session.transcript.count
    let prompt = Task { _ = try? await session.prompt([.text(TextContent(text: promptText))]) }
    await ObservationWait.until { session.transcript.count == count + 1 }
    return prompt
  }

  /// A production change that fails this test: the lookup reads the row key
  /// of the wire id, and not the entry that the model gives. The echo of
  /// the prompt links the wire id to the local user message of the prompt,
  /// whose row key is not the row key of the wire id.
  @Test func theHitOfALinkedPromptFindsTheLocalUserMessage() async throws {
    let session = SessionModel.preview()
    let response = try await session.prompt([.text(TextContent(text: Self.promptText))])
    session.apply(
      .userMessageChunk(
        TranscriptSearchTests.chunk(Self.promptText, id: response.messageId.rawValue)))
    let entry = try #require(session.transcript.last)

    let search = TranscriptSearchTests.search(
      showing: TranscriptSearchTests.hits([.userMessage(response.messageId)]), in: session)

    #expect(search.hits.map(\.rowKey) == [entry.rowKey])
  }

  /// A production change that fails this test: the lookup finds an echo
  /// that the model holds until the answer of its prompt, and the thread
  /// reveals a row that it does not show.
  @Test func aHitOfAHeldEchoIsSkipped() async {
    let session = TranscriptSearchTests.session(
      requestSender: PreviewSessionRequestSender(answer: .never))
    let prompt = await Self.startOpenPrompt(on: session)
    defer { prompt.cancel() }
    session.apply(
      .userMessageChunk(TranscriptSearchTests.chunk(Self.promptText, id: Self.heldEchoID)))

    let search = TranscriptSearchTests.search(
      showing: TranscriptSearchTests.hits([
        .userMessage(MessageId(rawValue: Self.heldEchoID)), TranscriptSearchTests.secondID,
      ]), in: session)

    #expect(
      search.hits.map(\.rowKey) == [TranscriptSearchTests.rowKey(TranscriptSearchTests.secondID)])
  }

  /// A production change that fails this test: the lookup finds an entry
  /// that a rollback of a failed replay removed.
  @Test func aHitOfAnEntryThatARollbackRemovedIsSkipped() async throws {
    let replayFrame = ScriptedSession.sessionUpdateFrame(
      update: try ScriptedSession.agentMessageChunkUpdate(
        messageID: Self.replayOnlyID, text: "Only in the replay."))
    let scripted = try await ScriptedSession.open { agent in
      agent.failingMethods = [Self.resumeMethod]
      agent.leadIns[Self.resumeMethod] = { _, _ in [replayFrame] }
    }
    defer { scripted.close() }
    try await scripted.send(
      update: .agentMessageChunk(
        TranscriptSearchTests.chunk("The parser fails.", id: Self.liveAnswerID)))
    await ObservationWait.until { scripted.model.transcript.count == 1 }
    await #expect(throws: (any Error).self) {
      _ = try await scripted.connection.resumeSession(ScriptedSession.replayFromStartRequest)
    }

    let search = TranscriptSearchTests.search(
      showing: TranscriptSearchTests.hits([
        .agentMessage(MessageId(rawValue: Self.replayOnlyID)),
        .agentMessage(MessageId(rawValue: Self.liveAnswerID)),
      ]), in: scripted.model)

    #expect(search.hits.map(\.position) == [0])
  }
}
