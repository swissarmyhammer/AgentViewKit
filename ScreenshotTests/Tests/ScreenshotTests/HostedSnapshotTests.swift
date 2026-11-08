@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorStyle
import EditorSwiftUI
import EditorTestSupport
import FoundationModelsACPClient
import Quartz
import SwiftUI
import Testing

/// The snapshot images of the real views of the kit, each in a real window on
/// the screen, captured from the window server (AVK-13, EditorKit `style.md`
/// rule 9).
///
/// Each test shows one view with the fixed data of ``SnapshotFixtures`` in
/// each look, Light and Dark, and records the capture as `<name>-light.png` or
/// `<name>-dark.png` for the review gallery. Nothing compares a capture with
/// an earlier one. The window server draws each part as the app shows it: the
/// AppKit views, the Liquid Glass and the scroll edge effect.
///
/// Open the review gallery after a run to look at the images.
@Suite(.serialized, .hostedSerially) @MainActor struct HostedSnapshotTests {
  /// Shows `view` in each look and records its image for the review gallery.
  ///
  /// - Parameters:
  ///   - view: The real view to show.
  ///   - name: The name of the view in the image name, such as `thread`.
  ///   - size: The size of the image, in points.
  ///   - hiddenTypes: The classes of the AppKit views that the image does not
  ///     show (``ReviewMount/hideViews(of:)``).
  ///   - settle: The wait for a certain event before the image.
  /// - Throws: The error of `settle`, or of the capture.
  static func generate<Content: View>(
    _ view: Content, named name: String, size: CGSize, hiding hiddenTypes: [NSView.Type] = [],
    settle: @escaping @MainActor () async throws -> Void = {}
  ) async throws {
    try await ReviewGalleryScreenTests.gallery.record(
      suite: "HostedSnapshotTests", named: name, size: size,
      settle: { mount in
        try await settle()
        mount.hideViews(of: hiddenTypes)
      },
      content: { _ in view })
  }

  @Test func theThread() async throws {
    let session = SnapshotFixtures.threadSession
    let cache = CodeBlockModelCache()
    let thread = AgentThreadView(session: session).environment(\.codeBlockModelCache, cache)

    try await Self.generate(thread, named: "thread", size: SnapshotFixtures.threadSize) {
      await SnapshotFixtures.waitForSyntax(of: try SnapshotFixtures.codeBlockModel(in: cache, session: session))
    }
  }

  /// The thread with the time of each row (`.transcriptTiming()`), over the
  /// timed turn of ``TimingGalleryFixtures``: the start time of each entry
  /// and the duration of each entry that ended, in one line such as
  /// "6:13 AM · 1m 15s", and the duration of the thought in its title.
  @Test func theThreadWithTheTimeOfEachRow() async throws {
    let session = try await TimingGalleryFixtures.openSession()
    defer { session.close() }
    let thread = AgentThreadView(session: session.model).transcriptTiming()

    try await Self.generate(thread, named: "thread-timing", size: SnapshotFixtures.threadSize)
  }

  /// The state banner with its Show Error button and the login card with its
  /// Sign In button, in the bottom bar of a thread at rest, below the
  /// transcript. The bar has no glass surface, so the buttons use the glass
  /// styles and not the bordered styles (EditorKit `style.md`, rule 4).
  ///
  /// The list is at rest and follows the bottom, and the transcript fits
  /// between the two bars, so no row is under a bar and each line of the
  /// image is readable (^zg9tysk). The scroll-to-bottom pill shows only when
  /// the list is away from the bottom, with rows under the bar, so this image
  /// does not show it. `GlassSnapshotTests` shows the pill in the floating
  /// controls.
  @Test func theButtonsOfTheBottomBarBelowTheTranscript() async throws {
    try await Self.generate(
      SnapshotFixtures.bottomBarThread, named: "bottom-bar-buttons", size: SnapshotFixtures.threadSize)
  }

