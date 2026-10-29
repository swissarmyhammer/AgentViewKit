import EditorTestSupport
import Foundation
import Testing

/// A way for a test to mount a view in a window or a hosting view, or to
/// capture a window. Each one makes a test an integration test (plan.md §11
/// decision 21).
enum HostedMount: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// EditorKit's off-screen window harness.
  case hostedViewHarness

  /// An AppKit hosting view of a SwiftUI view.
  case hostingView

  /// An AppKit hosting controller of a SwiftUI view.
  case hostingController

  /// A window that the test makes.
  case window

  /// A panel that the test makes.
  case panel

  /// EditorKit's on-screen window of a capture.
  case captureWindow

  /// EditorKit's capture of a real window.
  case capturedImage

  /// EditorKit's capture of the window server.
  case windowCapture

  /// EditorKit's bed that captures the focus ring of a control.
  case focusRingBed

  /// EditorKit's check of the host background, which mounts and captures.
  case hostBackgroundCheck

  /// EditorKit's window of layered controls.
  case layeredControlWindow

  /// EditorKit's layout checks of a mounted view.
  case hostedLayoutExpectations

  /// EditorKit's trait that holds the UI test lock of the Mac.
  case hostedSerially

  var testDescription: String { rawValue }

  /// The pattern that finds the mount in a line of code.
  var pattern: Regex<Substring> {
    switch self {
    case .hostedViewHarness: WordPattern.wholeWord("HostedViewHarness")
    case .hostingView: WordPattern.wholeWord("NSHostingView")
    case .hostingController: WordPattern.wholeWord("NSHostingController")
    case .window: GlassForm.callPattern("NSWindow")
    case .panel: GlassForm.callPattern("NSPanel")
    case .captureWindow: WordPattern.wholeWord("CaptureWindow")
    case .capturedImage: WordPattern.wholeWord("CapturedImage")
    case .windowCapture: WordPattern.wholeWord("WindowCapture")
    case .focusRingBed: WordPattern.wholeWord("FocusRingBed")
    case .hostBackgroundCheck: WordPattern.wholeWord("HostBackgroundCheck")
    case .layeredControlWindow: WordPattern.wholeWord("LayeredControlWindow")
    case .hostedLayoutExpectations: WordPattern.wholeWord("HostedLayoutExpectations")
    case .hostedSerially: WordPattern.wholeWord("hostedSerially")
    }
  }
}

/// The data of ``RootTestsHostNoViewTests`` for the shared form checks.
extension HostedMount: SampledCodeForm {
  static var sampleLines: [(form: HostedMount, line: String)] { RootTestsHostNoViewTests.sampleLines }

  static var lookAlikeLines: [String] { RootTestsHostNoViewTests.lookAlikeLines }
}

/// Holds the root `swift test` to the unit tests (plan.md §11 decision 21).
///
/// A test that mounts a view in a window or a hosting view, or that captures
/// a window, is an integration test. It lives in the nested
/// `IntegrationTests/` package and runs with `swift test --package-path
/// IntegrationTests`. No file of the test targets of the root package makes
/// such a mount, so the root `swift test` opens no window and captures
/// nothing. The scan blanks the comments and the string literals of each
/// file, then reads the file one line at a time.
@Suite struct RootTestsHostNoViewTests {
  /// The directory of the test targets of the root package, relative to the
  /// package root.
  static let rootTestsPath = "Tests"

  /// This file, relative to the package root. Its forms name each mount as
  /// a case, so the scan skips it.
  static let scanFile = "Tests/PackageStructureTests/RootTestsHostNoViewTests.swift"

  /// A sample line of each mount.
  static let sampleLines: [(form: HostedMount, line: String)] = [
    (.hostedViewHarness, "let harness = HostedViewHarness(view, size: size)"),
    (.hostingView, "let host = NSHostingView(rootView: view)"),
    (.hostingController, "let controller = NSHostingController(rootView: view)"),
    (.window, "let window = NSWindow(contentRect: frame, styleMask: [], backing: .buffered, defer: false)"),
    (.panel, "let panel = NSPanel(contentRect: frame, styleMask: [], backing: .buffered, defer: false)"),
    (.captureWindow, "let mount = try CaptureWindow.show(view)"),
    (.capturedImage, "let image = try await CapturedImage.of(mount)"),
    (.windowCapture, "let shot = try await WindowCapture.stableCapture(of: window)"),
    (.focusRingBed, "let bed = try FocusRingBed(control)"),
    (.hostBackgroundCheck, "#expect(try await HostBackgroundCheck.showsHost(view))"),
    (.layeredControlWindow, "let layered = LayeredControlWindow(view)"),
    (.hostedLayoutExpectations, "HostedLayoutExpectations.expectMinimumHeightFitsWidth(view)"),
    (.hostedSerially, "@Suite(.serialized, .hostedSerially) struct Probe {}"),
  ]

  /// Lines that look like a mount, but mount nothing.
  static let lookAlikeLines = [
    "let harnessSize = hostedViewHarnessSize",
    "let window: NSWindow? = nil",
    "let panelStyle = NSPanelStyle.utility",
    "let images = capturedImages",
    "let host = hostingViewFrame",
  ]

  @Test func eachPatternFindsOnlyItsOwnMount() {
    HostedMount.expectEachSampleFindsOnlyItsOwnForm()
  }

  @Test func noPatternFindsALookAlikeLine() {
    HostedMount.expectNoFormFindsALookAlikeLine()
  }

  /// The places of each use of `mount` in the code of the Swift files below
  /// `path`, other than this file.
  ///
  /// - Parameters:
  ///   - mount: The mount to find.
  ///   - path: The directory, relative to the package root.
  /// - Returns: `<file>:<line>` of each use.
  /// - Throws: The error of the scan of the directory.
  static func uses(of mount: HostedMount, below path: String) throws -> [String] {
    try SourceLineScanner.codeMatches(
      inSwiftFilesBelow: PackageFiles().file(path), relativeTo: PackageFiles().root, skipping: [scanFile]
    ) { line in
      line.text.contains(mount.pattern) ? ["\(line.file):\(line.number)"] : []
    }
  }

  /// The scan finds a mount in real test code: the integration tests mount
  /// their views in EditorKit's harness. An empty result for the root tests
  /// then means that they mount nothing.
  @Test func theScanFindsTheHarnessOfTheIntegrationTests() throws {
    #expect(!(try Self.uses(of: .hostedViewHarness, below: IntegrationPackage.testsPath)).isEmpty)
  }

  @Test(arguments: HostedMount.allCases)
  func noRootTestMountsAViewOrCapturesAWindow(mount: HostedMount) throws {
    let found = try Self.uses(of: mount, below: Self.rootTestsPath)

    #expect(found.isEmpty, "A root test is a unit test: move \(mount) to IntegrationTests. Found in: \(found)")
  }
}
