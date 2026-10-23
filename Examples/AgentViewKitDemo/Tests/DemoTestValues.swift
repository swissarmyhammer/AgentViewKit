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

  /// The launch arguments that each test gives to the app before its own
  /// arguments.
  ///
  /// AppKit can treat a launch argument that does not start with "-", for
  /// example `gallery` in `--tab gallery`, as a document to open. Then the
  /// app opens no window, and the test finds no element. CI run 39072794341
  /// on Xcode 27.1 showed this. `-NSTreatUnknownArgumentsAsOpen NO` stops
  /// AppKit from opening such an argument.
  static let appKitArguments = ["-NSTreatUnknownArgumentsAsOpen", "NO"]
}

extension XCUIApplication {
  /// Starts the app with `DemoTestValues.appKitArguments` and then `arguments`.
  ///
  /// - Parameter arguments: The launch arguments of the test.
  func launch(arguments: [String]) {
    launchArguments = DemoTestValues.appKitArguments + arguments
    launch()
  }
}

extension XCUIElement {
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
