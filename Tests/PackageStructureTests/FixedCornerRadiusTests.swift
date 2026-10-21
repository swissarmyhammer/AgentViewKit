import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// Holds the kit library free of fixed corner radii (D110 (e)).
///
/// A shape inside a container must have concentric corners: its corner
/// follows the corner of the container. `AgentSurface.shape(radius:)` gives
/// such a shape, with the radius token as the smallest corner. A
/// `RoundedRectangle(cornerRadius:)`, an `UnevenRoundedRectangle(cornerRadius:)`
/// or a `.rect(cornerRadius:)` shape has a fixed corner, so the scan finds
/// each one. The scan reads each Swift file of the kit as text, one line at a
/// time.
@Suite struct FixedCornerRadiusTests {
  /// The pattern that finds a fixed corner radius: a rounded rectangle, an
  /// uneven rounded rectangle or a `.rect` shape that takes a corner radius.
  static var fixedCornerRadiusPattern: some RegexComponent {
    Regex {
      ChoiceOf {
        WordPattern.wholeWord("RoundedRectangle")
        WordPattern.wholeWord("UnevenRoundedRectangle")
        ".rect"
      }
      "(cornerRadius:"
    }
  }

  /// Finds the lines of a source that give a fixed corner radius.
  ///
  /// - Parameter line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line gives a fixed corner radius, or
  ///   no result.
  static func fixedCornerRadiusUses(on line: SourceLine) -> [String] {
    line.text.contains(fixedCornerRadiusPattern) ? ["\(line.file):\(line.number)"] : []
  }

  @Test func theScanFindsEachRoundedRectangleAndRectWithACornerRadius() {
    let source = """
      .background(.quaternary, in: RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous))
      .clipShape(.rect(cornerRadius: theme.radii.s))
      .background(.quaternary, in: AgentSurface.shape(radius: theme.radii.m))
      .clipShape(RoundedRectangle(cornerSize: size))
      .clipShape(UnevenRoundedRectangle(cornerRadius: theme.radii.s))
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.fixedCornerRadiusUses(on:))

    #expect(found == ["A.swift:1", "A.swift:2", "A.swift:5"])
  }

  @Test func noKitViewGivesAFixedCornerRadius() throws {
    let found = try SourceLineScanner.matches(
      inSwiftFilesBelow: PackageFiles.file(KitSourceFiles.kitPath), relativeTo: PackageFiles.root,
      match: Self.fixedCornerRadiusUses(on:))

    #expect(found.isEmpty, "Give each corner as AgentSurface.shape(radius:): \(found)")
  }
}
