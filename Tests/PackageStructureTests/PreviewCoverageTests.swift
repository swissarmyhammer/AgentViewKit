import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// One public view type of a Swift file.
struct PublicViewDeclaration: Equatable, CustomStringConvertible {
  /// The file that declares the view, relative to the package root.
  let file: String
  /// The name of the view type.
  let name: String

  var description: String { "\(file): \(name)" }
}

/// Holds a `#Preview` for each public view of `Sources`.
///
/// Each public type that conforms to `View` has a `#Preview` in its own file,
/// and the body of that preview names the type. The scan reads each Swift
/// file as text.
@Suite struct PreviewCoverageTests {
  /// The directory of the Swift files that the scan reads, relative to the
  /// package root.
  static let sourcesPath = "Sources"

  /// The macro that starts a preview.
  static let previewMacro = "#Preview"

  /// The pattern of the declaration of a public structure or class: the name,
  /// then a generic clause or none, then the list of the conformances up to
  /// the opening brace.
  static var declarationPattern: Regex<(Substring, name: Substring, conformances: Substring)> {
    #/public\s+(?:final\s+)?(?:struct|class)\s+(?<name>\w+)(?:<[^>{]*>)?\s*:(?<conformances>[^{]*)\{/#
  }

  /// The pattern of the `where` clause after a list of conformances.
  static var whereClausePattern: Regex<Substring> { #/\bwhere\b.*/# }

  /// Finds the public view types that a source declares.
  ///
  /// A view type is a public structure or class with `View` in its list of
  /// conformances. A generic constraint such as `<Content: View>` is not a
  /// conformance of the type.
  ///
  /// - Parameter source: The text of a Swift file.
  /// - Returns: The names of the view types, in source order.
  static func publicViewNames(in source: String) -> [String] {
    source.matches(of: declarationPattern).compactMap { match in
      let conformances = match.output.conformances.replacing(whereClausePattern, with: "")
      let names = conformances.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      return names.contains("View") ? String(match.output.name) : nil
    }
  }

  /// Finds the body of each `#Preview` of a source: the text between the
  /// first opening brace after the macro and the brace that closes it.
  ///
  /// - Parameter source: The text of a Swift file.
  /// - Returns: The bodies, in source order. A preview with no closed body
  ///   gives no result.
  static func previewBodies(in source: String) -> [Substring] {
    source.ranges(of: previewMacro).compactMap { macro in
      guard let open = source[macro.upperBound...].firstIndex(of: "{") else { return nil }
      return balancedBody(in: source, from: open)
    }
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

  /// Finds the public views of a file that no `#Preview` of the file names.
  ///
  /// - Parameters:
  ///   - source: The text of a Swift file.
  ///   - file: The path of the file, for the result.
  /// - Returns: The views with no preview, in source order.
  static func viewsWithNoPreview(in source: String, file: String) -> [PublicViewDeclaration] {
    let bodies = previewBodies(in: source)
    return publicViewNames(in: source)
      .filter { name in !bodies.contains { $0.contains(wordPattern(name)) } }
      .map { PublicViewDeclaration(file: file, name: $0) }
  }

  /// The pattern of a whole word.
  ///
  /// - Parameter word: The word.
  /// - Returns: The pattern that finds `word` with a word boundary on each
  ///   side.
  static func wordPattern(_ word: String) -> Regex<Substring> {
    Regex {
      Anchor.wordBoundary
      word
      Anchor.wordBoundary
    }
  }

  // MARK: - The scan

  @Test func theScanFindsAPublicViewAndNotAGenericConstraint() {
    let source = """
      public struct PlainView: View {
      public struct GenericView<Content: View>: View where Content: Sendable {
      public struct Marked: View, Equatable {
      public final class Harness<Content: View> {
      public struct Value: Sendable {
      struct InternalView: View {
      """

    #expect(Self.publicViewNames(in: source) == ["PlainView", "GenericView", "Marked"])
  }

  @Test func theScanFindsTheBodyOfEachPreview() {
    let source = """
      #Preview {
        PlainView { Text("A") }
      }
      #Preview("Named") { Marked() }
      """

    #expect(Self.previewBodies(in: source).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      == [#"PlainView { Text("A") }"#, "Marked()"])
  }

  @Test func aViewThatNoPreviewNamesHasNoPreview() {
    let source = """
      public struct PlainView: View {}
      public struct PlainViewRow: View {}
      #Preview { PlainViewRow() }
      """

    #expect(
      Self.viewsWithNoPreview(in: source, file: "A.swift")
        == [PublicViewDeclaration(file: "A.swift", name: "PlainView")])
  }

  // MARK: - The sources

  @Test func eachPublicViewOfTheSourcesHasAPreviewInItsFile() throws {
    let files = try PackageFiles.swiftFileTexts(
      below: PackageFiles.file(Self.sourcesPath), relativeTo: PackageFiles.root)

    let views = files.flatMap { Self.publicViewNames(in: $0.text) }
    let missing = files.flatMap { Self.viewsWithNoPreview(in: $0.text, file: $0.path) }

    #expect(!views.isEmpty)
    #expect(missing.isEmpty, "Add a #Preview that shows the view to its file: \(missing)")
  }
}
