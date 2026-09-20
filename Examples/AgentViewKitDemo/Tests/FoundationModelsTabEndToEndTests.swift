import XCTest

/// The end-to-end tests of the FoundationModels tab of the demo app.
///
/// Each test starts the app with one launch argument. `--fake-language-model`
/// binds the scripted fake model, so the test runs on a machine without the
/// system model. `--force-model-unavailable` shows the tab as if the model
/// were not available. Each of the two arguments also opens the app on the
/// FoundationModels tab.
///
/// The identifiers are the identifiers of the kit views and of the demo
/// views. This test bundle does not link the kit, so it writes them as text.
///
/// The XCUIAutomation API is main-actor isolated, so the class is too.
@MainActor
final class FoundationModelsTabEndToEndTests: XCTestCase {
  /// The launch argument that binds the fake model.
  private static let fakeLanguageModelArgument = "--fake-language-model"

  /// The launch argument that makes the model unavailable.
  private static let forceModelUnavailableArgument = "--force-model-unavailable"

  /// The start of the identifier of each assistant message. The SDK gives the
  /// reply of the fake model a new id at each turn, so the test matches the
  /// start only.
  private static let assistantMessagePrefix = "assistant-message-"

  /// The start of the identifier of each user message.
  private static let userMessagePrefix = "user-message-"

  /// The identifier of the activity timeline.
  private static let activityTimeline = "activity-timeline"

  /// The identifier of the percentage of the context usage view.
  private static let contextUsagePercent = "context-usage-percent"

  /// The identifier of the text that says why the model is not available.
  private static let unavailable = "demo-foundation-models-unavailable"

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

  /// Starts the app with one launch argument.
  ///
  /// - Parameter argument: The launch argument.
  private func launch(with argument: String) {
    app.launchArguments = [argument]
    app.launch()
  }

  func testASendOfHelloShowsTheReplyOfTheFakeModel() throws {
    launch(with: Self.fakeLanguageModelArgument)
    let editor = app.element(DemoTestValues.promptEditor)
    XCTAssertTrue(editor.waitForExistence(timeout: DemoTestValues.elementTimeout), "The composer has no editor.")
    XCTAssertTrue(app.element(Self.activityTimeline).exists, "The tab has no activity timeline.")
    XCTAssertTrue(app.element(Self.contextUsagePercent).exists, "The tab has no context usage.")

    editor.click()
    editor.typeText("hello")
    let submit = app.element(DemoTestValues.promptSubmit)
    XCTAssertTrue(submit.waitForExistence(timeout: DemoTestValues.elementTimeout))
    submit.click()

    XCTAssertTrue(
      app.element(withIdentifierPrefix: Self.assistantMessagePrefix)
        .waitForExistence(timeout: DemoTestValues.elementTimeout),
      "The thread shows no reply.")
    XCTAssertTrue(app.element(withIdentifierPrefix: Self.userMessagePrefix).exists, "The thread shows no user message.")
  }

  func testWithTheModelUnavailableTheTabShowsTheReasonAndNoComposer() throws {
    launch(with: Self.forceModelUnavailableArgument)

    XCTAssertTrue(
      app.element(Self.unavailable).waitForExistence(timeout: DemoTestValues.elementTimeout),
      "The tab shows no reason.")
    XCTAssertFalse(app.element(DemoTestValues.promptEditor).exists, "The tab shows a composer.")
  }
}
