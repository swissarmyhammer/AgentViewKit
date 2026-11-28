import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The virtual stack of a thread stays correct when the transcript gets
/// shorter (card ^kr7cx7b).
///
/// A resume with a replay from the start first removes each entry of the
/// transcript, and the agent then replays the history. The stack reads the
/// transcript itself, and it gets the number of the shown rows from the
/// list, so the stack can evaluate its body with the number of the shown
/// rows of the longer transcript. The test shows a ``MovingThread`` of a
/// scripted session with ``answerCount`` answers, and then resumes the
/// session with a replay of no entry.
@MainActor @Suite(.serialized) struct TranscriptRowStackResetTests {
  /// The number of answers before the resume.
  static let answerCount = 6

  /// The text of the answer at `index`.
  ///
  /// - Parameter index: The index of the answer.
  /// - Returns: The text.
  static func answer(_ index: Int) -> String {
    "Reset answer \(index)."
  }

  /// The message id of the answer at `index`.
  ///
  /// - Parameter index: The index of the answer.
  /// - Returns: The message id.
  static func messageID(_ index: Int) -> String {
    "reset-answer-\(index)"
  }

  /// A production change that fails this test: the stack takes the shown
  /// rows from the number of the shown rows of the list, also when the
  /// transcript has fewer entries, so it reads an entry before the start of
  /// the transcript and the app stops.
  @Test func aReplayThatEmptiesTheTranscriptRemovesEachRow() async throws {
    let scripted = try await ScriptedSession.open()
    defer { scripted.close() }
    for index in 0..<Self.answerCount {
      try await scripted.send(
        update: .agentMessageChunk(
          ContentChunk(
            content: .text(TextContent(text: Self.answer(index))),
            messageId: MessageId(rawValue: Self.messageID(index)))))
    }
    await ObservationWait.until { scripted.model.transcript.count == Self.answerCount }
    let thread = try MovingThread(session: scripted.model)
    thread.settle()
    let answers = Set((0..<Self.answerCount).map(Self.answer))
    try #require(thread.textViews.contains { answers.contains($0.string) }, "the list shows no answer")

    _ = try await scripted.connection.resumeSession(ScriptedSession.replayFromStartRequest)
    thread.settle()

    #expect(!thread.textViews.contains { answers.contains($0.string) }, "\(thread.textViews.map(\.string))")
  }
}
