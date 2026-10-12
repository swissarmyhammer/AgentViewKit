import XCTest

/// The end-to-end test of the Gallery tab of the demo app.
///
/// The test starts the app on the Gallery tab. The tab starts the
/// `acp-agent` program of the sibling FoundationModelsACPAgent build over a
/// temporary copy of the recorded sessions, and lists them. The recorded
/// sessions are replaced over time, so the test does not read their content.
/// It finds the rows by the start of their identifiers.
///
/// The XCUIAutomation API is main-actor isolated, so the class is too.
@MainActor
final class GalleryTabEndToEndTests: XCTestCase {
  /// The launch argument that selects the tab of the window.
  private static let tabArgument = "--tab"

  /// The name of the Gallery tab.
  private static let galleryTab = "gallery"

  /// The launch argument that binds the in-memory agent to the ACP tab, so
  /// that the ACP tab starts no agent process.
  private static let inMemoryAgentArgument = "--in-memory-agent"

  /// The start of the identifier of each row of the session list.
  private static let sessionRowPrefix = "session-row-"

  /// The start of the identifier of each transcript row.
  private static let itemRowPrefix = "item-row-"

  /// The identifier of the text that shows a failed start of the Gallery.
  private static let failure = "demo-gallery-failure"

  /// The app under test. XCTest makes one test instance for each test
  /// method, so each test has its own app.
  private let app = XCUIApplication()

  override func setUp() async throws {
    try await super.setUp()
    continueAfterFailure = false
    app.launchArguments = [Self.inMemoryAgentArgument, Self.tabArgument, Self.galleryTab]
    app.launch()
  }

  override func tearDown() async throws {
    app.terminate()
    try await super.tearDown()
  }

  func testOpeningARecordedSessionShowsItsTranscript() throws {
    let row = app.element(withIdentifierPrefix: Self.sessionRowPrefix)
    let rowShows = row.waitForExistence(timeout: DemoTestValues.elementTimeout)
    XCTAssertFalse(app.element(Self.failure).exists, "The start of the Gallery failed.")
    XCTAssertTrue(rowShows, "The Gallery lists no recorded session.")

    row.click()

    XCTAssertTrue(
      app.element(withIdentifierPrefix: Self.itemRowPrefix).waitForExistence(timeout: DemoTestValues.elementTimeout),
      "The opened session shows no transcript row.")
  }
}
