#if DEBUG
  import AppKit
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// The static rows of a moving thread do no work on a scroll step that
  /// moves only the offset (card ^9ync5h3, #perf).
  ///
  /// The test shows a ``ConversationView`` of ``answerCount`` agent answers
  /// in a borderless window that is never ordered in: no window shows, and
  /// no window takes the focus. It first scrolls the list at rest from the
  /// bottom to the top and back, so each row has the height of its real
  /// layout and the list reported its rows in view. Then the rows move: the
  /// test posts the start of a live scroll, and each row in view shows its
  /// static form. The test moves the offset of the clip view in
  /// ``stepCount`` steps, with one synchronous layout after each step.
  ///
  /// For each row in view at the start and at the end, the test counts the
  /// bodies of the static row (``TranscriptStaticRow``), the bodies of its
  /// static text (``StaticMarkdownText``) and the layouts of its frame
  /// (``TranscriptStaticRowFrame``). Each count stays at its value before
  /// the steps.
  @MainActor @Suite struct StaticRowScrollTests {
    /// The number of answers in the transcript: more than the rows in view.
    static let answerCount = 50

    /// The number of scroll steps while the rows move.
    static let stepCount = 30

    /// The distance of one scroll step while the rows move, in points. It
    /// has a fraction, as a step of a flick has.
    static let stepDistance: CGFloat = 2.3

    /// The distance of one scroll step at rest, in points: less than the
    /// height of the list, so each row comes into view one time.
    static let settleDistance: CGFloat = 200

    /// The text of the answer at `index`. No other test uses it, so the
    /// counter key of its static text is the key of this test.
    ///
    /// - Parameter index: The index of the answer.
    /// - Returns: The text.
    static func answer(_ index: Int) -> String {
      "Static scroll answer \(index): the parser reads each line of the file."
    }

    /// The counts of the row of the answer at `index`: the bodies of the
    /// static row, the bodies of its static text, and the layouts of its
    /// frame.
    ///
    /// - Parameters:
    ///   - index: The index of the answer in the transcript.
    ///   - session: The session of the list.
    /// - Returns: The three counts.
    static func counts(ofAnswer index: Int, in session: SessionModel) -> [Int] {
      let rowKey = session.transcript[index].rowKey
      return [
        BodyEvaluationCounter.count(TranscriptStaticRow.counterKey(for: rowKey)),
        BodyEvaluationCounter.count(StaticMarkdownText.counterKey(for: answer(index))),
        BodyEvaluationCounter.count(TranscriptStaticRowFrame.counterKey(for: rowKey)),
      ]
    }

    /// The indices of the answers whose rows are in view.
    ///
    /// - Parameters:
    ///   - session: The session of the list.
    ///   - anchors: The manager of the list, which holds the rows in view.
    /// - Returns: The indices in the transcript.
    static func answersInView(of session: SessionModel, anchors: ScrollAnchorManager) -> Set<Int> {
      let inView = Set(anchors.visibleIDs)
      return Set(session.transcript.indices.filter { inView.contains(session.transcript[$0].rowKey) })
    }

    /// Moves the clip view of a scroll view to `y`, and lays the host out
    /// after the blocks of the main run loop that the layout added, so the
    /// list reports the rows in view.
    ///
    /// - Parameters:
    ///   - y: The new offset of the clip view.
    ///   - scrollView: The scroll view of the list.
    ///   - hosting: The host of the list.
    static func scrollAtRest(to y: CGFloat, _ scrollView: NSScrollView, in hosting: NSView) async {
      let clip = scrollView.contentView
      clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: y))
      scrollView.reflectScrolledClipView(clip)
      hosting.layoutSubtreeIfNeeded()
      await RunLoopBlockFence.afterPendingBlocks()
      hosting.layoutSubtreeIfNeeded()
    }

    /// Scrolls the list at rest from the bottom to the top and back, so
    /// each row was real one time and has the height of its layout.
    ///
    /// - Parameters:
    ///   - scrollView: The scroll view of the list.
    ///   - hosting: The host of the list.
    static func showEachRowAtRest(_ scrollView: NSScrollView, in hosting: NSView) async {
      let bottom = scrollView.contentView.bounds.origin.y
      let up = stride(from: bottom, through: .zero, by: -settleDistance).dropFirst()
      for y in Array(up) + [.zero] + Array(stride(from: .zero, through: bottom, by: settleDistance)) + [bottom] {
        await scrollAtRest(to: y, scrollView, in: hosting)
      }
    }

    /// Starts a live scroll of the list, so the rows move, and lays the host
    /// out after the blocks of the main run loop that the layout added.
    ///
    /// - Parameters:
    ///   - scrollView: The scroll view of the list.
    ///   - hosting: The host of the list.
    static func startMoving(_ scrollView: NSScrollView, in hosting: NSView) async {
      NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scrollView)
      hosting.layoutSubtreeIfNeeded()
      await RunLoopBlockFence.afterPendingBlocks()
      hosting.layoutSubtreeIfNeeded()
    }

    /// Moves the offset of the list up in ``stepCount`` steps of
    /// ``stepDistance``, with one synchronous layout after each step.
    ///
    /// - Parameters:
    ///   - scrollView: The scroll view of the list.
    ///   - hosting: The host of the list.
    static func stepWhileMoving(_ scrollView: NSScrollView, in hosting: NSView) {
      let clip = scrollView.contentView
      for _ in 0..<stepCount {
        let origin = clip.bounds.origin
        clip.scroll(to: NSPoint(x: origin.x, y: origin.y - stepDistance))
        scrollView.reflectScrolledClipView(clip)
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: scrollView)
        hosting.layoutSubtreeIfNeeded()
      }
    }

    /// A production change that fails this test: a value that each row
    /// observes changes on each scroll step, or the frame of a static row
    /// takes a new layout on each step, so SwiftUI lays out and draws the
    /// static text of each row in view again on each frame of a flick.
    @Test func aStaticRowInViewDoesNoWorkOnAStepOfTheOffset() async throws {
      let session = SessionModel.preview(transcript: (0..<Self.answerCount).map { .agent(Self.answer($0)) })
      let anchors = ScrollAnchorManager()
      let window = AnswerTextHitTests.mount(ConversationView(session: session, anchors: anchors))
      let hosting = try #require(window.contentView)
      let scrollView = try #require(
        views(ofType: NSScrollView.self, in: hosting).max { $0.frame.height < $1.frame.height })
      await Self.showEachRowAtRest(scrollView, in: hosting)
      await Self.startMoving(scrollView, in: hosting)
      try #require(views(ofType: NSTextView.self, in: hosting).isEmpty)
      let atStart = Self.answersInView(of: session, anchors: anchors)
      let before = Dictionary(uniqueKeysWithValues: atStart.map { ($0, Self.counts(ofAnswer: $0, in: session)) })
      try #require(before.values.allSatisfy { $0.allSatisfy { $0 > 0 } })

      Self.stepWhileMoving(scrollView, in: hosting)

      let staying = atStart.intersection(Self.answersInView(of: session, anchors: anchors)).sorted()
      try #require(!staying.isEmpty)
      let after = staying.map { Self.counts(ofAnswer: $0, in: session) }
      #expect(after == staying.map { before[$0] }, "rows \(staying): \(staying.map { before[$0] }) -> \(after)")
    }
  }
#endif
