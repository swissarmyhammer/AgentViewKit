#if DEBUG
  import AgentViewKitTestSupport
  import AppKit
  import EditorCommandsUI
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// A scroll of the thread builds no new text of the status line
  /// (^2n9ymsh, #perf).
  ///
  /// The status line is in the top bar of the thread, over the list. A
  /// scroll moves the list and lays out the window again, but it changes no
  /// run of the line. Thus the line must not build its text again.
  ///
  /// The test puts the thread in a borderless window that is never ordered
  /// in (``AnswerTextHitTests/mount(_:)``): no window shows, and no window
  /// takes the focus. The window gives the scroll view of the list a real
  /// clip view to move.
  @MainActor @Suite struct StatusLineScrollBuildTests {
    /// The title of the session: the text of the `session` module. No other
    /// test uses it, so the counter key of the test is its own.
    static let title = "Scroll build count session"

    /// The number of answers in the transcript: more than the height of the
    /// thread (``AnswerTextHitTests/size``) holds, so that the list can scroll.
    static let answerCount = 40

    /// The number of scroll steps.
    static let stepCount = 8

    /// The distance of one scroll step, in points.
    static let stepDistance: CGFloat = 40

    /// A session with ``answerCount`` agent answers.
    ///
    /// - Returns: The session model.
    static func longSession() -> SessionModel {
      .preview(transcript: (0..<answerCount).map { .agent("Answer \($0): the parser reads each line of the file.") })
    }

    /// The ``BodyEvaluationCounter`` key of the text of the `session` module
    /// of the line of a thread.
    ///
    /// - Parameters:
    ///   - session: The session of the thread.
    ///   - connection: The connection of the thread.
    /// - Returns: The key.
    static func sessionTextKey(session: SessionModel, connection: ConnectionModel) throws -> String {
      let input = StatusLineView.input(
        session: session, connection: connection, sessionTitle: title, model: StatusLineModel())
      let rendering = StatusLineRenderer.render(StatusLines.defaultDefinition, input: input)
      let piece = try #require(rendering.pieces.first { $0.module == .session })
      return StatusLineText.counterKey(for: piece.spans)
    }

    /// Moves the clip view of a scroll view up by ``stepCount`` steps, with
    /// one layout pass of the host after each step.
    ///
    /// - Parameters:
    ///   - scrollView: The scroll view of the list.
    ///   - hosting: The host of the thread.
    static func scrollUp(_ scrollView: NSScrollView, in hosting: NSView) {
      let clip = scrollView.contentView
      for _ in 0..<stepCount {
        let origin = clip.bounds.origin
        clip.scroll(to: NSPoint(x: origin.x, y: origin.y - stepDistance))
        scrollView.reflectScrolledClipView(clip)
        hosting.layoutSubtreeIfNeeded()
      }
    }

    /// A production change that fails this test: the text of the line is
    /// built in each evaluation of its body, or in each layout pass, and
    /// not one time for each set of runs.
    @Test func aScrollOfTheListBuildsNoNewTextOfTheLine() throws {
      let session = Self.longSession()
      let connection = ConnectionModel.preview()
      let window = AnswerTextHitTests.mount(
        AgentThreadView(session: session, connection: connection, sessionTitle: Self.title)
          .commandSystem(CommandSystem()))
      let hosting = try #require(window.contentView)
      let scrollView = try #require(
        views(ofType: NSScrollView.self, in: hosting).max { $0.frame.height < $1.frame.height })
      let key = try Self.sessionTextKey(session: session, connection: connection)
      let builds = BodyEvaluationCounter.count(key)
      try #require(builds > 0)
      let start = scrollView.contentView.bounds.origin.y

      Self.scrollUp(scrollView, in: hosting)

      try #require(scrollView.contentView.bounds.origin.y < start)
      #expect(BodyEvaluationCounter.count(key) == builds)
    }
  }
#endif
