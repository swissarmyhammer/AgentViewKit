import AgentViewKit
import AgentViewKitFoundationModels
import AgentViewKitTestSupport
import Foundation
import FoundationModels
import Testing

/// Tests of ``SessionThreadSource`` with local branches
/// (`Docs/decisions/branches.md`).
@Suite @MainActor struct SessionThreadSourceBranchTests {
  /// The text of the second prompt of a test.
  static let nextPrompt = "Read the next file."

  /// The source, the actions, and the ids of the first turn of one test.
  private struct Turn {
    /// The source over a session with the fake model.
    let source: SessionThreadSource

    /// The actions over the source.
    let actions: SessionThreadActions

    /// The id of the user message of the first turn.
    let promptID: String

    /// The id of the first answer.
    let answerID: String
  }

  /// Makes a source over a fake model that answers each prompt with text in
  /// a new response entry, and sends the first prompt.
  ///
  /// - Returns: The source, the actions, and the ids of the first turn.
  private func firstTurn() async throws -> Turn {
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [[.text(entryID: nil, text: "Hello")]]))
    let source = SessionThreadSource(session: session)
    let actions = SessionThreadActions(source: source)
    source.start()
    await actions.send(UserInput(text: SourceSamples.prompt))
    let promptID = try #require(source.thread.items.first?.id)
    let answerID = try #require(source.thread.items.last?.id)
    #expect(source.thread.items.map(\.id) == [promptID, answerID])
    return Turn(source: source, actions: actions, promptID: promptID, answerID: answerID)
  }

  /// Does what Regenerate does: records the answer as a branch, shows a new
  /// empty branch, and sends the prompt again.
  ///
  /// - Parameter turn: The first turn.
  /// - Returns: The id of the new answer.
  private func regenerate(_ turn: Turn) async throws -> String {
    let thread = turn.source.thread
    thread.apply(.addBranch(afterUserMessage: turn.promptID, items: []))
    thread.apply(.selectBranch(afterUserMessage: turn.promptID, index: 1))
    await turn.actions.send(UserInput(text: SourceSamples.prompt))
    return try #require(thread.items.last?.id)
  }

  /// The ids of the entries of a kind in a transcript.
  ///
  /// - Parameters:
  ///   - transcript: The transcript.
  ///   - isKind: Whether an entry is of the kind.
  /// - Returns: The ids, in order.
  private func ids(in transcript: Transcript, where isKind: (Transcript.Entry) -> Bool) -> [String] {
    transcript.filter(isKind).map(\.id)
  }

  @Test func regenerateRemovesTheOldAnswerFromTheTranscript() async throws {
    let turn = try await firstTurn()
    defer { turn.source.stop() }
    let session = turn.source.session

    let newAnswerID = try await regenerate(turn)

    #expect(newAnswerID != turn.answerID)
    #expect(!session.transcript.contains { $0.id == turn.answerID })
    let prompts = ids(in: session.transcript) { entry in
      if case .prompt = entry { return true }
      return false
    }
    let responses = ids(in: session.transcript) { entry in
      if case .response = entry { return true }
      return false
    }
    #expect(prompts.count == 1)
    #expect(responses == [newAnswerID])
    #expect(turn.source.thread.items.map(\.id) == [turn.promptID, newAnswerID])
    let set = try #require(turn.source.thread.branches[turn.promptID])
    #expect(set.alternatives.first?.map(\.id) == [turn.answerID])
    #expect(turn.source.thread.state == .idle(nil))
  }

  @Test func aTranscriptChangeAfterASwapDoesNotShowTheHiddenAnswer() async throws {
    let turn = try await firstTurn()
    defer { turn.source.stop() }
    let session = turn.source.session
    let thread = turn.source.thread
    let newAnswerID = try await regenerate(turn)
    thread.apply(.selectBranch(afterUserMessage: turn.promptID, index: 0))
    let addedID = "response-added"

    var entries = Array(session.transcript)
    let newAnswerPosition = try #require(entries.firstIndex { $0.id == newAnswerID })
    guard case .response(var response) = entries[newAnswerPosition] else {
      Issue.record("Expected the new answer")
      return
    }
    response.segments = [.text(Transcript.TextSegment(content: "Edited"))]
    entries[newAnswerPosition] = .response(response)
    entries.append(
      .response(Transcript.Response(id: addedID, segments: [.text(Transcript.TextSegment(content: "Added"))])))
    session.transcript = Transcript(entries: entries)

    #expect(await waitUntil { thread.item(id: addedID) != nil })
    #expect(thread.items.map(\.id) == [turn.promptID, turn.answerID, addedID])
    #expect(thread.isInHiddenBranch(newAnswerID))
  }

  @Test func aSendAfterASwapWritesTheShownBranchToTheTranscript() async throws {
    let turn = try await firstTurn()
    defer { turn.source.stop() }
    let session = turn.source.session
    let thread = turn.source.thread
    let newAnswerID = try await regenerate(turn)
    thread.apply(.selectBranch(afterUserMessage: turn.promptID, index: 0))

    await turn.actions.send(UserInput(text: Self.nextPrompt))

    let transcriptIDs = session.transcript.map(\.id)
    #expect(transcriptIDs.count == 4)
    #expect(Array(transcriptIDs.prefix(2)) == [turn.promptID, turn.answerID])
    #expect(!transcriptIDs.contains(newAnswerID))
    #expect(thread.items.map(\.id) == transcriptIDs)
  }

  @Test func aCancelledRegenerateKeepsTheUserMessage() async throws {
    let gate = FakeGate()
    let session = LanguageModelSession(
      model: FakeLanguageModel(
        rounds: [[.text(entryID: nil, text: "Hello"), .waitForGate]], gate: gate))
    let source = SessionThreadSource(session: session)
    let actions = SessionThreadActions(source: source)
    defer { source.stop() }
    source.start()
    gate.open()
    await actions.send(UserInput(text: SourceSamples.prompt))
    let thread = source.thread
    let promptID = try #require(thread.items.first?.id)
    thread.apply(.addBranch(afterUserMessage: promptID, items: []))
    thread.apply(.selectBranch(afterUserMessage: promptID, index: 1))

    let sending = Task { await actions.send(UserInput(text: SourceSamples.prompt)) }
    #expect(
      await waitUntil {
        session.transcript.contains { entry in
          if case .response = entry { return true }
          return false
        }
      })
    let cancelling = Task { await actions.cancel() }
    #expect(await waitUntil { actions.turn?.isCancelled == true })
    gate.open()
    await cancelling.value
    await sending.value

    #expect(thread.items.map(\.id) == [promptID])
    #expect(session.transcript.map(\.id) == [promptID])
    #expect(thread.state == .idle(nil))
  }
}
