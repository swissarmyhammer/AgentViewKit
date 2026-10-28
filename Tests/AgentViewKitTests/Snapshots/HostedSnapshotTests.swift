@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import FoundationModelsACPClient
import Quartz
import SwiftUI
import Testing

/// The snapshot images of the real views of the kit in a hidden window
/// (AVK-13, path A of ``ViewSnapshot``).
///
/// Each test shows one view with the fixed data of ``SnapshotFixtures`` in
/// each ``SnapshotVariant``, and compares the image with its reference image
/// in `__Snapshots__/HostedSnapshotTests/`. The cache of a window shows no
/// glass, so a glass part shows the window background here.
/// ``GlassSnapshotTests`` shows the glass parts.
///
/// To record the reference images again, run
/// `AVK_SNAPSHOT_RECORD=1 swift test --filter SnapshotTests`, and then look
/// at each image before the commit.
@Suite(.serialized, .hostedSerially) @MainActor struct HostedSnapshotTests {
  /// Shows `view` in `variant` and compares the image with its reference
  /// image.
  ///
  /// - Parameters:
  ///   - view: The real view to show.
  ///   - name: The name of the view in the image name, such as `thread`.
  ///   - size: The size of the image, in points.
  ///   - variant: The settings of the image.
  ///   - hiddenTypes: The classes of the AppKit views that the image does not
  ///     show (``ViewSnapshot/hostedPixels(of:size:variant:hiding:settle:)``).
  ///   - settle: The wait for a certain event before the image.
  ///   - sourceLocation: The location of the caller, for the issue.
  /// - Throws: The error of `settle`, or of ``SnapshotStore``.
  static func verify(
    _ view: some View, named name: String, size: CGSize, variant: SnapshotVariant,
    hiding hiddenTypes: [NSView.Type] = [], settle: @MainActor () async throws -> Void = {},
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws {
    let pixels = try await ViewSnapshot.hostedPixels(
      of: view, size: size, variant: variant, hiding: hiddenTypes, settle: settle)
    try SnapshotStore(suite: "HostedSnapshotTests")
      .verify(pixels, named: variant.name(of: name), sourceLocation: sourceLocation)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theThread(variant: SnapshotVariant) async throws {
    let session = SnapshotFixtures.threadSession
    let cache = CodeBlockModelCache()
    let thread = AgentThreadView(session: session).environment(\.codeBlockModelCache, cache)

    try await Self.verify(thread, named: "thread", size: SnapshotFixtures.threadSize, variant: variant) {
      await SnapshotFixtures.waitForSyntax(of: try SnapshotFixtures.codeBlockModel(in: cache, session: session))
    }
  }

  /// The state banner with its Show Error button and the login card with its
  /// Sign In button, in the bottom bar of a thread at rest, below the
  /// transcript. The bar has no glass surface, so the buttons use the glass
  /// styles and not the bordered styles (EditorKit `style.md`, rule
  /// 4). The cache of a window shows no glass, so a glass button shows its
  /// label with no bezel, and a bordered button shows its bezel.
  ///
  /// The list is at rest and follows the bottom, and the transcript fits
  /// between the two bars, so no row is under a bar and each line of the
  /// image is readable (^zg9tysk). A row under a bar shows through the bar in
  /// this image: the cache of a window draws neither the glass of the bar nor
  /// the scroll edge effect. The scroll-to-bottom pill shows only when the
  /// list is away from the bottom, with rows under the bar, so this image does
  /// not show it. `GlassSnapshotTests` shows the pill in the floating controls.
  @Test(arguments: SnapshotVariant.allCases)
  func theButtonsOfTheBottomBarBelowTheTranscript(variant: SnapshotVariant) async throws {
    try await Self.verify(
      SnapshotFixtures.bottomBarThread, named: "bottom-bar-buttons", size: SnapshotFixtures.threadSize,
      variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theIdleComposer(variant: SnapshotVariant) async throws {
    let composer = SnapshotFixtures.composer(for: SnapshotFixtures.idleSession)

    try await Self.verify(composer, named: "composer-idle", size: SnapshotFixtures.composerSize, variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theComposerWhileTheAgentRuns(variant: SnapshotVariant) async throws {
    let composer = SnapshotFixtures.composer(for: SnapshotFixtures.runningSession)

    try await Self.verify(composer, named: "composer-running", size: SnapshotFixtures.composerSize, variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func thePermissionRequestCard(variant: SnapshotVariant) async throws {
    let card = try PermissionViewSurfaceHostedTests.card()

    try await Self.verify(card, named: "permission-card", size: SnapshotFixtures.cardSize, variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theRequestDeckInTheBar(variant: SnapshotVariant) async throws {
    try await Self.verify(
      RequestDeckSurfaceHostedTests.deckInBar, named: "request-deck-bar", size: RequestDeckSurfaceTests.size,
      variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theSessionNotice(variant: SnapshotVariant) async throws {
    let banner = SessionNoticeBanner(session: SessionNoticeBannerSurfaceHostedTests.session)

    try await Self.verify(banner, named: "session-notice", size: SnapshotFixtures.cardSize, variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theStatusBanner(variant: SnapshotVariant) async throws {
    let banner = StateBanner(session: SnapshotFixtures.runningSession)

    try await Self.verify(banner, named: "status-banner", size: SnapshotFixtures.bannerSize, variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theCodeBlock(variant: SnapshotVariant) async throws {
    let model = EditorModel(PreviewFixtures.codeSample)
    let block = CodeBlockView(
      code: PreviewFixtures.codeSample, language: PreviewFixtures.codeSampleLanguage, model: model)

    try await Self.verify(block, named: "code-block", size: SnapshotFixtures.codeBlockSize, variant: variant) {
      await SnapshotFixtures.waitForSyntax(of: model)
    }
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theTerminalOutput(variant: SnapshotVariant) async throws {
    let entry = try #require(
      PreviewFixtures.entry(
        .terminal(
          command: SnapshotFixtures.terminalCommand, output: SnapshotFixtures.terminalOutput,
          exitCode: CommandOutputView.successExitCode),
        as: TerminalEntry.self))

    try await Self.verify(
      TerminalView(entry: entry), named: "terminal", size: SnapshotFixtures.terminalSize, variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theElicitationForm(variant: SnapshotVariant) async throws {
    let session = PreviewFixtures.elicitationSession
    let request = try #require(session.pendingElicitations.first)

    try await Self.verify(
      ElicitationView(request: request, owner: session), named: "elicitation-form",
      size: SnapshotFixtures.elicitationSize, variant: variant)
  }

  /// The attachment inspector of a file on disk, over the text backdrop of
  /// ``GlassSnapshotTests/backdrop``. The grouped form of the inspector hides
  /// its own background (^bkhgxs5), so the text shows in the margins of the
  /// form and between its sections.
  ///
  /// The image hides the live `QLPreviewView` of the preview row. QuickLook
  /// draws the preview out of process, and no event tells when it is drawn:
  /// a read soon after the mount shows no preview, and a read about one
  /// second later shows the text of the file. Thus the preview row shows its
  /// place at the fixed height of the preview, with the backdrop through the
  /// row, on each run.
  @Test(arguments: SnapshotVariant.allCases)
  func theAttachmentInspector(variant: SnapshotVariant) async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try AttachmentInspectorHostedTests.attachment(
      named: SnapshotFixtures.inspectorFileName, in: directory)
    let inspector = ZStack {
      GlassSnapshotTests.backdrop
      AttachmentInspector(attachment)
    }

    try await Self.verify(
      inspector, named: "attachment-inspector", size: SnapshotFixtures.inspectorSize, variant: variant,
      hiding: [QLPreviewView.self])
  }
}
