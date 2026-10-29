import EditorTestSupport
import Foundation
import RegexBuilder
import Testing

/// The kind of a top-level declaration that names a type or a function.
enum TopLevelDeclaration: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// A `struct` declaration.
  case structure = "struct"

  /// A `class` declaration, also a `final class`.
  case classType = "class"

  /// An `enum` declaration.
  case enumeration = "enum"

  /// An `actor` declaration.
  case actorType = "actor"

  /// A `protocol` declaration.
  case protocolType = "protocol"

  /// A `typealias` declaration.
  case typeAlias = "typealias"

  /// A `func` declaration.
  case function = "func"

  var testDescription: String { rawValue }

  /// An attribute before a declaration, such as `@MainActor` or
  /// `@available(macOS 27, *)`.
  static var attribute: some RegexComponent<Substring> {
    Regex {
      "@"
      OneOrMore(.word)
      Optionally {
        "("
        ZeroOrMore(CharacterClass.anyOf(")").inverted)
        ")"
      }
    }
  }

  /// A modifier word before a declaration, such as `public` or `final`.
  static var modifier: some RegexComponent<Substring> {
    ChoiceOf {
      "public"
      "package"
      "internal"
      "fileprivate"
      "private"
      "open"
      "final"
      "nonisolated"
      "indirect"
      "static"
    }
  }

  /// The name of a declaration: a Swift identifier.
  static var identifier: some RegexComponent<Substring> {
    Regex {
      CharacterClass(.word).subtracting(.digit)
      ZeroOrMore(.word)
    }
  }

  /// The start of the declaration at the start of a line: its attributes,
  /// its modifiers and its keyword, up to its name.
  var keywordPrefix: some RegexComponent<Substring> {
    Regex {
      Anchor.startOfSubject
      ZeroOrMore(.whitespace)
      ZeroOrMore {
        ChoiceOf {
          Self.attribute
          Self.modifier
        }
        OneOrMore(.whitespace)
      }
      rawValue
      OneOrMore(.whitespace)
    }
  }

  /// The pattern that finds the declaration in a line of code.
  var pattern: Regex<Substring> {
    Regex {
      keywordPrefix
      Self.identifier
    }
  }

  /// The pattern of ``pattern`` that captures the declared name.
  var namePattern: Regex<(Substring, Substring)> {
    Regex {
      keywordPrefix
      Capture { Self.identifier }
    }
  }

  /// The name of the declaration on a line, or `nil` when the line does not
  /// start with a declaration of this kind.
  ///
  /// - Parameter line: The line of code.
  /// - Returns: The declared name.
  func name(on line: Substring) -> String? {
    line.firstMatch(of: namePattern).map { String($0.output.1) }
  }
}

/// The data of ``NoEditorKitDuplicateTests`` for the shared form checks.
extension TopLevelDeclaration: SampledCodeForm {
  static var sampleLines: [(form: TopLevelDeclaration, line: String)] { NoEditorKitDuplicateTests.sampleLines }

  static var lookAlikeLines: [String] { NoEditorKitDuplicateTests.lookAlikeLines }
}

/// Holds the test support of the package free of copies of EditorKit's
/// generic test helpers (card ^t3eq162).
///
/// The generic helpers, such as the hosted view harness and the observation
/// waits, live in EditorKit's `EditorTestSupport`, and the review gallery in
/// its `EditorReviewGallery`, so that EditorKit, AgentViewKit and
/// KanbanViewKit share one copy; the package files of a test are EditorKit's
/// `PackageFiles` too. `AgentViewKitTestSupport` keeps only the agent-specific
/// helpers. A top-level type or function of the package's own test code
/// (``scannedPaths``) whose name EditorKit's test support also declares is a
/// copy, and fails the suite. The scan blanks the comments and
/// the string literals of each file, then reads each line at brace depth 0:
/// a member of a type or of an extension is not top level.
@Suite struct NoEditorKitDuplicateTests {
  /// The directories of the package's own test code, relative to the package
  /// root: the agent test support, the package file support of the tests (the
  /// decision-record table reader, after its copy of EditorKit's
  /// `PackageFiles` went), and the test targets.
  static let scannedPaths = ["Sources/AgentViewKitTestSupport", "Sources/PackageFileSupport", "Tests"]

  /// The checkout of EditorKit that SwiftPM resolves, relative to the
  /// package root.
  static let editorKitCheckoutPath = ".build/checkouts/EditorKit"

  /// The directories of EditorKit's test support, relative to its checkout.
  static let editorKitTestSupportPaths = ["Sources/EditorTestSupport", "Sources/EditorReviewGallery"]

