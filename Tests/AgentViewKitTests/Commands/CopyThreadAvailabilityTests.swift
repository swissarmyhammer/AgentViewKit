import AgentViewKitTestSupport
import AppKit
import EditorCommandsUI
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The availability check of Copy Thread (task ^6w509rj, #perf).
///
/// The check (``ThreadExporter/hasMessageText(in:)``) must give the same
/// answer as `!AgentCommandTarget.plainText(of:).isEmpty` for each
/// transcript, and it must not render the copy text. Each message footer
/// asks for the availability of Copy Thread, and each streamed chunk changes
/// the transcript.
@MainActor @Suite struct CopyThreadAvailabilityTests {
  /// The number of user messages and of agent messages of a long mixed
  /// transcript: each one comes with a thought and a tool call.
  nonisolated static let longTurnCount = 60

  /// A text block that only the assistant reads.
  nonisolated static let assistantOnlyText = FoundationModelsACP.ContentBlock.text(
    TextContent(text: "Hidden.", annotations: FoundationModelsACP.Annotations(audience: [.assistant])))

  /// An agent message chunk with one block.
  ///
  /// - Parameters:
  ///   - block: The content block of the chunk.
  ///   - id: The raw message id of the chunk.
  /// - Returns: The preview item of the chunk.
  nonisolated static func agentChunk(_ block: FoundationModelsACP.ContentBlock, id: String) -> PreviewTranscriptItem {
    .update(.agentMessageChunk(ContentChunk(content: block, messageId: MessageId(rawValue: id))))
  }

  /// A completed tool call that reads a file.
  nonisolated static let toolCall = PreviewTranscriptItem.toolCall(title: "Read", kind: .read, status: .completed)

  /// The items of some turns: for each turn, a user message, then the
  /// work items of the turn, then an agent message.
  ///
  /// - Parameters:
  ///   - count: The number of turns.
  ///   - work: Gives the items between the two messages of a turn.
  /// - Returns: The items, in transcript order.
  nonisolated static func turns(
    _ count: Int, work: (Int) -> [PreviewTranscriptItem] = { _ in [] }
  ) -> [PreviewTranscriptItem] {
    (0..<count).flatMap { turn in
      [.user("Question \(turn).")] + work(turn) + [.agent("Answer \(turn).")]
    }
  }

  /// The items of a long transcript: for each turn, a user message, a
  /// thought, a tool call and an agent message.
  nonisolated static let longMixedTranscript = turns(longTurnCount) { turn in
    [.thought("Think \(turn)."), toolCall]
  }

  /// The transcripts of the agreement test, by name.
  nonisolated static let transcripts: [String: [PreviewTranscriptItem]] = [
    "empty": [],
    "only tool calls": [toolCall, toolCall],
    "only a user message": [.user("Fix the test.")],
    "a message with empty text": [agentChunk(.text(TextContent(text: "")), id: "empty-text")],
    "only text for the assistant": [agentChunk(assistantOnlyText, id: "assistant-only")],
    "only a thought": [.thought("Think.")],
    "a long mixed transcript": longMixedTranscript,
  ]

  /// A production change that fails this test: the check reads an entry
  /// that the copy text omits, or omits an entry that the copy text keeps.
  @Test(arguments: transcripts.keys.sorted())
  func theCheckAgreesWithTheCopyText(name: String) throws {
    let session = SessionModel.preview(transcript: try #require(Self.transcripts[name]))

    #expect(
      ThreadExporter.hasMessageText(in: session.transcript)
        == !AgentCommandTarget.plainText(of: session).isEmpty)
  }

  // MARK: - Renders

  #if DEBUG
    /// The number of message rows of the mounted thread: a user message and
    /// an agent message for each turn.
    static let mountedTurnCount = 10

    /// The number of agent message chunks that the test streams.
    static let streamedChunkCount = 50

    /// The raw message id of the streamed agent message.
    static let streamedMessageID = "copy-thread-stream"

    /// A thread of `session` with a message footer on each message row, in
    /// a window that is never ordered in, laid out one time.
    ///
    /// - Parameter session: The session model of the thread.
    /// - Returns: The window. Its content view is the host of the thread.
    static func mountThreadWithFooters(_ session: SessionModel) -> NSWindow {
      AnswerTextHitTests.mount(
        AgentThreadView(session: session)
          .messageFooter { entry in MessageActions(entry: entry) }
          .commandSystem(CommandSystem()))
    }

    /// A production change that fails this test: the availability check of
    /// Copy Thread renders the copy text of the whole thread.
    @Test func streamedChunksRenderNoCopyText() {
      let session = SessionModel.preview(transcript: Self.turns(Self.mountedTurnCount))
      let key = AgentCommandTarget.plainTextCounterKey(for: session)
      BodyEvaluationCounter.reset(key)
      let window = Self.mountThreadWithFooters(session)

      withExtendedLifetime(window) {
        for chunk in 0..<Self.streamedChunkCount {
          session.apply(
            .agentMessageChunk(
              ContentChunk(
                content: .text(TextContent(text: "Chunk \(chunk). ")),
                messageId: MessageId(rawValue: Self.streamedMessageID))))
          window.contentView?.layoutSubtreeIfNeeded()
        }
      }

      #expect(BodyEvaluationCounter.count(key) == 0)
      BodyEvaluationCounter.reset(key)
    }
  #endif
}
