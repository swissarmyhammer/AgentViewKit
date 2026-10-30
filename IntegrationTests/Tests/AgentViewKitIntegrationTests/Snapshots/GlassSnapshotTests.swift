@testable import AgentViewKit
import EditorStyle
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The snapshot images of the glass parts of the kit over the text of a
/// transcript, each in a real window on the screen, captured from the window
/// server (AVK-13, EditorKit `style.md` rule 9).
///
/// The window server draws the Liquid Glass of each part as the app shows it,
/// with the real views on the glass: the header of a thread, the composer with
/// the EditorKit editor and its accessory row, the request deck in the bar
/// with its cards, and the scroll-to-bottom pill with the composer in one
/// `FloatingGlassContainer`.
///
/// Clear glass over the plain window background shows almost no pixels. In
/// a thread, the transcript scrolls under the bottom bar. Thus each glass
/// part is at the bottom of its image, over text (``overText(_:)``), so that
/// the image shows the glass.
///
/// Each test generates the image of the capture, `<name>-light.png` or
/// `<name>-dark.png`, with ``GeneratedImages`` for the review gallery.
@Suite(.serialized, .hostedSerially) @MainActor struct GlassSnapshotTests {
  /// The size of the image of the floating controls of the thread, in
  /// points.
  static let controlsSize = CGSize(width: 480, height: 200)

  /// The number of new items that the scroll-to-bottom pill shows.
  static let newItemCount = 3

  /// The spacing of the style between two floating controls.
  static var spacing: CGFloat { EditorStyle.default.spacing.s }

  /// Shows `view` over text in `look` and generates its image for the
  /// review gallery.
  ///
  /// - Parameters:
  ///   - view: The glass part to show.
  ///   - name: The name of the view in the image name, such as
  ///     `composer-field`.
  ///   - size: The size of the image, in points.
  ///   - look: The look of the window.
  ///   - sourceLocation: The location of the caller, for the issue.
  /// - Throws: The error of the capture.
  static func generate(
    _ view: some View, named name: String, size: CGSize, look: ReviewAppearance,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws {
    let part = overText(view)
    let image = try await CaptureMount.capture(part, size: size, appearance: look)
    try GeneratedImages.write(image, suite: "GlassSnapshotTests", named: name, in: look)
  }

  /// The Markdown text under the glass: two plain paragraphs of a transcript.
  static let backdropMarkdown: LocalizedStringKey = """
    The migration copies the invoices of each month to the new `invoices_v2` table. \
    The total of **each month** stays the same, so the old table can go.

    The next step adds an index on the date of each invoice, so that the report \
    of one month reads fewer rows.
    """

  /// The number of copies of ``backdropMarkdown`` under the glass. The
  /// copies fill each image, so that the text goes under the glass part.
  static let backdropCopies = 4

  /// The text that fills an image behind a part: ``backdropCopies`` copies
  /// of ``backdropMarkdown`` from the top of the image, as a transcript.
  ///
  /// The text is a SwiftUI `Text` of Markdown, which draws in its first
  /// layout pass with no load, so each capture shows the same text.
  static var backdrop: some View {
    let margin = EditorStyle.default.spacing.m
    return VStack(alignment: .leading, spacing: margin) {
      ForEach(0..<backdropCopies, id: \.self) { _ in
        Text(backdropMarkdown)
      }
    }
    .padding(margin)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .clipped()
  }

  /// `part` at the bottom of the image, over text that fills the image
  /// (``backdrop``), as the bottom bar of a thread is over the transcript.
  ///
  /// - Parameter part: The glass part.
  /// - Returns: The part over the text.
  static func overText(_ part: some View) -> some View {
    ZStack(alignment: .bottom) {
      backdrop
      part.padding(EditorStyle.default.spacing.m)
    }
  }

  /// The composer of `session` in one `FloatingGlassContainer`, as in the
  /// composer slot of ``AgentThreadView``: the field of the composer with the
  /// EditorKit editor, above the accessory row. The row shows the Stop button
  /// while the agent of `session` runs.
  ///
  /// - Parameter session: The session of the composer.
  /// - Returns: The view.
  static func composer(for session: SessionModel) -> some View {
    FloatingGlassContainer(spacing: spacing) {
      SnapshotFixtures.composer(for: session)
    }
  }

  /// The floating controls of a thread: the scroll-to-bottom pill and the
  /// composer in one `FloatingGlassContainer`, as in the bottom bar of
  /// ``AgentThreadView`` (D110 (c)).
  static var floatingControls: some View {
    FloatingGlassContainer(spacing: spacing) {
      VStack(spacing: spacing) {
        ScrollToBottomPill(newItemCount: newItemCount) {}
        SnapshotFixtures.composer(for: SnapshotFixtures.idleSession)
      }
    }
  }

  /// The size of the image of the thread header, in points.
  static let headerSize = CGSize(width: 480, height: 120)

  /// The session title that the thread header shows in its image.
  static let headerSessionTitle = "AgentViewKit"

  /// The header of a thread with the "Agent › Session" breadcrumb, on the
  /// floating glass of the kit in one `FloatingGlassContainer`, as in the
  /// top bar of ``AgentThreadView``.
  static var threadHeader: some View {
    FloatingGlassContainer(spacing: spacing) {
      AgentInfoHeader(connection: AgentAuthViewSurfaceHostedTests.connection, sessionTitle: headerSessionTitle)
        .padding(.horizontal, EditorStyle.default.spacing.m)
        .padding(.vertical, EditorStyle.default.spacing.s)
        .floatingGlass()
    }
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theHeaderOfTheThread(look: ReviewAppearance) async throws {
    try await Self.generate(Self.threadHeader, named: "thread-header", size: Self.headerSize, look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theComposer(look: ReviewAppearance) async throws {
    try await Self.generate(
      Self.composer(for: SnapshotFixtures.idleSession), named: "composer-field-idle",
      size: SnapshotFixtures.composerSize, look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theComposerWhileTheAgentRuns(look: ReviewAppearance) async throws {
    try await Self.generate(
      Self.composer(for: SnapshotFixtures.runningSession), named: "composer-field-running",
      size: SnapshotFixtures.composerSize, look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theRequestDeckInTheBar(look: ReviewAppearance) async throws {
    try await Self.generate(
      RequestDeckSurfaceHostedTests.deckInBar, named: "request-deck-bar", size: RequestDeckSurfaceHostedTests.size,
      look: look)
  }

  @Test(arguments: ReviewAppearance.allCases)
  func theFloatingControlsOfTheThread(look: ReviewAppearance) async throws {
    try await Self.generate(Self.floatingControls, named: "floating-controls", size: Self.controlsSize, look: look)
  }
}
