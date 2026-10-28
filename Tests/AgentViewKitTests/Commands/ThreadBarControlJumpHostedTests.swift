#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorCommands
  import EditorCommandsUI
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// What the controls of a ``BarControlThreadHost`` change and report, so
  /// that a test reads what a press on a control did.
  @MainActor struct BarControlRecord {
    /// The text, the attachments and the submit count of the composer. The
    /// composer starts with the attachments of the fixtures, so that its
    /// field shows the Remove button of each chip.
    let draft: PromptInputHostedTestModel

    /// The method of each request that a control of the thread starts
    /// (``SwiftUI/EnvironmentValues/requestStartReport``).
    let requestStarts = ReportRecorder<String>()

    /// Each phase of the dictation button
    /// (``SwiftUI/EnvironmentValues/speechInputPhaseReport``).
    let speechPhases = ReportRecorder<SpeechInputButton.Phase>()

    /// Makes a record whose composer holds `text`.
    ///
    /// - Parameter text: The first text of the composer.
    init(text: String = "") {
      draft = PromptInputHostedTestModel(text: text, attachments: PreviewFixtures.attachments)
    }
  }

  /// A thread whose bars show the bar controls, in a window with a command
  /// system.
  ///
  /// The composer is a ``PromptInputView`` over the draft of the record, so
  /// that the field shows the Remove button of each attachment chip. The
  /// environment gives suggestions and a speech transcriber, so that the
  /// composer shows the suggestion chips and the dictation button.
  struct BarControlThreadHost: View {
    /// The session model of the thread.
    let session: SessionModel

    /// The connection model of the thread, or `nil`.
    let connection: ConnectionModel?

    /// The manager of the scroll position of the thread.
    let anchors: ScrollAnchorManager

    /// The command system of the window.
    let system: CommandSystem

    /// What the controls of the thread change and report.
    let record: BarControlRecord

    var body: some View {
      AgentThreadView(session: session, connection: connection, anchors: anchors) {
        PromptInputView(text: Bindable(record.draft).text, attachments: Bindable(record.draft).attachments) {
          record.draft.submitCount += 1
        }
      }
      .environment(\.promptSuggestions, PreviewFixtures.suggestions)
      .environment(\.requestStartReport, record.requestStarts.report)
      .environment(\.speechInputPhaseReport, record.speechPhases.report)
      .speechTranscriber(FakeSpeechTranscriber())
      .commandSystem(system)
      .transaction { $0.disablesAnimations = true }
    }
  }

  /// One control in a bar of a thread.
  enum BarControl: String, CaseIterable, CustomTestStringConvertible, Sendable {
    /// The Send button of the composer.
    case send
    /// The Stop button of the composer, while the agent runs.
    case stop
    /// The permission-mode picker of the composer.
    case modePicker
    /// The Sign In button of the login prompt.
    case signIn
    /// The Sign Out button of the login prompt.
    case signOut
    /// The Dismiss button of a notice banner in the top bar.
    case dismiss
    /// The Reload button of the missed-updates banner in the top bar.
    case reload
    /// The Show Error button of the state banner.
    case showError
    /// The editor of the composer.
    case editor
    /// The dictation button of the composer.
    case dictation
    /// The first suggestion chip of the composer.
    case suggestion
    /// The Remove button of the first attachment chip of the composer.
    case removeAttachment
    /// The scroll-to-bottom pill, while the list is not at its bottom.
    case scrollPill

    var testDescription: String { rawValue }

    /// Whether a landed jump presses the control (EditorKit leaf landing).
    ///
    /// A landing presses each button. It only focuses the editor, which is
    /// no leaf control, and the segmented permission-mode picker, which
    /// takes no press: the arrow keys and Space then change its segment.
    nonisolated var takesPress: Bool {
      switch self {
      case .editor, .modePicker: false
      case .send, .stop, .signIn, .signOut, .dismiss, .reload, .showError, .dictation, .suggestion,
        .removeAttachment, .scrollPill:
        true
      }
    }

    /// Whether `answer`, the accessibility identifier of the element that
    /// the hit test of the window answers over the control, names the
    /// control.
    ///
    /// Over the segmented permission-mode picker, the hit test answers the
    /// segment under the point, as VoiceOver reads a segmented control. Over
    /// each other control, it answers the control.
    ///
    /// - Parameters:
    ///   - answer: The identifier of the answered element, or `nil`.
    ///   - identifier: The accessibility identifier of the control.
    /// - Returns: `true` when the answer is the control, or a segment of the
    ///   picker.
    func names(_ answer: String?, identifier: String) -> Bool {
      guard self == .modePicker else { return answer == identifier }
      return answer?.hasPrefix(PermissionModePicker.segmentIdentifierPrefix) == true
    }

    /// The controls that a landed jump presses. It is `nonisolated` because
    /// the arguments of a test use it.
    nonisolated static let pressedCases = allCases.filter(\.takesPress)

    /// The controls that a landed jump only focuses. It is `nonisolated`
    /// because the arguments of a test use it.
    nonisolated static let focusedCases = allCases.filter { !$0.takesPress }
  }

  /// A thread that shows one bar control.
  @MainActor struct ShownBarControl {
    /// The harness that shows the thread.
    let harness: HostedViewHarness<BarControlThreadHost>

    /// The session model of the thread.
    let session: SessionModel

    /// The accessibility identifier of the control.
    let identifier: String

    /// Whether a press reached the control, read from what the press
    /// changes in the same step; `nil` for a control that a landed jump
    /// only focuses (``BarControl/takesPress``).
    let wasPressed: (@MainActor () -> Bool)?

    /// Closes the scripted session of the thread, if it has one.
    let closeSession: () -> Void

    /// The path of the scope of the control.
    var path: FocusPath {
      AgentCommandScopeHostedTests.path(of: session).appending(AgentScopeKind.control(identifier))
    }

    /// Closes the window and the scripted session.
    func close() {
      harness.close()
      closeSession()
    }
  }

  /// Tests for the jump targets of the bar controls of a thread (KanbanViewKit
  /// D109 (e), "the jump is necessary").
  ///
  /// Each control in the top bar and the bottom bar of a thread has its own
  /// EditorKit scope (`agentControlScope(_:corners:)`), which asks for the
  /// leaf landing. So a jump session shows a label on the control, a jump
  /// that lands on a button presses it, and the accessibility hit test of
  /// the window over the control answers the control. The tests read the
  /// labels of a jump session, what a press changes, the first responder
  /// and the hit test of the window, after one render pass for each change.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadBarControlJumpHostedTests {
    /// The size of a window that shows both bars of a thread whole.
    static let windowSize = CGSize(width: 480, height: 900)

    /// The title of the notice of the Dismiss test.
    static let noticeTitle = "The context is almost full"

    /// The message of the error entry of the Show Error test.
    static let errorMessage = "failed"

    /// The text in the composer of the Send tests, so that Send is enabled.
    static let message = "Hello"

    /// Shows a thread of `session` in a window with `system`.
    ///
    /// - Parameters:
    ///   - session: The session model of the thread.
    ///   - connection: The connection model of the thread, or `nil`.
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - record: What the controls of the thread change and report.
    ///   - system: The command system of the window.
    /// - Returns: The harness, after one render pass.
    static func mount(
      _ session: SessionModel, connection: ConnectionModel? = nil, anchors: ScrollAnchorManager = ScrollAnchorManager(),
      record: BarControlRecord = BarControlRecord(), system: CommandSystem
    ) -> HostedViewHarness<BarControlThreadHost> {
      let harness = HostedViewHarness(
        BarControlThreadHost(session: session, connection: connection, anchors: anchors, system: system, record: record),
        size: windowSize)
      harness.render()
      return harness
    }

    /// Shows a thread of a preview session model that shows `identifier`.
    ///
    /// - Parameters:
    ///   - session: The session model.
    ///   - identifier: The accessibility identifier of the control.
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - record: What the controls of the thread change and report.
    ///   - system: The command system of the window.
    ///   - wasPressed: Whether a press reached the control, or `nil` for a
    ///     control that a landed jump only focuses.
    /// - Returns: The shown control.
    static func show(
      _ session: SessionModel, identifier: String, anchors: ScrollAnchorManager = ScrollAnchorManager(),
      record: BarControlRecord = BarControlRecord(), system: CommandSystem,
      wasPressed: (@MainActor () -> Bool)?
    ) -> ShownBarControl {
      ShownBarControl(
        harness: mount(session, anchors: anchors, record: record, system: system), session: session,
        identifier: identifier, wasPressed: wasPressed, closeSession: {})
    }

    /// Shows a thread whose bars show `control`.
    ///
    /// - Parameters:
    ///   - control: The bar control.
    ///   - system: The command system of the window.
    /// - Returns: The shown control, after the render pass that shows it.
    /// - Throws: The error of a scripted session, or an issue when the
    ///   session does not reach the state that shows the control.
    static func show(_ control: BarControl, system: CommandSystem) async throws -> ShownBarControl {
      switch control {
      case .send: showSend(system: system)
      case .stop: showStop(system: system)
      case .modePicker:
        show(
          PreviewFixtures.configuredSession, identifier: PermissionModePicker.pickerIdentifier, system: system,
          wasPressed: nil)
      case .signIn:
        try await showAuthAction(
          identifier: AgentAuthView.signInIdentifier(for: ConnectionModelViewsHostedTests.agentMethodID), system: system)
      case .signOut: try await showAuthAction(identifier: AgentAuthView.signOutIdentifier, system: system)
      case .dismiss: try showDismiss(system: system)
      case .reload: try await showReload(system: system)
      case .showError: try showShowError(system: system)
      case .editor: show(.preview(), identifier: EditorKitPromptEditor.identifier, system: system, wasPressed: nil)
      case .dictation: showDictation(system: system)
      case .suggestion: try showSuggestion(system: system)
      case .removeAttachment: try showRemoveAttachment(system: system)
      case .scrollPill: try await showScrollPill(system: system)
      }
    }

    /// Shows a thread whose composer holds ``message``, so that the Send
    /// button is enabled. A press calls the host `onSubmit`.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    static func showSend(system: CommandSystem) -> ShownBarControl {
      let record = BarControlRecord(text: message)
      return show(.preview(), identifier: DefaultPromptAccessory.submitIdentifier, record: record, system: system) {
        record.draft.submitCount == 1
      }
    }

    /// Shows a thread whose agent runs, so that the composer shows the Stop
    /// button. A press starts `session/cancel`.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    static func showStop(system: CommandSystem) -> ShownBarControl {
      let record = BarControlRecord()
      return show(
        ThreadBottomBarHostedTests.runningSession(), identifier: DefaultPromptAccessory.stopIdentifier, record: record,
        system: system
      ) { record.requestStarts.values == [ScriptedSession.cancelMethod] }
    }

    /// Shows a thread of a scripted agent that asks for a sign-in, so that
    /// the login prompt shows the Sign In and the Sign Out buttons.
    ///
    /// The agent holds its answers to `auth/login` and `auth/logout`, so the
    /// call of a pressed button runs until the session closes, and the
    /// button stays disabled while it runs.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of the button.
    ///   - system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: The error of the scripted session.
    static func showAuthAction(identifier: String, system: CommandSystem) async throws -> ShownBarControl {
      let session = try await ConnectionModelViewsHostedTests.openSession {
        $0.heldMethods = [ScriptedSession.loginMethod, AgentAuthViewHostedTests.logoutMethod]
      }
      let harness = mount(session.model, connection: session.connection, system: system)
      return ShownBarControl(
        harness: harness, session: session.model, identifier: identifier,
        wasPressed: { harness.element(identifier: identifier)?.isEnabled == false }, closeSession: session.close)
    }

    /// Shows a thread with one notice, so that the top bar shows its Dismiss
    /// button. A press removes the notice.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: An issue when the model holds no notice.
    static func showDismiss(system: CommandSystem) throws -> ShownBarControl {
      let session = SessionModel.preview(transcript: [.update(.notice(Notice(severity: .warning, title: noticeTitle)))])
      let notice = try #require(session.notices.first)
      return show(session, identifier: SessionNoticeBanner.dismissIdentifier(for: notice.id), system: system) {
        session.notices.isEmpty
      }
    }

    /// Shows a thread whose connection missed updates, so that the top bar
    /// shows the Reload button. A press starts `session/resume`.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: The error of the scripted session.
    static func showReload(system: CommandSystem) async throws -> ShownBarControl {
      let session = try await SessionStateBannersHostedTests.openOverflowingSession()
      let model = session.model
      let record = BarControlRecord()
      let harness = mount(model, connection: session.connection, record: record, system: system)
      await harness.render { model.hasMissedUpdates }
      return ShownBarControl(
        harness: harness, session: model, identifier: SessionStreamBanner.reloadIdentifier,
        wasPressed: { record.requestStarts.values == [ScriptedSession.resumeMethod] }, closeSession: session.close)
    }

    /// Shows a thread with an error entry and an idle state, so that the
    /// state banner shows its Show Error button. A press makes the error
    /// entry the anchor of the scroll position.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: An issue when the model holds no error entry.
    static func showShowError(system: CommandSystem) throws -> ShownBarControl {
      let session = SessionModel.preview(transcript: [
        .update(.stateUpdate(.idle(IdleStateUpdate(stopReason: .refusal))))
      ])
      session.appendError(code: .internalError, message: errorMessage, data: nil)
      // `appendError` puts the error entry at the end of the transcript.
      let errorKey = try #require(session.transcript.last?.rowKey)
      let anchors = ScrollAnchorManager()
      return show(session, identifier: StateBanner.showErrorIdentifier, anchors: anchors, system: system) {
        anchors.anchorID == errorKey
      }
    }

    /// Shows a thread whose composer shows the dictation button. A press
    /// starts a dictation session.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    static func showDictation(system: CommandSystem) -> ShownBarControl {
      let record = BarControlRecord()
      return show(.preview(), identifier: SpeechInputButton.identifier, record: record, system: system) {
        record.speechPhases.values == [.recording]
      }
    }

    /// Shows a thread whose composer shows the suggestion chips. A press on
    /// the first chip puts its suggestion in the composer.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: An issue when the fixture has no suggestion.
    static func showSuggestion(system: CommandSystem) throws -> ShownBarControl {
      let suggestion = try #require(PreviewFixtures.suggestions.first)
      let record = BarControlRecord()
      return show(.preview(), identifier: SuggestionsView.chipIdentifier(at: 0), record: record, system: system) {
        record.draft.plainText == suggestion
      }
    }

    /// Shows a thread whose composer shows its attachments, so that the
    /// field shows the Remove button of the first chip. A press removes the
    /// first attachment.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: An issue when the fixture has no attachment.
    static func showRemoveAttachment(system: CommandSystem) throws -> ShownBarControl {
      let attachment = try #require(PreviewFixtures.attachments.first)
      let record = BarControlRecord()
      let remaining = PreviewFixtures.attachments.dropFirst().map(\.id)
      return show(
        .preview(), identifier: AttachmentChips.removeIdentifier(for: attachment.id), record: record, system: system
      ) { record.draft.attachments.map(\.id) == remaining }
    }

    /// Shows a long thread that the Previous Prompt command scrolled up, so
    /// that the bottom bar shows the scroll-to-bottom pill. A press pins the
    /// list to its bottom.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: The error of the scripted session, or an issue when the
    ///   command does not scroll the list up.
    static func showScrollPill(system: CommandSystem) async throws -> ShownBarControl {
      let session = try await ThreadFloatingControlsHostedTests.openLongSession()
      let anchors = ScrollAnchorManager()
      let harness = mount(session.model, anchors: anchors, system: system)
      let shown = ShownBarControl(
        harness: harness, session: session.model, identifier: ScrollToBottomPill.identifier,
        wasPressed: { anchors.isPinnedToBottom }, closeSession: session.close)
      do {
        try ThreadFloatingControlsHostedTests.scrollUpByCommand(session, anchors: anchors, system: system, harness: harness)
      } catch {
        shown.close()
        throw error
      }
      return shown
    }

    /// The frame of an accessibility element in the window space of
    /// EditorKit, the space of the jump labels: the origin at the top left of
    /// the window, and y grows down.
    ///
    /// - Parameters:
    ///   - screenFrame: The accessibility frame, in screen points with the
    ///     origin at the bottom left.
    ///   - window: The window of the element.
    /// - Returns: The frame in the window space.
    static func windowSpaceFrame(of screenFrame: CGRect, in window: NSWindow) -> CGRect {
      CGRect(
        x: screenFrame.minX - window.frame.minX, y: window.frame.maxY - screenFrame.maxY,
        width: screenFrame.width, height: screenFrame.height)
    }

    /// Opens a jump session in the layer of the thread of `shown`.
    ///
    /// - Parameters:
    ///   - shown: The shown control.
    ///   - system: The command system of the window.
    /// - Returns: The controller of the open session.
    /// - Throws: An issue when no session opens.
    static func openJump(on shown: ShownBarControl, system: CommandSystem) throws -> JumpModeController {
      let jump = JumpModeController(system: system)
      try #require(jump.activate(layer: AgentCommandScopeHostedTests.path(of: shown.session)))
      return jump
    }

    @Test(arguments: BarControl.allCases)
    func aJumpLabelShowsOnEachBarControl(_ control: BarControl) async throws {
      let system = CommandSystem()
      let shown = try await Self.show(control, system: system)
      defer { shown.close() }
      let screenFrame = try #require(shown.harness.frame(identifier: shown.identifier))
      let jump = try Self.openJump(on: shown, system: system)

      let chips = try #require(jump.overlayState?.chips)

      let chip = try #require(chips.first { $0.id == shown.path }, "\(chips.map(\.id))")
      let controlFrame = Self.windowSpaceFrame(of: screenFrame, in: shown.harness.window)
      #expect(controlFrame.contains(chip.anchor.origin), "label \(chip.anchor.origin), control \(controlFrame)")
    }

    /// A landed jump presses each bar button, as a click does: the press
    /// changes what the button changes, in the same step.
    @Test(arguments: BarControl.pressedCases)
    func aJumpToEachBarButtonPressesIt(_ control: BarControl) async throws {
      let system = CommandSystem()
      let shown = try await Self.show(control, system: system)
      defer { shown.close() }
      let wasPressed = try #require(shown.wasPressed)
      try #require(!wasPressed())
      let jump = try Self.openJump(on: shown, system: system)

      try #require(jump.commit(shown.path))
      shown.harness.render()

      #expect(wasPressed())
    }

    /// A landed jump focuses the editor and the segmented permission-mode
    /// picker, the controls that take no press.
    @Test(arguments: BarControl.focusedCases)
    func aJumpToEachFocusOnlyBarControlFocusesIt(_ control: BarControl) async throws {
      let system = CommandSystem()
      let shown = try await Self.show(control, system: system)
      defer { shown.close() }
      let window = shown.harness.window
      window.makeFirstResponder(nil)
      try #require(AgentNavigationHostedTests.focusedItem(among: [shown.path], in: system, window: window) == nil)
      let jump = try Self.openJump(on: shown, system: system)

      try #require(jump.commit(shown.path))
      shown.harness.render()

      #expect(AgentNavigationHostedTests.focusedItem(among: [shown.path], in: system, window: window) == shown.path)
    }

    /// A disabled Send, with no text in the composer, is no jump target: the
    /// session gives it no label, and a commit on its path lands nowhere.
    @Test func aDisabledSendIsNoJumpTarget() throws {
      let system = CommandSystem()
      let record = BarControlRecord()
      let shown = Self.show(
        .preview(), identifier: DefaultPromptAccessory.submitIdentifier, record: record, system: system,
        wasPressed: nil)
      defer { shown.close() }
      try #require(shown.harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == false)
      let jump = try Self.openJump(on: shown, system: system)

      let chips = try #require(jump.overlayState?.chips)

      #expect(!chips.contains { $0.id == shown.path }, "\(chips.map(\.id))")
      #expect(!jump.commit(shown.path))
      #expect(record.draft.submitCount == 0)
    }

    /// The accessibility hit test of the window at the center of each bar
    /// control answers the control, not the transcript row under the bar:
    /// the read that VoiceOver with the pointer, Hover Text and XCUI make.
    @Test(arguments: BarControl.allCases)
    func theHitTestAtTheCenterOfEachBarControlAnswersTheControl(_ control: BarControl) async throws {
      let system = CommandSystem()
      let shown = try await Self.show(control, system: system)
      defer { shown.close() }

      let element = accessibilityHitTest(atCenterOfScopeAt: shown.path, in: system, window: shown.harness.window)

      let answer = element.flatMap(accessibilityIdentifier(of:))
      #expect(control.names(answer, identifier: shown.identifier), "\(String(describing: answer))")
    }

    /// A jump to the editor of the composer focuses its text view, so the
    /// next key types into the prompt.
    @Test func aJumpToTheComposerEditorFocusesItsTextView() async throws {
      let system = CommandSystem()
      let shown = try await Self.show(.editor, system: system)
      defer { shown.close() }
      shown.harness.window.makeFirstResponder(nil)
      let jump = try Self.openJump(on: shown, system: system)

      try #require(jump.commit(shown.path))
      shown.harness.render()

      let responder = try #require(shown.harness.window.firstResponder as? NSTextView)
      #expect(responder.accessibilityIdentifier() == EditorKitPromptEditor.identifier)
    }
  }
#endif
