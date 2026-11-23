#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorCommands
  import EditorCommandsUI
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The scroll-to-bottom pill of a thread stays in the view tree while the
  /// list is pinned to the bottom (task ^ts5hyjr, #scroll-perf).
  ///
  /// The pill hides its button in place, so an unpin from the bottom only
  /// changes the values of the hidden pill. The tests show a thread in a
  /// harness window, and read the counts of ``BodyEvaluationCounter``, the
  /// accessibility tree, the jump labels and the frame of the floating
  /// controls. The unpin test gives the manager one report of the rows at the
  /// top, the call that the list makes after a scroll up, and then makes one
  /// render pass. A pinned test makes no change after the first render pass.
  @Suite(.serialized, .hostedSerially) @MainActor struct ConversationPillMountHostedTests {
    /// Opens a long session and shows its thread with `anchors`. The list
    /// of a new thread starts at the bottom, so the manager stays pinned.
    ///
    /// - Parameters:
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - system: The command system of the window.
    /// - Returns: The session and the harness, after one render pass.
    /// - Throws: The error of the scripted session.
    static func mountThread(anchors: ScrollAnchorManager, system: CommandSystem) async throws
      -> (ScriptedSession, HostedViewHarness<some View>)
    {
      let session = try await ThreadFloatingControlsHostedTests.openLongSession()
      let harness = ThreadFloatingControlsHostedTests.mount(
        session, anchors: anchors, system: system
      ) {
        EmptyView()
      }
      return (session, harness)
    }

    /// Opens a long session and shows its thread in the window of the jump
    /// tests, with the hidden pill of the pinned list as the shown control.
    ///
    /// - Parameters:
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - system: The command system of the window.
    /// - Returns: The shown control, after one render pass.
    /// - Throws: The error of the scripted session.
    static func showHiddenPill(anchors: ScrollAnchorManager, system: CommandSystem) async throws
      -> ShownBarControl
    {
      let session = try await ThreadFloatingControlsHostedTests.openLongSession()
      return ShownBarControl(
        harness: ThreadBarControlJumpHostedTests.mount(
          session.model, anchors: anchors, system: system),
        session: session.model, identifier: ScrollToBottomPill.identifier, wasPressed: nil,
        closeSession: session.close)
    }

    /// Unpins the thread one time: the manager gets the report of the rows
    /// at the top of the transcript, and the harness makes one render pass.
    ///
    /// - Parameters:
    ///   - session: The scripted session of the thread.
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - harness: The harness that shows the thread.
    static func unpinOneTime(
      _ session: ScriptedSession, anchors: ScrollAnchorManager,
      harness: HostedViewHarness<some View>
    ) {
      ConversationViewHostedTests.reportRows(at: .top, of: session.model, to: anchors)
      harness.render()
    }

    /// Sets the counts of the floating controls, of the pill and of its
    /// button to zero.
    ///
    /// - Parameters:
    ///   - session: The session model of the thread.
    ///   - anchors: The manager of the scroll position of the thread.
    static func resetCounts(of session: SessionModel, anchors: ScrollAnchorManager) {
      BodyEvaluationCounter.reset(AgentThreadLayout.floatingControlsCounterKey(for: session))
      BodyEvaluationCounter.reset(ConversationPill.counterKey(for: anchors))
      BodyEvaluationCounter.reset(ConversationPill.buttonCounterKey(for: anchors))
    }

    /// The count of `key` after one unpin of a pinned thread.
    ///
    /// - Parameter key: The function that gives the counter key from the
    ///   session model and the manager of the thread.
    /// - Returns: The count of the key in the unpin.
    /// - Throws: The error of the scripted session, or an issue when the
    ///   unpin does not unpin the manager.
    static func countInOneUnpin(
      of key: @MainActor (SessionModel, ScrollAnchorManager) -> String
    ) async throws -> Int {
      let anchors = ScrollAnchorManager()
      let (session, harness) = try await mountThread(anchors: anchors, system: CommandSystem())
      defer {
        harness.close()
        session.close()
        resetCounts(of: session.model, anchors: anchors)
      }
      try #require(anchors.isPinnedToBottom)
      resetCounts(of: session.model, anchors: anchors)

      unpinOneTime(session, anchors: anchors, harness: harness)

      try #require(!anchors.isPinnedToBottom)
      return BodyEvaluationCounter.count(key(session.model, anchors))
    }

    /// A production change that fails this test: the thread reads the pin
    /// state in its own body, so an unpin makes its floating controls again.
    @Test func anUnpinDoesNotEvaluateTheFloatingControls() async throws {
      let count = try await Self.countInOneUnpin { session, _ in
        AgentThreadLayout.floatingControlsCounterKey(for: session)
      }

      #expect(count == 0)
    }

    /// A production change that fails this test: the pill does not read the
    /// pin state in its own body, or a view above it evaluates it again.
    @Test func anUnpinEvaluatesThePillOneTime() async throws {
      let count = try await Self.countInOneUnpin { _, anchors in
        ConversationPill.counterKey(for: anchors)
      }

      #expect(count == 1)
    }

    /// A production change that fails this test: the pill makes its button
    /// on an unpin, or the button reads the pin state.
    @Test func anUnpinDoesNotEvaluateTheButtonOfThePill() async throws {
      let count = try await Self.countInOneUnpin { _, anchors in
        ConversationPill.buttonCounterKey(for: anchors)
      }

      #expect(count == 0)
    }

    /// A production change that fails this test: the hidden pill of a
    /// pinned thread is in the accessibility tree.
    @Test func aPinnedThreadHasNoPillInTheAccessibilityTree() async throws {
      let anchors = ScrollAnchorManager()
      let (session, harness) = try await Self.mountThread(anchors: anchors, system: CommandSystem())
      defer {
        harness.close()
        session.close()
      }
      try #require(anchors.isPinnedToBottom)

      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    /// A production change that fails this test: the unpin moves the pill
    /// into the layout of the floating controls, so the glass container of
    /// the bottom bar changes its frame.
    @Test func anUnpinKeepsTheFrameOfTheFloatingControls() async throws {
      let anchors = ScrollAnchorManager()
      let (session, harness) = try await Self.mountThread(anchors: anchors, system: CommandSystem())
      defer {
        harness.close()
        session.close()
      }
      try #require(anchors.isPinnedToBottom)
      let controls = AgentThreadLayout.floatingControlsIdentifier
      let pinnedFrame = try #require(harness.frame(identifier: controls))

      Self.unpinOneTime(session, anchors: anchors, harness: harness)

      try #require(harness.element(identifier: ScrollToBottomPill.identifier) != nil)
      #expect(harness.frame(identifier: controls) == pinnedFrame)
    }

    /// A production change that fails this test: the hidden pill of a
    /// pinned thread is enabled, so a jump session gives it a label and a
    /// commit on its path presses it.
    @Test func aPinnedThreadGivesThePillNoJumpLabel() async throws {
      let system = CommandSystem()
      let anchors = ScrollAnchorManager()
      let shown = try await Self.showHiddenPill(anchors: anchors, system: system)
      defer { shown.close() }
      try #require(anchors.isPinnedToBottom)
      let jump = try ThreadBarControlJumpHostedTests.openJump(on: shown, system: system)

      let chips = try #require(jump.overlayState?.chips)

      #expect(!chips.contains { $0.id == shown.path }, "\(chips.map(\.id))")
    }

    /// A production change that fails this test: the hidden pill of a
    /// pinned thread takes a landed jump.
    @Test func aJumpCommitOnTheHiddenPillLandsNowhere() async throws {
      let system = CommandSystem()
      let anchors = ScrollAnchorManager()
      let shown = try await Self.showHiddenPill(anchors: anchors, system: system)
      defer { shown.close() }
      try #require(anchors.isPinnedToBottom)
      let jump = try ThreadBarControlJumpHostedTests.openJump(on: shown, system: system)

      #expect(!jump.commit(shown.path))
    }
  }
#endif
