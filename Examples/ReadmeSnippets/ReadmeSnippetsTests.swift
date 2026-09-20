import Foundation
import Testing

/// The target of the compiled README snippets (plan.md §1).
///
/// The job of this target is the build. Each `// readme:compile` block of
/// `README.md` is a file in `Snippets/`, that `Scripts/extract-readme-snippets.sh`
/// writes. `swift test` compiles the files against the products that a host
/// imports, so a snippet that does not compile fails the build.
/// `ReadmeSnippetTests` in PackageStructureTests holds the README and the
/// files equal.
///
/// This suite checks that the directory has a file to compile, so that the
/// target does not pass with nothing in it.
@Suite struct ReadmeSnippetsTests {
  /// The directory of the snippet files.
  static var snippetsDirectory: URL {
    URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Snippets")
  }

  @Test func theTargetCompilesAtLeastOneSnippet() throws {
    let files = try FileManager.default.contentsOfDirectory(
      at: Self.snippetsDirectory, includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "swift" }

    #expect(!files.isEmpty, "Snippets/ has no file. Run Scripts/extract-readme-snippets.sh")
  }
}
