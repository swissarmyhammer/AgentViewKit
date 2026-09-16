import EditorComplete
import EditorCore
import Foundation
import Testing

@testable import AgentViewKit

/// An in-memory file system for the file reference tests.
struct InMemoryFileSystem: FileSystem {
  /// The entries of each directory, by the path relative to the root.
  let directories: [String: [FileSystemEntry]]

  func entries(at directory: String) async throws -> [FileSystemEntry] {
    guard let entries = directories[directory] else { throw CocoaError(.fileNoSuchFile) }
    return entries
  }
}

/// A temporary directory with files, for the tests that read the disk.
struct TemporaryFileRoot: ~Copyable {
  /// The directory.
  let url: URL

  /// Makes a directory with `files`. A path that ends in `/` is a directory.
  ///
  /// - Parameter files: The paths to make, relative to the directory.
  init(files: [String]) throws {
    url = FileManager.default.temporaryDirectory
      .appending(path: "FileReferenceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    for file in files {
      let item = url.appending(path: file)
      if file.hasSuffix("/") {
        try FileManager.default.createDirectory(at: item, withIntermediateDirectories: true)
      } else {
        try FileManager.default.createDirectory(
          at: item.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(file.utf8).write(to: item)
      }
    }
  }

  deinit {
    try? FileManager.default.removeItem(at: url)
  }
}

@Suite @MainActor struct FileReferenceSourceTests {
  /// The file system of the tests.
  static let fileSystem = InMemoryFileSystem(directories: [
    "": [
      FileSystemEntry(name: "notes.txt", isDirectory: false),
      FileSystemEntry(name: "src", isDirectory: true),
      FileSystemEntry(name: ".hidden", isDirectory: false),
      FileSystemEntry(name: "README.md", isDirectory: false),
    ],
    "src": [
      FileSystemEntry(name: "main.swift", isDirectory: false),
      FileSystemEntry(name: "model", isDirectory: true),
    ],
  ])

  /// A fixture with the file reference source over ``fileSystem``, and the
  /// slash source as the kit editor composes them.
  static func fixture(_ text: String) -> CompletionFixture {
    CompletionFixture(
      text,
      sources: [
        SlashCommandSource(commands: []), FileReferenceSource(fileSystem: fileSystem),
      ])
  }

  // MARK: - Completion

  @Test func anAtSignListsTheRootEntriesWithDirectoriesFirst() async {
    let labels = await Self.fixture("@").query()

    #expect(labels.first == "src/")
    #expect(Set(labels) == ["src/", "notes.txt", "README.md"])
  }

  @Test func theTextAfterTheAtSignFiltersTheEntries() async {
    let labels = await Self.fixture("see @no").query()

    #expect(labels == ["notes.txt"])
  }

  @Test func aDotShowsTheHiddenEntries() async {
    let labels = await Self.fixture("@.h").query()

    #expect(labels == [".hidden"])
  }

  @Test func acceptAFileInsertsTheReferenceAndASpace() async {
    let fixture = Self.fixture("@no")
    _ = await fixture.query()

    #expect(fixture.accept("notes.txt"))
    #expect(fixture.text == "@notes.txt ")
  }

  @Test func acceptADirectoryInsertsTheReferenceAndASlash() async {
    let fixture = Self.fixture("@sr")
    _ = await fixture.query()

    #expect(fixture.accept("src/"))
    #expect(fixture.text == "@src/")
  }

  @Test func aPathListsTheEntriesOfItsDirectory() async {
    let fixture = Self.fixture("@src/")
    let labels = await fixture.query()

    #expect(labels == ["model/", "main.swift"])
    #expect(fixture.accept("main.swift"))
    #expect(fixture.text == "@src/main.swift ")
  }

  @Test func aPartialNameInADirectoryCompletesTheFullPath() async {
    let fixture = Self.fixture("@src/ma")
    _ = await fixture.query()

    #expect(fixture.accept("main.swift"))
    #expect(fixture.text == "@src/main.swift ")
  }

  @Test func aPartialNameWithADotCompletesTheFullPath() async {
    let fixture = Self.fixture("@src/main.sw")
    _ = await fixture.query()

    #expect(fixture.accept("main.swift"))
    #expect(fixture.text == "@src/main.swift ")
  }

  @Test func anAtSignInAWordListsNothing() async {
    let labels = await Self.fixture("me@no").query()

    #expect(labels.isEmpty)
  }

  @Test func aPathThatGoesUpListsNothing() async {
    #expect(await Self.fixture("@../").query().isEmpty)
    #expect(await Self.fixture("@/").query().isEmpty)
  }

  @Test func theSafePathCheckRejectsParentAndAbsolutePaths() {
    #expect(FileReferenceSource.isSafe("src/main.swift"))
    #expect(FileReferenceSource.isSafe("src/..x"))
    #expect(!FileReferenceSource.isSafe("src/../../etc"))
    #expect(!FileReferenceSource.isSafe("/etc"))
  }

  // MARK: - Disk

  @Test func theDirectoryFileSystemListsTheEntriesOnDisk() async throws {
    let root = try TemporaryFileRoot(files: ["a.txt", "docs/"])
    let entries = try await DirectoryFileSystem(root: root.url).entries(at: "")

    #expect(
      Set(entries) == [
        FileSystemEntry(name: "a.txt", isDirectory: false),
        FileSystemEntry(name: "docs", isDirectory: true),
      ])
  }

