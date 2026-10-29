import EditorTestSupport
import Foundation
import Testing

/// The import boundaries of the ACP client kit (plan.md §1, §11 decision 1).
///
/// The kit is one target that links the ACP packages. No target in
/// `Sources/` imports the FoundationModels framework or the FoundationModels
/// family packages that are not ACP. A FoundationModels agent and a Router
/// agent reach the kit through FoundationModelsACPAgent and ACP. No target in
/// `Sources/` imports the other view kits, `KanbanViewKit` and
/// `SnapshotViewKit`. No Swift file imports the merged `AgentViewKitACP`
/// module.
@Suite struct ImportBoundaryTests {
  /// The modules that no target in `Sources/` can import.
  ///
  /// The FoundationModels runtimes stay out of the kit. The other view kits
  /// stay out too, so that no kit links another kit. The scope kind text is
  /// the contract between the kits.
  static let forbiddenInSources: Set<String> = [
    "FoundationModels",
    "FoundationModelsRouter",
    "FoundationModelsExtras",
    "KanbanViewKit",
    "SnapshotViewKit",
  ]

  /// The module that the `AgentViewKit` target now holds (plan.md §11
  /// decision 1).
  static let mergedModule = "AgentViewKitACP"

  /// The agent package. Only the demo-only target `DemoSupport` imports it,
  /// for the agent of the Gallery tab. The kit gets an agent from its host.
  static let agentModule = "FoundationModelsACPAgent"

  /// The directory of the Swift files of the kit target.
  static let kitSourcesPath = "Sources/AgentViewKit"

  /// The directory of the Swift files of the style library.
  static let styleSourcesPath = KitSourceFiles.stylePath

  /// The modules that no Swift file of the style library can import.
  ///
  /// The style library is the shared look of the view kits, with no agent
  /// in it: it links EditorKit only. Thus it imports no ACP module, not the
  /// Markdown text (`Textual`) or the math (`SwiftUIMath`) of the kit, and
  /// no view kit, `AgentViewKit` or `KanbanViewKit`, so that each kit can
  /// link it.
  static let forbiddenInStyle: Set<String> = [
    "FoundationModelsACP",
    "FoundationModelsACPClient",
    agentModule,
    "Textual",
    "SwiftUIMath",
    "AgentViewKit",
    "KanbanViewKit",
  ]

  /// The package directories that hold Swift files, with the tests of the
  /// integration package.
  static let swiftDirectories = ["Sources", "Tests", "Examples", IntegrationPackage.testsPath]

  /// The hosted tests of the public API of the style library. They link the
  /// style library only, so they hold the import rule of the style library.
  static let styleIntegrationTestsPath = "\(IntegrationPackage.testsPath)/AgentViewKitStyleIntegrationTests"

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
    get throws { try PackageFiles().file("Tests/PackageStructureTests/Fixtures/ImportBoundary") }
  }

  /// The import boundaries of the package: each pair is a directory,
  /// relative to the package root, and the modules that no Swift file in it
  /// can import.
  ///
  /// - No target in `Sources/` imports a FoundationModels runtime or another
  ///   view kit.
  /// - The kit target does not import the agent package.
  /// - The style library imports no ACP module, no text or math package of
  ///   the kit, and no view kit (``forbiddenInStyle``).
  /// - The hosted tests of the style library hold the same rule.
  /// - No Swift file imports the merged ACP module.
  static let boundaries: [(directory: String, forbidden: Set<String>)] =
    [
      ("Sources", forbiddenInSources),
      (kitSourcesPath, Set([agentModule])),
      (styleSourcesPath, forbiddenInStyle),
      (styleIntegrationTestsPath, forbiddenInStyle),
    ] + swiftDirectories.map { ($0, Set([mergedModule])) }

  /// Expects that no Swift file below `directory` imports a module of
  /// `forbidden`.
  ///
  /// - Parameters:
  ///   - directory: The directory to scan.
  ///   - forbidden: The modules that no file can import.
  /// - Throws: The error of the scan of the directory.
  static func expectNoImport(below directory: URL, of forbidden: Set<String>) throws {
    let violations = try ImportScanner.violations(in: directory, forbidden: forbidden)
    #expect(violations.isEmpty, "\(violations)")
  }

  @Test(arguments: boundaries)
  func noSwiftFileCrossesTheImportBoundaryOfItsDirectory(directory: String, forbidden: Set<String>) throws {
    try Self.expectNoImport(below: PackageFiles().file(directory), of: forbidden)
  }

  @Test func theStyleLibraryImportsNoACPModuleNoKitPackageAndNoViewKit() throws {
    let style = try PackageFiles().file(Self.styleSourcesPath)

    #expect(!swiftFiles(under: style).isEmpty)
    try Self.expectNoImport(below: style, of: Self.forbiddenInStyle)
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

  @Test func sourcesForbidTheImportsOfTheOtherViewKits() throws {
    let violations = try ImportScanner.violations(
      in: Self.fixtures.appending(path: "OtherKits"),
      forbidden: Self.forbiddenInSources
    )

    #expect(violations.map(\.module) == ["KanbanViewKit", "SnapshotViewKit"])
  }

  @Test func scannerAcceptsTheCleanFixture() throws {
    try Self.expectNoImport(below: Self.fixtures.appending(path: "Clean"), of: Self.forbiddenInSources)
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
