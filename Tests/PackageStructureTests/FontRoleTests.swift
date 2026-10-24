import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// Holds the views of the kit and of the examples to the font roles of the
/// EditorKit theme.
///
/// Each font of a kit view comes from a `FontRole` of the theme: `uiFont` for
/// the chrome, `displayFont` for the prose and the text a person types, and
/// `codeFont` for the code. A font that a view picks for itself does not
/// follow the theme: a fixed monospaced font, such as `.body.monospaced()`, a
/// font family that the view names, such as `.custom("Menlo", size: 12)`, or
/// a design, such as `design: .serif`. The scan finds each of these. A system
/// text style, such as `.caption`, picks a size and no font, so the scan does
/// not find it. The digit form `.monospacedDigit()` keeps the current font,
/// so the scan does not find it either. The scan reads each Swift file as
/// text, one line at a time.
@Suite struct FontRoleTests {
  /// The pattern that finds a font that a view picks outside the roles: the
  /// monospaced design or modifier, a fixed-pitch system font of AppKit, a
  /// named font family of SwiftUI, AppKit or UIKit, or a font design.
  static var fontOutsideTheRolesPattern: some RegexComponent {
    ChoiceOf {
      Regex {
        "."
        ChoiceOf {
          "monospaced"
          "monospacedSystemFont"
          "userFixedPitchFont"
        }
        Anchor.wordBoundary
      }
      ".custom("
      "NSFont(name:"
      "UIFont(name:"
      "design:"
      ".fontDesign("
    }
  }

  /// Finds the lines of a source that pick a font outside the roles.
  ///
  /// - Parameter line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line picks a font outside the roles,
  ///   or no result.
  static func fontsOutsideTheRoles(on line: SourceLine) -> [String] {
    line.text.contains(fontOutsideTheRolesPattern) ? ["\(line.file):\(line.number)"] : []
  }

  @Test func theScanFindsEachFontThatAViewPicksOutsideTheRoles() {
    let source = """
      .font(.body.monospaced())
      .font(.system(size: size, design: .monospaced))
      NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
      .font(.custom("Menlo", size: size))
      NSFont(name: "Menlo", size: size)
      UIFont(name: "Menlo", size: size)
      .font(.system(.body, design: .serif))
      .fontDesign(.rounded)
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.fontsOutsideTheRoles(on:))

    #expect(found == (1...8).map { "A.swift:\($0)" })
  }

  @Test func theScanFindsNoRoleTextStyleOrDigitForm() {
    let source = """
      .font(editorTheme.uiFont)
      .font(editorTheme.displayFont.weight(.semibold))
      .font(editorTheme.codeFont)
      .font(editorTheme.font(for: .code))
      .font(.caption)
      .monospacedDigit()
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.fontsOutsideTheRoles(on:))

    #expect(found.isEmpty)
  }

  @Test func noViewPicksAFontOutsideTheRoles() throws {
    let found = try KitSourceFiles.scanViewFiles { directory in
      try SourceLineScanner.matches(
        inSwiftFilesBelow: directory, relativeTo: PackageFiles.root, match: Self.fontsOutsideTheRoles(on:))
    }

    #expect(found.isEmpty, "Use a font role of the EditorKit theme (uiFont, displayFont, codeFont): \(found)")
  }
}
