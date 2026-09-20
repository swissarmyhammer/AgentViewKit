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

  /// The identifier of the stock prompt editor.
  private static let promptEditor = "prompt-editor"

  /// The identifier of the submit button of the composer.
  private static let promptSubmit = "prompt-submit"

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

  /// The number of seconds that a test waits for an element.
  private static let timeout: TimeInterval = 20

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

  /// The first element of any type with `identifier`.
  private func element(_ identifier: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  /// Waits until the in-memory session binds.
  private func waitForTheSession() {
    let sessionShows = element(Self.sessionRow).waitForExistence(timeout: Self.timeout)
    XCTAssertFalse(element(Self.failure).exists, "The connection failed.")
    XCTAssertTrue(sessionShows, "The sidebar shows no session.")
    XCTAssertTrue(element(Self.promptEditor).waitForExistence(timeout: Self.timeout), "The composer has no editor.")
  }

  func testASendOfHelloShowsTheReplyOfTheAgent() throws {
    waitForTheSession()
    let editor = element(Self.promptEditor)

    editor.click()
    editor.typeText("hello")
    let submit = element(Self.promptSubmit)
    XCTAssertTrue(submit.waitForExistence(timeout: Self.timeout))
    submit.click()

    XCTAssertTrue(element(Self.firstReplyRow).waitForExistence(timeout: Self.timeout), "The thread shows no reply.")
    XCTAssertTrue(element(Self.firstUserRow).exists, "The thread shows no user message.")
  }

  func testTheSettingsSheetShowsTheConnectionsAndTheAgentAuthentication() throws {
    waitForTheSession()

    element(Self.settingsButton).click()

    XCTAssertTrue(element(Self.agentAuth).waitForExistence(timeout: Self.timeout), "The sheet has no AgentAuthView.")
    XCTAssertTrue(element(Self.connectedChip).exists, "The sheet has no connected server in ConnectionsView.")
    XCTAssertFalse(element(Self.connectionsEmpty).exists, "ConnectionsView shows its empty state.")
    let done = element(Self.settingsDone)
    XCTAssertTrue(done.exists)
    done.click()
    XCTAssertTrue(
      waitForNonExistence(of: element(Self.agentAuth)), "The sheet did not close.")
  }

  /// Waits until `element` does not exist.
  private func waitForNonExistence(of element: XCUIElement) -> Bool {
    element.waitForNonExistence(timeout: Self.timeout)
  }
}
