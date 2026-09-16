import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``ElicitationView``.
@Suite(.serialized) @MainActor struct ElicitationViewHostedTests {
  /// The longest time that a test waits for an action call, in seconds.
  static let callWaitSeconds: TimeInterval = 1

  /// The size of a hosted form.
  static let formSize = CGSize(width: 520, height: 480)

  /// The accessibility identifier of the button in the custom footer.
  static let customFooterIdentifier = "custom-footer-refuse"

  /// The accessibility identifier of the text in the custom footer that
  /// shows the Submit state.
  static let customFooterStateIdentifier = "custom-footer-state"

  /// The accessibility identifier of the text in the custom header.
  static let customHeaderIdentifier = "custom-header"

  // MARK: - Fixtures

  /// A property schema of a single-choice field with the values `red` and
  /// `blue`.
  static let colorProperty: JSONValue = .object([
    "type": .string("string"),
    "title": .string("Color"),
    "enum": .array([.string("red"), .string("blue")]),
  ])

  /// A property schema of a boolean field.
  static let agreeProperty: JSONValue = .object([
    "type": .string("boolean"),
    "title": .string("Agree"),
  ])

  /// A property schema of a number field with a default.
  static let countProperty: JSONValue = .object([
    "type": .string("integer"),
    "title": .string("Count"),
    "minimum": .number(1),
    "maximum": .number(9),
    "default": .number(3),
  ])

  /// Makes a form request.
  ///
  /// - Parameters:
  ///   - properties: The property schemas, keyed by name.
  ///   - required: The names of the required properties.
  /// - Returns: The request.
  static func request(
    properties: [String: JSONValue],
    required: [String] = []
  ) -> ElicitationRequest {
    ElicitationRequest(
      id: ElicitationRequestID("form-test"),
      server: "Weather",
      message: "Select a color.",
      mode: .form(
        requestedSchema: .object([
          "type": .string("object"),
          "properties": .object(properties),
          "required": .array(required.map(JSONValue.string)),
        ]))
    )
  }

  /// A request with one required single-choice field.
  static var oneFieldRequest: ElicitationRequest {
    request(properties: ["color": colorProperty], required: ["color"])
  }

  /// A request with three fields.
  static var threeFieldRequest: ElicitationRequest {
    request(
      properties: ["color": colorProperty, "agree": agreeProperty, "count": countProperty],
      required: ["color"])
  }

  /// Mounts a form in the environment that a test gives.
  ///
  /// - Parameters:
  ///   - request: The request to show.
  ///   - actions: The actions that record each call.
  ///   - reporter: The reporter that records each focus move.
  ///   - content: The function that changes the form, such as a slot
  ///     override.
  /// - Returns: The harness.
  static func mount<Content: View>(
    _ request: ElicitationRequest,
    actions: NoopThreadActions = NoopThreadActions(),
    reporter: RecordingFocusReporter = RecordingFocusReporter(),
    @ViewBuilder content: (ElicitationView) -> Content
  ) -> HostedViewHarness<AnyView> {
    let view = content(ElicitationView(request: request))
      .environment(\.threadActions, actions)
      .environment(\.focusReporter, reporter)
    let harness = HostedViewHarness(AnyView(view), size: formSize)
    harness.pump()
    return harness
  }

  /// Mounts a form with no slot override.
  static func mount(
    _ request: ElicitationRequest,
    actions: NoopThreadActions = NoopThreadActions(),
    reporter: RecordingFocusReporter = RecordingFocusReporter()
  ) -> HostedViewHarness<AnyView> {
    mount(request, actions: actions, reporter: reporter) { $0 }
  }

  /// The identifiers of the tab elements of a harness.
  static func tabIdentifiers(_ harness: HostedViewHarness<AnyView>) -> Set<String> {
    Set(
      harness.accessibilityElements().compactMap(\.identifier).filter {
        $0.hasPrefix(ElicitationView.tabIdentifierPrefix)
      })
  }

  /// The elicitation results that `actions` recorded.
  static func results(_ actions: NoopThreadActions) -> [ElicitationResult] {
    actions.calls.compactMap { call in
      guard case .respondToElicitation(_, let result) = call else { return nil }
      return result
    }
  }

