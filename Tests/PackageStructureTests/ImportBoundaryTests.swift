import Foundation
import PackageFileSupport
import Testing

/// The import boundaries of plan.md §11 decision 1.
///
/// The ACP target must not import the FoundationModels framework or the
/// FoundationModels family packages that are not ACP. The model and view
/// target must not import a source runtime at all. Each source runtime lives
/// in its own adapter target.
@Suite struct ImportBoundaryTests {
  /// The modules that `Sources/AgentViewKitACP` must not import.
  static let forbiddenInACP: Set<String> = [
    "FoundationModels",
    "FoundationModelsRouter",
    "FoundationModelsExtras",
  ]

  /// The modules that `Sources/AgentViewKit` must not import.
  static let forbiddenInAgentViewKit: Set<String> = [
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

  @Test func acpTargetImportsNoFoundationModelsRuntime() throws {
    let violations = try ImportScanner.violations(
      in: PackageFiles.file("Sources/AgentViewKitACP"),
      forbidden: Self.forbiddenInACP
    )
    #expect(violations.isEmpty, "\(violations)")
  }

  @Test func agentViewKitTargetImportsNoSourceRuntime() throws {
    let violations = try ImportScanner.violations(
      in: PackageFiles.file("Sources/AgentViewKit"),
      forbidden: Self.forbiddenInAgentViewKit
    )
    #expect(violations.isEmpty, "\(violations)")
  }

  @Test func scannerReportsEachForbiddenImportInTheFixture() throws {
    let violatingDirectory = try Self.fixtures.appending(path: "Violating")
    let fixtureFile = "Nested/ImportsRuntimes.swift"
    let violations = try ImportScanner.violations(in: violatingDirectory, forbidden: Self.forbiddenInAgentViewKit)

    #expect(
      violations.map(\.module) == [
        "FoundationModels",
        "FoundationModelsACP",
        "FoundationModelsRouter",
        "FoundationModelsExtras",
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
      forbidden: Self.forbiddenInACP
    )
    #expect(violations.isEmpty, "\(violations)")
  }

  @Test func scannerFailsOnADirectoryThatDoesNotExist() {
    #expect(throws: CocoaError.self) {
      try ImportScanner.violations(
        in: Self.fixtures.appending(path: "NoSuchDirectory"),
        forbidden: Self.forbiddenInACP
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
