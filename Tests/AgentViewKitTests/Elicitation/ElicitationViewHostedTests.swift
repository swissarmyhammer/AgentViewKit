import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
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

  /// The JSON text of a property schema of a text field with a minimum
  /// length.
  static let noteProperty = #"{"type": "string", "title": "Note", "minLength": 2}"#

  /// The JSON text of a property schema of a text field with a minimum
  /// length and an empty default.
  static let emptyDefaultNoteProperty = #"{"type": "string", "title": "Note", "minLength": 2, "default": ""}"#

  /// The JSON text of a property schema of a multi-choice field with the
  /// values `a` and `b` and one or more items.
  static let tagsProperty =
    #"{"type": "array", "title": "Tags", "minItems": 1, "items": {"type": "string", "enum": ["a", "b"]}}"#

  /// The JSON text of a property schema of a text field with a default and a
  /// pattern that does not compile. The kit ignores the pattern, but Extras
  /// refuses it.
  static let codeProperty = #"{"type": "string", "title": "Code", "pattern": "[", "default": "abc"}"#

  /// The JSON text of a property schema of a multi-choice field with no
  /// choices. The kit makes no field for it, but Extras decodes it.
  static let noChoicesProperty = #"{"type": "array", "title": "Files", "items": {"type": "string", "enum": []}}"#

  /// The text before the reason of Extras in the failure of a refused answer.
  static let failureLead = "The agent cannot accept this answer: "

  /// The accessibility identifier of the button of the custom text field.
  static let customTextFieldIdentifier = "custom-text-field-write"

  /// The tab threshold that shows each field of a two-field form inline.
  static let inlineTabThreshold = 2

  /// The response of the agent to an accepted form whose only answer is
  /// `color: red`.
  static let acceptedRed = #"{"action": "accept", "content": {"color": "red"}}"#

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

    /// Calls ``ScriptedSession/resultOfAnsweredElicitation(ofRequest:sourceLocation:)``
    /// with ``ElicitationViewHostedTests/agentRequestID``.
    ///
    /// - Parameter sourceLocation: The location of the caller, for the
    ///   failure report.
    /// - Returns: The `result` member of the response, or `nil` when the
    ///   response has no `result` member.
    /// - Throws: An issue when the model holds a pending elicitation.
    func result(sourceLocation: SourceLocation = #_sourceLocation) async throws -> JSONValue? {
      try await session.resultOfAnsweredElicitation(
        ofRequest: ElicitationViewHostedTests.agentRequestID, sourceLocation: sourceLocation)
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
    harness.render()
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

  /// The params of a request with a required `color` field and one optional
  /// field.
  ///
  /// - Parameters:
  ///   - name: The name of the optional field.
  ///   - property: The JSON text of the property schema of the optional
  ///     field.
  /// - Returns: The JSON text of the params.
  static func colorParams(with name: String, _ property: String) -> String {
    makeFormParams(properties: ["color": colorProperty, name: property], required: ["color"])
  }

  /// Shows a form with a required `color` field and one optional field
  /// inline.
  ///
  /// - Parameters:
  ///   - name: The name of the optional field.
  ///   - property: The JSON text of the property schema of the optional
  ///     field.
  /// - Returns: The mounted form.
  /// - Throws: The error of ``mount(_:reporter:content:)``.
  static func mountInline(_ name: String, _ property: String) async throws -> Mounted {
    try await mount(colorParams(with: name, property)) { form in
      form.elicitationLayout(tabThreshold: inlineTabThreshold)
    }
  }

  /// Shows a form with a required `color` field and an optional `note` text
  /// field. A custom text field has a button that writes `value` to the
  /// answer of `note`.
  ///
  /// - Parameter value: The value that the button writes.
  /// - Returns: The mounted form.
  /// - Throws: The error of ``mount(_:reporter:content:)``.
  static func mountCustomNote(writing value: JSONValue) async throws -> Mounted {
    try await mount(colorParams(with: "note", noteProperty)) { form in
      form
        .elicitationLayout(tabThreshold: inlineTabThreshold)
        .elicitationTextField { context in
          Button("Write") { context.value.wrappedValue = value }
            .accessibilityIdentifier(customTextFieldIdentifier)
        }
    }
  }

  /// Selects `red` in the `color` field and presses Submit.
  ///
  /// - Parameter harness: The harness of the form.
  /// - Throws: The error of a press.
  static func submitRed(_ harness: HostedViewHarness<AnyView>) throws {
    try harness.press(identifier: ElicitationFieldView.choiceIdentifier(for: "color", value: "red"))
    try harness.press(identifier: ElicitationView.submitIdentifier)
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
    #expect(ElicitationView.failureIdentifier == "elicitation-failure")
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
    let result = try await mounted.result()

    #expect(result == (try JSONValue(json: #"{"action": "accept", "content": {"color": "red", "count": 3}}"#)))
    #expect(mounted.session.model.pendingElicitations.isEmpty)
  }

  // MARK: - Answer content

  @Test func anEmptyTextDefaultIsNotSent() async throws {
    let mounted = try await Self.mountInline("note", Self.emptyDefaultNoteProperty)
    defer { mounted.close() }

    try Self.submitRed(mounted.harness)

    #expect(try await mounted.result() == (try JSONValue(json: Self.acceptedRed)))
  }

  @Test func aMultiChoiceWithNoCheckIsNotSent() async throws {
    let mounted = try await Self.mountInline("tags", Self.tagsProperty)
    defer { mounted.close() }
    let harness = mounted.harness
    let choice = ElicitationFieldView.choiceIdentifier(for: "tags", value: "a")

    try harness.press(identifier: choice)
    try harness.press(identifier: choice)
    try Self.submitRed(harness)

    #expect(try await mounted.result() == (try JSONValue(json: Self.acceptedRed)))
  }

  @Test func aNullFromACustomFieldIsNotSent() async throws {
    let mounted = try await Self.mountCustomNote(writing: .null)
    defer { mounted.close() }

    try mounted.harness.press(identifier: Self.customTextFieldIdentifier)
    try Self.submitRed(mounted.harness)

    #expect(try await mounted.result() == (try JSONValue(json: Self.acceptedRed)))
  }

  @Test func aWrongTypeFromACustomFieldIsNotSent() async throws {
    let mounted = try await Self.mountCustomNote(writing: .number(3))
    defer { mounted.close() }
    let harness = mounted.harness

    try harness.press(identifier: Self.customTextFieldIdentifier)
    try harness.press(identifier: ElicitationFieldView.choiceIdentifier(for: "color", value: "red"))

    let submit = try #require(harness.element(identifier: ElicitationView.submitIdentifier))
    #expect(!submit.isEnabled)
    #expect(mounted.session.model.pendingElicitations.count == 1)
  }

  // MARK: - Check before the send

  /// Shows a form whose answer Extras refuses, with `announcer` as the
  /// announcer of the form.
  ///
  /// - Parameters:
  ///   - params: The JSON text of the params of the request.
  ///   - announcer: The announcer that records each announcement.
  /// - Returns: The mounted form.
  /// - Throws: The error of ``mount(_:reporter:content:)``.
  static func mountRefused(_ params: String, announcer: RecordingAnnouncer) async throws -> Mounted {
    try await mount(params) { form in
      form.environment(\.announcer, announcer)
    }
  }

  /// The params of a request with a required `color` field and a required
  /// `files` field that has no choices.
  static var noChoicesParams: String {
    makeFormParams(properties: ["color": colorProperty, "files": noChoicesProperty], required: ["color", "files"])
  }

  @Test func anAnswerThatExtrasRefusesIsNotSent() async throws {
    let announcer = RecordingAnnouncer()
    let params = Self.makeFormParams(properties: ["code": Self.codeProperty], required: ["code"])
    let mounted = try await Self.mountRefused(params, announcer: announcer)
    defer { mounted.close() }
    let harness = mounted.harness
    let pending = try #require(mounted.session.model.pendingElicitations.first)
    let reason = try #require(pending.validationFailure(of: .object(["code": .string("abc")])))
    let expected = Self.failureLead + reason

    try harness.press(identifier: ElicitationView.submitIdentifier)

    #expect(mounted.session.model.pendingElicitations.count == 1)
    #expect(harness.element(identifier: ElicitationView.failureIdentifier)?.label == expected)
    #expect(announcer.announcements == [RecordingAnnouncer.Announcement(message: expected, priority: .high)])
    #expect(harness.element(identifier: ElicitationView.formIdentifier) != nil)
  }

  @Test func aRequiredFieldWithNoControlIsNotSent() async throws {
    let mounted = try await Self.mountRefused(Self.noChoicesParams, announcer: RecordingAnnouncer())
    defer { mounted.close() }
    let harness = mounted.harness

    try Self.submitRed(harness)

    #expect(mounted.session.model.pendingElicitations.count == 1)
    let failure = try #require(harness.element(identifier: ElicitationView.failureIdentifier)?.label)
    #expect(failure.hasPrefix(Self.failureLead))
    #expect(failure.contains(#""files""#))
  }

  @Test func aChangeOfTheAnswersRemovesTheFailure() async throws {
    let mounted = try await Self.mountRefused(Self.noChoicesParams, announcer: RecordingAnnouncer())
    defer { mounted.close() }
    let harness = mounted.harness
    try Self.submitRed(harness)
    #expect(harness.element(identifier: ElicitationView.failureIdentifier) != nil)

    try harness.press(identifier: ElicitationFieldView.choiceIdentifier(for: "color", value: "blue"))

    #expect(harness.element(identifier: ElicitationView.failureIdentifier) == nil)
  }

  @Test func theFooterButtonsKeepTheirTextAsTheirLabels() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams)
    defer { mounted.close() }
    let harness = mounted.harness

    harness.expectButton(identifier: ElicitationView.cancelIdentifier, label: "Cancel")
    harness.expectButton(identifier: ElicitationView.declineIdentifier, label: "Decline")
    harness.expectButton(identifier: ElicitationView.submitIdentifier, label: "Submit")
  }

  @Test func declineSendsDecline() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams)
    defer { mounted.close() }

    try mounted.harness.press(identifier: ElicitationView.declineIdentifier)

    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "decline"}"#)))
  }

  @Test func cancelSendsCancel() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams)
    defer { mounted.close() }

    try mounted.harness.press(identifier: ElicitationView.cancelIdentifier)

    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "cancel"}"#)))
  }

  @Test func escapeSendsCancel() async throws {
    let mounted = try await Self.mount(Self.oneFieldParams)
    defer { mounted.close() }

    try mounted.harness.sendKey(.escape)

    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "cancel"}"#)))
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

    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "decline"}"#)))
  }

  // MARK: - Focus

  /// A new card does not take the focus. The ``RequestDeck`` moves the focus.
  @Test func theFormMovesNoFocusOnAppear() async throws {
    let reporter = RecordingFocusReporter()
    let mounted = try await Self.mount(Self.oneFieldParams, reporter: reporter)
    defer { mounted.close() }

    #expect(reporter.moves.isEmpty)
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
