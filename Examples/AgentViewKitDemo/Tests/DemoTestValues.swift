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

  /// The directory variables that the app gets from each test: `HOME` and
  /// the XDG Base Directory variables.
  ///
  /// Each variable names a directory in a new temporary root, so the app
  /// and the agents in its process read and write no file in the home
  /// directory. When a variable is not set, code in the app process uses a
  /// file below the home directory: for example `~/.config`, the
  /// `~/.gitconfig` that libgit2 reads through `HOME`, or the `~/.zshrc` of
  /// a shell. On a Mac where such a file is in iCloud Drive, the access
  /// shows a system permission prompt. No test can answer that prompt, and
  /// the prompt stops `terminate()` until the time limit of the gate. The
  /// tests need no file of the home directory.
  ///
  /// `XDG_CONFIG_HOME` is the first variable, because
  /// ``XCUIApplication/terminateAndRemoveTheTemporaryRoot()`` finds the
  /// root through it.
  static let xdgDirectoryVariables = ["XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "HOME"]

  /// The start of the name of the temporary root of each launch.
  static let temporaryRootPrefix = "AgentViewKitDemoUITests-"
}

extension XCUIApplication {
  /// Starts the app with `DemoTestValues.appKitArguments`, then
  /// `DemoTestValues.primaryScreenArgument`, and then `arguments`.
  ///
  /// The function also makes a new temporary root, and gives the app each
  /// variable of `DemoTestValues.xdgDirectoryVariables` as a directory in
  /// that root. ``terminateAndRemoveTheTemporaryRoot()`` removes the root.
  ///
  /// - Parameter arguments: The launch arguments of the test.
  /// - Throws: The error of the creation of the temporary root.
  func launch(arguments: [String]) throws {
    let root = FileManager.default.temporaryDirectory.appending(
      path: DemoTestValues.temporaryRootPrefix + UUID().uuidString, directoryHint: .isDirectory)
    var environment: [String: String] = [:]
    for variable in DemoTestValues.xdgDirectoryVariables {
      let directory = root.appending(path: variable, directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      environment[variable] = directory.path(percentEncoded: false)
    }
    launchEnvironment = environment
    launchArguments = DemoTestValues.appKitArguments + [DemoTestValues.primaryScreenArgument] + arguments
    launch()
  }

  /// Stops the app, and removes the temporary root that
  /// ``launch(arguments:)`` made. When the test did not start the app, the
  /// function removes nothing.
  ///
  /// - Throws: The error of the removal of the temporary root.
  func terminateAndRemoveTheTemporaryRoot() throws {
    terminate()
    guard let configHome = launchEnvironment[DemoTestValues.xdgDirectoryVariables[0]] else { return }
    let root = URL(filePath: configHome, directoryHint: .isDirectory).deletingLastPathComponent()
    guard root.lastPathComponent.hasPrefix(DemoTestValues.temporaryRootPrefix) else { return }
    try FileManager.default.removeItem(at: root)
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