  // MARK: - Identifiers

  @Test func theIdentifiersHaveTheDocumentedForm() {
    #expect(ElicitationView.formIdentifier == "elicitation-form")
    #expect(ElicitationView.tabIdentifier(for: "color") == "elicitation-tab-color")
    #expect(ElicitationView.submitIdentifier == "elicitation-submit")
    #expect(ElicitationView.declineIdentifier == "elicitation-decline")
    #expect(ElicitationView.cancelIdentifier == "elicitation-cancel")
  }

  // MARK: - Layout

  @Test func aOneFieldRequestShowsTheFieldInlineWithNoTabs() {
    let harness = Self.mount(Self.oneFieldRequest)
    defer { harness.close() }

    #expect(harness.element(identifier: ElicitationView.formIdentifier) != nil)
    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "color")) != nil)
    #expect(Self.tabIdentifiers(harness).isEmpty)
  }

  @Test func aThreeFieldRequestShowsOneTabForEachField() {
    let harness = Self.mount(Self.threeFieldRequest)
    defer { harness.close() }

    #expect(
      Self.tabIdentifiers(harness) == [
        ElicitationView.tabIdentifier(for: "agree"),
        ElicitationView.tabIdentifier(for: "color"),
        ElicitationView.tabIdentifier(for: "count"),
      ])
  }

  @Test func aTabPressShowsTheFieldOfTheTab() throws {
    let harness = Self.mount(Self.threeFieldRequest)
    defer { harness.close() }

    // The fields are in name order, so the first tab is `agree`.
    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "agree")) != nil)
    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "count")) == nil)

    try harness.press(identifier: ElicitationView.tabIdentifier(for: "count"))

    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "count")) != nil)
    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "agree")) == nil)
  }

  @Test func aTabShowsTheRequiredAndAnsweredMarks() throws {
    let harness = Self.mount(Self.threeFieldRequest)
    defer { harness.close() }

    let color = try #require(harness.element(identifier: ElicitationView.tabIdentifier(for: "color")))
    #expect(color.value == ElicitationTabMarks.text(required: true, answered: false))

    // The `count` field has a default, so its tab shows the answered mark.
    let count = try #require(harness.element(identifier: ElicitationView.tabIdentifier(for: "count")))
    #expect(count.value == ElicitationTabMarks.text(required: false, answered: true))
  }

  @Test func aLargerTabThresholdShowsThreeFieldsInline() {
    let harness = Self.mount(Self.threeFieldRequest) { form in
      form.elicitationLayout(tabThreshold: 3)
    }
    defer { harness.close() }

    #expect(Self.tabIdentifiers(harness).isEmpty)
    for name in ["agree", "color", "count"] {
      #expect(harness.element(identifier: ElicitationFieldView.identifier(for: name)) != nil)
    }
  }

  @Test func aCustomLayoutGetsEachField() {
    let harness = Self.mount(Self.threeFieldRequest) { form in
      form.elicitationLayout { layout in
        Text(layout.fields.map(\.schema.name).joined(separator: ","))
          .accessibilityIdentifier("custom-layout")
      }
    }
    defer { harness.close() }

    #expect(harness.element(identifier: "custom-layout")?.label == "agree,color,count")
    #expect(Self.tabIdentifiers(harness).isEmpty)
  }

  // MARK: - Header

  @Test func theDefaultHeaderNamesTheServerAndShowsTheMessage() {
    let harness = Self.mount(Self.oneFieldRequest)
    defer { harness.close() }

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains("Weather") })
    #expect(labels.contains("Select a color."))
  }

  @Test func aCustomHeaderReplacesTheDefaultHeader() {
    let harness = Self.mount(Self.oneFieldRequest) { form in
      form.elicitationHeader { request in
        Text("Banner for \(request.server)")
          .accessibilityIdentifier(Self.customHeaderIdentifier)
      }
    }
    defer { harness.close() }

    #expect(harness.element(identifier: Self.customHeaderIdentifier)?.label == "Banner for Weather")
    #expect(harness.element(identifier: ElicitationView.headerIdentifier) == nil)
  }

  // MARK: - Gate

  @Test func submitIsDisabledUntilEachRequiredFieldValidates() throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(Self.oneFieldRequest, actions: actions)
    defer { harness.close() }

    let before = try #require(harness.element(identifier: ElicitationView.submitIdentifier))
    #expect(!before.isEnabled)

    try harness.press(
      identifier: ElicitationFieldView.choiceIdentifier(for: "color", value: "blue"))

    let after = try #require(harness.element(identifier: ElicitationView.submitIdentifier))
    #expect(after.isEnabled)
  }

  // MARK: - Actions

  @Test func submitSendsTheValuesOfTheForm() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(Self.threeFieldRequest, actions: actions)
    defer { harness.close() }

    try harness.press(identifier: ElicitationView.tabIdentifier(for: "color"))
    try harness.press(
      identifier: ElicitationFieldView.choiceIdentifier(for: "color", value: "red"))
    try harness.press(identifier: ElicitationView.submitIdentifier)
    await harness.pump(until: Self.callWaitSeconds) { !actions.calls.isEmpty }

    #expect(
      Self.results(actions) == [
        .accept(.object(["color": .string("red"), "count": .number(3)]))
      ])
    #expect(actions.calls.first.map { call in
      guard case .respondToElicitation(let request, _) = call else { return false }
      return request == Self.threeFieldRequest
    } == true)
  }

  @Test func declineSendsDecline() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(Self.oneFieldRequest, actions: actions)
    defer { harness.close() }

    try harness.press(identifier: ElicitationView.declineIdentifier)
    await harness.pump(until: Self.callWaitSeconds) { !actions.calls.isEmpty }

    #expect(Self.results(actions) == [.decline])
  }

  @Test func cancelSendsCancel() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(Self.oneFieldRequest, actions: actions)
    defer { harness.close() }

    try harness.press(identifier: ElicitationView.cancelIdentifier)
    await harness.pump(until: Self.callWaitSeconds) { !actions.calls.isEmpty }

    #expect(Self.results(actions) == [.cancel])
  }

  @Test func escapeSendsCancel() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(Self.oneFieldRequest, actions: actions)
    defer { harness.close() }

    try harness.sendKey(.escape)
    await harness.pump(until: Self.callWaitSeconds) { !actions.calls.isEmpty }

    #expect(Self.results(actions) == [.cancel])
  }

  // MARK: - Footer

  @Test func aCustomFooterReplacesTheDefaultFooter() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(Self.oneFieldRequest, actions: actions) { form in
      form.elicitationFooter { footer in
        VStack {
          Text(footer.canSubmit ? "Ready" : "Waiting")
            .accessibilityIdentifier(Self.customFooterStateIdentifier)
          Button("Refuse") { footer.decline() }
            .accessibilityIdentifier(Self.customFooterIdentifier)
        }
      }
    }
    defer { harness.close() }

    #expect(harness.element(identifier: ElicitationView.submitIdentifier) == nil)
    #expect(harness.element(identifier: ElicitationView.declineIdentifier) == nil)
    #expect(harness.element(identifier: ElicitationView.cancelIdentifier) == nil)
    #expect(harness.element(identifier: Self.customFooterStateIdentifier)?.label == "Waiting")

    try harness.press(
      identifier: ElicitationFieldView.choiceIdentifier(for: "color", value: "blue"))
    #expect(harness.element(identifier: Self.customFooterStateIdentifier)?.label == "Ready")

    try harness.press(identifier: Self.customFooterIdentifier)
    await harness.pump(until: Self.callWaitSeconds) { !actions.calls.isEmpty }

    #expect(Self.results(actions) == [.decline])
  }

  // MARK: - Focus

  @Test func theFormReportsTheFocusOnAppear() {
    let reporter = RecordingFocusReporter()
    let harness = Self.mount(Self.oneFieldRequest, reporter: reporter)
    defer { harness.close() }

    #expect(reporter.moves == [ElicitationView.formIdentifier])
  }

  // MARK: - URL mode

  @Test func aURLRequestShowsNoFields() {
    let harness = Self.mount(ThreadFixtures.urlElicitationRequest())
    defer { harness.close() }

    let fieldIdentifiers = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(ElicitationFieldView.identifierPrefix)
    }
    #expect(fieldIdentifiers.isEmpty)
  }
}
