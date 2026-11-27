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

  /// The window root of a jump label bed: `content` with the jump labels of
  /// `controller` drawn over it (`.jumpMode(_:)`), inside the command system
  /// of the window, as a host applies them at the window root.
  struct JumpLabelWindowRoot<Content: View>: View {
    /// The command system of the window.
    let system: CommandSystem

    /// The jump controller of the window, whose labels `.jumpMode(_:)` draws.
    let controller: JumpModeController

    /// The content of the window.
    let content: Content

    var body: some View {
      content
        .jumpMode(controller)
        .commandSystem(system)
        .transaction { $0.disablesAnimations = true }
    }
  }

  /// The drawn jump labels of one jump session, and the window that shows
  /// them.
  struct ShownJumpLabels {
    /// The accessibility frame of each drawn label, in screen points.
    let frames: [CGRect]

    /// The number of labels that the session gives: one for each candidate
    /// with an anchor (`JumpOverlayState.chips`).
    let labelCount: Int

    /// The frame of the window, in screen points.
    let window: CGRect

    /// Each two drawn labels whose frames intersect, as text for an issue.
    var overlaps: [String] {
      frames.indices.flatMap { first in
        frames.indices.filter { $0 > first && frames[first].intersects(frames[$0]) }.map {
          "\(frames[first]) and \(frames[$0])"
        }
      }
    }

    /// The frame of each drawn label that is not fully in the window.
    var outsideWindow: [CGRect] {
      frames.filter { !window.contains($0) }
    }
  }

  /// One window that shows `content` with the jump labels of its own jump
  /// controller.
  @MainActor struct JumpLabelBed<Content: View> {
    /// The command system of the window.
    let system = CommandSystem()

    /// The jump controller of the window.
    let controller: JumpModeController

    /// The harness that shows the window.
    let harness: HostedViewHarness<JumpLabelWindowRoot<Content>>

    /// Shows `content` in a window of `size`, with the jump labels drawn,
    /// and renders it one time.
    ///
    /// - Parameters:
    ///   - content: The content of the window.
    ///   - size: The size of the window.
    init(_ content: Content, size: CGSize) {
      controller = JumpModeController(system: system)
      harness = HostedViewHarness(
        JumpLabelWindowRoot(system: system, controller: controller, content: content), size: size)
      harness.render()
    }

    /// Starts a jump session in `layer`, renders its labels, and reads the
    /// frame of each drawn label (`jump.chip`) from the accessibility tree.
    ///
    /// - Parameter layer: The path of the scope whose targets get labels.
    /// - Returns: The drawn labels.
    /// - Throws: An issue when no session starts.
    func showLabels(in layer: FocusPath) throws -> ShownJumpLabels {
      try #require(controller.activate(layer: layer))
      harness.render()
      let labelCount = try #require(controller.overlayState?.chips.count)
      let frames = accessibilityElements(
        identifiedAs: JumpLabelOverlapHostedTests.labelIdentifier, under: harness.hostingView
      ).compactMap(accessibilityFrame(of:))
      return ShownJumpLabels(frames: frames, labelCount: labelCount, window: harness.window.frame)
    }

    /// Ends the jump session and closes the window.
    func close() {
      controller.cancel()
      harness.close()
    }
  }

  /// Tests that no two jump labels overlap in the dense places of the kit,
  /// and that each label is in the window (TestudoApp, ^9524ap0).
  ///
  /// EditorKit draws a label (`jump.chip`) over each target of a jump
  /// session. Its chip layout (EditorKit ^5851ngm) moves a label that hits an
  /// earlier label to a free place inside or next to its own target, in the
  /// visible rect of the window. Each test shows a dense place in a window
  /// with `.jumpMode(_:)` at its root, starts a jump session, renders the
  /// labels one time, and reads the frame of each drawn label through the
  /// accessibility tree: the frames that a person and VoiceOver see.
  ///
  /// A production change that fails each test: the chip layout puts each
  /// label at the anchor of its target with no overlap check, so the labels
  /// of close targets stand on top of each other; or AVK puts two jump
  /// targets so close that the layout cannot separate their labels.
  @Suite(.serialized, .hostedSerially) @MainActor struct JumpLabelOverlapHostedTests {
    /// The accessibility identifier of each jump label: the identifier of
    /// the EditorKit `JumpOverlay` chip, which EditorKit does not make
    /// public.
    static let labelIdentifier = "jump.chip"

    /// The least number of drawn labels in a dense place, so that an
    /// overlap check over the labels checks pairs.
    static let leastLabelCount = 2

    /// The size of the window of the transcript test.
    static let transcriptWindowSize = CGSize(width: 480, height: 600)

    /// The number of times the transcript repeats ``denseTurn``.
    static let denseTurnCount = 12

    /// One short turn of the dense transcript: a user message, a tool call
    /// row and an agent message, each of one line.
    static let denseTurn: [PreviewTranscriptItem] = [
      .user("Run it"),
      .toolCall(title: "Read Parser.swift", kind: .read, status: .completed),
      .agent("Done."),
    ]

    /// The size of the window of the session jump list test.
    static let jumpListWindowSize = CGSize(width: 400, height: 640)

    /// The number of child sessions in the session jump list.
    static let childCount = 8

    /// The segment of the window scope of the session jump list test: the
    /// layer of its jump session.
    static let jumpListWindowSegment = FocusSegment(kind: "jumpListWindow")

    /// The text in the composer of the thread bar test.
    static let composerText = "Hello"

    /// Expects that `labels` has several drawn labels, one for each label of
    /// the session, that each one is in the window, and that no two
    /// intersect.
    ///
    /// - Parameters:
    ///   - labels: The drawn labels.
    ///   - sourceLocation: The location that an issue names.
    static func expectApartInTheWindow(
      _ labels: ShownJumpLabels, sourceLocation: SourceLocation = #_sourceLocation
    ) {
      #expect(labels.frames.count >= leastLabelCount, sourceLocation: sourceLocation)
      #expect(
        labels.frames.count == labels.labelCount, "drawn \(labels.frames.count)",
        sourceLocation: sourceLocation)
      #expect(
        labels.outsideWindow.isEmpty, "window \(labels.window): \(labels.outsideWindow)",
        sourceLocation: sourceLocation)
      #expect(labels.overlaps.isEmpty, "\(labels.overlaps)", sourceLocation: sourceLocation)
    }

    /// A dense transcript: many short messages and tool call rows in an
    /// ``AgentThreadView``, so that each row is a jump target near the next.
    @Test func noTwoJumpLabelsOverlapInADenseTranscript() throws {
      let transcript = Array(repeating: Self.denseTurn, count: Self.denseTurnCount).flatMap { $0 }
      let session = SessionModel.preview(transcript: transcript)
      let bed = JumpLabelBed(AgentThreadView(session: session), size: Self.transcriptWindowSize)
      defer { bed.close() }

      let labels = try bed.showLabels(in: AgentCommandScopeHostedTests.path(of: session))

      Self.expectApartInTheWindow(labels)
    }

    /// The ``SessionJumpList`` of a session with ``childCount`` child
    /// sessions: the filter field and one row for each session, each row a
    /// jump target of the `EditorSelectionList`.
    @Test func noTwoJumpLabelsOverlapInTheSessionJumpList() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      for index in 0..<Self.childCount {
        try await session.announceChild(
          SessionId(rawValue: "child-\(index)"), title: "Worker \(index)")
      }
      let entries = session.model.jumpEntries
      try #require(entries.count == Self.childCount)
      let list = SessionJumpList(agent: session.connection.agentName, entries: entries) { _ in }
        .commandScope(segment: Self.jumpListWindowSegment)
        .targetable(.childrenOnly)
      let bed = JumpLabelBed(list, size: Self.jumpListWindowSize)
      defer { bed.close() }

      let labels = try bed.showLabels(in: .root(Self.jumpListWindowSegment))

      Self.expectApartInTheWindow(labels)
    }

    /// The bars of a thread: the top bar with the status line and the
    /// header of the connection, and the bottom bar with a request deck over
    /// the composer, which shows its suggestion chips, its attachment chips,
    /// the dictation button and Send.
    @Test func noTwoJumpLabelsOverlapInTheThreadBars() throws {
      let connection = ConnectionModel.previewSample
      let session = try #require(connection.openSessions.first)
      try #require(!session.pendingRequests.isEmpty)
      let draft = PromptInputHostedTestModel(
        text: Self.composerText, attachments: PreviewFixtures.attachments)
      let thread = AgentThreadView(session: session, connection: connection) {
        VStack {
          RequestDeck(session: session)
          PromptInputView(text: Bindable(draft).text, attachments: Bindable(draft).attachments) {}
        }
      }
      .environment(\.promptSuggestions, PreviewFixtures.suggestions)
      .speechTranscriber(FakeSpeechTranscriber())
      let bed = JumpLabelBed(thread, size: ThreadBarControlJumpHostedTests.windowSize)
      defer { bed.close() }

      let labels = try bed.showLabels(in: AgentCommandScopeHostedTests.path(of: session))

      Self.expectApartInTheWindow(labels)
    }
  }
#endif
