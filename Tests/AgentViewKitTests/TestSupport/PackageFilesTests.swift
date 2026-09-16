import AgentViewKitTestSupport
import Foundation
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
}