  /// The sign-in card while its sign-in runs (^dj4hchg): EditorKit's busy
  /// state of the Sign In button, a spinner over the room of its icon, with
  /// its caption kept and no press taken. The scripted agent holds its answer
  /// to `auth/login`, so the sign-in of each look runs until the end of the
  /// test. Each look has a session of its own: the card of the first look
  /// cancels its sign-in when it goes away, and the connection then records
  /// the failure. The settle presses the button through accessibility, as
  /// VoiceOver does, and the card disables it in the same step.
  @Test func theSignInCardWhileSigningIn() async throws {
    let light = try await Self.openHeldSignInSession()
    defer { light.close() }
    let dark = try await Self.openHeldSignInSession()
    defer { dark.close() }
    let signIn = AgentAuthView.signInIdentifier(for: ScriptedSession.loginAuthMethodID)

    try await ReviewGalleryScreenTests.gallery.record(
      suite: "HostedSnapshotTests", named: "sign-in-card-signing-in", size: SnapshotFixtures.cardSize,
      settle: { mount in
        _ = try AccessibilityAction.press.perform(on: signIn, in: mount.window)
        mount.render()
      },
      content: { appearance in
        let session = appearance == .light ? light : dark
        return AgentAuthView(connection: session.connection).environment(\.sessionModel, session.model)
      })
  }

  /// Opens a session whose agent asks for a sign-in with
  /// `ScriptedSession.loginAuthMethodID`, and holds its answer to
  /// `auth/login`.
  ///
  /// - Returns: The scripted session.
  /// - Throws: The error of `initialize` or of `session/new`.
  static func openHeldSignInSession() async throws -> ScriptedSession {
    try await ScriptedSession.open {
      $0.results["initialize"] = ScriptedSession.loginInitializeResult
      $0.heldMethods = [ScriptedSession.loginMethod]
    }
  }

  @Test func theIdleComposer() async throws {
    let composer = SnapshotFixtures.composer(for: SnapshotFixtures.idleSession)

    try await Self.generate(composer, named: "composer-idle", size: SnapshotFixtures.composerSize)
  }

  @Test func theComposerWhileTheAgentRuns() async throws {
    let composer = SnapshotFixtures.composer(for: SnapshotFixtures.runningSession)

    try await Self.generate(composer, named: "composer-running", size: SnapshotFixtures.composerSize)
  }

  @Test func thePermissionRequestCard() async throws {
    let card = try SnapshotFixtures.permissionCard()

    try await Self.generate(card, named: "permission-card", size: SnapshotFixtures.cardSize)
  }

  @Test func theRequestDeckInTheBar() async throws {
    try await Self.generate(
      SnapshotFixtures.deckInBar, named: "request-deck-bar", size: SnapshotFixtures.requestDeckSize)
  }

  @Test func theSessionNotice() async throws {
    // The banner has no margin of its own (^rgsq3k4); the image spaces it
    // with the tile margin, as the top bar of a thread does.
    let banner = SessionNoticeBanner(session: SnapshotFixtures.noticeSession)
      .padding(EditorStyle.default.tile.margin)

    try await Self.generate(banner, named: "session-notice", size: SnapshotFixtures.cardSize)
  }

  /// Each view of the kit that shows a status, in each status, drawn with
  /// EditorKit's status token (``StatusGalleryFixtures``).
  @Test func theStatusOfEachKind() async throws {
    try await Self.generate(StatusGalleryFixtures.gallery, named: "statuses", size: StatusGalleryFixtures.size)
  }

  /// The location chips of a tool call and the file chips of a diff in a
  /// narrow column, each in EditorKit's `EditorChipRows`, wrapping to more
  /// than one row (``ChipRowsGalleryFixtures``).
  @Test func theChipRowsInANarrowColumn() async throws {
    try await Self.generate(
      ChipRowsGalleryFixtures.gallery, named: "chip-rows-narrow", size: ChipRowsGalleryFixtures.size)
  }

  /// The selection and the focus of the items of the kit (^r3sm8nh,
  /// EditorKit `style.md`, "Selection and focus"): the rows of an
  /// ``AgentRowList``, an ``AttachmentChip``, the chip of an
  /// ``AttachmentView`` and a message, with the focus on one item of each
  /// image, and the inactive grey of a window that is not key
  /// (``SelectionGalleryFixtures``).
  @Test func theSelectionAndTheFocusOfTheItems() async throws {
    try await SelectionGalleryFixtures.record(in: ReviewGalleryScreenTests.gallery)
  }

  /// The button families of the kit in a narrow column: each button with too
  /// little room shows its symbol alone, and no caption is cut
  /// (``ButtonGalleryFixtures``).
  @Test func theButtonsInANarrowColumn() async throws {
    try await Self.generate(
      try ButtonGalleryFixtures.gallery(), named: "buttons-narrow", size: ButtonGalleryFixtures.narrowSize)
  }

