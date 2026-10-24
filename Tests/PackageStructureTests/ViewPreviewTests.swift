import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// A form of code that the preview scan of ``ViewPreviewTests`` finds.
enum ViewPreviewForm: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// The declaration of a type that conforms to `View`. The declaration is a
  /// structure, a class, an enumeration, an actor or an extension. Its list of
  /// conformances contains `View` or `SwiftUI.View`. A generic constraint,
  /// such as `<Content: View>`, is not in the list of conformances. A `where`
  /// clause is also not in the list.
  case viewDeclaration

  /// The `#Preview` macro.
  case preview

  var testDescription: String { rawValue }

  /// The pattern that finds the form in the code of a file.
  var pattern: Regex<Substring> {
    switch self {
    case .viewDeclaration: Self.viewDeclarationPattern
    case .preview: Self.previewPattern
    }
  }

  /// The pattern of the name of a type, with qualifiers or with none, such as
  /// `Badge` or `Card.Row`.
  static var typeName: Regex<Substring> {
    Regex {
      OneOrMore(.word)
      ZeroOrMore {
        "."
        OneOrMore(.word)
      }
    }
  }

  /// The pattern of one item of a list of conformances, with the comma after
  /// it. An item has no `,`, no `:` and no `{`. Thus the item cannot go into
  /// a `where` clause or into the body of the type.
  static var conformanceBeforeComma: Regex<Substring> {
    Regex {
      OneOrMore(CharacterClass.anyOf(",:{").inverted)
      ","
    }
  }

  /// The pattern that finds the declaration of a type that conforms to
  /// `View`. The declaration can continue on the next lines.
  ///
  /// The pattern finds the keyword, the name, a generic clause or none, then
  /// `:`. Then it finds the items of the list of conformances up to `View`.
  /// After `View` it must find `,`, `{` or `where`.
  static var viewDeclarationPattern: Regex<Substring> {
    Regex {
      Anchor.wordBoundary
      ChoiceOf {
        "struct"
        "class"
        "enum"
        "actor"
        "extension"
      }
      OneOrMore(.whitespace)
      typeName
      Optionally {
        "<"
        ZeroOrMore(CharacterClass.anyOf(">{").inverted)
        ">"
      }
      ZeroOrMore(.whitespace)
      ":"
      ZeroOrMore(conformanceBeforeComma)
      ZeroOrMore(.whitespace)
      Optionally("SwiftUI.")
      "View"
      Lookahead {
        ZeroOrMore(.whitespace)
        ChoiceOf {
          ","
          "{"
          WordPattern.wholeWord("where")
        }
      }
    }
    .wordBoundaryKind(.simple)
  }

  /// The pattern that finds the `#Preview` macro as a whole word.
  static var previewPattern: Regex<Substring> {
    Regex {
      PreviewCoverageTests.previewMacro
      Anchor.wordBoundary
    }
    .wordBoundaryKind(.simple)
  }
}

/// The data of ``ViewPreviewTests`` for the shared form checks.
extension ViewPreviewForm: SampledCodeForm, FixtureCodeForm {
  static var sampleLines: [(form: ViewPreviewForm, line: String)] { ViewPreviewTests.sampleForms }

  static var lookAlikeLines: [String] { ViewPreviewTests.lookAlikeLines }

  static var fixtures: URL {
    get throws { try ViewPreviewTests.fixtures }
  }

  static var scan: CodeScan { .text }
}

