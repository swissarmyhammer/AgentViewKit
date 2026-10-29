import EditorTestSupport
import Foundation
import Testing

/// Holds the shared paths of ``KitSourceFiles`` in the package, so a scan
/// that reads them reads real files.
@Suite struct KitSourceFilesTests {
  @Test func aKitFileIsBelowTheKitDirectory() {
    #expect(KitSourceFiles.kitFile("Items/A.swift") == "Sources/AgentViewKit/Items/A.swift")
  }

  @Test func eachSharedFileOfTheKitIsInThePackage() throws {
    let files = [KitSourceFiles.statusBarFile, KitSourceFiles.taskListFile]

    let texts = try files.map { try PackageFiles().text(of: $0) }

    #expect(texts.allSatisfy { !$0.isEmpty })
  }

  @Test func eachViewPathIsADirectoryOfThePackage() throws {
    let found = try KitSourceFiles.scanViewFiles(swiftFiles(under:))

    #expect(!found.isEmpty)
  }

  @Test func theViewScanGivesEachViewDirectoryToTheScanInOrder() throws {
    let expected = try KitSourceFiles.viewPaths.map { try PackageFiles().file($0) }

    let scanned = try KitSourceFiles.scanViewFiles { directory in [directory] }

    #expect(scanned == expected)
  }

  /// The error that a scan of a test throws.
  struct ScanFailure: Error, Equatable {}

  @Test func theViewScanGivesTheErrorOfTheScan() {
    #expect(throws: ScanFailure()) {
      try KitSourceFiles.scanViewFiles { _ -> [URL] in throw ScanFailure() }
    }
  }
}
