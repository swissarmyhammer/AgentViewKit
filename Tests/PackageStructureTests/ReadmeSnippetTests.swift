import Foundation
import PackageFileSupport
import Testing

/// Holds the compiled snippets of `README.md` and the files of
/// `Examples/ReadmeSnippets/Snippets/` equal (plan.md §1).
///
/// The `ReadmeSnippetsTests` target compiles the files. This suite checks
/// that each snippet of the README is the file of its name, and that each
/// file is a snippet of the README. A snippet that changed in one place only
/// fails here.
@Suite struct ReadmeSnippetTests {
  /// A snippet name that is a Swift identifier.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var identifier: Regex<Substring> {
    /^[A-Za-z_][A-Za-z0-9_]*$/
  }

  @Test func theRootHoldsTheReadme() throws {
    let readme = try PackageFiles.file(ReadmeSnippets.readmePath)

    #expect(FileManager.default.fileExists(atPath: readme.path(percentEncoded: false)))
  }

  @Test func theReadmeHasAtLeastOneSnippet() throws {
    #expect(!(try ReadmeSnippets.readmeSnippets()).isEmpty)
  }

  @Test func eachMarkerLineOfTheReadmeOpensASnippet() throws {
    let readme = try ReadmeSnippets.readme()

    #expect(
      ReadmeSnippets.markerLineCount(in: readme) == ReadmeSnippets.snippets(in: readme).count,
      "A marker line is not the first line of a ```swift block")
  }

  @Test func eachSnippetHasAnIdentifierName() throws {
    for snippet in try ReadmeSnippets.readmeSnippets() {
      #expect(snippet.name.contains(Self.identifier), "The marker '\(snippet.name)' is not an identifier")
    }
  }

  @Test func eachSnippetHasItsOwnName() throws {
    let names = try ReadmeSnippets.readmeSnippets().map(\.name)

    #expect(Set(names).count == names.count, "Two snippets have the same name: \(names)")
  }

  @Test func eachSnippetIsTheFileOfItsName() throws {
    let files = try ReadmeSnippets.snippetFiles()

    for snippet in try ReadmeSnippets.readmeSnippets() {
      let file = try #require(files[snippet.name], "README.md has the snippet \(snippet.name), but Examples/ReadmeSnippets/Snippets/ has no file for it. Run Scripts/extract-readme-snippets.sh")
      #expect(file == snippet.body + "\n", "The snippet \(snippet.name) differs from its file. Run Scripts/extract-readme-snippets.sh")
    }
  }

  @Test func eachSnippetFileIsASnippetOfTheReadme() throws {
    let names = Set(try ReadmeSnippets.readmeSnippets().map(\.name))
    let files = Set(try ReadmeSnippets.snippetFiles().keys)

    #expect(files == names, "The files \(files.subtracting(names).sorted()) are not in README.md")
  }

  @Test func swiftBlocksTakesTheSwiftBlocksAndDropsTheFences() {
    let markdown = """
      Prose.
      ```swift
      let first = 1
      ```
      ```bash
      swift build
      ```
      ```swift
      let second = 2
      let third = 3
      ```
      """

    #expect(ReadmeSnippets.swiftBlocks(in: markdown) == ["let first = 1", "let second = 2\nlet third = 3"])
  }

  @Test(arguments: ["```Swift", " ```swift", "```swift "])
  func swiftBlocksOpensOnTheExactFenceOnly(fence: String) {
    let markdown = "\(fence)\nlet value = 1\n```\n"

    #expect(ReadmeSnippets.swiftBlocks(in: markdown).isEmpty)
  }

  @Test func snippetsKeepsTheMarkedBlocksOnly() {
    let markdown = """
      ```swift
      .package(url: "git@github.com:swissarmyhammer/AgentViewKit.git", branch: "main")
      ```
      ```swift
      \(ReadmeSnippets.marker) Example
      let compiled = true
      ```
      """

    #expect(
      ReadmeSnippets.snippets(in: markdown) == [
        ReadmeSnippets.Snippet(name: "Example", body: "\(ReadmeSnippets.marker) Example\nlet compiled = true")
      ])
  }

  @Test func snippetsGivesAnEmptyNameToAMarkerWithNoName() {
    let markdown = "```swift\n\(ReadmeSnippets.marker)\nlet value = 1\n```\n"

    #expect(ReadmeSnippets.snippets(in: markdown).map(\.name) == [""])
  }

  @Test func markerLineCountCountsTheLinesThatStartWithTheMarker() {
    let text = "\(ReadmeSnippets.marker) One\nlet a = 1\n  \(ReadmeSnippets.marker) Indented\n\(ReadmeSnippets.marker)\n"

    #expect(ReadmeSnippets.markerLineCount(in: text) == 2)
  }
}
