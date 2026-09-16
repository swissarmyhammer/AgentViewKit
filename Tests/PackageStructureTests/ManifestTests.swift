import Foundation
import Testing

/// Checks the package manifest against plan.md §11 decision 1.
///
/// The test reads `Package.swift` as text. The manifest spells each library
/// product and each dependency product in full, so the text is the contract.
@Suite struct ManifestTests {
  /// The library products of the package.
  static let libraryProducts: Set<String> = [
    "AgentViewKit",
    "AgentViewKitFoundationModels",
    "AgentViewKitRouter",
    "AgentViewKitACP",
  ]

  /// The EditorKit products that the package uses.
  static let editorKitProducts: Set<String> = [
    "EditorSwiftUI",
    "EditorCore",
    "EditorText",
    "EditorTheme",
    "EditorCommands",
    "EditorCommandsUI",
    "EditorCommandsTestSupport",
    "EditorComplete",
    "EditorDecorations",
  ]

  /// The Textual row of `Docs/decisions/dependencies.md`.
  struct TextualDecision {
    /// The URL of the Textual repository.
    let url: String
    /// The exact version that the package pins.
    let version: String
    /// The library product name that Textual declares.
    let product: String
  }

  /// The `Package.swift` text.
  let manifest: String

  init() throws {
    manifest = try PackageRoot.text(of: "Package.swift")
  }

  @Test func declaresTheFourLibraryProducts() {
    let names = manifest.matches(of: /\.library\(\s*name:\s*"(?<name>[^"]+)"/).map { String($0.output.name) }
    #expect(Set(names) == Self.libraryProducts)
    #expect(names.count == Self.libraryProducts.count)
  }

  @Test func usesTheNineEditorKitProducts() {
    let names = manifest.matches(of: /\.product\(\s*name:\s*"(?<name>[^"]+)",\s*package:\s*"EditorKit"\s*\)/)
      .map { String($0.output.name) }
    #expect(Set(names) == Self.editorKitProducts)
  }

  @Test func pinsTheSiblingPackagesToMain() {
    for sibling in ["EditorKit", "FoundationModelsACP", "FoundationModelsACPClient", "FoundationModelsRouter", "FoundationModelsExtras"] {
      #expect(
        manifest.contains(#".package(url: "git@github.com:swissarmyhammer/\#(sibling).git", branch: "main")"#),
        "\(sibling) is not pinned to main"
      )
    }
  }

  @Test func setsTheMacOS27FloorAndNoOtherPlatform() {
    #expect(manifest.contains(/platforms:\s*\[\s*\.macOS\("27\.0"\),?\s*\]/))
  }

  @Test func usesTheTextualProductNamedInTheDependencyDecision() throws {
    let textual = try Self.textualDecision()
    #expect(manifest.contains(#".package(url: "\#(textual.url)", exact: "\#(textual.version)")"#))
    #expect(manifest.contains(#".product(name: "\#(textual.product)", package: "textual")"#))
  }

  @Test func resolvesTextualAtTheDecidedVersion() throws {
    let textual = try Self.textualDecision()
    let data = try Data(contentsOf: PackageRoot.file("Package.resolved"))
    let resolved = try JSONDecoder().decode(ResolvedFile.self, from: data)
    let pin = try #require(resolved.pins.first { $0.identity == "textual" })
    #expect(pin.state.version == textual.version)
  }

  /// Reads the Textual row from `Docs/decisions/dependencies.md`.
  ///
  /// The row has the form `| textual | <url> | exact <version> | `<product>` |`.
  static func textualDecision() throws -> TextualDecision {
    let decisions = try PackageRoot.text(of: "Docs/decisions/dependencies.md")
    let row = /\|\s*textual\s*\|\s*(?<url>[^|\s]+)\s*\|\s*exact\s+(?<version>[^|\s]+)\s*\|\s*`(?<product>[^`]+)`\s*\|/
    let match = try #require(decisions.firstMatch(of: row))
    return TextualDecision(
      url: String(match.output.url),
      version: String(match.output.version),
      product: String(match.output.product)
    )
  }
}

/// The part of `Package.resolved` that the tests read.
struct ResolvedFile: Decodable {
  /// One resolved package.
  struct Pin: Decodable {
    /// The resolved state of one package.
    struct State: Decodable {
      /// The version tag, or `nil` for a branch or revision pin.
      let version: String?
    }

    /// The package identity, such as `textual`.
    let identity: String
    /// The resolved state.
    let state: State
  }

  /// The resolved packages.
  let pins: [Pin]
}
