import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Synchronization
import Testing

@testable import AgentViewKit

/// The lookup of the entry of a search hit by the `wireID` of each entry
/// of the transcript (D207 (f)), and the lookup again when the echo of a
/// prompt links to its local user message.
///
/// ``TranscriptSearch`` states the lookup rule. The search skips a hit with
/// no entry: an unknown wire id (see
/// ``TranscriptSearchTests/aWireIDThatTheModelDoesNotHaveIsSkipped()``), the
/// echo of a prompt that the model holds until the answer of the prompt, and
/// an entry that a rollback of a failed replay removed. The test of the
/// driver lays out an `NSHostingView` with no window, so no test shows a
/// window or takes the focus.
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

  /// Shows the driver of `search` for `session` with the hits of the host,
  /// in an `NSHostingView` with no window, and lays it out one time.
  ///
  /// - Parameters:
  ///   - search: The search of the thread.
  ///   - session: The session that the thread shows.
  ///   - hits: The hits of the host.
  /// - Returns: The host. Lay it out again with `StyleViewHost.layOut(_:)`.
  static func hostDriver(
    of search: TranscriptSearch, for session: SessionModel, hits: TranscriptSearchHits
  ) -> NSHostingView<AnyView> {
    let hosting = NSHostingView(
      rootView: AnyView(
        TranscriptSearchDriver(session: session, search: search, store: ExpandedBlocksStore())
          .environment(\.transcriptSearchHits, .constant(hits))))
    StyleViewHost.layOut(hosting)
    return hosting
  }

  /// Tells if a write fires the observation of a read.
  ///
  /// - Parameters:
  ///   - read: The reads that the observation tracks.
  ///   - write: The write to make after the tracking starts.
  /// - Returns: `true` when the write fired the observation.
  static func observationFires(reading read: () -> Void, during write: () -> Void) -> Bool {
    let fired = Mutex(false)
    withObservationTracking(read) {
      fired.withLock { $0 = true }
    }
    write()
    return fired.withLock { $0 }
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

  /// A production change that fails this test: the driver looks up the
  /// hits again only when the number of the entries changes. The echo of a
  /// prompt links to the local user message of the prompt and adds no
  /// entry, so a hit on the prompt that came before the echo never reveals.
  @Test func aHitBeforeTheEchoOfItsPromptRevealsTheLocalMessageWhenTheEchoLinks() async throws {
    let session = SessionModel.preview()
    let response = try await session.prompt([.text(TextContent(text: Self.promptText))])
    let entry = try #require(session.transcript.last)
    let search = TranscriptSearch()
    let hosting = Self.hostDriver(
      of: search, for: session,
      hits: TranscriptSearchTests.hits([.userMessage(response.messageId)]))
    try #require(search.hostRemoval != nil)
    try #require(search.hits.isEmpty)
    let count = session.transcript.count
    session.apply(
      .userMessageChunk(
        TranscriptSearchTests.chunk(Self.promptText, id: response.messageId.rawValue)))
    try #require(session.transcript.count == count)

    StyleViewHost.layOut(hosting)

    #expect(search.takeRevealRequest()?.rowKey == entry.rowKey)
    #expect(search.mark(forRowKey: entry.rowKey)?.isCurrent == true)
  }

  /// A production change that fails this test: the lookup reads a value
  /// that each streamed token changes, such as the content of an entry. The
  /// driver then evaluates the lookup again on each token.
  @Test func aStreamedTokenDoesNotFireTheReadsOfTheLookup() throws {
    let session = TranscriptSearchTests.session()
    let answer: AgentMessageEntry? =
      if case .agentMessage(let entry) = session.transcript[1] { entry } else { nil }
    let content = try #require(answer).content
    let hits = TranscriptSearchTests.hits([TranscriptSearchTests.secondID])

    let fired = Self.observationFires {
      _ = TranscriptSearch.hits(of: hits, in: session.transcript)
    } during: {
      session.apply(.agentMessageChunk(TranscriptSearchTests.chunk(" More.", id: "agent-1")))
    }

    try #require(answer?.content != content)
    #expect(!fired)
  }

  /// A production change that fails this test: the driver does not read the
  /// binding of the host in its body, so hits that the host gives after the
  /// mount do not reach the search, and the first hit is not announced. The
  /// host makes its binding in its body, as a host app does
  /// (``TranscriptSearchHitsHost``). One layout pass gives the hits to the
  /// search and announces the first hit.
  @Test func hitsThatAHostGivesAfterTheMountAnnounceTheFirstHitInOneLayoutPass() {
    let session = SessionModel.preview(transcript: [
      .user(Self.promptText), .agent("The parser fails."),
    ])
    let ids = session.transcript.compactMap(TranscriptSearchTests.wireID)
    let host = HostSearchHits()
    let announcer = RecordingAnnouncer()
    let hosting = NSHostingView(
      rootView: TranscriptSearchHitsHost(host: host) {
        TranscriptSearchDriver(
          session: session, search: TranscriptSearch(), store: ExpandedBlocksStore())
      }
      .environment(\.announcer, announcer))
    StyleViewHost.layOut(hosting)

    host.hits = TranscriptSearchTests.hits(ids)
    StyleViewHost.layOut(hosting)

    let expected = TranscriptSearchDriver.announcement(
      number: 1, count: 2, author: MessageRole.user.title)
    #expect(announcer.announcements.map(\.message) == [expected])
  }
}
