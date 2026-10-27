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

  /// The middle of the render size.
  static let center = CGPoint(x: size.width / 2, y: size.height / 2)

  /// The exit code of a command that completed.
  static let successExitCode = 0

  /// The exit code of a command that failed.
  static let failureExitCode = 1

  /// The font size of the citation pill, large so that the digit has many
  /// opaque pixels.
  static let citationFontSize: CGFloat = 48

  /// The distance from the trailing edge of the text area of a code block to
  /// the point that a test reads, in points: past the end of a short line of
  /// code, and inside the text area.
  static let textAreaProbeInset: CGFloat = 8

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
    try unthemedPixels(of: view.editorTheme(DistinctRolesTheme()))
  }

  /// The pixels of `view` with the EditorKit theme of the environment: the
  /// default theme, not ``DistinctRolesTheme``.
  ///
  /// - Parameter view: The view to render.
  /// - Returns: The pixels.
  /// - Throws: An error when the renderer gives no pixels.
  static func unthemedPixels(of view: some View) throws -> RenderedPixels {
    try #require(RenderedPixels(rendering: view, size: size))
  }

  /// The pixels of `view` in light mode, from `render`, after a check that
  /// the view draws something.
  ///
  /// A test that finds no pixel of a color must render through this
  /// function. A view that draws nothing has no pixel of any color, so the
  /// test would pass for the wrong cause.
  ///
  /// The function renders `view` first, so a test that calls it can be the
  /// first render of the test process.
  ///
  /// - Parameters:
  ///   - view: The view to render.
  ///   - render: The renderer, for example ``pixels(of:)`` or
  ///     ``cachedPixels(of:)``. The check renders a clear view with it too.
  /// - Returns: The pixels.
  /// - Throws: An error when `render` gives no pixels, or when the pixels are
  ///   the same as the pixels of a clear view.
  static func drawnPixels(
    of view: some View, using render: @MainActor (AnyView) throws -> RenderedPixels
  ) throws -> RenderedPixels {
    let drawn = try render(AnyView(view.environment(\.colorScheme, .light)))
    return try requireDrawn(drawn, blank: render(AnyView(Color.clear)))
  }

  /// The pixels of `view` in light mode with ``DistinctRolesTheme`` as its
  /// EditorKit theme, after a check that the view draws something. See
  /// ``drawnPixels(of:using:)``.
  ///
  /// - Parameter view: The view to render.
  /// - Returns: The pixels.
  /// - Throws: An error when the renderer gives no pixels, or when the pixels
  ///   are the same as the pixels of a clear view.
  static func drawnPixels(of view: some View) throws -> RenderedPixels {
    try drawnPixels(of: view, using: pixels(of:))
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
    try drawnPixels(of: view, using: cachedPixels(of:))
  }

  /// The succeeded status color of the default EditorKit theme, resolved in
  /// light mode, so that a pixel of a light-mode render can match it.
  static var defaultThemeSucceededInLightMode: Color {
    defaultThemeSucceeded(in: .light)
  }

  /// The succeeded status color of the default EditorKit theme, resolved in
  /// `colorScheme`, so that a pixel of a render in that scheme can match it.
  ///
  /// - Parameter colorScheme: The color scheme of the render.
  /// - Returns: The resolved color, with no dynamic part.
  static func defaultThemeSucceeded(in colorScheme: ColorScheme) -> Color {
    var environment = EnvironmentValues()
    environment.colorScheme = colorScheme
    return Color(environment.editorTheme.statusSucceeded.resolve(in: environment))
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
    let rows = stride(from: 0, to: size.height, by: ContentEdgeHostedProbe.rowStep)
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
    // `ImageRenderer` does not draw the EditorKit editor, so the header row
    // is the row of the block that draws. The backdrop fills the frame of the
    // block, so it shows only when the header row has no fill.
    let block = CodeBlockView(code: "let x = 1", language: "swift")
    let pixels = try Self.drawnPixels(of: SurfaceWithBackdrop(content: block, placement: .behindToTheEdge))
    #expect(pixels.contains(GlassRenderProbeTests.backdrop))
    #expect(!pixels.contains(Role.statusBarBackground))
    #expect(!pixels.contains(Role.terminalBackground))
  }

  @Test func aSeparatorLineIsUnderTheHeaderRow() throws {
    // A clear header row is above clear content, and the backdrop fills the
    // frame behind both. With no fill on the header, the backdrop shows in
    // the rows of the header and of the content. Only a line under the
    // header hides the backdrop between them. Clear content keeps the
    // EditorKit editor and its text out of the check, so only the header
    // row and its line can hide the backdrop.
    let block = VStack(spacing: 0) {
      Self.clearBlock.editorBlockHeader()
      Self.clearBlock
    }
    let pixels = try Self.pixels(of: SurfaceWithBackdrop(content: block, placement: .behindToTheEdge))
    #expect(Self.showsALineInTheBackdrop(pixels, atColumn: Self.size.width / 2))
  }

  @Test(.hostedSerially) func theTextAreaOfACodeBlockShowsTheContentBehindTheBlock() throws {
    // A code block has no fill (D113), and EditorKit draws no background
    // behind its text (^0apj6a2, ^m231ph5). `ImageRenderer` does not draw the
    // EditorKit editor, so this test reads the cache of a window. The
    // backdrop fills the frame of the block, so it shows in the text area
    // only when no view fills the text area.
    let block = CodeBlockView(code: "let x = 1", language: "swift")
      .editorTheme(DistinctRolesTheme())
    let harness = HostedViewHarness(SurfaceWithBackdrop(content: block, placement: .behindToTheEdge), size: Self.size)
    defer { harness.close() }
    let textView = try #require(harness.views(of: NSTextView.self).first)
    let pixels = try #require(RenderedPixels(cachingDisplayOf: harness.hostingView))
    // The pixels start at the top row, so the frame must count from the top.
    try #require(harness.hostingView.isFlipped)

    let textArea = harness.hostingView.convert(textView.bounds, from: textView)
    let pastTheCode = CGPoint(x: textArea.maxX - Self.textAreaProbeInset, y: textArea.midY)

    #expect(pixels.contains(GlassRenderProbeTests.backdrop, at: pastTheCode))
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
    // The backdrop fills the frame behind clear content, so it shows in the
    // middle of the block only when the frame draws no fill there.
    let block = Self.clearBlock.editorBlockFrame()
    let pixels = try Self.drawnPixels(of: SurfaceWithBackdrop(content: block, placement: .behindToTheEdge))
    #expect(pixels.contains(GlassRenderProbeTests.backdrop, at: Self.center))
    #expect(!pixels.contains(Role.terminalBackground))
  }

  @Test func withNoThemeTheCommandOutputDrawsNoRoleColor() throws {
    let view = CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode)
    let pixels = try Self.drawnPixels(of: view, using: Self.unthemedPixels(of:))
    #expect(pixels.contains(Self.defaultThemeSucceededInLightMode))
    #expect(!pixels.contains(Role.statusBarBackground))
    #expect(!pixels.contains(Role.succeeded))
  }

  @Test func theCommandOutputFrameUsesTheTerminalBackgroundAndTheHeaderHasNoFill() throws {
    let pixels = try Self.pixels(
      of: CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode))
    #expect(pixels.contains(Role.terminalBackground))
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

  /// The citation pill on an opaque white ground, so that its translucent
  /// fill draws opaque pixels.
  static var citationPillOnWhite: some View {
    InlineCitation(index: 1)
      .font(.system(size: citationFontSize))
      .background(Color.white)
  }

  /// The color of the capsule fill of the citation pill over white: the
  /// accent at ``InlineCitationPill/fillOpacity``, over white.
  ///
  /// - Returns: The color.
  /// - Throws: An error when the accent has no sRGB components.
  static func citationFillOverWhite() throws -> Color {
    let accent = try #require(NSColor(Role.accent).usingColorSpace(.sRGB))
    let opacity = InlineCitationPill.fillOpacity
    let overWhite = { (component: CGFloat) in Double(component) * opacity + (1 - opacity) }
    return Color(
      red: overWhite(accent.redComponent), green: overWhite(accent.greenComponent),
      blue: overWhite(accent.blueComponent))
  }

  /// The digits of a citation pill are not in the accent: the accent is only
  /// for the selection and the focus (card ^y2mrfxt).
  @Test func theCitationPillDigitsDoNotUseTheAccentOfTheTheme() throws {
    let pixels = try Self.drawnPixels(of: Self.citationPillOnWhite)
    // The capsule shows the accent of the theme, so the theme reaches the
    // pill, and the digits still draw no pixel of the accent.
    #expect(try pixels.contains(Self.citationFillOverWhite()))
    #expect(!pixels.contains(Role.accent))
  }

  /// The capsule of a citation pill keeps the accent fill of the theme, the
  /// one permitted exception (shared style rule 1).
  @Test func theCitationPillFillUsesTheAccentOfTheTheme() throws {
    let pixels = try Self.drawnPixels(of: Self.citationPillOnWhite)
    #expect(try pixels.contains(Self.citationFillOverWhite()))
  }
}
