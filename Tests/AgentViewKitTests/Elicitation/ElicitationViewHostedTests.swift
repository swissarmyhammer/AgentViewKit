import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import SwiftUI
import Testing

/// Hosted tests of ``ElicitationView``.
///
/// Each test gets a `PendingElicitation` from the session model of a
/// ``ScriptedSession``, shows it in an ``ElicitationView``, and reads the
/// response that the scripted agent receives.
@Suite(.serialized, .hostedSerially) @MainActor struct ElicitationViewHostedTests {
  /// The size of a hosted form.
  static let formSize = CGSize(width: 520, height: 480)

  /// The JSON-RPC id of the elicitation request of the agent.
  static let agentRequestID = 7

  /// The message of each form request of the tests.
  static let message = "Select a color."

  /// The accessibility identifier of the button in the custom footer.
  static let customFooterIdentifier = "custom-footer-refuse"

  /// The accessibility identifier of the text in the custom footer that
  /// shows the Submit state.
  static let customFooterStateIdentifier = "custom-footer-state"

  /// The accessibility identifier of the text in the custom header.
  static let customHeaderIdentifier = "custom-header"

  // MARK: - Fixtures

  /// The JSON text of a property schema of a single-choice field with the
  /// values `red` and `blue`.
  static let colorProperty = #"{"type": "string", "title": "Color", "enum": ["red", "blue"]}"#

  /// The JSON text of a property schema of a boolean field.
  static let agreeProperty = #"{"type": "boolean", "title": "Agree"}"#

  /// The JSON text of a property schema of a number field with a default.
  static let countProperty = #"{"type": "integer", "title": "Count", "minimum": 1, "maximum": 9, "default": 3}"#

