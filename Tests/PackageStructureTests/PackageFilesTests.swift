import Foundation
import PackageFileSupport
import Testing

@Suite struct PackageFilesTests {
  @Test func theRootHoldsThePackageManifest() {
    let manifest = PackageFiles.root.appending(path: "Package.swift")

    #expect(FileManager.default.fileExists(atPath: manifest.path(percentEncoded: false)))
  }

  @Test func textReadsAFileRelativeToTheRoot() throws {
    let text = try PackageFiles.text(of: "Package.swift")

    #expect(text.contains("name: \"AgentViewKit\""))
  }

  @Test func textThrowsForAMissingFile() {
    #expect(throws: (any Error).self) {
      try PackageFiles.text(of: "Docs/decisions/no-such-file.md")
    }
  }

  @Test(arguments: ["../Package.swift", "Docs/../../Package.swift", "/etc/hosts", "Docs/.."])
  func fileRejectsAPathOutsideTheRoot(relativePath: String) {
    #expect(throws: PackageFiles.PathOutsideRoot(relativePath: relativePath)) {
      try PackageFiles.file(relativePath)
    }
  }

  @Test func fileKeepsAPathInsideTheRoot() throws {
    let url = try PackageFiles.file("Docs/decisions/usage-model.md")

    #expect(url == PackageFiles.root.appending(path: "Docs/decisions/usage-model.md"))
  }

  @Test func swiftFilesListsOnlySwiftFilesInSubdirectoriesToo() throws {
    let sources = try PackageFiles.file("Sources")

    let names = try PackageFiles.swiftFiles(in: sources).map(\.lastPathComponent)

    #expect(names.contains("PackageFiles.swift"))
    #expect(names.allSatisfy { $0.hasSuffix(".swift") })
  }

  @Test func swiftFilesThrowsForAMissingDirectory() throws {
    let missing = try PackageFiles.file("Sources/NoSuchDirectory")

    #expect(throws: CocoaError.self) {
      try PackageFiles.swiftFiles(in: missing)
    }
  }
}