  /// A sample line of each declaration kind.
  static let sampleLines: [(form: TopLevelDeclaration, line: String)] = [
    (.structure, "@MainActor public struct AccessibilityElementSnapshot: Equatable, Sendable {"),
    (.classType, "public final class HostedViewHarness<Content: View> {"),
    (.classType, "nonisolated final class ChangeFlag: Sendable {"),
    (.enumeration, "public enum ObservationWait {"),
    (.actorType, "actor Recorder {"),
    (.protocolType, "@available(macOS 27, *) public protocol RenderedMount {"),
    (.typeAlias, "public typealias Handler = () -> Void"),
    (.function, "  @MainActor public func views<V: NSView>(ofType type: V.Type, in root: NSView) -> [V] {"),
  ]

  /// Lines that look like a declaration, but declare no type and no
  /// function.
  static let lookAlikeLines = [
    "let classification = structure.enumCase",
    "extension HostedViewHarness: RenderedMount {}",
    "import class EditorTestSupport.RecordingAnnouncer",
    "static let enumCount = 3",
    "let actor = Actor()",
    "funcName = protocolName",
  ]

  /// A source with a declaration of each depth, and the top-level names in
  /// it.
  static let depthSample = (
    source: """
      public enum Outer {
        struct Inner {}
        func member() {}
      }
      extension NSView {
        public var descendants: [NSView] { [] }
        func hidden() {}
      }
      #if canImport(AppKit)
        public func free() {}
      #endif
      """,
    topLevelNames: ["Outer", "free"]
  )

  /// The top-level names of a code text, each with its line number.
  ///
  /// A line is top level when the braces before it are balanced.
  ///
  /// - Parameter code: The code, with the comments and the string literals
  ///   blanked.
  /// - Returns: The name and the line number of each top-level declaration,
  ///   in line order.
  static func topLevelNames(in code: String) -> [(name: String, line: Int)] {
    var depth = 0
    var names: [(name: String, line: Int)] = []
    for (offset, line) in code.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
      if depth == 0, let name = TopLevelDeclaration.allCases.lazy.compactMap({ $0.name(on: line) }).first {
        names.append((name, offset + 1))
      }
      depth += line.count { $0 == "{" } - line.count { $0 == "}" }
    }
    return names
  }

  /// The places of each top-level name of the Swift files below a directory.
  ///
  /// - Parameters:
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the file name of each place is relative to.
  /// - Returns: `<file>:<line>` of each declaration, by name.
  /// - Throws: The error of
  ///   ``SourceLineScanner/codeTexts(inSwiftFilesBelow:relativeTo:skipping:)``.
  static func declarations(inSwiftFilesBelow directory: URL, relativeTo base: URL) throws -> [String: [String]] {
    try SourceLineScanner.codeTexts(inSwiftFilesBelow: directory, relativeTo: base, skipping: [])
      .flatMap { file in topLevelNames(in: file.code).map { (name: $0.name, place: "\(file.path):\($0.line)") } }
      .reduce(into: [:]) { places, declaration in places[declaration.name, default: []].append(declaration.place) }
  }

  @Test func eachPatternFindsOnlyItsOwnDeclaration() {
    TopLevelDeclaration.expectEachSampleFindsOnlyItsOwnForm()
  }

  @Test func noPatternFindsALookAlikeLine() {
    TopLevelDeclaration.expectNoFormFindsALookAlikeLine()
  }

  @Test func eachSampleLineGivesItsName() {
    let names = Self.sampleLines.map { $0.form.name(on: Substring($0.line)) }

    #expect(
      names == [
        "AccessibilityElementSnapshot", "HostedViewHarness", "ChangeFlag", "ObservationWait", "Recorder",
        "RenderedMount", "Handler", "views",
      ])
  }

  @Test func onlyTheDeclarationsAtBraceDepthZeroAreTopLevel() {
    let names = Self.topLevelNames(in: Self.depthSample.source).map(\.name)

    #expect(names == Self.depthSample.topLevelNames)
  }

  @Test func noTestCodeDeclarationCopiesEditorKitTestSupport() throws {
    let package = PackageFiles()
    let checkout = package.root.appending(path: Self.editorKitCheckoutPath)
    let checkoutExists = FileManager.default.fileExists(atPath: checkout.path(percentEncoded: false))
    try #require(
      checkoutExists,
      "The EditorKit checkout is not at \(Self.editorKitCheckoutPath). Run `swift package resolve` in the package root."
    )
    let editorKitNames = try Self.editorKitTestSupportPaths.reduce(into: Set<String>()) { names, path in
      names.formUnion(
        try Self.declarations(inSwiftFilesBelow: checkout.appending(path: path), relativeTo: checkout).keys)
    }
    let ownDeclarations = try Self.scannedPaths.reduce(into: [String: [String]]()) { places, path in
      places.merge(
        try Self.declarations(inSwiftFilesBelow: package.file(path), relativeTo: package.root), uniquingKeysWith: +)
    }

    let copies = ownDeclarations
      .filter { editorKitNames.contains($0.key) }
      .sorted { $0.key < $1.key }
      .map { "\($0.key) (\($0.value.joined(separator: ", ")))" }

    #expect(copies.isEmpty, "EditorKit's test support declares these names. Use its copy: \(copies)")
  }
}
