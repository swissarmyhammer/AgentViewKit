import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// A call that shows a window on the screen, or that makes the application
/// active and takes the focus from the user (AVK-12).
enum WindowFocusCall: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// A `makeKeyAndOrderFront(_:)` call, which shows a window and makes it the
  /// key window.
  case makeKeyAndOrderFront

  /// An `orderFront(_:)` call, which shows a window.
  case orderFront

  /// An `orderFrontRegardless()` call, which shows a window also when the
  /// application is not active.
  case orderFrontRegardless

  /// An `activate` call on the application, which takes the focus.
  case activateApplication

  /// A `setActivationPolicy(.regular)` call, which lets the application show
  /// in the Dock and take the focus.
  case regularActivationPolicy

  var testDescription: String { rawValue }

  /// The receivers of an application `activate` call: the shared
  /// application and the running application of the process.
  static var applicationReceiver: some RegexComponent<Substring> {
    ChoiceOf {
      "NSApp"
      "NSApplication.shared"
      "NSRunningApplication.current"
    }
  }

  /// The pattern that finds the call in a line of code.
  var pattern: Regex<Substring> {
    switch self {
    case .makeKeyAndOrderFront, .orderFront, .orderFrontRegardless:
      GlassForm.callPattern(rawValue)
    case .activateApplication:
      WordPattern.memberPattern(after: Self.applicationReceiver, GlassForm.callPattern("activate"))
    case .regularActivationPolicy:
      GlassForm.memberCallPattern("setActivationPolicy", WordPattern.wholeWord("regular"))
    }
  }
}

/// The data of ``HiddenTestWindowTests`` for the shared form checks.
extension WindowFocusCall: SampledCodeForm {
  static var sampleLines: [(form: WindowFocusCall, line: String)] { HiddenTestWindowTests.sampleCalls }

  static var lookAlikeLines: [String] { HiddenTestWindowTests.lookAlikeLines }
}

/// Holds each window of the tests off the screen, and the test process out of
/// the focus (AVK-12).
///
/// A hosted test mounts its view in a window that is never on the screen, and
/// the test process has the `.prohibited` activation policy. Thus a test run
/// shows no window and does not take the focus from the user. No test source
/// and no test-support source can show a window or make the application
/// active. The scan blanks the comments and the string literals of each file,
/// then reads the file one line at a time.
@Suite struct HiddenTestWindowTests {
  /// The directories of the test sources and of the test-support sources,
  /// relative to the package root.
  static let testSourcePaths = ["Tests", "Sources/AgentViewKitTestSupport", "Examples/ReadmeSnippets"]

  /// The files, relative to the package root, that can make a
  /// ``WindowFocusCall``, each with the reason. The list is empty: no test
  /// shows a window or takes the focus.
  static let allowedFiles: [String: String] = [:]

  /// A sample line of each call.
  static let sampleCalls: [(form: WindowFocusCall, line: String)] = [
    (.makeKeyAndOrderFront, "window.makeKeyAndOrderFront(nil)"),
    (.orderFront, "window.orderFront(nil)"),
    (.orderFrontRegardless, "panel.orderFrontRegardless()"),
    (.activateApplication, "NSApp.activate(ignoringOtherApps: true)"),
    (.activateApplication, "NSApplication.shared.activate()"),
    (.activateApplication, "NSRunningApplication.current.activate()"),
    (.regularActivationPolicy, "NSApplication.shared.setActivationPolicy(.regular)"),
  ]

  /// Lines that look like a call, but do not show a window or take the focus.
  static let lookAlikeLines = [
    "try #require(jump.activate(layer: thread))",
    "NSWorkspace.shared.activateFileViewerSelecting([url])",
    "window.orderOut(nil)",
    "application.setActivationPolicy(.prohibited)",
  ]

  @Test func eachPatternFindsOnlyItsOwnCall() {
    WindowFocusCall.expectEachSampleFindsOnlyItsOwnForm()
  }

  @Test func noPatternFindsALookAlikeLine() {
    WindowFocusCall.expectNoFormFindsALookAlikeLine()
  }

  @Test(arguments: WindowFocusCall.allCases)
  func noTestSourceShowsAWindowOrTakesTheFocus(call: WindowFocusCall) throws {
    let found = try Self.testSourcePaths.flatMap { path in
      try SourceLineScanner.codeMatches(
        inSwiftFilesBelow: PackageFiles.file(path), relativeTo: PackageFiles.root,
        skipping: Set(Self.allowedFiles.keys)
      ) { line in
        line.text.contains(call.pattern) ? ["\(line.file):\(line.number)"] : []
      }
    }

    #expect(found.isEmpty, "A hosted test shows no window and takes no focus. \(call) is in: \(found)")
  }
}
