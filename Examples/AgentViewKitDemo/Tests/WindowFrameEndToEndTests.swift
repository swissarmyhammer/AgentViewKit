import AppKit
import XCTest

/// The end-to-end tests that the demo window fits the screen it stands on.
///
/// A window taller than the visible part of its screen puts the bottom of the
/// window, where the floating controls of the thread hold the request deck and
/// the composer, below the screen. The permission request of the Gallery tab
/// once grew the window to 1558 pt on a 1440-pt display. Each test reads the
/// frame of the window from XCUITest and the visible frame of each screen from
/// AppKit, in the test runner process, and checks that the window lies within
/// the visible frame of its screen.
///
/// The XCUIAutomation API and `NSScreen` are main-actor isolated, so the class
/// is too.
@MainActor
final class WindowFrameEndToEndTests: XCTestCase {
  /// The app under test. XCTest makes one test instance for each test
  /// method, so each test has its own app.
  private let app = XCUIApplication()

  override func setUp() async throws {
    try await super.setUp()
    continueAfterFailure = false
  }

  override func tearDown() async throws {
    app.terminate()
    try await super.tearDown()
  }

  func testTheWindowOfTheGalleryTabFitsTheVisibleFrameOfItsScreen() throws {
    app.launch(arguments: DemoTestValues.galleryLaunchArguments)
    XCTAssertTrue(
      app.element(DemoTestValues.permissionSessionRow).waitForExistence(timeout: DemoTestValues.elementTimeout),
      "The Gallery lists no permission session.")

    try assertTheWindowFitsTheVisibleFrameOfItsScreen()
  }

  func testTheWindowOfTheACPTabFitsTheVisibleFrameOfItsScreen() throws {
    app.launch(arguments: [DemoTestValues.inMemoryAgentArgument])
    XCTAssertTrue(
      app.element(DemoTestValues.promptEditor).waitForExistence(timeout: DemoTestValues.elementTimeout),
      "The composer has no editor.")

    try assertTheWindowFitsTheVisibleFrameOfItsScreen()
  }

  func testTheWindowFitsTheVisibleFrameOfItsScreenWhileAPermissionRequestWaits() throws {
    app.launch(arguments: DemoTestValues.galleryLaunchArguments)
    app.openThePermissionSession()

    try assertTheWindowFitsTheVisibleFrameOfItsScreen()
  }

  /// Checks that the window of the app lies within the visible frame of the
  /// screen that holds it: the frame of the screen without the menu bar and
  /// the Dock.
  ///
  /// - Parameters:
  ///   - file: The file of the failure.
  ///   - line: The line of the failure.
  /// - Throws: An `XCTUnwrap` failure when no screen holds the window.
  private func assertTheWindowFitsTheVisibleFrameOfItsScreen(
    file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let window = app.windows.firstMatch
    XCTAssertTrue(
      window.waitForExistence(timeout: DemoTestValues.elementTimeout), "The app shows no window.", file: file,
      line: line)
    let windowFrame = window.frame
    let visibleFrame = try XCTUnwrap(
      NSScreen.visibleFrame(ofScreenHolding: windowFrame), "No screen holds the window frame \(windowFrame).",
      file: file, line: line)
    XCTAssertTrue(
      visibleFrame.contains(windowFrame),
      "The window frame \(windowFrame) does not fit the visible frame \(visibleFrame) of its screen.", file: file,
      line: line)
  }
}

extension NSScreen {
  /// The visible frame of the screen that holds the most of `frame`, in the
  /// coordinates of XCUITest.
  ///
  /// XCUITest gives the frame of an element in global coordinates whose
  /// origin is the top-left corner of the primary screen, with y down. AppKit
  /// gives the frame of a screen in global coordinates whose origin is the
  /// bottom-left corner of the primary screen, with y up. The primary screen,
  /// the one with the menu bar, is the first of `screens`.
  ///
  /// - Parameter frame: A frame in the coordinates of XCUITest, for example
  ///   the frame of a window.
  /// - Returns: The visible frame of the screen whose frame has the largest
  ///   overlap with `frame`, in the coordinates of XCUITest, or `nil` when no
  ///   screen overlaps `frame`.
  fileprivate static func visibleFrame(ofScreenHolding frame: CGRect) -> CGRect? {
    guard let primaryScreen = screens.first else { return nil }
    let primaryFrame = primaryScreen.frame
    let holdingScreen =
      screens
      .map { (frame: $0.frame.flippedVertically(in: primaryFrame), visibleFrame: $0.visibleFrame) }
      .filter { $0.frame.intersects(frame) }
      .max { $0.frame.intersection(frame).area < $1.frame.intersection(frame).area }
    return holdingScreen?.visibleFrame.flippedVertically(in: primaryFrame)
  }
}

extension CGRect {
  /// The number of square points that the rectangle covers.
  fileprivate var area: CGFloat { width * height }

  /// This rectangle, given in AppKit global coordinates (origin at the
  /// bottom-left corner of the primary screen, y up), in the global
  /// coordinates of XCUITest (origin at the top-left corner of the primary
  /// screen, y down).
  ///
  /// - Parameter primaryFrame: The AppKit frame of the primary screen.
  /// - Returns: The same rectangle with a top-left origin.
  fileprivate func flippedVertically(in primaryFrame: CGRect) -> CGRect {
    CGRect(x: minX, y: primaryFrame.maxY - maxY, width: width, height: height)
  }
}
