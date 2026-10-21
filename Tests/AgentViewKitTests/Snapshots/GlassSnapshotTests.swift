@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The snapshot images of the glass parts of the kit in isolation (AVK-13,
/// path B of ``ViewSnapshot``).
///
/// `ImageRenderer` draws each glass part with no window. The images show a
/// glass look, which can be different from the Liquid Glass that the system
/// draws in a window. ``HostedSnapshotTests`` shows the full views with no
/// glass.
///
/// `ImageRenderer` cannot draw the full glass views of the kit:
///
/// - It draws an AppKit view as a yellow placeholder. The full composer has
///   AppKit parts (the EditorKit editor, the drop target of the attachments,
///   and the bordered controls of the accessory row), so its render is the
///   placeholder.
/// - It draws nothing for a view with `accessibilityFocused(_:)`, such as
///   each card of a ``RequestDeck``. In the bar, the buttons of a card also
///   use the bordered styles, which are AppKit controls.
/// - It stops the process with a SwiftUI fatal error ("no current update to
///   enqueue action to") for the full ``AgentThreadView``.
///
/// Thus each image shows the glass surface of the kit for the part, with
/// SwiftUI content of the kit in the place of the AppKit and focus parts:
/// the field surface of the composer (``PromptFieldSurface``), the floating
/// glass of the deck in the bar, and the scroll-to-bottom pill with the
/// field in one ``FloatingGlassContainer``.
///
/// Clear glass over the plain window background shows almost no pixels. In
/// a thread, the transcript scrolls under the bottom bar. Thus each glass
/// part is at the bottom of its image, over text (``overText(_:)``), so that
/// the image shows the glass.
///
/// Each test compares the image with its reference image in
/// `__Snapshots__/GlassSnapshotTests/`. The rim of a rounded glass changes
/// after the first renders of the process, so the image can have
/// ``RenderedPixels/glassRimShare`` of changed pixels.
@Suite @MainActor struct GlassSnapshotTests {
  /// The size of the image of the floating controls of the thread, in
  /// points.
  static let controlsSize = CGSize(width: 480, height: 200)

  /// The number of new items that the scroll-to-bottom pill shows.
  static let newItemCount = 3

  /// The spacing of the theme between two floating controls.
  static var spacing: CGFloat { AgentTheme.default.spacing.s }

  /// Renders `view` in `variant` and compares the image with its reference
  /// image.
  ///
  /// - Parameters:
  ///   - view: The glass part to render.
  ///   - name: The name of the view in the image name, such as
  ///     `composer-field`.
  ///   - size: The size of the image, in points.
  ///   - variant: The settings of the image.
  ///   - sourceLocation: The location of the caller, for the issue.
  /// - Throws: The error of ``SnapshotStore``.
  static func verify(
    _ view: some View, named name: String, size: CGSize, variant: SnapshotVariant,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    try SnapshotStore(suite: "GlassSnapshotTests", changedPixelShare: RenderedPixels.glassRimShare).verify(
      ViewSnapshot.renderedPixels(of: overText(view), size: size, variant: variant), named: variant.name(of: name),
      sourceLocation: sourceLocation)
  }

  /// The Markdown text under the glass: two plain paragraphs of a transcript.
  static let backdropMarkdown: LocalizedStringKey = """
    `Parser.swift` does not import **Foundation**, so the type `URL` is not in scope. \
    Add the import at the top of the file, and then run the tests again.

    The tests pass now. The build of the package takes less time, because the \
    module of the parser has no new dependency.
    """

  /// The number of copies of ``backdropMarkdown`` under the glass. The
  /// copies fill each image, so that the text goes under the glass part.
  static let backdropCopies = 4

  /// `part` at the bottom of the image, over text that fills the image, as
  /// the bottom bar of a thread is over the transcript.
  ///
  /// The text is a SwiftUI `Text`, and not a ``ResponseView``:
  /// `ImageRenderer` draws nothing for a ``ResponseView``.
  ///
  /// - Parameter part: The glass part.
  /// - Returns: The part over the text.
  static func overText(_ part: some View) -> some View {
    let margin = AgentTheme.default.spacing.m
    return ZStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: margin) {
        ForEach(0..<backdropCopies, id: \.self) { _ in
          Text(backdropMarkdown)
        }
      }
      .padding(margin)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .clipped()
      part.padding(margin)
    }
  }

  /// The field of the composer: the placeholder text of the composer in the
  /// place of the editor, on the field surface of ``PromptInputView``.
  static var field: some View {
    Text(PromptInputView<StockPromptEditor, DefaultPromptAccessory>.placeholder)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .modifier(PromptFieldSurface())
  }

  /// The glass parts of the composer of `session`: the field above the
  /// accessory row (``DefaultPromptAccessory``), in one
  /// ``FloatingGlassContainer``, as ``PromptInputView`` shows them. The row
  /// shows the Stop button while the agent of `session` runs.
  ///
  /// - Parameter session: The session of the composer.
  /// - Returns: The view.
  static func composer(for session: SessionModel) -> some View {
    FloatingGlassContainer(spacing: spacing) {
      VStack(alignment: .leading, spacing: spacing) {
        field
        DefaultPromptAccessory()
      }
    }
    .environment(\.sessionModel, session)
  }

  /// The floating glass of a ``RequestDeck`` in the bar, with the header of
  /// the form request of ``RequestDeckSurfaceTests/session`` in the place of
  /// the cards. In the bar, the deck pads its cards with the medium spacing
  /// of the theme.
  ///
  /// - Returns: The view.
  /// - Throws: An issue when the session holds no form request.
  static func deckInBar() throws -> some View {
    let request = try #require(RequestDeckSurfaceTests.session.pendingElicitations.first)
    return FloatingGlassContainer(spacing: spacing) {
      ElicitationHeader(request: request)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AgentTheme.default.spacing.m)
        .agentFloatingGlass()
    }
  }

  /// The floating controls of a thread: the scroll-to-bottom pill and the
  /// composer in one ``FloatingGlassContainer``, as in the bottom bar of
  /// ``AgentThreadView`` (D110 (c)).
  static var floatingControls: some View {
    FloatingGlassContainer(spacing: spacing) {
      VStack(spacing: spacing) {
        ScrollToBottomPill(newItemCount: newItemCount) {}
        composer(for: SnapshotFixtures.idleSession)
      }
    }
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theComposer(variant: SnapshotVariant) throws {
    try Self.verify(
      Self.composer(for: SnapshotFixtures.idleSession), named: "composer-field-idle",
      size: SnapshotFixtures.composerSize, variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theComposerWhileTheAgentRuns(variant: SnapshotVariant) throws {
    try Self.verify(
      Self.composer(for: SnapshotFixtures.runningSession), named: "composer-field-running",
      size: SnapshotFixtures.composerSize, variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theRequestDeckInTheBar(variant: SnapshotVariant) throws {
    try Self.verify(
      Self.deckInBar(), named: "request-deck-bar", size: RequestDeckSurfaceTests.size, variant: variant)
  }

  @Test(arguments: SnapshotVariant.allCases)
  func theFloatingControlsOfTheThread(variant: SnapshotVariant) throws {
    try Self.verify(Self.floatingControls, named: "floating-controls", size: Self.controlsSize, variant: variant)
  }
}
