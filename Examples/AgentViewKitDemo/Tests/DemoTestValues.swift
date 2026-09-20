import XCTest

/// The values that the end-to-end tests of each tab share.
///
/// The identifiers are the identifiers of the kit views. This test bundle
/// does not link the kit, so it writes them as text.
enum DemoTestValues {
  /// The identifier of the stock prompt editor.
  static let promptEditor = "prompt-editor"

  /// The identifier of the submit button of the composer.
  static let promptSubmit = "prompt-submit"

  /// The number of seconds that a test waits for an element.
  static let elementTimeout: TimeInterval = 20
}

extension XCUIApplication {
  /// The first element of any type with `identifier`.
  ///
  /// - Parameter identifier: The accessibility identifier.
  /// - Returns: The element.
  func element(_ identifier: String) -> XCUIElement {
    descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  /// The first element of any type whose identifier starts with `prefix`.
  ///
  /// - Parameter prefix: The start of the accessibility identifier.
  /// - Returns: The element.
  func element(withIdentifierPrefix prefix: String) -> XCUIElement {
    descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
  }
}
