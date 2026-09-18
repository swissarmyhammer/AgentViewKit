import AgentViewKit
import Foundation
import PackageFileSupport
import Testing

/// Checks that the R9 decision in `Docs/decisions/math-engine.md` agrees with
/// ``MathView/engineName`` and with the package manifest.
@Suite struct MathEngineDecisionTests {
  /// The decision file, relative to the package root.
  private static let decisionPath = "Docs/decisions/math-engine.md"

  /// The prefix of the line that states the engine.
  private static let enginePrefix = "engine:"

  /// The prefix of the line that states the exact version of the engine.
  private static let versionPrefix = "version:"

  /// The prefix of the line that states the URL of the engine package.
  private static let urlPrefix = "url:"

  /// The prefix of the paragraph that states the rule for a version change.
  private static let reviewPrefix = "review:"

  /// The heading of the section that names each SPI symbol of the engine.
  private static let spiHeading = "## The SPI symbols"

  /// The start of any other section of the decision file.
  private static let headingPrefix = "## "

  /// The import that a source file writes when it uses the SPI of the engine.
  private static let spiImport = "@_spi(Textual) import SwiftUIMath"

  /// The directory of the model and view target, relative to the package root.
  private static let kitSources = "Sources/AgentViewKit"

  /// The value of the one line in the decision file that starts with
  /// `prefix`.
  ///
  /// - Parameter prefix: The start of the line, such as `engine:`.
  /// - Returns: The text after the prefix, with no spaces and no backticks
  ///   at the ends.
  private static func lineValue(_ prefix: String) throws -> String {
    let text = try PackageFiles.text(of: decisionPath)
    let lines = text.split(separator: "\n").filter { $0.hasPrefix(prefix) }
    #expect(lines.count == 1, "The file must have exactly one \(prefix) line.")
    let line = try #require(lines.first)
    return line.dropFirst(prefix.count)
      .trimmingCharacters(in: .whitespaces)
      .trimmingCharacters(in: CharacterSet(charactersIn: "`"))
  }

  @Test func engineNameMatchesTheEngineLine() throws {
    #expect(try Self.lineValue(Self.enginePrefix) == MathView.engineName)
  }

  @Test func manifestPinsTheEngineToTheDecidedVersion() throws {
    let manifest = try PackageFiles.text(of: "Package.swift")
    let url = try Self.lineValue(Self.urlPrefix)
    let version = try Self.lineValue(Self.versionPrefix)
    #expect(manifest.contains(#".package(url: "\#(url)", exact: "\#(version)")"#))
    #expect(manifest.contains(#"package: "\#(MathView.engineName)")"#))
  }

  @Test func resolvedFilePinsTheEngineToTheDecidedVersion() throws {
    let version = try Self.lineValue(Self.versionPrefix)
    let data = try Data(contentsOf: PackageFiles.file("Package.resolved"))
    let resolved = try JSONDecoder().decode(ResolvedPins.self, from: data)
    let pin = try #require(resolved.pins.first { $0.identity == MathView.engineName })
    #expect(pin.state.version == version)
  }

  /// The paragraph of the decision file that starts with `prefix`.
  ///
  /// A paragraph ends at the first empty line.
  ///
  /// - Parameter prefix: The start of the first line, such as `review:`.
  /// - Returns: The lines of the paragraph, joined with one space.
  private static func paragraph(startingWith prefix: String) throws -> String {
    let text = try PackageFiles.text(of: decisionPath)
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    let starts = lines.indices.filter { lines[$0].hasPrefix(prefix) }
    #expect(starts.count == 1, "The file must have exactly one \(prefix) paragraph.")
    let start = try #require(starts.first)
    let end = lines[(start + 1)...].firstIndex { $0.isEmpty } ?? lines.endIndex
    return lines[start..<end].joined(separator: " ")
  }

  /// The text of the section that names each SPI symbol.
  ///
  /// - Returns: The heading and the body of the section, up to the next
  ///   heading.
  private static func spiSection() throws -> String {
    let text = try PackageFiles.text(of: decisionPath)
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    let start = try #require(
      lines.firstIndex { String($0) == spiHeading },
      "The file must have a \(spiHeading) section."
    )
    let end =
      lines[(start + 1)...].firstIndex { $0.hasPrefix(headingPrefix) } ?? lines.endIndex
    return lines[start..<end].joined(separator: "\n")
  }

  /// Each source file of the kit that imports the SPI of the engine.
  ///
  /// - Returns: The path of each file, relative to the package root, and the
  ///   text of the file. The list is sorted by path.
  private static func spiFiles() throws -> [(path: String, text: String)] {
    let rootPath = PackageFiles.root.path(percentEncoded: false)
    let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
    var files: [(path: String, text: String)] = []
    for url in try PackageFiles.swiftFiles(in: PackageFiles.file(kitSources)) {
      let text = try String(contentsOf: url, encoding: .utf8)
      guard text.contains(spiImport) else { continue }
      files.append((String(url.path(percentEncoded: false).dropFirst(prefix.count)), text))
    }
    return files.sorted { $0.path < $1.path }
  }

  /// Whether a match starts inside a longer name, such as `SwiftUIMath.`.
  ///
  /// - Parameters:
  ///   - range: The range of the match in `text`.
  ///   - text: The text of the match.
  /// - Returns: `true` when the character before the match is a letter, a
  ///   digit, or an underscore.
  private static func isInAName(_ range: Range<String.Index>, of text: String) -> Bool {
    guard range.lowerBound > text.startIndex else { return false }
    let before = text[text.index(before: range.lowerBound)]
    return before.isLetter || before.isNumber || before == "_"
  }

  @Test func theDecisionNamesEachFileThatImportsTheSPI() throws {
    let section = try Self.spiSection()
    let files = try Self.spiFiles()
    #expect(!files.isEmpty, "At least one file must import the SPI of the engine.")
    for file in files {
      #expect(section.contains(file.path), "The section must name \(file.path).")
    }
  }

  @Test func theDecisionNamesEachEngineSymbolThatTheKitUses() throws {
    let decision = try PackageFiles.text(of: Self.decisionPath)
    // A symbol of the engine, such as `Math.typographicBounds`.
    let symbol = /Math\.[A-Za-z_][A-Za-z0-9_]*/
    var symbols: Set<String> = []
    for file in try Self.spiFiles() {
      for match in file.text.matches(of: symbol) {
        guard !Self.isInAName(match.range, of: file.text) else { continue }
        symbols.insert(String(match.output))
      }
    }
    #expect(!symbols.isEmpty, "The kit must use at least one symbol of the engine.")
    for name in symbols.sorted() {
      #expect(
        decision.contains("`" + name),
        "The decision file must name \(name), as SPI or as public API."
      )
    }
  }

  @Test func theDecisionTellsAPersonToReadANewVersionBeforeThePinMoves() throws {
    let rule = try Self.paragraph(startingWith: Self.reviewPrefix)
    #expect(rule.contains("a person must read the SPI of the new version"))
    #expect(rule.contains("Package.swift"))
    #expect(rule.contains("Package.resolved"))
  }
}

/// The part of `Package.resolved` that ``MathEngineDecisionTests`` reads.
private struct ResolvedPins: Decodable {
  /// One resolved package.
  struct Pin: Decodable {
    /// The resolved state of one package.
    struct State: Decodable {
      /// The version tag, or `nil` for a branch or revision pin.
      let version: String?
    }

    /// The package identity, such as `swiftui-math`.
    let identity: String
    /// The resolved state.
    let state: State
  }

  /// The resolved packages.
  let pins: [Pin]
}
