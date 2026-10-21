@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import SwiftUI
import Testing

/// Checks that the kit views draw the colors of the EditorKit theme in the
/// environment: the frame and the header of an editor block, the status of a
/// command, the diff counts, and the accent.
///
/// Each test gives a view ``DistinctRolesTheme`` with `.editorTheme(_:)`, and
/// looks for the color of one role in the pixels of the view. No other part
/// of the view draws that color, so the color comes from the theme.
@Suite @MainActor struct EditorThemeViewsTests {
  /// The role colors of ``DistinctRolesTheme``.
  typealias Role = DistinctRolesTheme.Role

  /// The size that the tests render each view at.
  static let size = CGSize(width: 480, height: 240)

  /// The exit code of a command that completed.
  static let successExitCode = 0

  /// The exit code of a command that failed.
  static let failureExitCode = 1

  /// The font size of the citation pill, large so that the digit has many
  /// opaque pixels.
  static let citationFontSize: CGFloat = 48

  /// A patch with one added line and one removed line.
  static let patch = """
    diff --git a/Sources/App.swift b/Sources/App.swift
    --- a/Sources/App.swift
    +++ b/Sources/App.swift
    @@ -1,2 +1,2 @@
     import SwiftUI
    -let name = "old"
    +let name = "new"
    """

  /// A block with clear content that fills the render size. In a frame, only
  /// the fill of the frame and its edge draw a color.
  static var clearBlock: some View {
    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// The pixels of `view` with ``DistinctRolesTheme`` as its EditorKit theme.
  ///
  /// - Parameter view: The view to render.
  /// - Returns: The pixels.
  /// - Throws: An error when the renderer gives no pixels.
  static func pixels(of view: some View) throws -> RenderedPixels {
    try #require(RenderedPixels(rendering: view.editorTheme(DistinctRolesTheme()), size: size))
  }

  /// The pixels of `view` in light mode with ``DistinctRolesTheme`` as its
  /// EditorKit theme, after a check that the view draws something.
  ///
  /// A test that finds no pixel of a role must use this function. A view that
  /// draws nothing has no pixel of any role, so the test would pass for the
  /// wrong cause.
  ///
  /// The function renders the clear view before `view`, and the order is
  /// necessary. When the first render of the test process is
  /// ``AgentInfoHeader`` or ``PendingRequestCountBadge``, `ImageRenderer`
  /// draws nothing for these two views in that render and in each later
  /// render. When the first render is the clear view, each later render of
  /// these views draws.
  ///
  /// - Parameter view: The view to render.
  /// - Returns: The pixels.
  /// - Throws: An error when the renderer gives no pixels, or when the pixels
  ///   are the same as the pixels of a clear view.
  static func drawnPixels(of view: some View) throws -> RenderedPixels {
    let blank = try pixels(of: Color.clear)
    return try requireDrawn(pixels(of: view.environment(\.colorScheme, .light)), blank: blank)
  }

  /// The same as ``drawnPixels(of:)``, but the pixels come from the cache of
  /// a window. Use this function for a view that `ImageRenderer` does not
  /// draw, for example a view in a `ScrollView`. A test that calls it must
  /// have the `.hostedSerially` trait.
  ///
  /// - Parameter view: The view to show in the window.
  /// - Returns: The pixels.
  /// - Throws: An error when AppKit gives no pixels, or when the pixels are
  ///   the same as the pixels of a clear view.
  static func drawnCachedPixels(of view: some View) throws -> RenderedPixels {
    let blank = try cachedPixels(of: Color.clear)
    return try requireDrawn(cachedPixels(of: view.environment(\.colorScheme, .light)), blank: blank)
  }

  /// The pixels that AppKit caches for `view` in a window, with
  /// ``DistinctRolesTheme`` as its EditorKit theme.
  ///
  /// - Parameter view: The view to show in the window.
  /// - Returns: The pixels.
  /// - Throws: An error when AppKit gives no pixels.
  static func cachedPixels(of view: some View) throws -> RenderedPixels {
    try GlassRenderProbeHostedTests.cachedPixels(of: view.editorTheme(DistinctRolesTheme()), size: size)
  }

  /// Checks that a view draws something.
  ///
  /// - Parameters:
  ///   - drawn: The pixels of the view.
  ///   - blank: The pixels of a clear view, from the same renderer.
  /// - Returns: `drawn`.
  /// - Throws: An error when `drawn` is the same as `blank`.
  static func requireDrawn(_ drawn: RenderedPixels, blank: RenderedPixels) throws -> RenderedPixels {
    try #require(!drawn.isClose(to: blank))
    return drawn
  }

  /// Whether a line that hides the backdrop of ``GlassRenderProbeTests`` is
  /// between two rows that show it, in the column at `x`.
  ///
  /// - Parameters:
  ///   - pixels: The pixels of a view over the backdrop.
  ///   - x: The distance of the column from the leading edge, in points.
  /// - Returns: `true` when a row that does not show the backdrop is below a
  ///   row that shows it and above a different row that shows it.
  static func showsALineInTheBackdrop(_ pixels: RenderedPixels, atColumn x: CGFloat) -> Bool {
    let rows = stride(from: 0, to: size.height, by: ContentSurfaceHostedProbe.rowStep)
    let shows = rows.map { pixels.contains(GlassRenderProbeTests.backdrop, at: CGPoint(x: x, y: $0)) }
    guard let first = shows.firstIndex(of: true), let last = shows.lastIndex(of: true) else {
      return false
    }
    return shows[first...last].contains(false)
  }

  // D113: the header row of a code block, a terminal or a command output is
  // content, not a bar. It has no fill, and a separator line under it marks
  // it.

  @Test func theCodeBlockHeaderHasNoStatusBarBackground() throws {
    let pixels = try Self.pixels(of: CodeBlockView(code: "let x = 1", language: "swift"))
    #expect(!pixels.contains(Role.statusBarBackground))
    #expect(!pixels.contains(Role.terminalBackground))
  }

  @Test func aSeparatorLineIsUnderTheHeaderRow() throws {
    // A clear header row is above clear content, and the backdrop fills the
    // frame behind both. With no fill on the header, the backdrop shows in
    // the rows of the header and of the content. Only a line under the
    // header hides the backdrop between them. Clear content keeps the
    // EditorKit editor out of the check, because the cache of a window
    // shows the text area of the editor as an opaque color.
    let block = VStack(spacing: 0) {
      Self.clearBlock.editorBlockHeader()
      Self.clearBlock
    }
    let pixels = try Self.pixels(of: SurfaceWithBackdrop(content: block, placement: .behindToTheEdge))
    #expect(Self.showsALineInTheBackdrop(pixels, atColumn: Self.size.width / 2))
  }

  @Test(.hostedSerially) func theCodeBlockFrameHasNoEditorBackground() throws {
    // A code block has no fill (D113). `ImageRenderer` does not draw the
    // EditorKit editor, and the editor covers the frame below the header.
    // Thus this test reads the cache of a window, which draws the editor. The
    // editor draws no background of its own, so the editor background shows
    // only when the frame fills the block.
    let block = CodeBlockView(code: "let x = 1", language: "swift")
      .editorTheme(DistinctRolesTheme())
    let pixels = try GlassRenderProbeHostedTests.cachedPixels(of: block, size: Self.size)
    #expect(!pixels.contains(Role.editorBackground))
  }

  // D113: terminal output keeps the background of the terminal palette. The
  // background is terminal data, and the ANSI colors need it for contrast. A
  // code block has no fill. The next two tests hold this rule on the frames
  // themselves, with clear content, so only the frame can draw a fill.

  @Test func theTerminalFrameFillsTheBlockWithTheTerminalBackground() throws {
    let pixels = try Self.pixels(of: Self.clearBlock.terminalBlockFrame())
    #expect(pixels.contains(Role.terminalBackground))
  }

  @Test func theCodeBlockFrameFillsTheBlockWithNoThemeColor() throws {
    let pixels = try Self.pixels(of: Self.clearBlock.editorBlockFrame())
    #expect(!pixels.contains(Role.terminalBackground))
    #expect(!pixels.contains(Role.editorBackground))
  }

  @Test func withNoThemeTheCommandOutputDrawsNoRoleColor() throws {
    let view = CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode)
    let pixels = try #require(RenderedPixels(rendering: view, size: Self.size))
    #expect(!pixels.contains(Role.editorBackground))
    #expect(!pixels.contains(Role.statusBarBackground))
    #expect(!pixels.contains(Role.succeeded))
  }

