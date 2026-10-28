import Foundation
import PackageFileSupport
import Testing

/// Proves that the dependency closure of the `AgentViewKitStyle` product holds
/// no ACP package, no Textual and no math engine.
///
/// KanbanViewKit and SnapshotViewKit link only this product, and their
/// manifest tests forbid each ACP package. The proof has two steps. First,
/// the style target links only EditorKit products and no target of this
/// package. Second, the walk of the package manifests that SwiftPM resolved,
/// from EditorKit down, reaches no forbidden package.
@Suite struct AgentViewKitStyleClosureTests {
  /// The name of the style target and product.
  static let styleTarget = "AgentViewKitStyle"

  /// The one package that the style target links products of.
  static let editorKitPackage = "EditorKit"

  /// The start of the name of each ACP package: the wire types, the client
  /// and the agent.
  static let acpNamePrefix = "FoundationModelsACP"

  /// The packages of the kit that the style closure must not hold beside
  /// the ACP packages: the Markdown renderer and the math engine.
  static let forbiddenPackages: Set<String> = ["textual", "swiftui-math"]

  /// The directory of the resolved package checkouts, relative to the
  /// package root.
  static let checkoutsPath = ".build/checkouts"

  /// The `Package.swift` text.
  let manifest: String

  init() throws {
    manifest = try PackageFiles.text(of: "Package.swift")
  }

  @Test func declaresTheStyleProduct() {
    #expect(manifest.contains(#".library(name: "AgentViewKitStyle", targets: ["AgentViewKitStyle"])"#))
  }

  @Test func theStyleTargetLinksOnlyEditorKitProducts() throws {
    let dependencies = try styleTargetDependencies()
    let packages = dependencies.flatMap { $0.matches(of: /package:\s*"(?<name>[^"]+)"/).map { String($0.output.name) } }

    #expect(!packages.isEmpty)
    #expect(Set(packages) == [Self.editorKitPackage], "\(packages)")
  }

  @Test func theStyleTargetLinksNoTargetOfThePackage() throws {
    let bodies = try styleTargetDependencies()
    let targets = bodies.flatMap { body in
      body.replacing(/\.product\([^)]*\)/, with: "").matches(of: /"(?<name>[^"]+)"/).map { String($0.output.name) }
    }

    #expect(targets.isEmpty, "\(targets)")
  }

  @Test func theKitTargetLinksTheStyleTarget() {
    #expect(manifest.contains(/\.target\(\s*name:\s*"AgentViewKit",\s*dependencies:\s*\["AgentViewKitStyle"\]/))
  }

  @Test func thePackageClosureOfEditorKitHoldsNoACPTextualOrMathPackage() throws {
    let closure = try Self.packageClosure(from: Self.editorKitPackage)

    let forbidden = closure.filter { $0.hasPrefix(Self.acpNamePrefix) || Self.forbiddenPackages.contains($0.lowercased()) }

    #expect(closure.contains(Self.editorKitPackage))
    #expect(closure.count > 1, "The walk read no manifest of EditorKit: \(closure)")
    #expect(forbidden.isEmpty, "\(forbidden)")
  }

  @Test func theScanFindsTheACPPackagesOfTheKitManifest() {
    let kitPackages = Self.packageNames(in: manifest)

    #expect(kitPackages.contains { $0.hasPrefix(Self.acpNamePrefix) })
  }

  /// The bodies of the dependency arrays of the style target.
  ///
  /// The target lists its dependencies as a sum of named arrays, such as
  /// `styleEditorKitProducts`. The function returns the body of each array.
  ///
  /// - Returns: The text between the brackets of each array.
  /// - Throws: An issue when the manifest has no style target or no array.
  func styleTargetDependencies() throws -> [String] {
    let target = /\.target\(\s*name:\s*"AgentViewKitStyle",\s*dependencies:\s*(?<arrays>[^,\n]+),/
    let match = try #require(manifest.firstMatch(of: target))
    return try match.output.arrays.split(separator: "+").map { name in
      let trimmed = name.trimmingCharacters(in: .whitespaces)
      let declaration = try Regex(#"let \#(trimmed): \[Target\.Dependency\] = \[(?<body>[^\]]*)\]"#)
      let array = try #require(manifest.firstMatch(of: declaration), "No array named \(trimmed)")
      return String(try #require(array["body"]?.substring))
    }
  }

  /// The names of the packages that a manifest depends on.
  ///
  /// - Parameter manifest: The text of a `Package.swift`.
  /// - Returns: The last path component of each `.package(url:)`, with no
  ///   `.git`.
  static func packageNames(in manifest: String) -> [String] {
    manifest.matches(of: /\.package\(\s*url:\s*"[^"]*\/(?<name>[^"\/]+?)(?:\.git)?"/).map { String($0.output.name) }
  }

  /// The packages that `root` reaches through the manifests of the resolved
  /// checkouts, `root` with them.
  ///
  /// A package that SwiftPM did not resolve has no checkout. It is not in the
  /// package graph, so the walk does not read it.
  ///
  /// - Parameter root: The name of the package to start from.
  /// - Returns: The name of each reached package.
  /// - Throws: The error of a read of the checkout of `root`.
  static func packageClosure(from root: String) throws -> Set<String> {
    let checkouts = try PackageFiles.file(checkoutsPath)
    var reached: Set<String> = []
    var pending = [root]
    while let name = pending.popLast() {
      guard reached.insert(name).inserted else { continue }
      let manifestFile = checkouts.appending(path: name).appending(path: "Package.swift")
      guard let text = try? String(contentsOf: manifestFile, encoding: .utf8) else { continue }
      pending += packageNames(in: text)
    }
    return reached
  }
}
