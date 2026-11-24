#if DEBUG
  import AgentViewKitTestSupport
  import AppKit
  import EditorCommands
  import EditorCommandsUI
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// The scroll-to-bottom pill stays in the view tree while the list is
  /// pinned to the bottom (task ^ts5hyjr, #scroll-perf).
  ///
  /// An unpin must not make the button of the pill: the EditorKit button,
  /// its glass and its control scope. The pill hides its button in place, so
  /// an unpin evaluates only the body of the pill. The views are in an
  /// `NSHostingView` with no window, so a test shows no window and takes no
  /// focus. Each test makes its own manager and session, so the counter keys
  /// of the tests do not mix.
  @MainActor @Suite struct ConversationPillMountTests {
    /// The row keys of the list of a test that has no session.
    static let rowKeys = ["first-row", "last-row"]

    /// Unpins a manager from the bottom: the list shows its first row, far
    /// from the bottom.
    ///
    /// - Parameters:
    ///   - anchors: The manager.
    ///   - keys: The row keys of the list, in list order.
    static func unpin(_ anchors: ScrollAnchorManager, rowKeys keys: [String]) {
      anchors.noteLastItemChanged(to: keys.last)
      anchors.noteVisible(ids: Array(keys.prefix(1)), distanceFromBottom: .greatestFiniteMagnitude)
    }

    /// A pill of `anchors` in a host with no window, at its ideal size, laid
    /// out one time.
    ///
    /// - Parameter anchors: The manager of the pill.
    /// - Returns: The host.
    static func mountPill(_ anchors: ScrollAnchorManager) -> NSHostingView<some View> {
      mountPill(anchors) { $0 }
    }

    /// A pill of `anchors` in the view that `wrap` makes of it, in a host
    /// with no window, laid out one time.
    ///
    /// - Parameters:
    ///   - anchors: The manager of the pill.
    ///   - wrap: Makes the root view of the host from the pill.
    /// - Returns: The host.
    static func mountPill<Root: View>(
      _ anchors: ScrollAnchorManager, wrap: (AnyView) -> Root
    ) -> NSHostingView<Root> {
      let hosting = NSHostingView(rootView: wrap(AnyView(ConversationPill(anchors: anchors).fixedSize())))
      StyleViewHost.layOut(hosting)
      return hosting
    }

    /// A thread of a session with two messages and `anchors`, in a host with
    /// no window, laid out one time.
    ///
    /// - Parameters:
    ///   - session: The session model of the thread.
    ///   - anchors: The manager of the scroll position of the thread.
    /// - Returns: The host.
    static func mountThread(_ session: SessionModel, anchors: ScrollAnchorManager)
      -> NSHostingView<some View>
    {
      StyleViewHost.host(
        AgentThreadView(session: session, anchors: anchors) { EmptyView() },
        size: CGSize(width: ThreadHeaderTests.width, height: ThreadHeaderTests.height))
    }

    /// A session with one prompt and one answer.
    ///
    /// - Returns: The session model.
    static func twoMessageSession() -> SessionModel {
      .preview(transcript: [.user("Fix the test."), .agent("Done.")])
    }

    /// A pill of `anchors` in the agent command scope of a session, with a
    /// command system, in a host with no window, laid out one time.
    ///
    /// - Parameters:
    ///   - anchors: The manager of the pill.
    ///   - system: The command system of the host.
    /// - Returns: The host and the path of the control scope of the pill.
    static func mountScopedPill(_ anchors: ScrollAnchorManager, system: CommandSystem)
      -> (hosting: NSHostingView<some View>, path: FocusPath)
    {
      let session = twoMessageSession()
      let hosting = mountPill(anchors) { pill in
        pill.agentCommandScope(session: session).commandSystem(system)
      }
      let path = FocusPath.root(AgentCommandTarget.segment(for: session))
        .appending(AgentScopeKind.control(ScrollToBottomPill.identifier))
      return (hosting, path)
    }

    /// A production change that fails this test: the hidden pill keeps the
    /// targeting of a shown control, so a jump session gives it a label and
    /// a commit on its path presses it. A disabled pill is not enough:
    /// EditorKit reads the disabled state from the accessibility tree, and
    /// the hidden pill is not in that tree.
    @Test func aPinnedPillIsNoTargetOfJumpAndNavigation() throws {
      let system = CommandSystem()
      let anchors = ScrollAnchorManager()
      let (hosting, path) = Self.mountScopedPill(anchors, system: system)

      try withExtendedLifetime(hosting) {
        try #require(anchors.isPinnedToBottom)
        try #require(system.geometry.livePaths.contains(path), "\(system.geometry.livePaths)")
        #expect(!system.geometry.isTargetable(at: path))
      }
    }

    /// A production change that fails this test: the pill stays out of
    /// targeting after an unpin, so a jump session gives the shown pill no
    /// label.
    @Test func anUnpinnedPillIsATargetOfJumpAndNavigation() throws {
      let system = CommandSystem()
      let anchors = ScrollAnchorManager()
      let (hosting, path) = Self.mountScopedPill(anchors, system: system)

      Self.unpin(anchors, rowKeys: Self.rowKeys)
      StyleViewHost.layOut(hosting)

      try #require(!anchors.isPinnedToBottom)
      try #require(system.geometry.livePaths.contains(path), "\(system.geometry.livePaths)")
      #expect(system.geometry.isTargetable(at: path))
    }

    /// A production change that fails this test: the pill removes its button
    /// while the list is pinned, so a pinned pill takes no space.
    @Test func aPinnedPillHasTheSizeOfTheShownPill() throws {
      let anchors = ScrollAnchorManager()
      let hosting = Self.mountPill(anchors)
      let pinnedSize = hosting.fittingSize

      Self.unpin(anchors, rowKeys: Self.rowKeys)
      StyleViewHost.layOut(hosting)

      try #require(!anchors.isPinnedToBottom)
      let shownSize = hosting.fittingSize
      try #require(shownSize.height > 0)
      #expect(pinnedSize == shownSize)
    }

    /// A production change that fails this test: the pill makes its button
    /// on an unpin, or the button reads the pin state.
    @Test func anUnpinDoesNotEvaluateTheButtonOfThePill() throws {
      let anchors = ScrollAnchorManager()
      let hosting = Self.mountPill(anchors)
      let key = ConversationPill.buttonCounterKey(for: anchors)
      BodyEvaluationCounter.reset(key)

      Self.unpin(anchors, rowKeys: Self.rowKeys)
      StyleViewHost.layOut(hosting)

      try #require(!anchors.isPinnedToBottom)
      #expect(BodyEvaluationCounter.count(key) == 0)
      BodyEvaluationCounter.reset(key)
    }

    /// A production change that fails this test: the pill does not read the
    /// pin state in its own body, or a view above it reads the pin state
    /// and evaluates the pill again.
    @Test func anUnpinEvaluatesThePillOneTime() throws {
      let anchors = ScrollAnchorManager()
      let hosting = Self.mountPill(anchors)
      let key = ConversationPill.counterKey(for: anchors)
      BodyEvaluationCounter.reset(key)

      Self.unpin(anchors, rowKeys: Self.rowKeys)
      StyleViewHost.layOut(hosting)

      try #require(!anchors.isPinnedToBottom)
      #expect(BodyEvaluationCounter.count(key) == 1)
      BodyEvaluationCounter.reset(key)
    }

    /// A production change that fails this test: the thread reads the pin
    /// state in its own body, so an unpin makes the floating controls of
    /// the thread again.
    @Test func anUnpinDoesNotEvaluateTheFloatingControlsOfTheThread() throws {
      let session = Self.twoMessageSession()
      let anchors = ScrollAnchorManager()
      let hosting = Self.mountThread(session, anchors: anchors)
      let key = AgentThreadLayout.floatingControlsCounterKey(for: session)
      try #require(BodyEvaluationCounter.count(key) > 0)
      BodyEvaluationCounter.reset(key)

      Self.unpin(anchors, rowKeys: session.transcript.map(\.rowKey))
      StyleViewHost.layOut(hosting)

      try #require(!anchors.isPinnedToBottom)
      #expect(BodyEvaluationCounter.count(key) == 0)
      BodyEvaluationCounter.reset(key)
    }
  }
#endif
