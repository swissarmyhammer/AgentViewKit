import XCTest

/// The end-to-end tests of the ACP tab of the demo app.
///
/// Each test starts the app with `--in-memory-agent`, so the tab binds the
/// scripted in-memory agent and starts no agent binary.
///
/// The identifiers are the identifiers of the kit views and of the demo
/// views. This test bundle does not link the kit, so it writes them as text.
///
/// The XCUIAutomation API is main-actor isolated, so the class is too.
@MainActor
final class ACPTabEndToEndTests: XCTestCase {
  /// The launch argument that binds the in-memory agent.
  private static let inMemoryAgentArgument = "--in-memory-agent"

  /// The identifier of the row of the first reply of the in-memory agent.
  private static let firstReplyRow = "item-row-demo-reply-1"

  /// The identifier of the row of the first echoed user message.
  private static let firstUserRow = "item-row-demo-user-1"

  /// The identifier of the row of the in-memory session in the sidebar.
  private static let sessionRow = "session-row-demo-session"

  /// The identifier of the settings button of the ACP tab.
  private static let settingsButton = "demo-acp-settings"

  /// The identifier of the Done button of the settings sheet.
  private static let settingsDone = "demo-settings-done"

  /// The identifier of the agent authentication card.
  private static let agentAuth = "agent-auth"

  /// The identifier of the chip of a connected server.
  private static let connectedChip = "connection-chip-connected"

  /// The identifier of the empty state of the connection list.
  private static let connectionsEmpty = "connections-empty"

  /// The identifier of the text that shows a failed connection.
  private static let failure = "demo-acp-failure"

  /// The app under test. XCTest makes one test instance for each test
  /// method, so each test has its own app.
  private let app = XCUIApplication()

  override func setUp() async throws {
    try await super.setUp()
    continueAfterFailure = false
    app.launchArguments = [Self.inMemoryAgentArgument]
    app.launch()
  }

  override func tearDown() async throws {
    app.terminate()
    try await super.tearDown()
  }

  /// Waits until the in-memory session binds.
  private func waitForTheSession() {
    let sessionShows = app.element(Self.sessionRow).waitForExistence(timeout: DemoTestValues.elementTimeout)
    XCTAssertFalse(app.element(Self.failure).exists, "The connection failed.")
    XCTAssertTrue(sessionShows, "The sidebar shows no session.")
    XCTAssertTrue(
      app.element(DemoTestValues.promptEditor).waitForExistence(timeout: DemoTestValues.elementTimeout),
      "The composer has no editor.")
  }

  func testASendOfHelloShowsTheReplyOfTheAgent() throws {
    waitForTheSession()
    let editor = app.element(DemoTestValues.promptEditor)

    editor.click()
    editor.typeText("hello")
    let submit = app.element(DemoTestValues.promptSubmit)
    XCTAssertTrue(submit.waitForExistence(timeout: DemoTestValues.elementTimeout))
    submit.click()

    XCTAssertTrue(
      app.element(Self.firstReplyRow).waitForExistence(timeout: DemoTestValues.elementTimeout),
      "The thread shows no reply.")
    XCTAssertTrue(app.element(Self.firstUserRow).exists, "The thread shows no user message.")
  }

  func testTheSettingsSheetShowsTheConnectionsAndTheAgentAuthentication() throws {
    waitForTheSession()

    app.element(Self.settingsButton).click()

    XCTAssertTrue(
      app.element(Self.agentAuth).waitForExistence(timeout: DemoTestValues.elementTimeout),
      "The sheet has no AgentAuthView.")
    XCTAssertTrue(app.element(Self.connectedChip).exists, "The sheet has no connected server in ConnectionsView.")
    XCTAssertFalse(app.element(Self.connectionsEmpty).exists, "ConnectionsView shows its empty state.")
    let done = app.element(Self.settingsDone)
    XCTAssertTrue(done.exists)
    done.click()
    XCTAssertTrue(
      waitForNonExistence(of: app.element(Self.agentAuth)), "The sheet did not close.")
  }

  /// Waits until `element` does not exist.
  private func waitForNonExistence(of element: XCUIElement) -> Bool {
    element.waitForNonExistence(timeout: DemoTestValues.elementTimeout)
  }
}
