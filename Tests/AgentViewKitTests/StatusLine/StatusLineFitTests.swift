import AgentViewKitTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The `directory` module shows the widest form of its path that fits the
/// width that the line gives to it (^mqxwh36).
///
/// Each test measures the views in a hosting controller with no window, so
/// no test shows a window or takes the focus.
@MainActor @Suite struct StatusLineFitTests {
  /// A working folder with one long middle name, so that each form has a
  /// different width.
  static let cwd = "/Users/me/Engineering/Applications/Sources/App"

  /// The rendered piece of the `directory` module.
  static func directoryPiece() throws -> StatusLinePiece {
    let input = StatusLineInput(cwd: cwd, homeFolder: "/Users/me")
    let line = StatusLineRenderer.render(StatusLines.defaultDefinition, input: input)
    return try #require(line.pieces.first { $0.module == .directory })
  }

  /// The ideal width of each form of a piece, from the widest form.
  static func formWidths(of piece: StatusLinePiece) -> [CGFloat] {
    ([piece.spans] + piece.narrowerSpans).map { StyleViewHost.fittingSize(of: StatusLineText(spans: $0)).width }
  }

  /// A production change that fails this test: the module shows only the
  /// whole path, which the line then cuts at its end.
  @Test func narrowWidthShowsTheWidestFormThatFits() throws {
    let piece = try Self.directoryPiece()
    let widths = Self.formWidths(of: piece)
    let secondWidth = try #require(widths.dropFirst().first)

    let shown = StyleViewHost.size(of: StatusLinePieceText(piece: piece), proposedWidth: secondWidth + 1)

    #expect(shown.width == secondWidth)
  }

  /// A production change that fails this test: the module removes a name
  /// when the whole path fits.
  @Test func wideWidthShowsTheWholePath() throws {
    let piece = try Self.directoryPiece()
    let wholeWidth = try #require(Self.formWidths(of: piece).first)

    let shown = StyleViewHost.size(of: StatusLinePieceText(piece: piece), proposedWidth: wholeWidth + 1)

    #expect(shown.width == wholeWidth)
  }
}
