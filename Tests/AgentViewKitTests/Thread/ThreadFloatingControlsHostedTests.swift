#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorCommands
  import EditorCommandsUI
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Tests for the floating controls of ``AgentThreadView``: the
  /// scroll-to-bottom pill and the composer slot in one glass container
  /// (D110 (c), D36).
  ///
  /// A change that the test makes on the main actor is followed by one render
  /// pass. A frame of the agent is followed by a wait for the model value that
  /// the frame is certain to change. No test waits for the pill: a scroll up
  /// by command unpins the manager in the layout pass that moves the list,
  /// and the test checks that state before it reads the pill.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadFloatingControlsHostedTests {
    /// The size of a window that shows a thread and a composer. The
    /// transcript of the scroll tests is taller than the list in it.
    static let windowSize = CGSize(width: 480, height: 480)

    /// The message id of the user message at the top of the transcript.
    static let promptMessageID = "floating-u1"

    /// The text of the user message and of the composer.
    static let message = "Hello"

    /// Opens a scripted session whose transcript has one user message and
    /// then ``ConversationViewHostedTests/scrollEntryCount`` agent messages.
    ///
    /// When a send fails, the helper closes the session before it throws.
    ///
    /// - Returns: The session, after the model shows each message.
    /// - Throws: The error of the scripted session.
    static func openLongSession() async throws -> ScriptedSession {
      let session = try await ScriptedSession.open()
      do {
        try await session.sendUpdate(
          SessionTranscriptViewHostedTests.chunk(
            "user_message_chunk", messageID: promptMessageID, text: message))
        try await ConversationViewHostedTests.sendMessages(
          ConversationViewHostedTests.scrollEntryCount, to: session)
      } catch {
        session.close()
        throw error
      }
      return session
    }

    /// Mounts the thread view of `session` with `anchors` and `composer` in
    /// the slot, in a window with a command system.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - system: The command system of the window.
    ///   - composer: The builder of the view in the composer slot.
    /// - Returns: The harness, after one render pass.
    static func mount<Composer: View>(
      _ session: ScriptedSession, anchors: ScrollAnchorManager, system: CommandSystem,
      @ViewBuilder composer: () -> Composer
    ) -> HostedViewHarness<some View> {
      let thread = AgentThreadView(session: session.model, anchors: anchors, composer: composer)
      let harness = HostedViewHarness(size: windowSize) {
        thread
          .commandSystem(system)
          .transaction { $0.disablesAnimations = true }
      }
      harness.render()
      return harness
    }

    /// Scrolls the thread up with the Previous Prompt command
    /// (``AgentCommandVerb/jumpToPrevious``), and lays out the result.
    ///
    /// The helper gives the manager the report of the rows at the bottom
    /// first, so that the command starts at a known row. The command then
    /// goes to the user message at the top. In the harness window, SwiftUI
    /// calls the visibility action of the list in the layout pass that moves
    /// the list, and that report unpins the manager
    /// (``ConversationViewHostedTests/aScrollUpMakesTheListReportItsRowsAndShowThePill()``).
    /// The helper checks that the manager is unpinned, and one more render
    /// pass then shows the reaction of the view: the pill.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - system: The command system of the window.
    ///   - harness: The harness that shows the thread.
    /// - Throws: An issue when the command does not run, or when the list
    ///   does not unpin the manager.
    static func scrollUpByCommand(
      _ session: ScriptedSession, anchors: ScrollAnchorManager, system: CommandSystem,
      harness: HostedViewHarness<some View>
    ) throws {
      let model = session.model
      ConversationViewHostedTests.reportRows(at: .bottom, of: model, to: anchors)
      let path = FocusPath.root(AgentCommandTarget.segment(for: model))
      try #require(system.registry.perform(AgentCommandVerb.jumpToPrevious.id, at: path))
      harness.render()
      try #require(!anchors.isPinnedToBottom)
      harness.render()
    }

    /// The identifiers of the elements in the floating controls of the
    /// thread.
    ///
    /// - Parameter harness: The harness that shows the thread.
    /// - Returns: The identifiers, in depth first order.
    static func floatingControlIdentifiers(in harness: HostedViewHarness<some View>) -> [String] {
      harness.elements(under: AgentThreadLayout.floatingControlsIdentifier).compactMap(\.identifier)
    }

    @Test func theDefaultComposerIsInTheFloatingControlsOfTheThread() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(size: Self.windowSize) {
        AgentThreadView(session: session.model)
      }
      defer { harness.close() }
      harness.render()

      let identifiers = Self.floatingControlIdentifiers(in: harness)
      #expect(identifiers.contains(DefaultPromptAccessory.submitIdentifier))
      #expect(identifiers.contains(StockPromptEditor.identifier))
    }

    @Test func aScrollUpByCommandShowsThePillInTheContainerOfTheComposer() async throws {
      let session = try await Self.openLongSession()
      defer { session.close() }
      let anchors = ScrollAnchorManager()
      let system = CommandSystem()
      let draft = PromptInputHostedTestModel()
      let harness = Self.mount(session, anchors: anchors, system: system) {
        PromptInputHost(model: draft)
      }
      defer { harness.close() }
      try #require(harness.element(identifier: ScrollToBottomPill.identifier) == nil)

      try Self.scrollUpByCommand(session, anchors: anchors, system: system, harness: harness)

      let identifiers = Self.floatingControlIdentifiers(in: harness)
      #expect(identifiers.contains(ScrollToBottomPill.identifier))
      #expect(identifiers.contains(DefaultPromptAccessory.submitIdentifier))
    }

    @Test func theConversationOfTheThreadDrawsNoSecondPill() async throws {
      let session = try await Self.openLongSession()
      defer { session.close() }
      let anchors = ScrollAnchorManager()
      let system = CommandSystem()
      let harness = Self.mount(session, anchors: anchors, system: system) {
        PromptInputHost(model: PromptInputHostedTestModel())
      }
      defer { harness.close() }

      try Self.scrollUpByCommand(session, anchors: anchors, system: system, harness: harness)

      let pills = harness.accessibilityElements().filter { $0.identifier == ScrollToBottomPill.identifier }
      #expect(pills.count == 1)
    }

    @Test func withNoComposerThePillShowsInTheFloatingControls() async throws {
      let session = try await Self.openLongSession()
      defer { session.close() }
      let anchors = ScrollAnchorManager()
      let system = CommandSystem()
      let harness = Self.mount(session, anchors: anchors, system: system) { EmptyView() }
      defer { harness.close() }

      try Self.scrollUpByCommand(session, anchors: anchors, system: system, harness: harness)

      let identifiers = Self.floatingControlIdentifiers(in: harness)
      #expect(identifiers.contains(ScrollToBottomPill.identifier))
      #expect(!identifiers.contains(DefaultPromptAccessory.submitIdentifier))
    }

    /// A press on the pill of the thread pins the manager, the manager sends
    /// the scroll to the bottom, and the pill goes away.
    ///
    /// The manager sends the scroll on the next main-actor tick after the
    /// press. The press always requests that scroll, and no jump cancels it,
    /// so the test waits for the event that the recorder gets the bottom
    /// target. The test does not check the pin state right after the press:
    /// the pill goes away, the list gets taller, and the geometry change can
    /// send the old rows in view to the manager again
    /// (``ConversationViewHostedTests/aPressOnThePillSetsTheNewEntryCountToZero()``).
    @Test func aPressOnThePillOfTheThreadScrollsTheListToTheBottom() async throws {
      let session = try await Self.openLongSession()
      defer { session.close() }
      let anchors = ScrollAnchorManager()
      let system = CommandSystem()
      let harness = Self.mount(session, anchors: anchors, system: system) {
        PromptInputHost(model: PromptInputHostedTestModel())
      }
      defer { harness.close() }
      try Self.scrollUpByCommand(session, anchors: anchors, system: system, harness: harness)
      let targets = ConversationViewHostedTests.recordScrollTargets(of: anchors)

      try harness.press(identifier: ScrollToBottomPill.identifier)
      await ObservationWait.until { targets.values.last == .bottom }
      harness.render()

      #expect(anchors.isPinnedToBottom)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    @Test func aComposerAloneMakesItsOwnContainer() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(size: Self.windowSize) {
        ProbeComposer()
          .environment(\.sessionModel, session.model)
      }
      defer { harness.close() }
      harness.render()

      #expect(FloatingGlassContainerHostedTests.containerCount(in: harness) == 1)
    }

    @Test func theComposerInTheThreadMakesNoSecondContainer() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(size: Self.windowSize) {
        AgentThreadView(session: session.model) {
          ProbeComposer()
        }
      }
      defer { harness.close() }
      harness.render()

      #expect(FloatingGlassContainerHostedTests.containerCount(in: harness) == 1)
    }

    @Test func aComposerInTheSlotSendsToTheSessionOfTheThread() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let draft = PromptInputHostedTestModel(text: Self.message)
      let harness = HostedViewHarness(size: Self.windowSize) {
        AgentThreadView(session: session.model) {
          PromptInputHost(model: draft)
        }
      }
      defer { harness.close() }
      harness.render()

      try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
      // The composer calls the host closure in the same step as it starts
      // the prompt task, so a press that sent nothing stops the test here.
      try #require(draft.submitCount == 1)
      await ObservationWait.until { !session.promptTexts.isEmpty }

      #expect(session.promptTexts == [Self.message])
    }
  }

  /// A composer whose editor is a ``FloatingContainerProbe``, so that a test
  /// reads the number of glass containers above the editor.
  struct ProbeComposer: View {
    /// The text of the composer.
    @State private var text = AttributedString()

    var body: some View {
      PromptInputView(text: $text, onSubmit: {}, editor: { _ in FloatingContainerProbe() })
    }
  }
#endif
