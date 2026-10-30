import XCTest

/// The values that the end-to-end tests of each tab share.
///
/// The identifiers are the identifiers of the kit views. This test bundle
/// does not link the kit, so it writes them as text.
enum DemoTestValues {
  /// The identifier of the text area of the prompt editor
  /// (`EditorKitPromptEditor.identifier`).
  static let promptEditor = "prompt-editor"

  /// The identifier of the submit button of the composer.
  static let promptSubmit = "prompt-submit"

  /// The number of seconds that a test waits for an element.
  static let elementTimeout: TimeInterval = 20

  /// The launch argument that binds the in-memory agent to the ACP tab, so
  /// that the ACP tab loads no model.
  static let inMemoryAgentArgument = "--in-memory-agent"

  /// The launch arguments that open the window on the Gallery tab, with the
  /// in-memory agent on the ACP tab.
  static let galleryLaunchArguments = [inMemoryAgentArgument, "--tab", "gallery"]

  /// The launch argument that opens the window on the primary screen, the
  /// one whose frame origin is (0, 0)
  /// (`DemoLaunchOptions.primaryScreenArgument`).
  ///
  /// This is a test-environment switch. The demo window opens on the screen
  /// that the user is working on, and XCTest's hit test fails for a window
  /// on a screen that lies above or left of the primary screen, where the
  /// global coordinates are negative.
  static let primaryScreenArgument = "--primary-screen"

  /// The identifier of the row of the scripted permission session in the
  /// session list of the Gallery tab.
  static let permissionSessionRow = "session-row-gallery-permission"

  /// The identifier of the row of the agent message of the permission
  /// session.
  static let permissionAgentMessageRow = "item-row-agent-message-gallery-permission-reply"

  /// The identifier of the card of a waiting permission request
  /// (`PermissionView.identifier`).
  static let permissionCard = "permission-card"

  /// The launch arguments that each test gives to the app before its own
  /// arguments.
  ///
  /// AppKit can treat a launch argument that does not start with "-", for
  /// example `gallery` in `--tab gallery`, as a document to open. Then the
  /// app opens no window, and the test finds no element. CI run 39072794341
  /// on Xcode 27.1 showed this. `-NSTreatUnknownArgumentsAsOpen NO` stops
  /// AppKit from opening such an argument.
  ///
  /// AppKit also restores the windows of the last run, by an identifier that
  /// SwiftUI derives from the type of the content of the `WindowGroup`. When a
  /// change gives the content a new type, the saved identifier matches no
  /// window, and the app opens none. `-ApplePersistenceIgnoreState YES` stops
  /// the restore, so each test starts from the window that the app makes.
  static let appKitArguments = ["-NSTreatUnknownArgumentsAsOpen", "NO", "-ApplePersistenceIgnoreState", "YES"]
}

extension XCUIApplication {
  /// Starts the app with `DemoTestValues.appKitArguments`, then
  /// `DemoTestValues.primaryScreenArgument`, and then `arguments`.
  ///
  /// - Parameter arguments: The launch arguments of the test.
  func launch(arguments: [String]) {
    launchArguments = DemoTestValues.appKitArguments + [DemoTestValues.primaryScreenArgument] + arguments
    launch()
  }

  /// Opens the scripted permission session of the Gallery tab with a double
  /// click on its row, and waits until its agent message and its waiting
  /// request show. A single click only selects the row.
  ///
  /// The app must run on the Gallery tab
  /// (`DemoTestValues.galleryLaunchArguments`).
  func openThePermissionSession() {
    let row = element(DemoTestValues.permissionSessionRow)
    XCTAssertTrue(row.appears(), "The Gallery lists no permission session.")
    row.doubleClick()
    XCTAssertTrue(
      element(DemoTestValues.permissionAgentMessageRow).appears(),
      "The permission session shows no agent message.")
    XCTAssertTrue(
      element(DemoTestValues.permissionCard).appears(),
      "The permission session shows no waiting request.")
  }
}

extension XCUIElement {
  /// Whether the element shows: true at once when it already exists, and
  /// otherwise after the wait of `DemoTestValues.elementTimeout`. The check of
  /// `exists` first skips the wait for an element that is there.
  ///
  /// - Returns: Whether the element exists.
  func appears() -> Bool {
    exists || waitForExistence(timeout: DemoTestValues.elementTimeout)
  }

  /// The first element of any type with `identifier` under this element.
  ///
  /// - Parameter identifier: The accessibility identifier.
  /// - Returns: The element.
  func element(_ identifier: String) -> XCUIElement {
    descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  /// The first element of any type under this element whose identifier
  /// starts with `prefix`.
  ///
  /// - Parameter prefix: The start of the accessibility identifier.
  /// - Returns: The element.
  func element(withIdentifierPrefix prefix: String) -> XCUIElement {
    descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
  }
}
