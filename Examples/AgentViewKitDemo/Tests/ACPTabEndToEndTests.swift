import XCTest

/// The end-to-end tests of the ACP tab of the demo app.
///
/// Each test starts the app with `--in-memory-agent`, so the tab runs the
/// in-memory agent in the app process through the in-process helper and
/// starts no agent binary. The tab shows the `ConnectionModel` and the
/// `SessionModel` of the client with the kit session views.
///
/// The identifiers are the identifiers of the kit views and of the demo
/// views. This test bundle does not link the kit, so it writes them as text.
///
/// The XCUIAutomation API is main-actor isolated, so the class is too.
@MainActor
final class ACPTabEndToEndTests: XCTestCase {
  /// The launch argument that binds the in-memory agent.
  private static let inMemoryAgentArgument = "--in-memory-agent"

  /// The identifier of the row of the first reply of the in-memory agent:
  /// the row key of the agent message `demo-reply-1`.
  private static let firstReplyRow = "item-row-agent-message-demo-reply-1"

  /// The identifier of the row of the reply that the in-memory agent replays
  /// when the sidebar resumes its saved session.
  private static let replayedReplyRow = "item-row-agent-message-demo-history-reply"

  /// The start of the identifier of each transcript row. The echoed user
  /// message has a new id for each prompt, so the test finds its row by this
  /// start.
  private static let itemRowPrefix = "item-row-"

  /// The identifier of the row of the saved session in the sidebar.
  private static let sessionRow = "session-row-demo-session"

  /// The identifier of the settings button of the ACP tab.
  private static let settingsButton = "demo-acp-settings"

  /// The identifier of the button that stops the agent.
  private static let stopAgentButton = "demo-acp-stop-agent"

  /// The identifier of the Done button of the settings sheet.
  private static let settingsDone = "demo-settings-done"

  /// The identifier of the agent authentication card.
  private static let agentAuth = "agent-auth"

  /// The identifier of the empty state of the connection list.
  private static let connectionsEmpty = "connections-empty"

  /// The identifier of the disconnected connection banner.
  private static let disconnectedBanner = "agent-connection-disconnected"

  /// The identifier of the text that shows a failed start.
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

  /// Waits until the first session of the in-memory agent shows.
  private func waitForTheSession() {
    let sessionShows = app.element(Self.sessionRow).waitForExistence(timeout: DemoTestValues.elementTimeout)
    XCTAssertFalse(app.element(Self.failure).exists, "The start of the agent failed.")
    XCTAssertTrue(sessionShows, "The sidebar shows no session.")
    XCTAssertTrue(
      app.element(DemoTestValues.promptEditor).waitForExistence(timeout: DemoTestValues.elementTimeout),
      "The composer has no editor.")
  }

  /// Waits until `identifier` exists.
  ///
  /// - Parameter identifier: The accessibility identifier.
  /// - Returns: `true` when the element exists before the time limit.
  private func waitForElement(_ identifier: String) -> Bool {
    app.element(identifier).waitForExistence(timeout: DemoTestValues.elementTimeout)
  }

  func testASendOfHelloShowsTheReplyOfTheAgent() throws {
    waitForTheSession()
    let editor = app.element(DemoTestValues.promptEditor)

    editor.click()
    editor.typeText("hello")
    let submit = app.element(DemoTestValues.promptSubmit)
    XCTAssertTrue(submit.waitForExistence(timeout: DemoTestValues.elementTimeout))
    submit.click()

    XCTAssertTrue(waitForElement(Self.firstReplyRow), "The transcript shows no reply.")
    let userRow = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", Self.itemRowPrefix, Self.firstReplyRow)
    ).firstMatch
    XCTAssertTrue(userRow.exists, "The transcript shows no user message.")
  }

  func testSelectingTheSavedSessionShowsItsReplayedHistory() throws {
    waitForTheSession()

    app.element(Self.sessionRow).click()

    XCTAssertTrue(waitForElement(Self.replayedReplyRow), "The resumed session shows no replayed message.")
  }

  func testStoppingTheAgentShowsTheDisconnectedBanner() throws {
    waitForTheSession()
    XCTAssertFalse(app.element(Self.disconnectedBanner).exists, "The banner shows before the agent stops.")

    app.element(Self.stopAgentButton).click()

    XCTAssertTrue(waitForElement(Self.disconnectedBanner), "The thread shows no disconnected banner.")
  }

  func testTheSettingsSheetShowsTheAgentAuthenticationAndNoAgentConnection() throws {
    waitForTheSession()

    app.element(Self.settingsButton).click()

    // The in-memory agent lists an auth method, so the thread also shows an
    // auth card while `authState` is `.required`. Thus the test finds the
    // card of the sheet in the sheet.
    let sheet = app.sheets.firstMatch
    XCTAssertTrue(sheet.waitForExistence(timeout: DemoTestValues.elementTimeout), "No settings sheet shows.")
    XCTAssertTrue(
      sheet.element(Self.agentAuth).waitForExistence(timeout: DemoTestValues.elementTimeout),
      "The sheet has no AgentAuthView.")
    XCTAssertTrue(
      sheet.element(Self.connectionsEmpty).exists,
      "ConnectionsView shows an MCP server. The demo agent reports no MCP server.")
    let done = sheet.element(Self.settingsDone)
    XCTAssertTrue(done.exists)
    done.click()
    XCTAssertTrue(sheet.waitForNonExistence(timeout: DemoTestValues.elementTimeout), "The sheet did not close.")
  }
}
