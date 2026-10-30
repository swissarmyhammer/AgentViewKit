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
}
