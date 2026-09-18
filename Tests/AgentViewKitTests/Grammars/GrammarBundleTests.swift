import EditorCore
import EditorText
import Foundation
import Testing

@testable import AgentViewKit

@Suite @MainActor struct GrammarBundleTests {
  /// One line of code in a bundled language, with the capture that the
  /// grammar must give for it.
  struct Sample: Sendable, CustomTestStringConvertible {
    /// The raw value of the language id.
    let language: String
    /// The code.
    let code: String
    /// The capture name that the scan of ``code`` must give. A markup
    /// language has no keyword, so it names another capture.
    let capture: String

    nonisolated init(
      language: String, code: String, capture: String = GrammarBundleTests.keywordCapture
    ) {
      self.language = language
      self.code = code
      self.capture = capture
    }

    var testDescription: String { language }
  }

  /// The largest size of the grammar folder, in bytes: 2 MB.
  static let resourceSizeLimit = 2 * 1024 * 1024

  /// The capture name of a keyword in the EditorKit capture vocabulary.
  ///
  /// ``samples`` reads it outside the main actor, as the default of
  /// ``Sample/init(language:code:capture:)``.
  nonisolated static let keywordCapture = "keyword"

  /// One sample for each bundled language.
  ///
  /// `@Test(arguments:)` reads the list outside the main actor.
  nonisolated static let samples: [Sample] = [
    Sample(language: "swift", code: "func greet() -> Int { return 1 }\n"),
    Sample(language: "python", code: "def greet():\n    return 1\n"),
    Sample(language: "typescript", code: "export function greet(): number { return 1; }\n"),
    Sample(language: "javascript", code: "export function greet() { return 1; }\n"),
    Sample(language: "rust", code: "pub fn greet() -> u32 { return 1; }\n"),
    Sample(language: "go", code: "func greet() int { return 1 }\n"),
    Sample(language: "shell", code: "if true; then exit 1; fi\n"),
    Sample(language: "yaml", code: "%YAML 1.2\n---\nkey: value\n"),
    // TOML has no keyword. The value of the pair is a boolean constant.
    Sample(language: "toml", code: "[table]\nkey = true\n", capture: "constant.builtin"),
    // HTML has no keyword. The `p` of the element is a tag name.
    Sample(language: "html", code: "<!DOCTYPE html>\n<p>text</p>\n", capture: "tag"),
    Sample(language: "css", code: "@media screen { p { color: red !important; } }\n"),
    Sample(language: "sql", code: "SELECT id FROM users WHERE id = 1;\n"),
  ]

  // MARK: - Registration

  @Test func registerLoadsEveryBundledLanguage() {
    GrammarBundle.register()

    #expect(GrammarBundle.languageIDs.count == Self.samples.count)
    for id in GrammarBundle.languageIDs {
      #expect(GrammarBundle.registry.grammar(for: id) != nil, "no grammar for \(id)")
    }
  }

  @Test func eachBundledLanguageHasOneSample() {
    let sampled = Set(Self.samples.map(\.language))
    let bundled = Set(GrammarBundle.languageIDs.map(\.rawValue))

    #expect(sampled == bundled)
  }

  @Test(arguments: samples)
  func eachGrammarHighlightsASampleToken(_ sample: Sample) throws {
    let grammar = try #require(GrammarBundle.registry.grammar(for: LanguageID(sample.language)))

    let captures = TextMateFallback.captures(in: TextBuffer(sample.code), grammar: grammar)

    #expect(
      captures.contains { $0.name == sample.capture },
      "\(sample.language) gave \(Set(captures.map(\.name)).sorted())")
  }

  @Test func aLanguageOutsideTheBundleHasNoGrammar() {
    #expect(GrammarBundle.registry.grammar(for: LanguageID("cobol")) == nil)
  }

  // MARK: - Fence tags

  @Test func theTSTagNamesTypeScript() {
    #expect(GrammarBundle.languageID(forFenceTag: "ts") == LanguageID("typescript"))
  }

  @Test(arguments: [
    ("js", "javascript"), ("py", "python"), ("rs", "rust"), ("sh", "shell"),
    ("bash", "shell"), ("zsh", "shell"), ("yml", "yaml"), ("golang", "go"),
  ])
  func aCommonTagNamesItsLanguage(tag: String, language: String) {
    #expect(GrammarBundle.languageID(forFenceTag: tag) == LanguageID(language))
  }

  @Test func eachLanguageIDIsAlsoATag() {
    for id in GrammarBundle.languageIDs {
      #expect(GrammarBundle.languageID(forFenceTag: id.rawValue) == id)
    }
  }

  @Test func theTagMatchIgnoresCaseAndOuterWhitespace() {
    #expect(GrammarBundle.languageID(forFenceTag: " TS\n") == LanguageID("typescript"))
    #expect(GrammarBundle.languageID(forFenceTag: "Bash") == LanguageID("shell"))
  }

  @Test(arguments: ["", "cobol", "json", "t s"])
  func anUnknownTagHasNoLanguage(tag: String) {
    #expect(GrammarBundle.languageID(forFenceTag: tag) == nil)
  }

  // MARK: - Load failures

  @Test func aMissingFileIsUnreadable() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("missing-\(UUID().uuidString).json")

    #expect(throws: GrammarBundle.LoadError.unreadable(url.lastPathComponent)) {
      try GrammarBundle.grammar(at: url)
    }
  }

  @Test func aFileThatIsNotAJSONObjectIsMalformed() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("malformed-\(UUID().uuidString).json")
    try Data("[1, 2]".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(throws: GrammarBundle.LoadError.malformed(url.lastPathComponent)) {
      try GrammarBundle.grammar(at: url)
    }
  }

  // MARK: - Resources

  @Test func theLicenseListNamesEachGrammarFile() throws {
    let folder = try #require(GrammarBundle.resourceFolder)
    let licenses = try String(
      contentsOf: folder.appendingPathComponent("LICENSES.md"), encoding: .utf8)

    #expect(Set(Self.licensedFileNames(in: licenses)) == Set(try Self.grammarFileNames(in: folder)))
    #expect(Self.licensedFileNames(in: licenses).count == GrammarBundle.languageIDs.count)
  }

  @Test func eachLanguageHasAGrammarFile() throws {
    let folder = try #require(GrammarBundle.resourceFolder)
    let expected = GrammarBundle.languageIDs.map { "\($0.rawValue).\(GrammarBundle.grammarExtension)" }

    #expect(Set(try Self.grammarFileNames(in: folder)) == Set(expected))
  }

  @Test func theResourceFolderIsSmallerThanTheLimit() throws {
    let folder = try #require(GrammarBundle.resourceFolder)
    let files = try FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: [.fileSizeKey])

    let size = try files.reduce(0) { total, file in
      total + (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
    }

    #expect(size > 0)
    #expect(size < Self.resourceSizeLimit)
  }

  // MARK: - Helpers

  /// The names of the grammar files in `folder`.
  ///
  /// - Parameter folder: The resource folder.
  /// - Returns: The file names.
  static func grammarFileNames(in folder: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: folder.path)
      .filter { $0.hasSuffix(".\(GrammarBundle.grammarExtension)") }
  }

  /// The file names in the first column of the license table.
  ///
  /// - Parameter licenses: The text of `LICENSES.md`.
  /// - Returns: The file names, in table order.
  static func licensedFileNames(in licenses: String) -> [String] {
    licenses.split(separator: "\n").compactMap { line in
      line.firstMatch(of: /^\| `([^`]+)` \|/).map { String($0.output.1) }
    }
  }
}
