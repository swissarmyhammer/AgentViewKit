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
/// each look, Light and Dark, in a ``CaptureMount``, and compares the capture
/// with its reference image `<name>-light.png` or `<name>-dark.png` in
/// `__Snapshots__/HostedSnapshotTests/` (EditorKit `SnapshotStore`). The
/// window server draws each part as the app shows it: the AppKit views, the
/// Liquid Glass and the scroll edge effect.
///
/// To record the reference images again, run
/// `SNAPSHOT_RECORD=1 swift test --filter SnapshotTests`, look at each image
/// before the commit, and run the tests again without the variable.
@Suite(.serialized, .hostedSerially) @MainActor struct HostedSnapshotTests {
  /// Shows `view` in `look` and compares the capture with its reference
  /// image.
  ///
  /// - Parameters:
  ///   - view: The real view to show.
  ///   - name: The name of the view in the image name, such as `thread`.
  ///   - size: The size of the image, in points.
  ///   - look: The look of the window.
  ///   - hiddenTypes: The classes of the AppKit views that the image does not
  ///     show (``CaptureMount/capture(_:size:appearance:hiding:settle:)``).
  ///   - settle: The wait for a certain event before the image.
  ///   - sourceLocation: The location of the caller, for the issue.
  /// - Throws: The error of `settle`, of the capture, or of `SnapshotStore`.
  static func verify<Content: View>(
    _ view: Content, named name: String, size: CGSize, look: ReviewAppearance,
    hiding hiddenTypes: [NSView.Type] = [], settle: @MainActor () async throws -> Void = {},
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws {
    let image = try await CaptureMount<Content>.capture(
      view, size: size, appearance: look, hiding: hiddenTypes, settle: { _ in try await settle() })
    try SnapshotStore(suite: "HostedSnapshotTests").verify(image, named: name, in: look, sourceLocation: sourceLocation)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theThread(look: ReviewAppearance) async throws {
    let session = SnapshotFixtures.threadSession
    let cache = CodeBlockModelCache()
    let thread = AgentThreadView(session: session).environment(\.codeBlockModelCache, cache)

    try await Self.verify(thread, named: "thread", size: SnapshotFixtures.threadSize, look: look) {
      await SnapshotFixtures.waitForSyntax(of: try SnapshotFixtures.codeBlockModel(in: cache, session: session))
    }
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
  @Test(arguments: ReviewAppearance.allCases)
  func theButtonsOfTheBottomBarBelowTheTranscript(look: ReviewAppearance) async throws {
    try await Self.verify(
      SnapshotFixtures.bottomBarThread, named: "bottom-bar-buttons", size: SnapshotFixtures.threadSize, look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theIdleComposer(look: ReviewAppearance) async throws {
    let composer = SnapshotFixtures.composer(for: SnapshotFixtures.idleSession)

    try await Self.verify(composer, named: "composer-idle", size: SnapshotFixtures.composerSize, look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theComposerWhileTheAgentRuns(look: ReviewAppearance) async throws {
    let composer = SnapshotFixtures.composer(for: SnapshotFixtures.runningSession)

    try await Self.verify(composer, named: "composer-running", size: SnapshotFixtures.composerSize, look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func thePermissionRequestCard(look: ReviewAppearance) async throws {
    let card = try PermissionViewSurfaceHostedTests.card()

    try await Self.verify(card, named: "permission-card", size: SnapshotFixtures.cardSize, look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theRequestDeckInTheBar(look: ReviewAppearance) async throws {
    try await Self.verify(
      RequestDeckSurfaceHostedTests.deckInBar, named: "request-deck-bar", size: RequestDeckSurfaceHostedTests.size,
      look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theSessionNotice(look: ReviewAppearance) async throws {
    // The banner has no margin of its own (^rgsq3k4); the image spaces it
    // with the tile margin, as the top bar of a thread does.
    let banner = SessionNoticeBanner(session: SessionNoticeBannerSurfaceHostedTests.session)
      .padding(EditorStyle.default.tile.margin)

    try await Self.verify(banner, named: "session-notice", size: SnapshotFixtures.cardSize, look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theStatusBanner(look: ReviewAppearance) async throws {
    let banner = StateBanner(session: SnapshotFixtures.runningSession)

    try await Self.verify(banner, named: "status-banner", size: SnapshotFixtures.bannerSize, look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theCodeBlock(look: ReviewAppearance) async throws {
    let model = EditorModel(PreviewFixtures.codeSample)
    let block = CodeBlockView(
      code: PreviewFixtures.codeSample, language: PreviewFixtures.codeSampleLanguage, model: model)

    try await Self.verify(block, named: "code-block", size: SnapshotFixtures.codeBlockSize, look: look) {
      await SnapshotFixtures.waitForSyntax(of: model)
    }
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theTerminalOutput(look: ReviewAppearance) async throws {
    let entry = try #require(
      PreviewFixtures.entry(
        .terminal(
          command: SnapshotFixtures.terminalCommand, output: SnapshotFixtures.terminalOutput,
          exitCode: CommandOutputView.successExitCode),
        as: TerminalEntry.self))

    try await Self.verify(
      TerminalView(entry: entry), named: "terminal", size: SnapshotFixtures.terminalSize, look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theElicitationForm(look: ReviewAppearance) async throws {
    let session = PreviewFixtures.elicitationSession
    let request = try #require(session.pendingElicitations.first)

    try await Self.verify(
      ElicitationView(request: request, owner: session), named: "elicitation-form",
      size: SnapshotFixtures.elicitationSize, look: look)
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
  @Test(arguments: ReviewAppearance.allCases)
  func theAttachmentInspector(look: ReviewAppearance) async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(
      named: SnapshotFixtures.inspectorFileName, in: directory)
    let inspector = ZStack {
      GlassSnapshotTests.backdrop
      AttachmentInspector(attachment)
    }

    try await Self.verify(
      inspector, named: "attachment-inspector", size: SnapshotFixtures.inspectorSize, look: look,
      hiding: [QLPreviewView.self])
  }
}