  @Test func theCommandOutputFrameUsesTheTerminalBackgroundAndTheHeaderHasNoFill() throws {
    let pixels = try Self.pixels(
      of: CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode))
    #expect(pixels.contains(Role.terminalBackground))
    #expect(!pixels.contains(Role.editorBackground))
    #expect(!pixels.contains(Role.statusBarBackground))
  }

  @Test func aCommandThatCompletedShowsTheSucceededRole() throws {
    let pixels = try Self.pixels(
      of: CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode))
    #expect(pixels.contains(Role.succeeded))
    #expect(!pixels.contains(Role.failed))
  }

  @Test func aCommandThatFailedShowsTheFailedRole() throws {
    let pixels = try Self.pixels(
      of: CommandOutputView(command: "ls", output: "a", exitCode: Self.failureExitCode))
    #expect(pixels.contains(Role.failed))
    #expect(!pixels.contains(Role.succeeded))
  }

  @Test func theDiffCountsUseTheDiffTextColorsOfTheTheme() throws {
    let pixels = try Self.pixels(of: DiffView(patch: Self.patch))
    #expect(pixels.contains(Role.addedText))
    #expect(pixels.contains(Role.removedText))
    #expect(!pixels.contains(Role.added))
    #expect(!pixels.contains(Role.removed))
  }

  @Test func theCitationPillUsesTheAccentOfTheTheme() throws {
    let pixels = try Self.pixels(
      of: InlineCitation(index: 1).font(.system(size: Self.citationFontSize)))
    #expect(pixels.contains(Role.accent))
  }
}
