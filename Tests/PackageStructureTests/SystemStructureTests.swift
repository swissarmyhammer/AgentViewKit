import EditorTestSupport
import Foundation
import RegexBuilder
import Testing

/// Holds the kit on the system structure (D111 steps 2 and 6, D113 answer 7).
///
/// - The kit, the demo support and the demo put no custom background and no
///   visual-effect view on a bar, the sidebar or the inspector (EditorKit
///   `style.md` rule 1), and extend no view under the sidebar. EditorKit's
///   `systemStructure` engine holds this over ``scanPaths``
///   (``StyleRuleEngineTests``).
/// - The side panel of the kit is the system `.inspector`.
/// - ``AgentThreadView`` has one top bar and one bottom bar
///   (`.safeAreaBar(edge:)`), and its list scrolls under them ("Scroll under
///   the bars"). The content of the two bars has no `.background(` fill
///   (D112 (e)). ``ThreadTopBarStructureTests`` (AVK-8am) and
///   ``ThreadBottomBarStructureTests`` (AVK-8al) hold the place of each header,
///   banner and prompt in its bar, so this suite does not check them again.
@Suite struct SystemStructureTests {
  /// The directories that the look scans read, relative to the package root:
  /// the kit, its style library, the demo support and the demo.
  static let scanPaths = KitSourceFiles.libraryPaths + ["Sources/DemoSupport", "Examples/AgentViewKitDemo"]

  /// The file of the side panel of the kit, which shows an attachment in the
  /// system inspector.
  static let inspectorFile = KitSourceFiles.kitFile("Attachments/AttachmentInspector.swift")

  /// The edges of the two bars of a thread.
  static let threadBarEdges = ["top", "bottom"]

  /// The code text before the content of each bar of a thread: the top bar
  /// block, and the floating controls of the bottom bar.
  static let threadBarStarts = [
    ThreadTopBarStructureTests.topBarStart, ThreadBottomBarStructureTests.floatingControlsStart,
  ]

  /// The fixture file with a fill in each bar, relative to the package root.
  static let filledBarsFixtureFile = "Tests/PackageStructureTests/Fixtures/SystemStructure/Bars/FilledBars.swift"

  /// The number of the fills in each bar of ``filledBarsFixtureFile``.
  static let filledBarsFixtureFillCount = 1

  /// The pattern that finds a bar of a view at one edge, such as
  /// `.safeAreaBar(edge: .top)`.
  ///
  /// - Parameter edge: The name of the edge, such as `top`.
  /// - Returns: The pattern, from ``WordPattern/memberPattern(after:_:)``.
  static func safeAreaBarPattern(edge: String) -> Regex<Substring> {
    let receiver = Regex {
      GlassForm.callPattern("safeAreaBar")
      ZeroOrMore(.whitespace)
      "edge:"
    }
    return WordPattern.memberPattern(after: receiver, WordPattern.wholeWord(edge))
  }

  /// The number of the `.background(` calls in the content of a bar of a
  /// file. A call in a comment or in a string literal does not count.
  ///
  /// - Parameters:
  ///   - start: The code text before the opening brace of the bar content.
  ///   - file: The file, relative to the package root.
  /// - Returns: The number of the calls in the block after `start`.
  /// - Throws: An error when the file cannot be read, or an issue when the
  ///   file has no block after `start`.
  static func backgroundCalls(inBarAfter start: String, of file: String) throws -> Int {
    let code = try ThreadBottomBarStructureTests.code(of: file)
    let bar = try #require(ThreadBottomBarStructureTests.block(after: start, in: code))
    return bar.matches(of: GlassForm.callPattern("background")).count
  }

  @Test func theSidePanelOfTheKitIsTheSystemInspector() throws {
    let inspectors = try ComposerGlassStructureTests.codeLineCount(
      of: GlassForm.callPattern("inspector"), in: Self.inspectorFile)

    #expect(inspectors == 1)
  }

  @Test(arguments: threadBarEdges)
  func theThreadHasOneBarAtTheEdge(edge: String) throws {
    let bars = try ComposerGlassStructureTests.codeLineCount(
      of: Self.safeAreaBarPattern(edge: edge), in: ComposerGlassStructureTests.threadFile)

    #expect(bars == 1)
  }

  @Test(arguments: threadBarStarts)
  func theContentOfEachBarOfTheThreadHasNoBackground(start: String) throws {
    let fills = try Self.backgroundCalls(inBarAfter: start, of: ComposerGlassStructureTests.threadFile)

    #expect(fills == 0, "The content of a bar is content with no fill (D112 (e)): \(start)")
  }

  @Test(arguments: threadBarStarts)
  func theBarScanCountsTheFillInEachBarOfTheFixture(start: String) throws {
    let fills = try Self.backgroundCalls(inBarAfter: start, of: Self.filledBarsFixtureFile)

    #expect(fills == Self.filledBarsFixtureFillCount)
  }
}
