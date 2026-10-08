import Foundation
import PackageFileSupport
import Testing

/// The import boundary of the `Benchmarks/` package (update.md §7 item 2).
///
/// The kit is an ACP client kit. The benchmarks measure the kit, so they must
/// not use the FoundationModels framework or the FoundationModels adapter of
/// the kit. The test reads the benchmark sources and the benchmark manifest
/// as text.
@Suite struct BenchmarkBoundaryTests {
  /// The modules and the products that the benchmark package must not use.
  static let forbiddenModules: Set<String> = [
    "FoundationModels",
    "AgentViewKitFoundationModels",
  ]

  /// The directory of the benchmark sources, relative to the package root.
  static let benchmarkSources = "Benchmarks/Benchmarks"

  /// The manifest of the benchmark package, relative to the package root.
  static let benchmarkManifest = "Benchmarks/Package.swift"

  @Test func benchmarkSourcesImportNoFoundationModelsModule() throws {
    let violations = try ImportScanner.violations(
      in: PackageFiles.file(Self.benchmarkSources),
      forbidden: Self.forbiddenModules
    )
    #expect(violations.isEmpty, "\(violations)")
  }

  /// The observation benchmark measures the binding of the transcript view
  /// to the `TranscriptEntry` objects of `SessionModel`. A benchmark class
  /// that is `@Observable` could stand between the entry and the row view,
  /// so no benchmark source declares one.
  @Test func benchmarkSourcesDeclareNoObservableClass() throws {
    let files = try PackageFiles.swiftFiles(in: PackageFiles.file(Self.benchmarkSources))
    #expect(!files.isEmpty, "The scan found no benchmark source")
    for file in files {
      let source = try String(contentsOf: file, encoding: .utf8)
      let names = RemovedVocabularyTests.observableClassNames(inSource: source)
      #expect(names.isEmpty, "\(file.lastPathComponent) declares \(names)")
    }
  }

  @Test func benchmarkManifestLinksNoFoundationModelsProduct() throws {
    let manifest = try PackageFiles.text(of: Self.benchmarkManifest)
    let products = Set(
      manifest.matches(of: /\.product\(\s*name:\s*"(?<name>[^"]+)"/).map { String($0.output.name) }
    )
    #expect(products.contains("AgentViewKit"), "The scan found no kit product: \(products)")
    #expect(products.isDisjoint(with: Self.forbiddenModules), "\(products)")
  }
}