/// Holds a `#Preview` in each view file of the kit.
///
/// A view file is a Swift file of `Sources/AgentViewKit` that declares a type
/// that conforms to `View` (``ViewPreviewForm/viewDeclaration``). Each view
/// file must contain a `#Preview`, or be on the allow list
/// (``filesWithNoPreview``). Each file on the allow list has a reason.
///
/// The scan reads the code of each Swift file. It blanks the comments and the
/// string literals, then reads each file as one text. Thus a declaration can
/// continue on the next lines.
///
/// ``PreviewCoverageTests`` does a different check. It reads only the public
/// views, and it makes sure that a preview names each of them.
@Suite struct ViewPreviewTests {
  /// The view files of the kit that have no `#Preview`, relative to the
  /// package root, each with the reason. Each view of these files has no look
  /// of its own, so a preview cannot show it.
  static let filesWithNoPreview = [
    KitSourceFiles.kitFile("Accessibility/ThreadAccessibility.swift"):
      "SessionAnnouncementObserver draws nothing. It only sends the announcements of a session to VoiceOver.",
    KitSourceFiles.kitFile("Content/MathMarkdownParser.swift"):
      "MathSpanAccessibility draws nothing. It only gives an accessibility element to each math span of a text.",
    KitSourceFiles.kitFile("Citations/CitationProse.swift"):
      "InlineCitationAccessibility draws nothing. It only gives an accessibility element to each citation pill.",
    KitSourceFiles.kitFile("Commands/HostPathContextMenu.swift"):
      "HostPathContextMenuItems is the content of a system context menu. The menu draws the items, so it has no look of its own.",
  ]

  /// A sample line of each form, with only that form on the line.
  static let sampleForms: [(form: ViewPreviewForm, line: String)] = [
    (.viewDeclaration, "struct PlainRow: View {"),
    (.viewDeclaration, "public struct Marked: Equatable, View {"),
    (.viewDeclaration, "struct GenericCard<Content: View>: View {"),
    (.viewDeclaration, "public final class Holder: SwiftUI.View {"),
    (.viewDeclaration, "enum Placeholder: View, Sendable {"),
    (.viewDeclaration, "extension Badge: View {"),
    (.viewDeclaration, "struct Bounded<Item>: View where Item: Sendable {"),
    (.preview, "#Preview {"),
    (.preview, "#Preview(\"Dark\") {"),
  ]

  /// Lines that look like a form, but declare no view and start no preview.
  static let lookAlikeLines = [
    "struct Harness<Content: View> {",
    "struct Boxed<Item>: Sendable where Item: View {",
    "struct Dimmed: ViewModifier {",
    "protocol Card: View {",
    "struct Layout: View.Body {",
    "func make<Content: View>(_ content: Content) -> some View {",
    "var body: some View {",
    "class var shared: View {",
    "struct Row_Previews: PreviewProvider {",
    ".previewLayout(.sizeThatFits)",
  ]

  /// The fixture directory of the form scan.
  static var fixtures: URL {
    get throws { try PackageFiles.file("Tests/PackageStructureTests/Fixtures/ViewPreview") }
  }

  /// The fixture directory, relative to ``fixtures``, with view files that
  /// have a preview, view files that have none, and files with no view.
  static let violatingFixtures = "Violating"

  /// The fixture file with views and no preview, relative to ``fixtures``.
  static let violatingFixtureFile = "\(violatingFixtures)/NoPreview.swift"

  /// Each form of ``violatingFixtures``, and the place where each use starts.
  static let violatingFixtureForms: [(form: ViewPreviewForm, uses: [String])] = [
    (
      .viewDeclaration,
      ["\(violatingFixtureFile):5", "\(violatingFixtureFile):9", "\(violatingFixtures)/WithPreview.swift:5"]
    ),
    (.preview, ["\(violatingFixtures)/WithPreview.swift:9"]),
  ]

  /// Each file on the allow list, in path order.
  static let allowedFiles = filesWithNoPreview.keys.sorted()

  /// Finds the files that use a form, in the code of each Swift file below a
  /// directory.
  ///
  /// - Parameters:
  ///   - form: The form to find.
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the path of each file is relative to.
  /// - Returns: The paths of the files, relative to `base`.
  /// - Throws: The error of ``CodeScan/uses(of:inSwiftFilesBelow:relativeTo:)``.
  static func files(using form: ViewPreviewForm, inSwiftFilesBelow directory: URL, relativeTo base: URL) throws
    -> Set<String>
  {
    let uses = try ViewPreviewForm.scan.uses(of: form.pattern, inSwiftFilesBelow: directory, relativeTo: base)
    return Set(uses.map { String($0.prefix { $0 != ":" }) })
  }

