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
    /// The helper waits for the event that the model holds the user message
    /// before it sends the agent messages. ``ConversationViewHostedTests/sendMessages(_:to:)``
    /// counts the entries that the model holds at its start, so without this
    /// wait it can return before the model holds the last agent message.
    ///
    /// - Returns: The session, after the model shows each message.
    /// - Throws: The error of the scripted session.
    static func openLongSession() async throws -> ScriptedSession {
      let session = try await ScriptedSession.open()
      do {
        try await session.sendUpdate(
          SessionTranscriptViewHostedTests.chunk(
            "user_message_chunk", messageID: promptMessageID, text: message))
        await ObservationWait.until { !session.model.transcript.isEmpty }
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

    /// A press on the pill of the thread pins the manager, the pill goes
    /// away, and the manager sends the scroll to the bottom. The pin and the
    /// pill stay so after the list moves. The test gives no visibility report
    /// after the press.
    ///
    /// The press makes a render pass. In that pass, the pill goes away, and
    /// the geometry change of the list sends the old rows in view to the
    /// manager again. The manager keeps the pin until the list reports the
    /// rows at the bottom (``ScrollAnchorManager/pinToBottom()``), so the test
    /// checks the pin and the pill right after the press.
    ///
    /// The manager sends the scroll on the next main-actor tick after the
    /// press. The press always requests that scroll, and no jump cancels it,
    /// so the test waits for the event that the recorder gets the bottom
    /// target. Then one ``HostedViewHarness/render()`` pass moves the list,
    /// and the test checks the pin and the pill again.
    ///
    /// The test does not wait for the report of the last row, and it does not
    /// check the rows in view. Only a layout pass of the list writes that
    /// report, and in the off-screen harness window no pass is certain to
    /// come. A wait for it stayed suspended for ever, while the test held
    /// `HostedTestLock` and stopped each other hosted test
    /// (``ConversationViewHostedTests/reportRows(at:of:to:)``). Also, in this
    /// window the rows in view after the scroll are not always the same: a
    /// scroll in a render pass of the test can stop the list two rows above
    /// the last row, and a scroll in an update of SwiftUI goes to the last
    /// row. Gap: ``ConversationViewHostedTests/aPressOnThePillScrollsTheListToTheLastRow()``
    /// checks that the list of a conversation moves to the last row.
    @Test func aPressOnThePillOfTheThreadRequestsTheScrollToTheBottom() async throws {
      let session = try await Self.openLongSession()
      defer { session.close() }
      let lastKey = try #require(session.model.transcript.last?.rowKey)
      let anchors = ScrollAnchorManager()
      let system = CommandSystem()
      let harness = Self.mount(session, anchors: anchors, system: system) {
        PromptInputHost(model: PromptInputHostedTestModel())
      }
      defer { harness.close() }
      try Self.scrollUpByCommand(session, anchors: anchors, system: system, harness: harness)
      try #require(anchors.visibleIDs.last != lastKey)
      let targets = ConversationViewHostedTests.recordScrollTargets(of: anchors)

      try harness.press(identifier: ScrollToBottomPill.identifier)
      try #require(anchors.isPinnedToBottom)
      try #require(harness.element(identifier: ScrollToBottomPill.identifier) == nil)

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
