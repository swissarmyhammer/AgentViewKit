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
