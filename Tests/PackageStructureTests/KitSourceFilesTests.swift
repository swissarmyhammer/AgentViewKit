import Foundation
import PackageFileSupport
import Testing

/// Holds the shared paths of ``KitSourceFiles`` in the package, so a scan
/// that reads them reads real files.
@Suite struct KitSourceFilesTests {
  @Test func aKitFileIsBelowTheKitDirectory() {
    #expect(KitSourceFiles.kitFile("Items/A.swift") == "Sources/AgentViewKit/Items/A.swift")
  }

  @Test func eachSharedFileOfTheKitIsInThePackage() throws {
    let files = [KitSourceFiles.statusBarFile, KitSourceFiles.taskListFile]

    let texts = try files.map { try PackageFiles.text(of: $0) }

    #expect(texts.allSatisfy { !$0.isEmpty })
  }

  @Test func eachViewPathIsADirectoryOfThePackage() throws {
    let found = try KitSourceFiles.viewPaths.flatMap { path in
      try PackageFiles.swiftFiles(in: PackageFiles.file(path))
    }

    #expect(!found.isEmpty)
  }
}
