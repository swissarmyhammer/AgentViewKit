import AgentViewKit
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

  /// The pixels of `view` with ``DistinctRolesTheme`` as its EditorKit theme.
  ///
  /// - Parameter view: The view to render.
  /// - Returns: The pixels.
  /// - Throws: An error when the renderer gives no pixels.
  static func pixels(of view: some View) throws -> RenderedPixels {
    try #require(RenderedPixels(rendering: view.editorTheme(DistinctRolesTheme()), size: size))
  }

  @Test func theCodeBlockBarUsesTheEditorTheme() throws {
    // The editor fills the body of the block, so the frame background shows
    // only in the command output test below. The two views use one frame.
    let pixels = try Self.pixels(of: CodeBlockView(code: "let x = 1", language: "swift"))
    #expect(pixels.contains(Role.statusBarBackground))
  }

  @Test func withNoThemeTheCommandOutputDrawsNoRoleColor() throws {
    let view = CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode)
    let pixels = try #require(RenderedPixels(rendering: view, size: Self.size))
    #expect(!pixels.contains(Role.editorBackground))
    #expect(!pixels.contains(Role.statusBarBackground))
    #expect(!pixels.contains(Role.succeeded))
  }

  @Test func theCommandOutputFrameAndBarUseTheEditorTheme() throws {
    let pixels = try Self.pixels(
      of: CommandOutputView(command: "ls", output: "a", exitCode: Self.successExitCode))
    #expect(pixels.contains(Role.editorBackground))
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

  @Test func theDiffCountsUseTheDiffColorsOfTheTheme() throws {
    let pixels = try Self.pixels(of: DiffView(patch: Self.patch))
    #expect(pixels.contains(Role.added))
    #expect(pixels.contains(Role.removed))
  }

  @Test func theCitationPillUsesTheAccentOfTheTheme() throws {
    let pixels = try Self.pixels(
      of: InlineCitation(index: 1).font(.system(size: Self.citationFontSize)))
    #expect(pixels.contains(Role.accent))
  }
}
