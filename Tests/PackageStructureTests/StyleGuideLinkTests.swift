import EditorTestSupport
import Foundation
import Testing

/// Holds the package on the one shared style guide, `../EditorKit/style.md`
/// (^tx59fk). EditorKit holds the guide for EditorKit, KanbanViewKit,
/// AgentViewKit, SnapshotViewKit and TestudoApp, and the package keeps no copy
/// of its rules. The guide and its research page moved out of TestudoApp, so no
/// file of the package still names their old paths.
@Suite struct StyleGuideLinkTests {
  /// The architecture document of the package, relative to the package root.
  static let architecturePath = "ARCHITECTURE.md"

  /// The Markdown link target of the shared style guide, as a document at the
  /// package root writes it.
  static let sharedStyleGuideLink = "](../EditorKit/style.md)"

  /// The old paths of the style guide and of its research page in TestudoApp.
  static let retiredGuidePaths = ["features/style.md", "features/research-liquid-glass.md"]

  /// The extensions of the files that can link a guide: the documents, the
  /// Swift sources and their comments, and the scripts.
  static let linkingFileExtensions: Set<String> = ["md", "swift", "sh"]

  /// The build folder of SwiftPM, which holds the checkouts of the other
  /// packages. It is hidden, so the scan does not read it.
  static let buildFolderPrefix = ".build/"

  /// The files below `directory` with one of `extensions`, in its
  /// subdirectories too, with no hidden item: the scan skips `.git`, `.build`
  /// and `.kanban` with all that they hold.
  ///
  /// - Parameters:
  ///   - directory: The directory to read.
  ///   - extensions: The file extensions to keep, without the dot.
  /// - Returns: The URL of each such file.
  /// - Throws: `CocoaError(.fileReadNoSuchFile)` when `directory` is not an
  ///   existing directory, so a wrong path fails the test instead of scanning
  ///   nothing.
  static func visibleFiles(below directory: URL, withExtensions extensions: Set<String>) throws -> [URL] {
    var isDirectory: ObjCBool = false
    guard
      FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue,
      let enumerator = FileManager.default.enumerator(
        at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
    else {
      throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: directory.path])
    }
    return enumerator.compactMap { $0 as? URL }.filter { extensions.contains($0.pathExtension) }
  }

  @Test func theArchitectureLinksTheSharedStyleGuide() throws {
    let architecture = try PackageFiles().text(of: Self.architecturePath)

    #expect(architecture.contains(Self.sharedStyleGuideLink))
  }

  @Test func noFileNamesAnOldPathOfTheStyleGuide() throws {
    let package = PackageFiles()
    let ownPath = try package.relativePath(of: URL(filePath: #filePath))
    let files = try Self.visibleFiles(below: package.root, withExtensions: Self.linkingFileExtensions)
    let paths = try files.map { try package.relativePath(of: $0) }

    let found = try paths.filter { $0 != ownPath }.sorted().flatMap { path in
      SourceLineScanner.matches(inSource: try package.text(of: path), file: path) { line in
        Self.retiredGuidePaths.flatMap { SourceLineScanner.uses(of: $0, on: line) }
      }
    }

    #expect(paths.contains(Self.architecturePath))
    #expect(!paths.contains { $0.hasPrefix(Self.buildFolderPrefix) })
    #expect(found.isEmpty, "Link ../EditorKit/style.md or ../EditorKit/Docs/research-liquid-glass.md: \(found)")
  }
}
