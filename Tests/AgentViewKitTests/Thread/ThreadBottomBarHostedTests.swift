#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorCommandsUI
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Tests for the bottom bar of a thread: the state banner and the login
  /// prompt are in the bar with the composer, and the list scrolls under the
  /// bar (TestudoApp `features/style.md`, "Scroll under the bars", D113
  /// answer 7).
  ///
  /// The frame tests read the frames that the views report to AppKit after
  /// one layout pass of the window: the frame of the `NSScrollView` of the
  /// list, and the accessibility frame of the banner. The list and the banner
  /// are inside the thread view, so a test cannot put a preference key on
  /// them. A change that a test makes on the main actor is followed by one
  /// render pass. A frame of the agent is followed by a wait for the model
  /// value that the frame is certain to change.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadBottomBarHostedTests {
    /// The largest difference, in points, between two edges that a frame
    /// test counts as the same edge. Layout rounds an edge to a pixel.
    static let edgeTolerance: CGFloat = 0.5

    /// A session model with ``ConversationViewHostedTests/scrollEntryCount``
    /// agent messages, and an agent that runs, so that the state banner
    /// shows.
    ///
    /// The transcript is taller than the window, so that the rows fill the
    /// part of the list in view.
    ///
    /// - Returns: The session model.
    static func runningSession() -> SessionModel {
      let messages = Array(repeating: PreviewTranscriptItem.agent("Done."), count: ConversationViewHostedTests.scrollEntryCount)
      return .preview(transcript: messages + [.update(.stateUpdate(.running(RunningStateUpdate())))])
    }

    /// The full frame of the list in `harness`, in screen points.
    ///
    /// The accessibility frame of the list is only the part in view: it
    /// leaves out the content insets that a bar gives. The full frame is the
    /// frame of the `NSScrollView` that holds that part.
    ///
    /// - Parameter harness: The harness that shows the list.
    /// - Returns: The frame of the scroll view of the list.
    /// - Throws: An issue when the list or its scroll view is not there.
    static func listFrame(in harness: HostedViewHarness<some View>) throws -> CGRect {
      let visiblePart = try #require(harness.frame(identifier: ConversationLayout.listIdentifier))
      let frames = harness.views(of: NSScrollView.self).map(harness.screenFrame(of:))
      return try #require(frames.first { $0.contains(visiblePart) })
    }

    /// Requires that the list in `harness` reaches the bottom edge of the
    /// hosting view, and that the state banner is inside the frame of the
    /// list, so that the list scrolls under the banner.
    ///
    /// - Parameter harness: The harness that shows the list and the banner.
    /// - Throws: An issue when the list or the banner is not there.
    static func expectListUnderTheBanner(in harness: HostedViewHarness<some View>) throws {
      let host = harness.screenFrame(of: harness.hostingView)
      let list = try listFrame(in: harness)
      let banner = try #require(harness.frame(identifier: StateBanner.bannerIdentifier))

      #expect(abs(list.minY - host.minY) <= edgeTolerance, "list \(list), host \(host)")
      #expect(list.contains(banner), "list \(list), banner \(banner)")
    }

    /// The position of the first element with `identifier` in the floating
    /// controls of the thread in `harness`.
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier.
    ///   - harness: The harness that shows the thread.
    /// - Returns: The position, in depth first order.
    /// - Throws: An issue when the floating controls hold no such element.
    static func floatingPosition(of identifier: String, in harness: HostedViewHarness<some View>) throws -> Int {
      try #require(ThreadFloatingControlsHostedTests.floatingControlIdentifiers(in: harness).firstIndex(of: identifier))
    }

    @Test func theStateBannerIsInTheFloatingControlsOfTheThread() {
      let harness = HostedViewHarness(size: ThreadFloatingControlsHostedTests.windowSize) {
        AgentThreadView(session: Self.runningSession())
      }
      defer { harness.close() }
      harness.render()

      let identifiers = ThreadFloatingControlsHostedTests.floatingControlIdentifiers(in: harness)
      #expect(identifiers.contains(StateBanner.bannerIdentifier))
    }

    @Test func theLoginPromptIsInTheFloatingControlsOfTheThread() async throws {
      let session = try await ConnectionModelViewsHostedTests.openSession()
      defer { session.close() }
      let harness = ConnectionModelViewsHostedTests.mountThread(session)
      defer { harness.close() }
      harness.render()

      let identifiers = ThreadFloatingControlsHostedTests.floatingControlIdentifiers(in: harness)
      #expect(identifiers.contains(AgentAuthView.identifier))
    }

    /// VoiceOver reads the floating controls in order: the banner, the login
    /// prompt, and then the composer.
    @Test func theFloatingControlsReadTheBannerThenThePromptThenTheComposer() async throws {
      let session = try await ConnectionModelViewsHostedTests.openSession()
      defer { session.close() }
      let model = session.model
      try await session.sendUpdate(ScriptedSession.endTurnState)
      await ObservationWait.until { model.agentState != nil }
      let harness = ConnectionModelViewsHostedTests.mountThread(session)
      defer { harness.close() }
      harness.render()

      let banner = try Self.floatingPosition(of: StateBanner.bannerIdentifier, in: harness)
      let prompt = try Self.floatingPosition(of: AgentAuthView.identifier, in: harness)
      let composer = try Self.floatingPosition(of: DefaultPromptAccessory.submitIdentifier, in: harness)
      #expect(banner < prompt)
      #expect(prompt < composer)
    }

    @Test func theListOfTheThreadReachesTheBottomEdgeUnderTheBanner() throws {
      let harness = HostedViewHarness(size: ThreadFloatingControlsHostedTests.windowSize) {
        AgentThreadView(session: Self.runningSession())
      }
      defer { harness.close() }
      harness.render()

      try Self.expectListUnderTheBanner(in: harness)
    }

    @Test func theListOfAConversationAloneReachesTheBottomEdgeUnderTheBanner() throws {
      let harness = HostedViewHarness(size: ThreadFloatingControlsHostedTests.windowSize) {
        ConversationView(session: Self.runningSession())
      }
      defer { harness.close() }
      harness.render()

      try Self.expectListUnderTheBanner(in: harness)
    }

    /// The reaction of the thread to a press on the Show Error button of its
    /// banner: the list scrolls to the error entry, and the manager keeps the
    /// error entry as its anchor. See
    /// ``ConversationViewHostedTests/theShowErrorButtonMovesToTheErrorEntry()``
    /// for the conversation alone.
    @Test func theShowErrorButtonOfTheThreadMovesToTheErrorEntry() async throws {
      let (session, errorKey) = try await ConversationViewHostedTests.openSessionWithErrorAtTop()
      defer { session.close() }
      let anchors = ScrollAnchorManager()
      let harness = ThreadFloatingControlsHostedTests.mount(session, anchors: anchors, system: CommandSystem()) {
        EmptyView()
      }
      defer { harness.close() }
      ConversationViewHostedTests.reportRows(at: .bottom, of: session.model, to: anchors)
      #expect(!ConversationViewHostedTests.showsRow(errorKey, in: harness))

      try await ConversationViewHostedTests.pressShowError(of: session, in: harness)

      #expect(ConversationViewHostedTests.showsRow(errorKey, in: harness))
      #expect(anchors.anchorID == errorKey)
    }
  }
#endif