  /// The button families of the kit in a wide column, each with its whole
  /// caption (``ButtonGalleryFixtures``).
  @Test func theButtonsInAWideColumn() async throws {
    try await Self.generate(
      try ButtonGalleryFixtures.gallery(), named: "buttons-wide", size: ButtonGalleryFixtures.wideSize)
  }

  @Test func theStatusBanner() async throws {
    let banner = StateBanner(session: SnapshotFixtures.runningSession)

    try await Self.generate(banner, named: "status-banner", size: SnapshotFixtures.bannerSize)
  }

  @Test func theTitleLinesOfTheBars() async throws {
    try await Self.generate(
      SnapshotFixtures.titleLineBars, named: "status-bar-title-lines", size: SnapshotFixtures.titleLineBarsSize)
  }

  /// The permission-mode picker, the menu buttons of the config options and
  /// the tools, and the choice and toggle controls that their menus hold.
  @Test func theConfigAndToolControls() async throws {
    try await Self.generate(
      SnapshotFixtures.configControls, named: "config-controls", size: SnapshotFixtures.configControlsSize)
  }

  @Test func theCodeBlock() async throws {
    let model = EditorModel(PreviewFixtures.codeSample)
    let block = CodeBlockView(
      code: PreviewFixtures.codeSample, language: PreviewFixtures.codeSampleLanguage, model: model)

    try await Self.generate(block, named: "code-block", size: SnapshotFixtures.codeBlockSize) {
      await SnapshotFixtures.waitForSyntax(of: model)
    }
  }

  @Test func theTerminalOutput() async throws {
    let entry = try #require(
      PreviewFixtures.entry(
        .terminal(
          command: SnapshotFixtures.terminalCommand, output: SnapshotFixtures.terminalOutput,
          exitCode: CommandOutputView.successExitCode),
        as: TerminalEntry.self))

    try await Self.generate(TerminalView(entry: entry), named: "terminal", size: SnapshotFixtures.terminalSize)
  }

  /// The output of a command that failed, whose line of the problem is wider
  /// than the block and wraps to its width.
  @Test func theCommandOutput() async throws {
    let output = CommandOutputView(
      command: PreviewFixtures.lintCommand, output: PreviewFixtures.lintOutput,
      exitCode: PreviewFixtures.failingExitCode)

    try await Self.generate(output, named: "command-output", size: SnapshotFixtures.commandOutputSize)
  }

  /// A diff of a patch: the file chips over EditorKit's one-value preview of
  /// the selected file.
  @Test func theDiff() async throws {
    try await Self.generate(
      DiffView(patch: PreviewFixtures.smallPatch), named: "diff", size: SnapshotFixtures.diffSize)
  }

  /// The diff of a patch that EditorKit cannot read: the failure state of
  /// the preview, with the line where the parse stopped. The settle waits
  /// for the load of the preview to fail.
  @Test func theDiffOfAnUnreadablePatch() async throws {
    try await Self.generate(
      DiffView(patch: SnapshotFixtures.unreadablePatch), named: "diff-unreadable", size: SnapshotFixtures.diffSize
    ) {
      await RunLoopBlockFence.afterPendingBlocks()
    }
  }

  @Test func theElicitationForm() async throws {
    let session = PreviewFixtures.elicitationSession
    let request = try #require(session.pendingElicitations.first)

    try await Self.generate(
      ElicitationView(request: request, owner: session), named: "elicitation-form",
      size: SnapshotFixtures.elicitationSize)
  }

  /// The attachment inspector of a file on disk, over the text backdrop of
  /// ``GlassSnapshotTests/backdrop``. The grouped form of the inspector hides
  /// its own background (^bkhgxs5), so the text shows in the margins of the
  /// form and between its sections.
  ///
  /// The image hides the live `QLPreviewView` of the preview row. QuickLook
  /// draws the preview out of process, and no event tells when it is drawn:
  /// a capture soon after the mount shows no preview, and a capture about one
  /// second later shows the text of the file. Thus the preview row shows its
  /// place at the fixed height of the preview, with the backdrop through the
  /// row, on each run.
  @Test func theAttachmentInspector() async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(
      named: SnapshotFixtures.inspectorFileName, in: directory)
    let inspector = ZStack {
      GlassSnapshotTests.backdrop
      AttachmentInspector(attachment)
    }

    try await Self.generate(
      inspector, named: "attachment-inspector", size: SnapshotFixtures.inspectorSize,
      hiding: [QLPreviewView.self])
  }
}
