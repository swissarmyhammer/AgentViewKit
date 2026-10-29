@testable import AgentViewKit
import AppKit
import EditorSwiftUI
import EditorTestSupport
import SwiftUI
import Testing

/// Checks that the kit views draw the colors of the EditorKit theme in the
/// environment: the frame and the header of an editor block, the status of a
/// command, the diff counts, and the accent.
///
/// Each test gives a view ``DistinctRolesTheme`` with `.editorTheme(_:)`,
/// shows it in a real window on the screen in the Light appearance, and looks
/// for the color of one role in the capture of the window from the window
/// server (EditorKit `CapturedImage`). No other part of the view draws that
/// color, so the color comes from the theme. The window server draws every
/// part of the view, the EditorKit editor included.
@Suite(.serialized, .hostedSerially) @MainActor struct EditorThemeViewsTests {
  /// The role colors of ``DistinctRolesTheme``.
  typealias Role = DistinctRolesTheme.Role

  /// The size that the tests show each view at.
  static let size = CGSize(width: 480, height: 240)

  /// The middle of the window.
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

  /// A block with clear content that fills the window. In a frame, only the
  /// fill of the frame and its edge draw a color.
  static var clearBlock: some View {
    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// The capture of `view` with ``DistinctRolesTheme`` as its EditorKit
  /// theme.
  ///
  /// - Parameter view: The view to show.
  /// - Returns: The image.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  static func capture(of view: some View) async throws -> CapturedImage {
    try await unthemedCapture(of: view.editorTheme(DistinctRolesTheme()))
  }