  @Test func theDirectoryFileSystemRejectsALinkOutOfTheRoot() async throws {
    let root = try TemporaryFileRoot(files: ["inside/"])
    let outside = try TemporaryFileRoot(files: ["secret.txt"])
    try FileManager.default.createSymbolicLink(
      at: root.url.appending(path: "escape"), withDestinationURL: outside.url)

    await #expect(throws: CocoaError.self) {
      try await DirectoryFileSystem(root: root.url).entries(at: "escape")
    }
  }

  // MARK: - Chips

  @Test func theReferenceScanFindsEachReferenceAfterWhiteSpace() {
    let references = FileReferenceDetector.references(in: "@a.txt and me@b.txt\n@src/c.swift")

    #expect(references.map(\.path) == ["a.txt", "src/c.swift"])
    #expect(references.map(\.text) == ["@a.txt", "@src/c.swift"])
    #expect(references.map(\.range) == [0..<6, 20..<32])
  }

  @Test func theDetectorMatchesOnlyTheAcceptedReferences() {
    let engine = EditorEngine("é @a.txt @b.txt")
    let context = EditorContext(engine.state)
    let detector = FileReferenceDetector(paths: ["b.txt"])

    let matches = detector.detect(
      in: EditorRange(context.state.document.position(utf8Offset: 0), context.documentEnd),
      context: context)

    #expect(matches.map(\.text) == ["@b.txt"])
    #expect(matches.map(\.kind) == [FileReferenceDetector.kind])
    #expect(matches.first.map { context.text(in: $0.range) } == "@b.txt")
  }

  @Test func theDetectorFindsNothingWithNoAcceptedReference() {
    let engine = EditorEngine("@a.txt")
    let context = EditorContext(engine.state)

    let matches = FileReferenceDetector(paths: []).detect(
      in: EditorRange(context.state.document.position(utf8Offset: 0), context.documentEnd),
      context: context)

    #expect(matches.isEmpty)
  }

  // MARK: - Prompt text

  @Test func theAcceptedReferencesLinkToTheirFiles() {
    let root = URL(filePath: "/project", directoryHint: .isDirectory)
    let text = EditorKitPromptEditor.attributedText(
      "é @a.txt and @b.txt", references: ["b.txt"], root: root)

    let links = text.runs.compactMap { run in run.link.map { (String(text[run.range].characters), $0) } }
    #expect(links.map(\.0) == ["@b.txt"])
    #expect(links.map(\.1) == [root.appending(path: "b.txt")])
    #expect(String(text.characters) == "é @a.txt and @b.txt")
  }

  @Test func theTextHasNoLinkWithoutARoot() {
    let text = EditorKitPromptEditor.attributedText("@a.txt", references: ["a.txt"], root: nil)

    #expect(text.runs.allSatisfy { $0.link == nil })
  }

  @Test func theComposerSendsEachLinkedFileOneTime() {
    let file = URL(filePath: "/project/a.txt")
    var text = AttributedString("@a.txt @a.txt see")
    let first = text.range(of: "@a.txt")!
    text[first].link = file
    let second = text[first.upperBound...].range(of: "@a.txt")!
    text[second].link = file
    text.append(AttributedString(" web"))
    let web = text.range(of: "web")!
    text[web].link = URL(string: "https://example.com")

    #expect(PromptInputView<StockPromptEditor, DefaultPromptAccessory>.attachments(in: text) == [file])
  }

  // MARK: - Triggers

  @Test func aTriggerIsASlashTokenAtTheStartOrAnAtSignRun() {
    #expect(EditorKitPromptEditor.isTrigger("/co", hasCommands: true, hasRoot: false))
    #expect(!EditorKitPromptEditor.isTrigger("/co", hasCommands: false, hasRoot: false))
    #expect(!EditorKitPromptEditor.isTrigger("/co ", hasCommands: true, hasRoot: false))
    #expect(!EditorKitPromptEditor.isTrigger("hi /co", hasCommands: true, hasRoot: false))
    #expect(EditorKitPromptEditor.isTrigger("see @src/ma", hasCommands: false, hasRoot: true))
    #expect(!EditorKitPromptEditor.isTrigger("see @src/ma", hasCommands: false, hasRoot: false))
    #expect(!EditorKitPromptEditor.isTrigger("@a.txt ", hasCommands: true, hasRoot: true))
  }

  @Test func anAcceptedFileIsAReferenceToAFileBeforeASpace() throws {
    let root = try TemporaryFileRoot(files: ["a.txt", "docs/"])

    #expect(EditorKitPromptEditor.acceptedFile(before: "see @a.txt ", root: root.url) == "a.txt")
    #expect(EditorKitPromptEditor.acceptedFile(before: "see @a.txt", root: root.url) == nil)
    #expect(EditorKitPromptEditor.acceptedFile(before: "@docs ", root: root.url) == nil)
    #expect(EditorKitPromptEditor.acceptedFile(before: "@missing.txt ", root: root.url) == nil)
    #expect(EditorKitPromptEditor.acceptedFile(before: "@a.txt ", root: nil) == nil)
  }

  @Test func theLastRunIsTheTextAfterTheLastSpace() {
    #expect(EditorKitPromptEditor.lastRun(of: "see @src") == "@src")
    #expect(EditorKitPromptEditor.lastRun(of: "@src") == "@src")
    #expect(EditorKitPromptEditor.lastRun(of: "see ") == "")
  }
}
