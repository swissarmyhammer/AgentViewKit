import EditorTestSupport
import Foundation
import Testing

/// Checks the package manifest against plan.md §11 decision 1.
///
/// The test reads `Package.swift` as text. The manifest spells each library
/// product and each dependency product in full, so the text is the contract.
@Suite struct ManifestTests {
  /// The library products of the package (plan.md §11 decision 1): the kit,
  /// and its style, the shared look of the view kits, for a host; and the
  /// two test support products, for the nested integration package (§11
  /// decision 21).
  static let libraryProducts = ["AgentViewKit", "AgentViewKitStyle", "AgentViewKitTestSupport", "DemoSupport"]

  /// The ACP products that the `AgentViewKit` target links.
  static let acpProducts: Set<String> = [
    "FoundationModelsACP",
    "FoundationModelsACPClient",
  ]

  /// The packages that the kit does not depend on directly (plan.md §1).
  ///
  /// A Router agent reaches the kit through FoundationModelsACPAgent and ACP.
  /// FoundationModelsExtras stays in the package graph only as a dependency of
  /// FoundationModelsACPClient.
  static let removedPackages: Set<String> = [
    "FoundationModelsRouter",
    "FoundationModelsExtras",
  ]

  /// The name prefixes of the removed targets and their test targets: the
  /// Router target, and the ACP target that the kit target now holds.
  static let removedTargetPrefixes = ["AgentViewKitRouter", "AgentViewKitACP"]

  /// The EditorKit products that only the tests link: the recording command
  /// system, and the hosted window and accessibility helpers.
  static let editorKitTestSupportProducts: Set<String> = [
    "EditorCommandsTestSupport",
    "EditorTestSupport",
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
    "EditorTestSupport",
    "EditorComplete",
    "EditorDecorations",
    "EditorExtensions",
    "EditorDiff",
    "EditorStyle",
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
    manifest = try PackageFiles().text(of: "Package.swift")
  }

  @Test func declaresTheKitTheStyleAndTheTestSupportLibraryProducts() {
    let names = manifest.matches(of: /\.library\(\s*name:\s*"(?<name>[^"]+)"/).map { String($0.output.name) }
    #expect(names == Self.libraryProducts)
  }

  @Test func linksTheACPAndEditorKitProductsToTheKitTarget() throws {
    let products = try kitTargetProducts()
    let expected = Self.acpProducts.union(Self.editorKitProducts.subtracting(Self.editorKitTestSupportProducts))
    #expect(products.isSuperset(of: expected), "\(products)")
  }

  /// The kit test target links each EditorKit test support product, and the
  /// kit target links none of them.
  @Test func linksTheEditorKitTestSupportProductsToTheKitTestsOnly() throws {
    let testSupport = try Set(products(inArrayNamed: "editorKitTestSupportProducts"))
    #expect(testSupport == Self.editorKitTestSupportProducts)
    #expect(manifest.contains(/\+ acpProducts \+ editorKitTestSupportProducts,/))
    #expect(try kitTargetProducts().isDisjoint(with: Self.editorKitTestSupportProducts))
  }

  @Test func usesTheThirteenEditorKitProducts() {
    let names = manifest.matches(of: /\.product\(\s*name:\s*"(?<name>[^"]+)",\s*package:\s*"EditorKit"\s*\)/)
      .map { String($0.output.name) }
    #expect(Set(names) == Self.editorKitProducts)
  }

  @Test func linksTheEditorDiffProductToTheKit() {
    #expect(manifest.contains(#".product(name: "EditorDiff", package: "EditorKit")"#))
  }

  /// The test support target links the kit, the scripted agent of
  /// `DemoSupport` with the ACP products, for its session helper, and
  /// EditorKit `EditorTestSupport`, for the generic test helpers and the
  /// capture of a real window that the review gallery writes. It links no
  /// other target.
  @Test func declaresTheTestSupportTargetOnTheKitAndTheScriptedAgent() {
    let target =
      /\.target\(\s*name:\s*"AgentViewKitTestSupport",\s*dependencies:\s*\["AgentViewKit",\s*"DemoSupport"\]\s*\+\s*acpProducts\s*\+\s*styleTestSupportProducts,/
    #expect(manifest.contains(target))
  }

  /// The Objective-C window target of the old hosted view harness is gone:
  /// EditorKit's `CaptureWindow` catches the exception of a display cycle
  /// loop (`ExceptionCatchingPanel`).
  @Test func declaresNoHostedWindowSupportTarget() {
    #expect(!manifest.contains("HostedWindowSupport"))
  }

  @Test func linksTheTestSupportTargetFromTheKitTestTarget() {
    let declaration =
      /\.testTarget\(\s*name:\s*"AgentViewKitTests",\s*dependencies:\s*\[[^\]]*"AgentViewKitTestSupport"[^\]]*\]/
    #expect(manifest.contains(declaration))
  }

