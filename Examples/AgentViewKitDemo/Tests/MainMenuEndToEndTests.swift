import XCTest

/// The end-to-end tests of the agent commands in the main menu bar of the
/// demo app.
///
/// The app mirrors the registry of its one `CommandSystem` into the menu bar
/// with EditorKit `EditorMenuCommands`, so the menu bar shows the agent
/// commands of the scope that has the focus. Each test starts the app on the
/// Gallery tab and opens the scripted session `gallery-permission`, whose
/// agent message stands above a waiting permission request. The test gives
/// the focus to the message or to the card of the request, then opens a menu
/// of the menu bar, as the user does, and reads its rows.
///
/// The titles are the English titles of the kit verbs and of the system Edit
/// menu. This test bundle does not link the kit, so it writes them as text.
///
/// The XCUIAutomation API is main-actor isolated, so the class is too.
@MainActor
final class MainMenuEndToEndTests: XCTestCase {
  /// The identifier of the first paragraph of a message
  /// (`ResponseView.paragraphIdentifier(index: 0)`).
  private static let firstParagraph = "response-paragraph-0"

  /// The identifier of the title of a permission request card
  /// (`PermissionView.titleIdentifier`).
  private static let permissionTitle = "permission-title"

  /// The normalized offset of the middle of an element, for a click.
  private static let middle = CGVector(dx: 0.5, dy: 0.5)

  /// The title of the system Edit menu.
  private static let editMenu = "Edit"

  /// The title of the system Copy row of the Edit menu.
  private static let copyRow = "Copy"

  /// The title of the Session menu of the agent commands (`MenuPath.session`).
  private static let sessionMenu = "Session"

  /// The title of the Copy Message row (`AgentCommandVerb.copyMessage`).
  private static let copyMessageRow = "Copy Message"

  /// The title of the Approve Request row (`AgentCommandVerb.approvePending`).
  private static let approveRow = "Approve Request"

  /// The title of the Reject Request row (`AgentCommandVerb.rejectPending`).
  private static let rejectRow = "Reject Request"

  /// The app under test. XCTest makes one test instance for each test
  /// method, so each test has its own app.
  private let app = XCUIApplication()

  override func setUp() async throws {
    try await super.setUp()
    continueAfterFailure = false
    app.launch(arguments: DemoTestValues.galleryLaunchArguments)
  }

  override func tearDown() async throws {
    app.terminate()
    try await super.tearDown()
  }

  /// Opens a top-level menu of the menu bar.
  ///
  /// - Parameter title: The title of the menu.
  /// - Returns: The rows of the open menu.
  private func openMenu(_ title: String) -> XCUIElementQuery {
    let menuBarItem = app.menuBars.menuBarItems[title]
    XCTAssertTrue(menuBarItem.waitForExistence(timeout: DemoTestValues.elementTimeout), "The menu bar has no \(title) menu.")
    menuBarItem.click()
    return menuBarItem.menus.firstMatch.menuItems
  }

  /// The position of the row titled `title` among `rows`.
  ///
  /// - Parameters:
  ///   - title: The title of the row.
  ///   - rows: The rows of an open menu.
  /// - Returns: The index of the first row with that title.
  /// - Throws: An `XCTUnwrap` failure when no row has the title.
  private func position(of title: String, in rows: XCUIElementQuery) throws -> Int {
    let titles = rows.allElementsBoundByIndex.map(\.title)
    return try XCTUnwrap(titles.firstIndex(of: title), "The menu has no \(title) row. Its rows: \(titles)")
  }

  func testTheEditMenuShowsCopyMessageEnabledAfterCopyForTheFocusedMessage() throws {
    app.openThePermissionSession()
    // A click on the text of the message makes the selectable text the first
    // responder, which stands in the scope of the message row. The paragraph
    // is as wide as the column, and its text can end before the middle of the
    // paragraph, so the click goes to the text and not to the paragraph.
    app.element(DemoTestValues.permissionAgentMessageRow).element(Self.firstParagraph).staticTexts.firstMatch.click()

    let rows = openMenu(Self.editMenu)

    let copyMessage = rows[Self.copyMessageRow]
    XCTAssertTrue(copyMessage.exists, "The Edit menu has no Copy Message row.")
    XCTAssertTrue(copyMessage.isEnabled, "Copy Message is disabled while a message has the focus.")
    XCTAssertGreaterThan(
      try position(of: Self.copyMessageRow, in: rows), try position(of: Self.copyRow, in: rows),
      "Copy Message is not below Copy.")
  }

  func testTheSessionMenuShowsApproveAndRejectEnabledWhileARequestWaits() throws {
    app.openThePermissionSession()
    // A click on the card gives the focus to the card, which stands in the
    // scope of the request. XCUITest reports no element of the floating
    // controls of the thread as hittable, so the click goes to the point at
    // the middle of the title of the card.
    app.element(DemoTestValues.permissionCard).element(Self.permissionTitle).coordinate(withNormalizedOffset: Self.middle)
      .click()

    let rows = openMenu(Self.sessionMenu)

    for title in [Self.approveRow, Self.rejectRow] {
      let row = rows[title]
      XCTAssertTrue(row.exists, "The Session menu has no \(title) row.")
      XCTAssertTrue(row.isEnabled, "\(title) is disabled while a request waits.")
    }
  }
}
