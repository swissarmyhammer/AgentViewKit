#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorCommands
  import EditorCommandsUI
  import EditorStyle
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

    /// The message id of the reply of the agent in the turn test.
    static let replyMessageID = "floating-reply-1"

    /// The text of the reply of the agent in the turn test.
    static let reply = "You said: Hello"

    /// The height of the space above the composer in the slot of the turn
    /// test, in points. With it, the bottom bar is about as tall as the bar of
    /// the demo app with its sign-in card, and the part of the list in view is
    /// shorter than the bottom inset.
    static let tallSlotSpace: CGFloat = 180

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
      #expect(identifiers.contains(EditorKitPromptEditor.identifier))
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

    /// The pill floats over the list, so its show does not change the bottom
    /// inset of the list (^66has33).
    ///
    /// The floating controls are the bottom bar of the list, and their height
    /// is the bottom inset. A pill in the layout of the controls made the inset
    /// depend on the pin state. Each change of the inset made the list report
    /// a layout with no row in view, and that report unpinned the manager. The
    /// pill then showed and changed the inset again, and the list pinned the
    /// manager again: the pin state, the pill and the inset went around in a
    /// loop. In the demo app the loop held the main actor, and the reply of the
    /// agent did not get to the list.
    @Test func theShowOfThePillKeepsTheBottomInsetOfTheList() async throws {
      let session = try await Self.openLongSession()
      defer { session.close() }
      let anchors = ScrollAnchorManager()
      let system = CommandSystem()
      let harness = Self.mount(session, anchors: anchors, system: system) {
        PromptInputHost(model: PromptInputHostedTestModel())
      }
      defer { harness.close() }
      let pinnedInset = try ThreadBarInsetHostedTests.listScrollView(in: harness).contentInsets.bottom

      try Self.scrollUpByCommand(session, anchors: anchors, system: system, harness: harness)
      try #require(harness.element(identifier: ScrollToBottomPill.identifier) != nil)

      let unpinnedInset = try ThreadBarInsetHostedTests.listScrollView(in: harness).contentInsets.bottom
      #expect(
        abs(unpinnedInset - pinnedInset) <= ThreadBarInsetHostedTests.insetTolerance,
        "bottom inset \(unpinnedInset) with the pill, \(pinnedInset) without it")
    }

    /// Gives the list the scroll to the bottom that the manager sent after an
    /// append, and lays out the result.
    ///
    /// The helper waits for the event that the recorder holds `count`
    /// targets, or that the manager was unpinned (`unpinned`): a manager that
    /// was unpinned at the append sends no scroll for it, and the test then
    /// reads the unpin. A pinned manager always sends the scroll of an append.
    ///
    /// - Parameters:
    ///   - count: The number of targets that the recorder holds after the
    ///     scroll.
    ///   - held: The recorder and the scroll closure of
    ///     ``holdScrollTargets(of:)``.
    ///   - unpinned: The flag that a change of the pin state sets.
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - harness: The harness that shows the thread.
    static func applyHeldScroll(
      count: Int, of held: (targets: ReportRecorder<ScrollAnchorTarget>, viewScroll: (ScrollAnchorTarget) -> Void),
      unpinned: ChangeFlag, anchors: ScrollAnchorManager, harness: HostedViewHarness<some View>
    ) async {
      await ObservationWait.until {
        unpinned.value || held.targets.values.count == count || !anchors.isPinnedToBottom
      }
      if let target = held.targets.values.last {
        held.viewScroll(target)
      }
      harness.render()
    }

    /// A streamed turn never unpins the thread: from the echo of the prompt
    /// to the end of the turn, the list follows the bottom, and the pill does
    /// not show (^66has33).
    ///
    /// The list scrolled to the bottom with an edge scroll of its scroll
    /// position. The position then kept the edge, and SwiftUI applied the edge
    /// again in later layout passes from the frame of the scroll target
    /// layout: past the end of the content by the bottom inset of the bar. The
    /// list reported no row in view for that layout, and the report unpinned
    /// the manager. In the demo app the lazy stack then kept no row, and the
    /// reply of the agent was not in the accessibility tree.
    ///
    /// The test holds each scroll of the manager
    /// (``holdScrollTargets(of:)``) and gives it to the list in a render pass
    /// of the test, so each step lays out the same passes. The slot has a
    /// space above the composer (``tallSlotSpace``), so the bottom inset is
    /// taller than the part of the list in view, as in the demo app.
    @Test func aStreamedTurnKeepsTheThreadPinnedToTheBottom() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let model = session.model
      let anchors = ScrollAnchorManager()
      let harness = Self.mount(session, anchors: anchors, system: CommandSystem()) {
        Color.clear.frame(height: Self.tallSlotSpace)
        PromptInputHost(model: PromptInputHostedTestModel())
      }
      defer { harness.close() }
      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("user_message_chunk", messageID: Self.promptMessageID, text: Self.message))
      await harness.render(when: { model.transcript.count == 1 })
      let held = Self.holdScrollTargets(of: anchors)
      let firstUnpin = ChangeFlag.observing { _ = anchors.isPinnedToBottom }
      await Self.applyHeldScroll(count: 1, of: held, unpinned: firstUnpin, anchors: anchors, harness: harness)
      try #require(anchors.isPinnedToBottom)
      let unpinned = ChangeFlag.observing { _ = anchors.isPinnedToBottom }

      try await session.sendUpdate(SessionStateBannersHostedTests.stateUpdate(#""state": "running""#))
      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("agent_message_chunk", messageID: Self.replyMessageID, text: Self.reply))
      await harness.render(when: { model.transcript.count == 2 })
      await Self.applyHeldScroll(count: 2, of: held, unpinned: unpinned, anchors: anchors, harness: harness)
      try await session.sendUpdate(SessionEntryRowsHostedTests.planUpdate(firstStatus: "completed"))
      await harness.render(when: { model.transcript.count == 3 })
      await Self.applyHeldScroll(count: 3, of: held, unpinned: unpinned, anchors: anchors, harness: harness)

      #expect(!unpinned.value, "the thread unpinned during the turn")
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
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

    /// Records each scroll target that `anchors` sends, and holds it: the
    /// list of the thread does not get the target.
    ///
    /// Call this helper after the first layout of the thread: the
    /// conversation sets ``ScrollAnchorManager/onScroll`` when it appears.
    /// The test then gives a held target to the returned closure, so that a
    /// ``HostedViewHarness/render()`` pass of the test, and not an update of
    /// SwiftUI that can come first, applies the scroll.
    ///
    /// - Parameter anchors: The manager of the scroll position of the thread.
    /// - Returns: The recorder of the held targets, and the scroll closure
    ///   that the conversation set.
    static func holdScrollTargets(
      of anchors: ScrollAnchorManager
    ) -> (targets: ReportRecorder<ScrollAnchorTarget>, viewScroll: (ScrollAnchorTarget) -> Void) {
      let targets = ReportRecorder<ScrollAnchorTarget>()
      let viewScroll = anchors.onScroll
      anchors.onScroll = { target in targets.report(target) }
      return (targets, viewScroll)
    }

    /// A press on the pill of the thread pins the manager, the pill goes
    /// away, the manager sends the scroll to the bottom, and all of the last
    /// row is in view above the floating controls. The test gives no
    /// visibility report after the press.
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
    /// target. The test holds the target (``holdScrollTargets(of:)``), and
    /// then gives it to the list and makes one ``HostedViewHarness/render()``
    /// pass. Thus the scroll and the layout of the last rows are always in
    /// the same pass. The test reads the frames of the last row and of the
    /// list after that pass, and it does not wait for a report of the list.
    ///
    /// The floating controls are a bottom bar over the list. A scroll to the
    /// last row by its identifier, in the pass that lays out the rows, stopped
    /// with the last row under the bar, and the list reported the row two rows
    /// above it as its last row (^92k32m0).
    @Test func aPressOnThePillOfTheThreadShowsAllOfTheLastRow() async throws {
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
      try #require(!ConversationViewHostedTests.showsRow(lastKey, in: harness))
      let (targets, viewScroll) = Self.holdScrollTargets(of: anchors)

      try harness.press(identifier: ScrollToBottomPill.identifier)
      try #require(anchors.isPinnedToBottom)
      try #require(harness.element(identifier: ScrollToBottomPill.identifier) == nil)

      await ObservationWait.until { targets.values.last == .bottom }
      viewScroll(.bottom)
      harness.render()

      #expect(ConversationViewHostedTests.showsWholeRow(lastKey, in: harness))
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

      let editorNamespace = try #require(FloatingNamespaceProbe.namespace(of: ProbeComposer.probeIdentifier, in: harness))
      #expect(editorNamespace != FloatingNamespaceProbe.noNamespace)
    }

    /// The accessibility identifier of the namespace probe in the composer
    /// slot, next to the composer and out of its own glass container.
    static let slotProbeIdentifier = "slot-namespace-probe"

    /// A container in a container makes no second container and keeps the
    /// namespace of the outer container, so the editor of the composer has
    /// the namespace of the floating controls of the thread.
    @Test func theComposerInTheThreadMakesNoSecondContainer() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(size: Self.windowSize) {
        AgentThreadView(session: session.model) {
          FloatingNamespaceProbe(identifier: Self.slotProbeIdentifier)
          ProbeComposer()
        }
      }
      defer { harness.close() }
      harness.render()

      let slotNamespace = try #require(FloatingNamespaceProbe.namespace(of: Self.slotProbeIdentifier, in: harness))
      #expect(slotNamespace != FloatingNamespaceProbe.noNamespace)
      #expect(FloatingNamespaceProbe.namespace(of: ProbeComposer.probeIdentifier, in: harness) == slotNamespace)
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

  /// A composer whose editor is a ``FloatingNamespaceProbe``, so that a test
  /// reads the glass namespace of the container above the editor.
  struct ProbeComposer: View {
    /// The accessibility identifier of the namespace probe in the editor.
    static let probeIdentifier = "editor-namespace-probe"

    /// The text of the composer.
    @State private var text = AttributedString()

    var body: some View {
      PromptInputView(
        text: $text, onSubmit: {}, editor: { _ in FloatingNamespaceProbe(identifier: Self.probeIdentifier) })
    }
  }

  /// A text that shows the glass namespace of the `FloatingGlassContainer`
  /// above it (`\.floatingGlassNamespace`), or ``noNamespace`` out of a
  /// container. The SDK gives no accessibility element for a
  /// `GlassEffectContainer`, so the tests read the namespace that the
  /// container gives to its content.
  struct FloatingNamespaceProbe: View {
    /// The text of the probe when no container gives a namespace.
    static let noNamespace = "none"

    /// The accessibility identifier of the probe.
    let identifier: String

    @Environment(\.floatingGlassNamespace) private var namespace

    var body: some View {
      Text(namespace.map { String(describing: $0) } ?? Self.noNamespace)
        .accessibilityIdentifier(identifier)
    }

    /// The text of the namespace probe with `identifier` in `harness`.
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier of the probe.
    ///   - harness: The harness that shows the probe.
    /// - Returns: The text, or `nil` when the probe is not in the tree.
    static func namespace(of identifier: String, in harness: HostedViewHarness<some View>) -> String? {
      harness.element(identifier: identifier)?.label
    }
  }
#endif
