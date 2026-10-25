#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorCommands
  import EditorCommandsUI
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// A thread whose bars show the bar controls, in a window with a command
  /// system.
  ///
  /// The composer is a ``PromptInputView`` with attachments, so that the
  /// field shows the Remove button of each chip. The environment gives
  /// suggestions and a speech transcriber, so that the composer shows the
  /// suggestion chips and the dictation button.
  struct BarControlThreadHost: View {
    /// The session model of the thread.
    let session: SessionModel

    /// The connection model of the thread, or `nil`.
    let connection: ConnectionModel?

    /// The manager of the scroll position of the thread.
    let anchors: ScrollAnchorManager

    /// The command system of the window.
    let system: CommandSystem

    var body: some View {
      AgentThreadView(session: session, connection: connection, anchors: anchors) {
        PromptInputView(text: .constant(AttributedString()), attachments: .constant(PreviewFixtures.attachments)) {}
      }
      .environment(\.promptSuggestions, PreviewFixtures.suggestions)
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
  }

  /// A thread that shows one bar control.
  struct ShownBarControl {
    /// The harness that shows the thread.
    let harness: HostedViewHarness<BarControlThreadHost>

    /// The session model of the thread.
    let session: SessionModel

    /// The accessibility identifier of the control.
    let identifier: String

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
  /// EditorKit scope (`agentControlScope(_:corners:)`). So a jump session
  /// shows a label on the control, and a jump lands on it. The tests read
  /// the labels of a jump session and the first responder of the window,
  /// after one render pass for each change.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadBarControlJumpHostedTests {
    /// The size of a window that shows both bars of a thread whole.
    static let windowSize = CGSize(width: 480, height: 900)

    /// The title of the notice of the Dismiss test.
    static let noticeTitle = "The context is almost full"

    /// The message of the error entry of the Show Error test.
    static let errorMessage = "failed"

    /// Shows a thread of `session` in a window with `system`.
    ///
    /// - Parameters:
    ///   - session: The session model of the thread.
    ///   - connection: The connection model of the thread, or `nil`.
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - system: The command system of the window.
    /// - Returns: The harness, after one render pass.
    static func mount(
      _ session: SessionModel, connection: ConnectionModel? = nil, anchors: ScrollAnchorManager = ScrollAnchorManager(),
      system: CommandSystem
    ) -> HostedViewHarness<BarControlThreadHost> {
      let harness = HostedViewHarness(
        BarControlThreadHost(session: session, connection: connection, anchors: anchors, system: system),
        size: windowSize)
      harness.render()
      return harness
    }

    /// Shows a thread of a preview session model that shows `identifier`.
    ///
    /// - Parameters:
    ///   - session: The session model.
    ///   - identifier: The accessibility identifier of the control.
    ///   - connection: The connection model, or `nil`.
    ///   - system: The command system of the window.
    /// - Returns: The shown control.
    static func show(
      _ session: SessionModel, identifier: String, connection: ConnectionModel? = nil, system: CommandSystem
    ) -> ShownBarControl {
      ShownBarControl(
        harness: mount(session, connection: connection, system: system), session: session, identifier: identifier,
        closeSession: {})
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
      case .send: show(.preview(), identifier: DefaultPromptAccessory.submitIdentifier, system: system)
      case .stop: show(ThreadBottomBarHostedTests.runningSession(), identifier: DefaultPromptAccessory.stopIdentifier, system: system)
      case .modePicker: show(PreviewFixtures.configuredSession, identifier: PermissionModePicker.pickerIdentifier, system: system)
      case .signIn: try await showSignIn(identifier: AgentAuthView.signInIdentifier(for: ConnectionModelViewsHostedTests.agentMethodID), system: system)
      case .signOut: try await showSignIn(identifier: AgentAuthView.signOutIdentifier, system: system)
      case .dismiss: try showDismiss(system: system)
      case .reload: try await showReload(system: system)
      case .showError: showShowError(system: system)
      case .editor: show(.preview(), identifier: EditorKitPromptEditor.identifier, system: system)
      case .dictation: show(.preview(), identifier: SpeechInputButton.identifier, system: system)
      case .suggestion: show(.preview(), identifier: SuggestionsView.chipIdentifier(at: 0), system: system)
      case .removeAttachment: try showRemoveAttachment(system: system)
      case .scrollPill: try await showScrollPill(system: system)
      }
    }

    /// Shows a thread of a scripted agent that asks for a sign-in, so that
    /// the login prompt shows the Sign In and the Sign Out buttons.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of the button.
    ///   - system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: The error of the scripted session.
    static func showSignIn(identifier: String, system: CommandSystem) async throws -> ShownBarControl {
      let session = try await ConnectionModelViewsHostedTests.openSession()
      return ShownBarControl(
        harness: mount(session.model, connection: session.connection, system: system), session: session.model,
        identifier: identifier, closeSession: session.close)
    }

    /// Shows a thread with one notice, so that the top bar shows its Dismiss
    /// button.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: An issue when the model holds no notice.
    static func showDismiss(system: CommandSystem) throws -> ShownBarControl {
      let session = SessionModel.preview(transcript: [.update(.notice(Notice(severity: .warning, title: noticeTitle)))])
      let notice = try #require(session.notices.first)
      return show(session, identifier: SessionNoticeBanner.dismissIdentifier(for: notice.id), system: system)
    }

    /// Shows a thread whose connection missed updates, so that the top bar
    /// shows the Reload button.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: The error of the scripted session.
    static func showReload(system: CommandSystem) async throws -> ShownBarControl {
      let session = try await SessionStateBannersHostedTests.openOverflowingSession()
      let model = session.model
      let harness = mount(model, connection: session.connection, system: system)
      await harness.render { model.hasMissedUpdates }
      return ShownBarControl(
        harness: harness, session: model, identifier: SessionStreamBanner.reloadIdentifier, closeSession: session.close)
    }

    /// Shows a thread with an error entry and an idle state, so that the
    /// state banner shows its Show Error button.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    static func showShowError(system: CommandSystem) -> ShownBarControl {
      let session = SessionModel.preview(transcript: [
        .update(.stateUpdate(.idle(IdleStateUpdate(stopReason: .refusal))))
      ])
      session.appendError(code: .internalError, message: errorMessage, data: nil)
      return show(session, identifier: StateBanner.showErrorIdentifier, system: system)
    }

    /// Shows a thread whose composer shows its attachments, so that the
    /// field shows the Remove button of the first chip.
    ///
    /// - Parameter system: The command system of the window.
    /// - Returns: The shown control.
    /// - Throws: An issue when the fixture has no attachment.
    static func showRemoveAttachment(system: CommandSystem) throws -> ShownBarControl {
      let attachment = try #require(PreviewFixtures.attachments.first)
      return show(.preview(), identifier: AttachmentChips.removeIdentifier(for: attachment.id), system: system)
    }

    /// Shows a long thread that the Previous Prompt command scrolled up, so
    /// that the bottom bar shows the scroll-to-bottom pill.
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
        harness: harness, session: session.model, identifier: ScrollToBottomPill.identifier, closeSession: session.close)
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
      let frame = try #require(shown.harness.frame(identifier: shown.identifier))
      let jump = try Self.openJump(on: shown, system: system)

      let chips = try #require(jump.overlayState?.chips)

      let chip = try #require(chips.first { $0.id == shown.path }, "\(chips.map(\.id))")
      let control = Self.windowSpaceFrame(of: frame, in: shown.harness.window)
      #expect(control.contains(chip.anchor.origin), "label \(chip.anchor.origin), control \(control)")
    }

    @Test(arguments: BarControl.allCases)
    func aJumpToEachBarControlLandsOnIt(_ control: BarControl) async throws {
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
