import EditorTestSupport
import Foundation
import RegexBuilder
import Testing

/// Holds the views of the kit and of the examples to the font roles of the
/// EditorKit theme.
///
/// Each font of a kit view comes from a `FontRole` of the theme: the `ui`
/// role for the chrome, the `display` role for the prose and the text a
/// person types, and the `code` role for the code. A view reads a role at a
/// text style with `editorTheme.font(for: .ui, style: .caption)`, or at the
/// body text style with `uiFont`, `displayFont` or `codeFont`. A font that a
/// view picks for itself does not follow the theme: a fixed monospaced font,
/// such as `.body.monospaced()`, a font family that the view names, such as
/// `.custom("Menlo", size: 12)`, a design, such as `design: .serif`, a bare
/// system text style, such as `.font(.caption)` or
/// `NSFont.preferredFont(forTextStyle: .body)`, or a system font at a fixed
/// size, such as `.system(size: 10)` or `NSFont.systemFont(ofSize: 10)`. The
/// last two draw in the system font and not in the face of the `ui` role. A
/// view that needs a fixed size copies the face of a role and sets its
/// `size`. The scan finds each of these. The
/// digit form `.monospacedDigit()` keeps the current font, so the scan does
/// not find it. The scan reads each Swift file as text, one line at a time.
@Suite struct FontRoleTests {
  /// The pattern that finds a font that a view picks outside the roles: the
  /// monospaced design or modifier, a fixed-pitch system font of AppKit, a
  /// named font family of SwiftUI, AppKit or UIKit, a font design, a system
  /// font at a fixed size, a fixed-size font factory of AppKit or UIKit, or a
  /// bare system text style.
  ///
  /// The one text `Font(ofSize:` finds each fixed-size factory, such as
  /// `NSFont.systemFont(ofSize:)`, `boldSystemFont(ofSize:)`,
  /// `labelFont(ofSize:)` or `monospacedDigitSystemFont(ofSize:weight:)`. It
  /// does not find `image.thumbnail(ofSize:)` or `NSFont.systemFontSize(for:)`,
  /// which pick no font.
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
      ".system(size:"
      "Font(ofSize:"
      bareTextStylePattern
    }
  }

  /// The pattern that finds a bare system text style: a font that a view
  /// gives as a SwiftUI text style, such as `.font(.caption)`,
  /// `.font(.headline.weight(.semibold))`, `Font.callout` or
  /// `.system(.footnote)`, or as an AppKit or UIKit text style, such as
  /// `NSFont.preferredFont(forTextStyle: .body)`. A text style that a view
  /// passes to a role, such as `style: .caption`, is not bare.
  static var bareTextStylePattern: some RegexComponent {
    ChoiceOf {
      // A Unicode word boundary does not stand between `NSFont.` and
      // `preferredFont`, so the text has no boundary anchor.
      "preferredFont(forTextStyle:"
      swiftUITextStylePattern
    }
  }

  /// The pattern that finds a bare SwiftUI text style, such as
  /// `.font(.caption)` or `Font.callout`.
  static var swiftUITextStylePattern: some RegexComponent {
    Regex {
      ChoiceOf {
        ".font(."
        Regex {
          Anchor.wordBoundary
          "Font."
        }
        ".system(."
      }
      ChoiceOf {
        "largeTitle"
        "title"
        "title2"
        "title3"
        "headline"
        "subheadline"
        "body"
        "callout"
        "footnote"
        "caption"
        "caption2"
      }
      // The style name ends at a character that is not a word character. A
      // Unicode word boundary does not stand in `headline.weight`, so the
      // pattern reads the next character and not a boundary.
      NegativeLookahead {
        CharacterClass.word
      }
    }
  }

  /// Finds the lines of a source that pick a font outside the roles.
  ///
  /// - Parameter line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line picks a font outside the roles,
  ///   or no result.
  static func fontsOutsideTheRoles(on line: SourceLine) -> [String] {
    SourceLineScanner.uses(of: fontOutsideTheRolesPattern, on: line)
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
      .font(.caption)
      .font(.headline.weight(.semibold))
      .font(.caption2.monospacedDigit())
      .font(Font.callout)
      .font(.system(.footnote))
      .font(.title)
      .font(.system(size: digitSize, weight: .semibold))
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.fontsOutsideTheRoles(on:))

    #expect(found == (1...15).map { "A.swift:\($0)" })
  }

  @Test func theScanFindsEachFixedSizeFontFactoryOfAppKitAndUIKit() {
    let source = """
      NSFont.systemFont(ofSize: size)
      UIFont.systemFont(ofSize: size, weight: .semibold)
      NSFont.boldSystemFont(ofSize: size)
      UIFont.italicSystemFont(ofSize: size)
      NSFont.labelFont(ofSize: size)
      NSFont.menuFont(ofSize: size)
      NSFont.menuBarFont(ofSize: size)
      NSFont.messageFont(ofSize: size)
      NSFont.paletteFont(ofSize: size)
      NSFont.titleBarFont(ofSize: size)
      NSFont.toolTipsFont(ofSize: size)
      NSFont.controlContentFont(ofSize: size)
      NSFont.userFont(ofSize: size)
      NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold)
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.fontsOutsideTheRoles(on:))

    #expect(found == (1...14).map { "A.swift:\($0)" })
  }

  @Test func theTextStyleScanFindsAPreferredFontAtATextStyle() {
    let source = """
      NSFont.preferredFont(forTextStyle: .body)
      UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traits)
      """

    let found = SourceLineScanner.matches(inSource: source, file: "A.swift") { line in
      SourceLineScanner.uses(of: Self.bareTextStylePattern, on: line)
    }

    #expect(found == ["A.swift:1", "A.swift:2"])
  }

  @Test func theScanFindsNoThumbnailSizeOrSystemFontSize() {
    let source = """
      image.thumbnail(ofSize: size)
      NSFont.systemFontSize(for: .regular)
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.fontsOutsideTheRoles(on:))

    #expect(found.isEmpty)
  }

  @Test func theScanFindsNoRoleFontOrDigitForm() {
    let source = """
      .font(editorTheme.uiFont)
      .font(editorTheme.displayFont.weight(.semibold))
      .font(editorTheme.codeFont)
      .font(editorTheme.font(for: .code))
      .font(editorTheme.font(for: .ui, style: .caption))
      .font(editorTheme.font(for: .ui, style: .headline).weight(.semibold))
      .font(chromeFont(.callout))
      .font(editorTheme.font(for: .ui, style: .caption).monospacedDigit())
      .font(digitFace.font().weight(.semibold))
      .monospacedDigit()
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.fontsOutsideTheRoles(on:))

    #expect(found.isEmpty)
  }

  @Test func noViewPicksAFontOutsideTheRoles() throws {
    let found = try KitSourceFiles.scanViewFiles { directory in
      try SourceLineScanner.matches(
        inSwiftFilesBelow: directory, relativeTo: PackageFiles().root, match: Self.fontsOutsideTheRoles(on:))
    }

    #expect(
      found.isEmpty,
      "Use a font role of the EditorKit theme (editorTheme.font(for:style:), uiFont, displayFont, codeFont): \(found)")
  }
}