  /// Finds the view files with no `#Preview`, in the code of each Swift file
  /// below a directory.
  ///
  /// - Parameters:
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the path of each file is relative to.
  ///   - allowed: The files, relative to `base`, that can have no preview.
  /// - Returns: The paths of the files, relative to `base`, in path order.
  /// - Throws: The error of ``files(using:inSwiftFilesBelow:relativeTo:)``.
  static func viewFilesWithNoPreview(
    inSwiftFilesBelow directory: URL, relativeTo base: URL, allowing allowed: Set<String> = []
  ) throws -> [String] {
    let views = try files(using: .viewDeclaration, inSwiftFilesBelow: directory, relativeTo: base)
    let previews = try files(using: .preview, inSwiftFilesBelow: directory, relativeTo: base)
    return views.subtracting(previews).subtracting(allowed).sorted()
  }

  @Test func eachPatternFindsOnlyItsOwnForm() {
    ViewPreviewForm.expectEachSampleFindsOnlyItsOwnForm()
  }

  @Test func noPatternFindsALookAlikeLine() {
    ViewPreviewForm.expectNoFormFindsALookAlikeLine()
  }

  @Test func theViewDeclarationPatternFindsAListOfConformancesOnMoreThanOneLine() {
    let declaration = """
      struct GenericCard<Content: View>: Sendable,
        View
      {
      """

    #expect(ViewPreviewForm.forms(in: declaration) == [.viewDeclaration])
  }

  @Test func eachViewFileOfTheKitHasAPreview() throws {
    let kit = try PackageFiles.file(KitSourceFiles.kitPath)
    let views = try Self.files(using: .viewDeclaration, inSwiftFilesBelow: kit, relativeTo: PackageFiles.root)

    let missing = try Self.viewFilesWithNoPreview(
      inSwiftFilesBelow: kit, relativeTo: PackageFiles.root, allowing: Set(Self.filesWithNoPreview.keys))

    #expect(!views.isEmpty)
    #expect(
      missing.isEmpty,
      """
      Add a #Preview that shows the view to each file. If a view has no look of its own, \
      add the file and the reason to the allow list: \(missing)
      """)
  }

  @Test func theScanReportsTheViewFileWithNoPreviewInTheViolatingFixture() throws {
    let found = try Self.viewFilesWithNoPreview(
      inSwiftFilesBelow: Self.fixtures.appending(path: Self.violatingFixtures), relativeTo: Self.fixtures)

    #expect(found == [Self.violatingFixtureFile])
  }

  @Test(arguments: violatingFixtureForms)
  func theScanReportsTheFormInTheViolatingFixture(form: ViewPreviewForm, uses: [String]) throws {
    let found = try ViewPreviewForm.fixtureUses(of: form, in: Self.violatingFixtures)

    #expect(found == uses)
  }

  @Test(arguments: ViewPreviewForm.allCases)
  func theScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture(form: ViewPreviewForm) throws {
    try form.expectNoUseInTheCleanFixture()
  }

  /// A file on the allow list that gets a `#Preview`, or that no longer
  /// declares a view, must leave the list. Thus the list stays exact.
  @Test(arguments: allowedFiles)
  func eachAllowedFileDeclaresAViewAndHasNoPreview(file: String) throws {
    let code = try ThreadBottomBarStructureTests.code(of: file)

    let declaresAView = code.contains(ViewPreviewForm.viewDeclaration.pattern)
    let hasAPreview = code.contains(ViewPreviewForm.preview.pattern)

    #expect(declaresAView, "\(file) declares no view")
    #expect(!hasAPreview, "\(file) has a #Preview")
  }
}
