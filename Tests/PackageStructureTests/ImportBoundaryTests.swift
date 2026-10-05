import Foundation
import PackageFileSupport
import Testing

/// The import boundaries of the ACP client kit (update.md §1, §3 D4).
///
/// The kit is one target that links the ACP packages. No target in
/// `Sources/` imports the FoundationModels framework or the FoundationModels
/// family packages that are not ACP. A FoundationModels agent and a Router
/// agent reach the kit through FoundationModelsACPAgent and ACP. No Swift file
/// imports the merged `AgentViewKitACP` module.
@Suite struct ImportBoundaryTests {
  /// The modules that no target in `Sources/` can import.
  static let forbiddenInSources: Set<String> = [
    "FoundationModels",
    "FoundationModelsRouter",
    "FoundationModelsExtras",
  ]

  /// The module that the `AgentViewKit` target now holds (update.md §3, D4).
  static let mergedModule = "AgentViewKitACP"

  /// The package directories that hold Swift files.
  static let swiftDirectories = ["Sources", "Tests", "Examples"]

  /// The modules that the violating fixture imports, and that the scanner
  /// tests forbid.
  static let fixtureForbidden: Set<String> = [
    "FoundationModels",
    "FoundationModelsACP",
    "FoundationModelsACPClient",
    "FoundationModelsRouter",
    "FoundationModelsExtras",
  ]

  /// The fixture directory for the scanner tests.
  static var fixtures: URL {
    get throws { try PackageFiles.file("Tests/PackageStructureTests/Fixtures/ImportBoundary") }
  }

  @Test func noSourceTargetImportsAFoundationModelsRuntime() throws {
    let violations = try ImportScanner.violations(
      in: PackageFiles.file("Sources"),
      forbidden: Self.forbiddenInSources
    )
    #expect(violations.isEmpty, "\(violations)")
  }

  @Test(arguments: swiftDirectories)
  func noFileImportsTheMergedACPModule(directory: String) throws {
    let violations = try ImportScanner.violations(
      in: PackageFiles.file(directory),
      forbidden: [Self.mergedModule]
    )
    #expect(violations.isEmpty, "\(violations)")
  }

  @Test func scannerReportsEachForbiddenImportInTheFixture() throws {
    let violatingDirectory = try Self.fixtures.appending(path: "Violating")
    let fixtureFile = "Nested/ImportsRuntimes.swift"
    let violations = try ImportScanner.violations(in: violatingDirectory, forbidden: Self.fixtureForbidden)

    #expect(
      violations.map(\.module) == [
        "FoundationModels",
        "FoundationModelsACP",
        "FoundationModelsACPClient",
        "FoundationModels",
        "FoundationModelsACPClient",
      ]
    )
    #expect(violations.allSatisfy { $0.file == fixtureFile })

    let fixtureLines = try String(contentsOf: violatingDirectory.appending(path: fixtureFile), encoding: .utf8)
      .split(separator: "\n", omittingEmptySubsequences: false)
    for violation in violations {
      let line = try #require(fixtureLines.dropFirst(violation.line - 1).first)
      let words = line.split { $0.isWhitespace || $0 == "." }
      #expect(words.contains("import") && words.contains(Substring(violation.module)), "\(violation)")
    }
  }

  @Test func scannerAcceptsTheCleanFixture() throws {
    let violations = try ImportScanner.violations(
      in: Self.fixtures.appending(path: "Clean"),
      forbidden: Self.forbiddenInSources
    )
    #expect(violations.isEmpty, "\(violations)")
  }

  @Test func scannerFailsOnADirectoryThatDoesNotExist() {
    #expect(throws: CocoaError.self) {
      try ImportScanner.violations(
        in: Self.fixtures.appending(path: "NoSuchDirectory"),
        forbidden: Self.forbiddenInSources
      )
    }
  }

  @Test(arguments: [
    ("import FoundationModels", "FoundationModels"),
    ("@preconcurrency import FoundationModels", "FoundationModels"),
    ("@testable import FoundationModelsACP", "FoundationModelsACP"),
    ("public import FoundationModelsRouter", "FoundationModelsRouter"),
    ("@_exported public import FoundationModelsExtras", "FoundationModelsExtras"),
    ("import struct FoundationModels.Transcript", "FoundationModels"),
    ("  internal import FoundationModelsACPClient.Submodule  ", "FoundationModelsACPClient"),
  ])
  func importedModuleReadsEachDeclarationForm(line: String, module: String) {
    #expect(ImportScanner.importedModule(in: Substring(line)) == module)
  }

  @Test(arguments: [
    "// import FoundationModels",
    "/// import FoundationModels",
    "let text = \"import FoundationModels\"",
    "#if canImport(FoundationModels)",
    "importer.run()",
    "",
  ])
  func importedModuleIgnoresLinesThatAreNotImports(line: String) {
    #expect(ImportScanner.importedModule(in: Substring(line)) == nil)
  }
}