  /// The params of a URL mode elicitation of the scripted session.
  static let urlParams = #"""
    {"sessionId": "\#(ScriptedSession.sessionID)", "message": "Sign in", "mode": "url",
     "url": "https://example.com/auth", "elicitationId": "url-1"}
    """#

  /// The objects that a hosted form uses.
  struct Mounted {
    /// The harness of the form.
    let harness: HostedViewHarness<AnyView>

    /// The scripted session whose model holds the request.
    let session: ScriptedSession

    /// Closes the harness, then stops the scripted agent.
    func close() {
      harness.close()
      session.close()
    }

    /// Waits for the response of the agent to the request.
    ///
    /// - Returns: The `result` member of the response, or `nil` when no
    ///   response came.
    func result() async -> JSONValue? {
      await session.result(ofRequest: ElicitationViewHostedTests.agentRequestID)
    }
  }

  /// The params of a form elicitation of the scripted session.
  ///
  /// - Parameters:
  ///   - properties: The JSON text of each property schema, keyed by name.
  ///   - required: The names of the required properties.
  /// - Returns: The JSON text of the params.
  static func makeFormParams(properties: [String: String], required: [String] = []) -> String {
    let members = properties.sorted { $0.key < $1.key }.map { #""\#($0.key)": \#($0.value)"# }
    let names = required.map { #""\#($0)""# }
    return #"""
      {"sessionId": "\#(ScriptedSession.sessionID)", "message": "\#(message)", "mode": "form",
       "requestedSchema": {"type": "object", "properties": {\#(members.joined(separator: ","))},
                           "required": [\#(names.joined(separator: ","))]}}
      """#
  }

  /// The params of a request with one required single-choice field.
  static var oneFieldParams: String {
    makeFormParams(properties: ["color": colorProperty], required: ["color"])
  }

  /// The params of a request with three fields.
  static var threeFieldParams: String {
    makeFormParams(
      properties: ["color": colorProperty, "agree": agreeProperty, "count": countProperty], required: ["color"])
  }

  /// Gets an elicitation from the agent and shows its form in the
  /// environment that a test gives.
  ///
  /// - Parameters:
  ///   - params: The JSON text of the params of the request.
  ///   - reporter: The reporter that records each focus move.
  ///   - content: The function that changes the form, such as a slot
  ///     override.
  /// - Returns: The mounted form.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no elicitation.
  static func mount<Content: View>(
    _ params: String,
    reporter: RecordingFocusReporter = RecordingFocusReporter(),
    @ViewBuilder content: (ElicitationView) -> Content
  ) async throws -> Mounted {
    let session = try await ScriptedSession.open()
    let pending = try await session.receiveElicitation(id: agentRequestID, params: params)
    let view = content(ElicitationView(request: pending, owner: session.model))
      .environment(\.focusReporter, reporter)
    let harness = HostedViewHarness(AnyView(view), size: formSize)
    harness.pump()
    return Mounted(harness: harness, session: session)
  }

  /// Gets an elicitation from the agent and shows its form with no slot
  /// override.
  static func mount(
    _ params: String,
    reporter: RecordingFocusReporter = RecordingFocusReporter()
  ) async throws -> Mounted {
    try await mount(params, reporter: reporter) { $0 }
  }

  /// The identifiers of the tab elements of a harness.
  static func tabIdentifiers(_ harness: HostedViewHarness<AnyView>) -> Set<String> {
    Set(
      harness.accessibilityElements().compactMap(\.identifier).filter {
        $0.hasPrefix(ElicitationView.tabIdentifierPrefix)
      })
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

  @Test func aOneFieldRequestShowsTheFieldInlineWithNoTabs() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams)
    defer { mounted.close() }
    let harness = mounted.harness

    #expect(harness.element(identifier: ElicitationView.formIdentifier) != nil)
    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "color")) != nil)
    #expect(Self.tabIdentifiers(harness).isEmpty)
  }

  @Test func aThreeFieldRequestShowsOneTabForEachField() async throws {
    let mounted = try await Self.mount(Self.threeFieldParams)
    defer { mounted.close() }

    #expect(
      Self.tabIdentifiers(mounted.harness) == [
        ElicitationView.tabIdentifier(for: "agree"),
        ElicitationView.tabIdentifier(for: "color"),
        ElicitationView.tabIdentifier(for: "count"),
      ])
  }

  @Test func aTabPressShowsTheFieldOfTheTab() async throws {
    let mounted = try await Self.mount(Self.threeFieldParams)
    defer { mounted.close() }
    let harness = mounted.harness

    // The fields are in name order, so the first tab is `agree`.
    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "agree")) != nil)
    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "count")) == nil)

    try harness.press(identifier: ElicitationView.tabIdentifier(for: "count"))

    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "count")) != nil)
    #expect(harness.element(identifier: ElicitationFieldView.identifier(for: "agree")) == nil)
  }

  @Test func aTabShowsTheRequiredAndAnsweredMarks() async throws {
    let mounted = try await Self.mount(Self.threeFieldParams)
    defer { mounted.close() }
    let harness = mounted.harness

    let color = try #require(harness.element(identifier: ElicitationView.tabIdentifier(for: "color")))
    #expect(color.value == ElicitationTabMarks.text(required: true, answered: false))

    // The `count` field has a default, so its tab shows the answered mark.
    let count = try #require(harness.element(identifier: ElicitationView.tabIdentifier(for: "count")))
    #expect(count.value == ElicitationTabMarks.text(required: false, answered: true))
  }

  @Test func aLargerTabThresholdShowsThreeFieldsInline() async throws {
    let mounted = try await Self.mount(Self.threeFieldParams) { form in
      form.elicitationLayout(tabThreshold: 3)
    }
    defer { mounted.close() }

    #expect(Self.tabIdentifiers(mounted.harness).isEmpty)
    for name in ["agree", "color", "count"] {
      #expect(mounted.harness.element(identifier: ElicitationFieldView.identifier(for: name)) != nil)
    }
  }

  @Test func aCustomLayoutGetsEachField() async throws {
    let mounted = try await Self.mount(Self.threeFieldParams) { form in
      form.elicitationLayout { layout in
        Text(layout.fields.map(\.schema.name).joined(separator: ","))
          .accessibilityIdentifier("custom-layout")
      }
    }
    defer { mounted.close() }

    #expect(mounted.harness.element(identifier: "custom-layout")?.label == "agree,color,count")
    #expect(Self.tabIdentifiers(mounted.harness).isEmpty)
  }

  // MARK: - Header

  @Test func theDefaultHeaderNamesTheAgentAndShowsTheMessage() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams)
    defer { mounted.close() }

    let labels = mounted.harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains(ElicitationHeader.title(server: ElicitationHeader.agentServer)) })
    #expect(labels.contains(Self.message))
  }

  @Test func aCustomHeaderGetsThePendingElicitation() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams) { form in
      form.elicitationHeader { pending in
        Text("Banner for \(pending.request.message)")
          .accessibilityIdentifier(Self.customHeaderIdentifier)
      }
    }
    defer { mounted.close() }

    #expect(
      mounted.harness.element(identifier: Self.customHeaderIdentifier)?.label == "Banner for \(Self.message)")
    #expect(mounted.harness.element(identifier: ElicitationView.headerIdentifier) == nil)
  }

  // MARK: - Gate

  @Test func submitIsDisabledUntilEachRequiredFieldValidates() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams)
    defer { mounted.close() }
    let harness = mounted.harness

    let before = try #require(harness.element(identifier: ElicitationView.submitIdentifier))
    #expect(!before.isEnabled)

    try harness.press(
      identifier: ElicitationFieldView.choiceIdentifier(for: "color", value: "blue"))

    let after = try #require(harness.element(identifier: ElicitationView.submitIdentifier))
    #expect(after.isEnabled)
  }

  // MARK: - Actions

  @Test func submitSendsTheValuesOfTheFormAsTheACPContent() async throws {
    let mounted = try await Self.mount(Self.threeFieldParams)
    defer { mounted.close() }
    let harness = mounted.harness

    try harness.press(identifier: ElicitationView.tabIdentifier(for: "color"))
    try harness.press(
      identifier: ElicitationFieldView.choiceIdentifier(for: "color", value: "red"))
    try harness.press(identifier: ElicitationView.submitIdentifier)
    let result = await mounted.result()

    #expect(result == (try JSONValue(json: #"{"action": "accept", "content": {"color": "red", "count": 3}}"#)))
    #expect(mounted.session.model.pendingElicitations.isEmpty)
  }

  @Test func declineSendsDecline() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams)
    defer { mounted.close() }

    try mounted.harness.press(identifier: ElicitationView.declineIdentifier)

    #expect(await mounted.result() == (try JSONValue(json: #"{"action": "decline"}"#)))
  }

  @Test func cancelSendsCancel() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams)
    defer { mounted.close() }

    try mounted.harness.press(identifier: ElicitationView.cancelIdentifier)

    #expect(await mounted.result() == (try JSONValue(json: #"{"action": "cancel"}"#)))
  }

  @Test func escapeSendsCancel() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams)
    defer { mounted.close() }

    try mounted.harness.sendKey(.escape)

    #expect(await mounted.result() == (try JSONValue(json: #"{"action": "cancel"}"#)))
  }

  // MARK: - Footer

  @Test func aCustomFooterReplacesTheDefaultFooter() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams) { form in
      form.elicitationFooter { footer in
        VStack {
          Text(footer.canSubmit ? "Ready" : "Waiting")
            .accessibilityIdentifier(Self.customFooterStateIdentifier)
          Button("Refuse") { footer.decline() }
            .accessibilityIdentifier(Self.customFooterIdentifier)
        }
      }
    }
    defer { mounted.close() }
    let harness = mounted.harness

    #expect(harness.element(identifier: ElicitationView.submitIdentifier) == nil)
    #expect(harness.element(identifier: ElicitationView.declineIdentifier) == nil)
    #expect(harness.element(identifier: ElicitationView.cancelIdentifier) == nil)
    #expect(harness.element(identifier: Self.customFooterStateIdentifier)?.label == "Waiting")

    try harness.press(
      identifier: ElicitationFieldView.choiceIdentifier(for: "color", value: "blue"))
    #expect(harness.element(identifier: Self.customFooterStateIdentifier)?.label == "Ready")

    try harness.press(identifier: Self.customFooterIdentifier)

    #expect(await mounted.result() == (try JSONValue(json: #"{"action": "decline"}"#)))
  }

  // MARK: - Focus

  @Test func theFormReportsTheFocusOnAppear() async throws {
    let reporter = RecordingFocusReporter()
    let mounted = try await Self.mount(Self.oneFieldParams, reporter: reporter)
    defer { mounted.close() }

    #expect(reporter.moves == [ElicitationView.formIdentifier])
  }

  // MARK: - URL mode

  @Test func aURLRequestShowsNoFields() async throws {
    let mounted = try await Self.mount(Self.urlParams)
    defer { mounted.close() }

    let fieldIdentifiers = mounted.harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(ElicitationFieldView.identifierPrefix)
    }
    #expect(fieldIdentifiers.isEmpty)
  }
}
