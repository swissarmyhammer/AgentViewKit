@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import EditorInspectorTestSupport
import EditorTestSupport
import FoundationModelsACP
import SwiftUI
import Testing

/// Hosted tests of the editing of the input of an ``ElicitationDateField``:
/// EditorKit's `DateField`, in an ``ElicitationView`` under a root command
/// scope, in the `en_US` locale and in UTC.
///
/// A commit writes the date that the whole text names. Return then presses
/// Submit when the form is complete, after the date is written, as in a
/// one-line text field.
@Suite(.serialized, .hostedSerially) @MainActor struct ElicitationDateFieldEditingHostedTests {
  /// The control identifier of the `day` field.
  static let control = ElicitationFieldView.controlIdentifier(for: "day")

  /// The params of a request with the one required `date` field `day`.
  static var requiredDayParams: String {
    ElicitationViewHostedTests.makeFormParams(
      properties: ["day": #"{"type": "string", "title": "Day", "format": "date"}"#], required: ["day"])
  }

  @Test func returnWritesTheTypedDateAndSubmitsTheForm() async throws {
    let system = CommandSystem()
    let form = try await ElicitationViewHostedTests.mount(Self.requiredDayParams) {
      SingleLineFieldChecks.scoped(
        $0.environment(\.locale, ElicitationFieldViewsHostedTests.dateLocale).environment(\.timeZone, .gmt),
        in: system)
    }
    defer { form.close() }

    try form.harness.inspectorDriver.replace(with: ElicitationFieldViewsHostedTests.dayText, in: Self.control)
    try form.harness.inspectorDriver.commit(Self.control)

    let accepted = try JSONValue(
      json: #"{"action": "accept", "content": {"day": "\#(ElicitationFieldViewsHostedTests.dayAnswer)"}}"#)
    #expect(try await form.result() == accepted)
  }
}
