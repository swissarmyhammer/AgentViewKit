import EditorTestSupport
import Foundation
import Testing

/// A view that must show only in one bar of a file, and the start of the
/// block that is that bar.
struct BarView: CustomTestStringConvertible, Sendable {
  /// The file that shows the view, relative to the package root.
  let file: String

  /// The name of the view type, such as `StateBanner`.
  let view: String

  /// The code text before the opening brace of the bar block, such as
  /// `var floatingControls` or `.safeAreaBar(edge: .top)`.
  let barStart: String

  var testDescription: String { "\(file) \(view)" }
}

/// Checks that the banner and the login prompt of a thread are in the bottom
/// bar (EditorKit `style.md`, "Scroll under the bars", D113 answer
/// 7).
///
/// The list of a view scrolls under its bars. A banner or a prompt next to a
/// bar is in the same `.safeAreaBar(edge:)`, not between the list and the
/// bar. In ``AgentThreadView``, the bottom bar is its floating controls. A
/// ``ConversationView`` alone puts its state banner in its own bottom bar.
///
/// The scan blanks the comments and the string literals of each file, then
/// finds the block of the bar with ``balancedBody(in:from:)``.
@Suite struct ThreadBottomBarStructureTests {
  /// The code text before the opening brace of the content of the bottom bar
  /// of a thread: the floating controls of ``AgentThreadView``.
  static let floatingControlsStart = "var floatingControls"

  /// Each view that shows only in the bottom bar of its file.
  static let bottomBarViews = [
    BarView(
      file: ComposerGlassStructureTests.threadFile, view: "StateBanner", barStart: floatingControlsStart),
    BarView(
      file: ComposerGlassStructureTests.threadFile, view: "AgentLoginPrompt", barStart: floatingControlsStart),
    BarView(
      file: KitSourceFiles.kitFile("Thread/ConversationView.swift"), view: "StateBanner",
      barStart: ".safeAreaBar(edge: .bottom)"),
  ]

  /// The code of a file, with each comment and each string literal blanked.
  ///
  /// - Parameter file: The file, relative to the package root.
  /// - Returns: The code text.
  /// - Throws: An error when the file cannot be read.
  static func code(of file: String) throws -> String {
    let text = try String(contentsOf: PackageFiles().file(file), encoding: .utf8)
    return String(decoding: SwiftLiteralLexer.blankingCommentsAndLiterals(in: Array(text.utf8)), as: UTF8.self)
  }

  /// The text of the first block after `start` in `code`: the text between
  /// the first opening brace after `start` and the brace that closes it.
  ///
  /// - Parameters:
  ///   - start: The code text before the block.
  ///   - code: The code of a file.
  /// - Returns: The text of the block, or `nil` when `code` has no such block.
  static func block(after start: String, in code: String) -> Substring? {
    guard let range = code.range(of: start), let open = code[range.upperBound...].firstIndex(of: "{") else {
      return nil
    }
    return balancedBody(in: code, from: open)
  }

  /// Finds the text inside a pair of braces.
  ///
  /// - Parameters:
  ///   - source: The text that holds the braces.
  ///   - open: The index of the opening brace.
  /// - Returns: The text between the opening brace and the brace that closes
  ///   it, or `nil` when no brace closes it.
  static func balancedBody(in source: String, from open: String.Index) -> Substring? {
    var depth = 0
    for index in source[open...].indices {
      switch source[index] {
      case "{": depth += 1
      case "}":
        depth -= 1
        if depth == 0 { return source[source.index(after: open)..<index] }
      default: break
      }
    }
    return nil
  }

  /// Expects that the file of `place` calls its view one time, and only in
  /// the bar of `place`.
  ///
  /// - Parameter place: The view and its bar.
  /// - Throws: An error when the file cannot be read, or an issue when the
  ///   file has no bar block.
  static func expectOnlyInItsBar(_ place: BarView) throws {
    let code = try Self.code(of: place.file)
    let bar = try #require(Self.block(after: place.barStart, in: code))
    let call = GlassForm.callPattern(place.view)

    let usesInBar = bar.matches(of: call).count

    #expect(usesInBar == 1, "\(place.view) is not in the bar \(place.barStart) of \(place.file)")
    #expect(
      code.matches(of: call).count == usesInBar, "\(place.view) is outside the bar \(place.barStart) of \(place.file)")
  }

  @Test(arguments: bottomBarViews)
  func eachViewNextToTheBottomBarIsOnlyInThatBar(_ place: BarView) throws {
    try Self.expectOnlyInItsBar(place)
  }
}
