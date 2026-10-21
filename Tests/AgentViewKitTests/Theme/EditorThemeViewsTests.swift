@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import SwiftUI
import Testing

/// Checks that the kit views draw the colors of the EditorKit theme in the
/// environment: the frame and the bar of an editor block, the status of a
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

  @Test func theCodeBlockBarUsesTheEditorTheme() throws {
    let pixels = try Self.pixels(of: CodeBlockView(code: "let x = 1", language: "swift"))
    #expect(pixels.contains(Role.statusBarBackground))
    #expect(!pixels.contains(Role.terminalBackground))
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

  @Test func theCommandOutputFrameUsesTheTerminalBackgroundAndTheBarUsesTheEditorTheme() throws {
    let pixels = try Self.pixels(
      of: CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode))
    #expect(pixels.contains(Role.terminalBackground))
    #expect(!pixels.contains(Role.editorBackground))
    #expect(pixels.contains(Role.statusBarBackground))
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
