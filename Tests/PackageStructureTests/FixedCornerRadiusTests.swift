import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// Holds the kit library free of fixed and literal corner radii (D110 (e),
/// KanbanViewKit plan.md §5.1 decision 18).
///
/// A shape inside a container must have concentric corners: its corner
/// follows the corner of the container. `EditorSurface.shape(radius:)` of the
/// EditorKit `EditorStyle` target gives such a shape, with a radius of the
/// scale of `\.editorStyle` as the smallest corner. A
/// `RoundedRectangle(cornerRadius:)`, an `UnevenRoundedRectangle(cornerRadius:)`
/// or a `.rect(cornerRadius:)` shape has a fixed corner, and so does a
/// `.cornerRadius(_:)` modifier, so the scan finds each one. A kit view also
/// makes no `ConcentricRectangle` of its own, and gives no corner radius as a
/// number: each radius comes from the scale. The scans read each Swift file
/// of the kit as text, one line at a time.
@Suite struct FixedCornerRadiusTests {
  /// The pattern that finds a fixed corner radius: a rounded rectangle, an
  /// uneven rounded rectangle or a `.rect` shape that takes a corner radius,
  /// or a `.cornerRadius(` modifier with an argument of any form, such as a
  /// radius of the scale.
  static var fixedCornerRadiusPattern: some RegexComponent {
    ChoiceOf {
      Regex {
        ChoiceOf {
          WordPattern.wholeWord("RoundedRectangle")
          WordPattern.wholeWord("UnevenRoundedRectangle")
          ".rect"
        }
        "(cornerRadius:"
      }
      ".cornerRadius("
    }
  }

  /// The pattern that finds the start of a number literal, such as `6`,
  /// `-2` or `.5`.
  static var numberStart: Regex<Substring> {
    Regex {
      Optionally("-")
      Optionally(".")
      One(.digit)
    }
  }

  /// The pattern that finds a corner radius given as a number literal:
  /// - a number after a `radius:` or a `cornerRadius:` argument label, such as
  ///   `.inlineEdge(radius: 8)`.
  /// - a number in a `.cornerRadius(` call or in a `.fixed(` corner, such as
  ///   `.concentric(minimum: .fixed(6))`.
  /// - a number as the value of a name that holds a radius, such as
  ///   `static let radiusSmall: CGFloat = 6`.
  static var literalCornerRadiusPattern: Regex<Substring> {
    Regex {
      ChoiceOf {
        Regex {
          ChoiceOf {
            WordPattern.wholeWord("radius")
            WordPattern.wholeWord("cornerRadius")
          }
          ZeroOrMore(.whitespace)
          ":"
        }
        Regex {
          "."
          ChoiceOf {
            "cornerRadius"
            "fixed"
          }
          "("
        }
        Regex {
          ZeroOrMore(.word)
          ChoiceOf {
            "radius"
            "Radius"
          }
          ZeroOrMore(.word)
          Optionally {
            ZeroOrMore(.whitespace)
            ":"
            ZeroOrMore(.whitespace)
            OneOrMore(CharacterClass(.word, .anyOf(".?")))
          }
          ZeroOrMore(.whitespace)
          "="
        }
      }
      ZeroOrMore(.whitespace)
      numberStart
    }
  }

  /// The pattern that finds a concentric shape that a kit view makes itself,
  /// in place of `EditorSurface.shape(radius:)`.
  static var ownConcentricShapePattern: Regex<Substring> {
    WordPattern.wholeWord("ConcentricRectangle")
  }

  /// Finds the lines of a source that give a fixed corner radius.
  ///
  /// - Parameter line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line gives a fixed corner radius, or
  ///   no result.
  static func fixedCornerRadiusUses(on line: SourceLine) -> [String] {
    SourceLineScanner.uses(of: fixedCornerRadiusPattern, on: line)
  }

  /// Finds the lines of a source that give a corner radius as a number.
  ///
  /// - Parameter line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line gives a corner radius as a
  ///   number, or no result.
  static func literalCornerRadiusUses(on line: SourceLine) -> [String] {
    SourceLineScanner.uses(of: literalCornerRadiusPattern, on: line)
  }

  /// Finds the lines of a source that make a concentric shape.
  ///
  /// - Parameter line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line makes a `ConcentricRectangle`,
  ///   or no result.
  static func ownConcentricShapeUses(on line: SourceLine) -> [String] {
    SourceLineScanner.uses(of: ownConcentricShapePattern, on: line)
  }

  /// Runs a line scan over the code of the kit library, with the comments
  /// and the string literals blanked.
  ///
  /// - Parameter match: The function that finds the matches on one line.
  /// - Returns: `<file>:<line>` for each match.
  /// - Throws: The error of the scan when a file cannot be read.
  static func kitCodeMatches(_ match: (SourceLine) -> [String]) throws -> [String] {
    try SourceLineScanner.codeMatches(
      inSwiftFilesBelow: PackageFiles.file(KitSourceFiles.kitPath), relativeTo: PackageFiles.root, match: match)
  }

  @Test func theScanFindsEachRoundedRectangleAndRectWithACornerRadius() {
    let source = """
      .background(.quaternary, in: RoundedRectangle(cornerRadius: style.radii.m, style: .continuous))
      .clipShape(.rect(cornerRadius: style.radii.s))
      .background(.quaternary, in: EditorSurface.shape(radius: style.radii.m))
      .clipShape(RoundedRectangle(cornerSize: size))
      .clipShape(UnevenRoundedRectangle(cornerRadius: style.radii.s))
      .cornerRadius(style.radii.m)
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.fixedCornerRadiusUses(on:))

    #expect(found == ["A.swift:1", "A.swift:2", "A.swift:5", "A.swift:6"])
  }

  @Test func theScanFindsEachCornerRadiusGivenAsANumber() {
    let source = """
      .inlineEdge(radius: 8)
      .scopeFocusRing(cornerRadius: .5)
      ConcentricRectangle(corners: .concentric(minimum: .fixed(6)), isUniform: true)
      static let radiusSmall: CGFloat = 6
      .inlineEdge(radius: editorStyle.radii.m)
      let inset: CGFloat = 6
      EditorSurface.innerRadius(outer: editorStyle.radii.l, inset: 4)
      guard radius == 0 else { return }
      .cornerRadius(-2)
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.literalCornerRadiusUses(on:))

    #expect(found == ["A.swift:1", "A.swift:2", "A.swift:3", "A.swift:4", "A.swift:9"])
  }

  @Test func theScanFindsEachConcentricShapeOfItsOwn() {
    let source = """
      ConcentricRectangle(corners: .concentric(minimum: .fixed(radius)), isUniform: true)
      EditorSurface.shape(radius: editorStyle.radii.l)
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.ownConcentricShapeUses(on:))

    #expect(found == ["A.swift:1"])
  }

  @Test func noKitViewGivesAFixedCornerRadius() throws {
    let found = try Self.kitCodeMatches(Self.fixedCornerRadiusUses(on:))

    #expect(found.isEmpty, "Give each corner as EditorSurface.shape(radius:): \(found)")
  }

  @Test func noKitViewGivesACornerRadiusAsANumber() throws {
    let found = try Self.kitCodeMatches(Self.literalCornerRadiusUses(on:))

    #expect(found.isEmpty, "Read each corner radius from the radius scale of \\.editorStyle: \(found)")
  }

  @Test func noKitViewMakesAConcentricShapeOfItsOwn() throws {
    let found = try Self.kitCodeMatches(Self.ownConcentricShapeUses(on:))

    #expect(found.isEmpty, "Use EditorSurface.shape(radius:) of EditorStyle: \(found)")
  }
}