  /// The capture of `view` with the EditorKit theme of the environment: the
  /// default theme, not ``DistinctRolesTheme``.
  ///
  /// - Parameter view: The view to show.
  /// - Returns: The image.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  static func unthemedCapture(of view: some View) async throws -> CapturedImage {
    try await GlassRenderProbeTests.capture(of: view, size: size)
  }

  /// The capture of `view` from `capture`, after a check that the view draws
  /// something.
  ///
  /// A test that finds no pixel of a color must capture through this
  /// function. A view that draws nothing has no pixel of any color, so the
  /// test would pass for the wrong cause.
  ///
  /// - Parameters:
  ///   - view: The view to show.
  ///   - capture: The capture, for example ``capture(of:)`` or
  ///     ``unthemedCapture(of:)``. The check captures a clear view with it
  ///     too.
  /// - Returns: The image.
  /// - Throws: An error when the capture fails, or when the image is the same
  ///   as the image of a clear view.
  static func drawnCapture(
    of view: some View, using capture: @MainActor (AnyView) async throws -> CapturedImage = capture(of:)
  ) async throws -> CapturedImage {
    let drawn = try await capture(AnyView(view))
    let blank = try await capture(AnyView(Color.clear))
    try #require(drawn != blank)
    return drawn
  }

  /// Whether `image` holds a pixel of `color`.
  ///
  /// - Parameters:
  ///   - image: The capture.
  ///   - color: A fixed color, such as a role of ``DistinctRolesTheme``.
  /// - Returns: `true` when a pixel shows the color.
  /// - Throws: `CapturedImageError.pixelsUnreadable` when the color has no
  ///   sRGB form.
  static func contains(_ image: CapturedImage, _ color: Color) throws -> Bool {
    try image.contains(CaptureGeometry.cgColor(of: color))
  }

  /// The succeeded status color of the default EditorKit theme, resolved in
  /// light mode, so that a pixel of a capture in the Light appearance can
  /// match it.
  static var defaultThemeSucceededInLightMode: Color {
    defaultThemeSucceeded(in: .light)
  }

  /// The succeeded status color of the default EditorKit theme, resolved in
  /// `colorScheme`, so that a pixel of a capture in that scheme can match it.
  ///
  /// - Parameter colorScheme: The color scheme of the capture.
  /// - Returns: The resolved color, with no dynamic part.
  static func defaultThemeSucceeded(in colorScheme: ColorScheme) -> Color {
    var environment = EnvironmentValues()
    environment.colorScheme = colorScheme
    return Color(environment.editorTheme.statusSucceeded.resolve(in: environment))
  }

  /// Whether a line that hides the backdrop of ``GlassRenderProbeTests`` is
  /// between two rows that show it, in the column at `x`.
  ///
  /// - Parameters:
  ///   - image: The capture of a view over the backdrop.
  ///   - x: The distance of the column from the leading edge, in points.
  /// - Returns: `true` when a row that does not show the backdrop is below a
  ///   row that shows it and above a different row that shows it.
  /// - Throws: `CapturedImageError.pixelsUnreadable` when the color has no
  ///   sRGB form.
  static func showsALineInTheBackdrop(_ image: CapturedImage, atColumn x: CGFloat) throws -> Bool {
    let rows = stride(from: 0, to: size.height, by: ContentEdgeHostedProbe.rowStep)
    let shows = try rows.map { try GlassRenderProbeTests.showsBackdrop(image, at: CGPoint(x: x, y: $0)) }
    let first = try #require(shows.firstIndex(of: true), "No row shows the backdrop.")
    let last = try #require(shows.lastIndex(of: true), "No row shows the backdrop.")
    return shows[first...last].contains(false)
  }

  // D113: the header row of a code block, a terminal or a command output is
  // content, not a bar. It has no fill, and a separator line under it marks
  // it.

  @Test func theCodeBlockHeaderHasNoStatusBarBackground() async throws {
    // The backdrop fills the frame of the block, so it shows only when the
    // header row and the text area have no fill.
    let block = CodeBlockView(code: "let x = 1", language: "swift")
    let image = try await Self.drawnCapture(of: SurfaceWithBackdrop(content: block, placement: .behindToTheEdge))
    #expect(try Self.contains(image, GlassRenderProbeTests.backdrop))
    #expect(try !Self.contains(image, Role.statusBarBackground))
    #expect(try !Self.contains(image, Role.terminalBackground))
  }

  @Test func aSeparatorLineIsUnderTheHeaderRow() async throws {
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
    let image = try await Self.capture(of: SurfaceWithBackdrop(content: block, placement: .behindToTheEdge))
    #expect(try Self.showsALineInTheBackdrop(image, atColumn: Self.size.width / 2))
  }

  @Test func theTextAreaOfACodeBlockShowsTheContentBehindTheBlock() async throws {
    // A code block has no fill (D113), and EditorKit draws no background
    // behind its text (^0apj6a2, ^m231ph5). The backdrop fills the frame of
    // the block, so it shows in the text area only when no view fills the
    // text area.
    let block = CodeBlockView(code: "let x = 1", language: "swift")
      .editorTheme(DistinctRolesTheme())
    let mount = CaptureMount(SurfaceWithBackdrop(content: block, placement: .behindToTheEdge), size: Self.size)
    defer { mount.close() }
    let textView = try #require(firstView(ofType: NSTextView.self, in: mount.hostingView))
    // The capture starts at the top row, so the frame must count from the top.
    try #require(mount.hostingView.isFlipped)
    let textArea = mount.hostingView.convert(textView.bounds, from: textView)
    let pastTheCode = CGPoint(x: textArea.maxX - Self.textAreaProbeInset, y: textArea.midY)

    let image = try await mount.capture()

    #expect(try GlassRenderProbeTests.showsBackdrop(image, at: pastTheCode))
  }

  // D113: terminal output keeps the background of the terminal palette. The
  // background is terminal data, and the ANSI colors need it for contrast. A
  // code block has no fill. The next two tests hold this rule on the frames
  // themselves, with clear content, so only the frame can draw a fill.

  @Test func theTerminalFrameFillsTheBlockWithTheTerminalBackground() async throws {
    let image = try await Self.capture(of: Self.clearBlock.terminalBlockFrame())
    #expect(try Self.contains(image, Role.terminalBackground))
  }

  @Test func theCodeBlockFrameFillsTheBlockWithNoThemeColor() async throws {
    // The backdrop fills the frame behind clear content, so it shows in the
    // middle of the block only when the frame draws no fill there.
    let block = Self.clearBlock.editorBlockFrame()
    let image = try await Self.drawnCapture(of: SurfaceWithBackdrop(content: block, placement: .behindToTheEdge))
    #expect(try GlassRenderProbeTests.showsBackdrop(image, at: Self.center))
    #expect(try !Self.contains(image, Role.terminalBackground))
  }

  @Test func withNoThemeTheCommandOutputDrawsNoRoleColor() async throws {
    let view = CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode)
    let image = try await Self.drawnCapture(of: view, using: Self.unthemedCapture(of:))
    #expect(try Self.contains(image, Self.defaultThemeSucceededInLightMode))
    #expect(try !Self.contains(image, Role.statusBarBackground))
    #expect(try !Self.contains(image, Role.succeeded))
  }

  @Test func theCommandOutputFrameUsesTheTerminalBackgroundAndTheHeaderHasNoFill() async throws {
    let image = try await Self.capture(
      of: CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode))
    #expect(try Self.contains(image, Role.terminalBackground))
    #expect(try !Self.contains(image, Role.statusBarBackground))
  }

  @Test func aCommandThatCompletedShowsTheSucceededRole() async throws {
    let image = try await Self.capture(
      of: CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode))
    #expect(try Self.contains(image, Role.succeeded))
    #expect(try !Self.contains(image, Role.failed))
  }

  @Test func aCommandThatFailedShowsTheFailedRole() async throws {
    let image = try await Self.capture(
      of: CommandOutputView(command: "ls", output: "a", exitCode: Self.failureExitCode))
    #expect(try Self.contains(image, Role.failed))
    #expect(try !Self.contains(image, Role.succeeded))
  }

  @Test func theDiffCountsUseTheDiffTextColorsOfTheTheme() async throws {
    let image = try await Self.capture(of: DiffView(patch: Self.patch))
    #expect(try Self.contains(image, Role.addedText))
    #expect(try Self.contains(image, Role.removedText))
    #expect(try !Self.contains(image, Role.added))
    #expect(try !Self.contains(image, Role.removed))
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
  @Test func theCitationPillDigitsDoNotUseTheAccentOfTheTheme() async throws {
    let image = try await Self.drawnCapture(of: Self.citationPillOnWhite)
    // The capsule shows the accent of the theme, so the theme reaches the
    // pill, and the digits still draw no pixel of the accent.
    #expect(try Self.contains(image, Self.citationFillOverWhite()))
    #expect(try !Self.contains(image, Role.accent))
  }

  /// The capsule of a citation pill keeps the accent fill of the theme, the
  /// one permitted exception (shared style rule 1).
  @Test func theCitationPillFillUsesTheAccentOfTheTheme() async throws {
    let image = try await Self.drawnCapture(of: Self.citationPillOnWhite)
    #expect(try Self.contains(image, Self.citationFillOverWhite()))
  }
}
