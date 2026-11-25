#if DEBUG
  import AppKit
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// The row bodies that a scroll of a long conversation evaluates
  /// (task ^c4sg6gz, #perf).
  ///
  /// Each element of the `ForEach` of the transcript is one view: the row
  /// of the entry and the modelChanged status lines after it. The test
  /// scrolls the list up in steps, and counts the bodies of the rows with
  /// the ``BodyEvaluationCounter`` key of each row. Before the change, a
  /// scroll of ``stepCount`` steps evaluated 60 row bodies, and no row more
  /// than one time.
  ///
  /// The list is in a borderless window that is never ordered in: no window
  /// shows, and no window takes the focus. Each entry has a message id that
  /// no other test uses, so the counts of other tests do not change the
  /// counts here.
  @MainActor @Suite struct ConversationRowElementTests {
    /// The number of messages in the transcript. It is larger than the rows
    /// in view, so a scroll brings new rows into view.
    static let messageCount = 120

    /// The number of messages between two modelChanged notices.
    static let noticeInterval = 4

    /// The number of scroll steps of the test.
    static let stepCount = 60

    /// The number of rows that one scroll step moves up.
    static let rowsPerStep = 1

    /// The start of the message id of each entry of these tests.
    static let idPrefix = "row-element-scroll-"

    /// The raw message id of the message at `index`.
    ///
    /// - Parameter index: The index of the message in the transcript.
    /// - Returns: The message id.
    static func messageID(_ index: Int) -> String {
      "\(idPrefix)\(index)"
    }

    /// The update of the message at `index`: a user message at an even
    /// index, and an agent message at an odd index.
    ///
    /// - Parameter index: The index of the message.
    /// - Returns: The update.
    static func message(_ index: Int) -> SessionUpdate {
      let chunk = ContentChunk(
        content: .text(TextContent(text: "Message \(index) of the scroll test.")),
        messageId: MessageId(rawValue: messageID(index)))
      return index.isMultiple(of: 2) ? .userMessageChunk(chunk) : .agentMessageChunk(chunk)
    }

    /// A modelChanged notice after the message at `index`.
    ///
    /// - Parameter index: The index of the message.
    /// - Returns: The update of the notice.
    static func modelChange(after index: Int) -> SessionUpdate {
      let meta: [String: JSONValue] = [
        ModelChangeNotice.kindKey: .string(ModelChangeNotice.kind),
        ModelChangeNotice.afterMessageIdKey: .string(messageID(index)),
      ]
      return .notice(Notice(severity: .info, title: "Model changed after \(index).", meta: .object(meta)))
    }

    /// The updates of the transcript: the messages, with a notice after each
    /// ``noticeInterval`` messages.
    static let updates: [SessionUpdate] = (0..<messageCount).flatMap { index in
      index.isMultiple(of: noticeInterval) ? [message(index), modelChange(after: index)] : [message(index)]
    }

    /// A session with the transcript of these tests.
    ///
    /// - Returns: The session model.
    static func makeSession() -> SessionModel {
      .preview(transcript: updates.map(PreviewTranscriptItem.update))
    }

    /// The ``BodyEvaluationCounter`` key of the row of each entry of
    /// `session`.
    ///
    /// - Parameter session: The session model.
    /// - Returns: The keys, in transcript order.
    static func rowCounterKeys(of session: SessionModel) -> [String] {
      session.transcript.map { ItemRow.counterKey(for: $0.rowKey) }
    }

    /// Sets the row body count of each entry of `session` to zero.
    ///
    /// - Parameter session: The session model.
    static func resetRowBodyCounts(of session: SessionModel) {
      for key in rowCounterKeys(of: session) {
        BodyEvaluationCounter.reset(key)
      }
    }

    /// The position in the transcript of the row that a scroll step jumps
    /// to.
    ///
    /// - Parameters:
    ///   - step: The index of the step.
    ///   - session: The session model of the list.
    /// - Returns: The position of the row.
    static func jumpPosition(of step: Int, in session: SessionModel) -> Int {
      session.transcript.count - 1 - step * rowsPerStep
    }

    /// The position in the transcript of the row that the last scroll step
    /// jumps to.
    ///
    /// - Parameter session: The session model of the list.
    /// - Returns: The position of the row.
    static func lastJumpPosition(in session: SessionModel) -> Int {
      jumpPosition(of: stepCount - 1, in: session)
    }

    /// Scrolls the list up in ``stepCount`` steps of ``rowsPerStep`` rows
    /// from the last row, and lays out the host after each step.
    ///
    /// A step of one row jumps to a row next to the rows in view, whose
    /// place the lazy stack knows. A jump to a far row lands at a place that
    /// the stack estimates, and the count of the row bodies then depends on
    /// the sizes that earlier tests measured.
    ///
    /// Each step jumps to a row as the thread minimap does
    /// (``ScrollAnchorManager/noteJump(to:)``), so the follow of the bottom
    /// does not move the list back.
    ///
    /// - Parameters:
    ///   - session: The session model of the list.
    ///   - anchors: The manager of the list.
    ///   - hosting: The host of the list.
    static func scrollUp(_ session: SessionModel, anchors: ScrollAnchorManager, in hosting: NSView) {
      let keys = session.transcript.map(\.rowKey)
      for step in 0..<stepCount {
        let key = keys[jumpPosition(of: step, in: session)]
        anchors.noteJump(to: key)
        anchors.onScroll(.item(key))
        hosting.layoutSubtreeIfNeeded()
      }
    }

    /// A production change that fails this test: an element of the
    /// `ForEach` gets a new identity on each body of the list, so a scroll
    /// makes the rows in view again.
    @Test func aScrollEvaluatesEachRowBodyAtMostOneTime() throws {
      let session = Self.makeSession()
      let anchors = ScrollAnchorManager()
      let window = AnswerTextHitTests.mount(ConversationView(session: session, anchors: anchors))
      let hosting = try #require(window.contentView)
      Self.resetRowBodyCounts(of: session)

      Self.scrollUp(session, anchors: anchors, in: hosting)

      let counts = Self.rowCounterKeys(of: session).map(BodyEvaluationCounter.count)
      try #require(counts[Self.lastJumpPosition(in: session)] > 0, "\(counts)")
      #expect(counts.allSatisfy { $0 <= 1 }, "\(counts)")
      Self.resetRowBodyCounts(of: session)
    }
  }
#endif
