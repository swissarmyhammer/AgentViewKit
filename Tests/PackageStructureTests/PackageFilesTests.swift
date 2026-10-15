import Foundation
import PackageFileSupport
import Testing

@Suite struct PackageFilesTests {
  /// The path of the source file in the symlink test, relative to the target
  /// directory of the link.
  private static let linkedFilePath = "Sources/Linked.swift"

  /// A directory that holds a real directory and a symlink to it, for one
  /// test.
  ///
  /// The link is one level higher than its target. Thus a cut by the length
  /// or by the depth of the link path gives a wrong relative path.
  private struct LinkedDirectory {
    /// The temporary directory that holds the target and the link.
    let top: URL
    /// The symlink, `top/link`.
    let link: URL
    /// The real directory, `top/deeper/real`.
    let target: URL

    /// Makes the target directory, one Swift file in it, and the link.
    ///
    /// - Throws: The error of the file manager when it cannot make an item.
    init() throws {
      top = FileManager.default.temporaryDirectory
        .appending(path: "PackageFilesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
      link = top.appending(path: "link", directoryHint: .isDirectory)
      target = top.appending(path: "deeper/real", directoryHint: .isDirectory)
      let file = target.appending(path: PackageFilesTests.linkedFilePath)
      try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data().write(to: file)
      try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    }

    /// Removes the directory and each item in it.
    func remove() {
      try? FileManager.default.removeItem(at: top)
    }
  }

  @Test func relativePathIsCorrectWhenTheDirectoryPathHasASymlink() throws {
    let linked = try LinkedDirectory()
    defer { linked.remove() }

    let fileThroughTarget = linked.target.appending(path: Self.linkedFilePath)
    let folderThroughLink = linked.link.appending(path: Self.linkedFilePath).deletingLastPathComponent()
    let filesThroughLink = try PackageFiles.swiftFiles(in: folderThroughLink)

    #expect(try PackageFiles.relativePath(of: fileThroughTarget, to: linked.link) == Self.linkedFilePath)
    #expect(try filesThroughLink.map { try PackageFiles.relativePath(of: $0, to: linked.link) } == [Self.linkedFilePath])
    #expect(try filesThroughLink.map { try PackageFiles.relativePath(of: $0, to: linked.target) } == [Self.linkedFilePath])
  }

  @Test func relativePathRejectsAFileOutsideTheDirectory() throws {
    let sources = try PackageFiles.file("Sources")
    let manifest = try PackageFiles.file("Package.swift")

    #expect(throws: PackageFiles.FileOutsideDirectory(file: manifest, directory: sources)) {
      try PackageFiles.relativePath(of: manifest, to: sources)
    }
  }

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
