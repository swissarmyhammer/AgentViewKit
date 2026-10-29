import EditorTestSupport
import Foundation
import Testing

/// A renderer that draws a view outside the window server, which a test uses
/// in the place of a capture of the real window (EditorKit `style.md`, rule 9
/// and "Review gallery").
enum StandInRenderer: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// The `CARenderer` of Core Animation, which composites a layer tree in the
  /// process.
  case coreAnimationRenderer

  /// A `cacheDisplay(in:to:)` call, which draws a view into a bitmap that
  /// shows no glass and no vibrancy.
  case cacheDisplay

  /// An `ImageRenderer(...)` of SwiftUI, which draws a view with no window
  /// and no AppKit view.
  case imageRenderer

  /// The `LayerTreeRenderer` of the old test support, which rebuilt the image
  /// of a window from its layer tree.
  case layerTreeRenderer

  var testDescription: String { rawValue }

  /// The pattern that finds the renderer in a line of code.
  var pattern: Regex<Substring> {
    switch self {
    case .coreAnimationRenderer: WordPattern.wholeWord("CARenderer")
    case .cacheDisplay: GlassForm.callPattern("cacheDisplay")
    case .imageRenderer: GlassForm.callPattern("ImageRenderer")
    case .layerTreeRenderer: WordPattern.wholeWord("LayerTreeRenderer")
    }
  }
}

/// The data of ``RealCaptureOnlyTests`` for the shared form checks.
extension StandInRenderer: SampledCodeForm {
  static var sampleLines: [(form: StandInRenderer, line: String)] { RealCaptureOnlyTests.sampleLines }

  static var lookAlikeLines: [String] { RealCaptureOnlyTests.lookAlikeLines }
}

/// Holds every screenshot and every pixel test of the package to a capture of
/// the real window from the window server (EditorKit `style.md`, rule 9).
///
/// A test shows the view in a real on-screen window and captures it with
/// EditorKit's `CapturedImage`, which takes the window from ScreenCaptureKit.
/// No test, no test-support source and no README snippet draws a view with a
/// stand-in renderer: such an image does not show what the app shows. The scan
/// blanks the comments and the string literals of each file, then reads the
/// file one line at a time.
@Suite struct RealCaptureOnlyTests {
  /// The directories of the test code, relative to the package root, with
  /// the tests of the integration package, which take the captures.
  static let testCodePaths = [
    "Sources/AgentViewKitTestSupport", "Tests", "Examples/ReadmeSnippets", IntegrationPackage.testsPath,
  ]

  /// A sample line of each renderer.
  static let sampleLines: [(form: StandInRenderer, line: String)] = [
    (.coreAnimationRenderer, "let renderer = CARenderer(mtlTexture: texture, options: nil)"),
    (.cacheDisplay, "view.cacheDisplay(in: view.bounds, to: bitmap)"),
    (.imageRenderer, "let renderer = ImageRenderer(content: view)"),
    (.layerTreeRenderer, "LayerTreeRenderer.pixels(of: hostingView, scale: 2)"),
  ]

  /// Lines that look like a renderer, but draw nothing outside the window
  /// server.
  static let lookAlikeLines = [
    "let image = try await CapturedImage(capturing: window)",
    "let cached = cacheDisplayName",
    "let renderers = ImageRendererOptions()",
    "let tree = layerTreeRenderer",
  ]

  @Test func eachPatternFindsOnlyItsOwnRenderer() {
    StandInRenderer.expectEachSampleFindsOnlyItsOwnForm()
  }

  @Test func noPatternFindsALookAlikeLine() {
    StandInRenderer.expectNoFormFindsALookAlikeLine()
  }

  @Test(arguments: StandInRenderer.allCases)
  func noTestCodeDrawsAViewWithAStandInRenderer(renderer: StandInRenderer) throws {
    let found = try Self.testCodePaths.flatMap { path in
      try SourceLineScanner.codeMatches(
        inSwiftFilesBelow: PackageFiles().file(path), relativeTo: PackageFiles().root, skipping: []
      ) { line in
        line.text.contains(renderer.pattern) ? ["\(line.file):\(line.number)"] : []
      }
    }

    #expect(found.isEmpty, "A test captures the real window. \(renderer) is in: \(found)")
  }
}
