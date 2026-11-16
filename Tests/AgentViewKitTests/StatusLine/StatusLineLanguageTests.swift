@testable import AgentViewKit
import Testing

/// The languages of a folder, and the walk of a folder outside a repository
/// (D194 (f), (g)).
@Suite struct StatusLineLanguageTests {
  static func names(_ files: [String], _ change: (inout LanguagesModule) -> Void = { _ in }) -> [String] {
    var module = LanguagesModule()
    change(&module)
    return StatusLineLanguageDetector.languages(of: files, module: module).map(\.name)
  }

  @Test func languageWithMostFilesIsFirst() {
    let files = ["a.py", "Sources/a.swift", "Sources/b.swift", "c.swift", "x.rs", "y.rs"]
    #expect(Self.names(files) == ["swift", "rust", "python"])
  }

  @Test func atMostFourLanguagesShow() {
    let files = ["a.c", "b.go", "c.rs", "d.swift", "e.py", "f.rb"]
    #expect(Self.names(files).count == 4)
  }

  @Test func markerFileCountsForItsLanguage() {
    #expect(Self.names(["Package.swift"]) == ["swift"])
    #expect(Self.names(["sub/Cargo.toml"]) == ["rust"])
  }

  @Test func markerFolderCountsOneTime() {
    #expect(Self.names(["node_modules/a/x.txt", "node_modules/b/y.txt"]) == ["javascript"])
  }

  @Test func filesWithNoLanguageShowNothing() {
    #expect(Self.names(["README.md", "notes.txt", "Makefile"]).isEmpty)
  }

  @Test func minimumFilesHidesARareLanguage() {
    let files = ["a.swift", "b.swift", "x.py"]
    #expect(Self.names(files) { $0.minimumFiles = 2 } == ["swift"])
  }

  @Test func disabledLanguageDoesNotShow() {
    let files = ["a.swift", "x.py"]
    let names = Self.names(files) { module in
      module.languages = module.languages.map { var copy = $0; copy.disabled = $0.name == "swift"; return copy }
    }
    #expect(names == ["python"])
  }

  @Test func extensionMatchIgnoresCase() {
    #expect(Self.names(["A.SWIFT"]) == ["swift"])
  }

  @Test func walkListsTheFilesAndSkipsHiddenFiles() throws {
    let folder = try StatusLineTemporaryFolder()
    try folder.write("a.swift")
    try folder.write("Sources/b.rs")
    try folder.write(".hidden/c.py")
    try folder.write(".env")
    #expect(Set(StatusLineFolderWalk.files(in: folder.path)) == ["a.swift", "Sources/b.rs"])
  }

  @Test func walkStopsAtItsLimit() throws {
    let folder = try StatusLineTemporaryFolder()
    for index in 0..<5 { try folder.write("f\(index).swift") }
    #expect(StatusLineFolderWalk.files(in: folder.path, limit: 3).count == 3)
  }
}