  @Test func pinsTheSiblingPackagesToMain() {
    for sibling in ["EditorKit", "FoundationModelsACP", "FoundationModelsACPClient"] {
      #expect(
        manifest.contains(#".package(url: "git@github.com:swissarmyhammer/\#(sibling).git", branch: "main")"#),
        "\(sibling) is not pinned to main"
      )
    }
  }

  /// The integration package depends on the root package by path, and names
  /// each other package with the URL and the pin of the root manifest, so
  /// that SwiftPM resolves one copy of each (plan.md §11 decision 21).
  @Test func theIntegrationPackageDependsOnTheRootByPathAndPinsAsTheRootDoes() throws {
    let integration = try PackageFiles().text(of: IntegrationPackage.manifestPath)
    let urlDependencies = integration.matches(of: /\.package\(url:[^\n]*\)/).map { String($0.output) }

    #expect(integration.contains(#".package(path: "..")"#))
    #expect(!urlDependencies.isEmpty)
    for dependency in urlDependencies {
      #expect(manifest.contains(dependency), "\(dependency) differs from the root manifest")
    }
  }

  @Test func declaresNoRouterOrExtrasPackage() {
    let packages = Set(
      manifest.matches(of: /\.package\(\s*url:\s*"[^"]*\/(?<name>[^"\/]+?)(?:\.git)?"/).map { String($0.output.name) }
    )
    #expect(packages.contains("EditorKit"), "The scan found no sibling package: \(packages)")
    #expect(packages.isDisjoint(with: Self.removedPackages), "\(packages)")
  }

  @Test func linksNoRouterOrExtrasProduct() {
    let packages = Set(manifest.matches(of: /package:\s*"(?<name>[^"]+)"/).map { String($0.output.name) })
    #expect(packages.contains("EditorKit"), "The scan found no product dependency: \(packages)")
    #expect(packages.isDisjoint(with: Self.removedPackages), "\(packages)")
  }

  @Test func declaresNoRemovedTarget() {
    let names = manifest.matches(of: /"(?<name>[^"\n]+)"/).map { String($0.output.name) }
    #expect(names.contains("AgentViewKit"), "The scan found no quoted name")
    for prefix in Self.removedTargetPrefixes {
      #expect(!names.contains { $0.hasPrefix(prefix) }, "\(prefix): \(names)")
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
    let data = try Data(contentsOf: PackageFiles().file("Package.resolved"))
    let resolved = try JSONDecoder().decode(ResolvedFile.self, from: data)
    let pin = try #require(resolved.pins.first { $0.identity == "textual" })
    #expect(pin.state.version == textual.version)
  }

  /// The dependency products of the `AgentViewKit` target.
  ///
  /// The target lists its dependencies as a sum of named arrays, such as
  /// `editorKitProducts + acpProducts`, after the literal array of its
  /// target dependency, `["AgentViewKitStyle"]`. The function reads the
  /// declaration of each named array and returns the product names in it.
  func kitTargetProducts() throws -> Set<String> {
    let target = /\.target\(\s*name:\s*"AgentViewKit",\s*dependencies:\s*(?<arrays>[^,\n]+),/
    let match = try #require(manifest.firstMatch(of: target))
    let arrayNames = match.output.arrays.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.hasPrefix("[") }
    return try Set(arrayNames.flatMap { try products(inArrayNamed: $0) })
  }

  /// The product names in one dependency array of the manifest.
  ///
  /// - Parameter name: The name of a `let <name>: [Target.Dependency]` array.
  /// - Returns: The name of each `.product(name:package:)` in the array.
  func products(inArrayNamed name: String) throws -> [String] {
    let declaration = try Regex(#"let \#(name): \[Target\.Dependency\] = \[(?<body>[^\]]*)\]"#)
    let match = try #require(manifest.firstMatch(of: declaration), "No array named \(name)")
    let body = try #require(match["body"]?.substring)
    return body.matches(of: /\.product\(\s*name:\s*"(?<name>[^"]+)"/).map { String($0.output.name) }
  }

  /// Reads the Textual row from `Docs/decisions/dependencies.md`.
  ///
  /// The row has the form `| textual | <url> | exact <version> | `<product>` |`.
  static func textualDecision() throws -> TextualDecision {
    let decisions = try PackageFiles().text(of: "Docs/decisions/dependencies.md")
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
  struct Pin: Decodable, Equatable {
    /// The resolved state of one package.
    struct State: Decodable, Equatable {
      /// The version tag, or `nil` for a branch or revision pin.
      let version: String?

      /// The branch that the manifest follows, or `nil` for a version pin.
      let branch: String?

      /// The resolved commit.
      let revision: String
    }

    /// The package identity, such as `textual`.
    let identity: String
    /// The resolved state.
    let state: State
  }

  /// The resolved packages.
  let pins: [Pin]
}
