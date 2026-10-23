@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import FoundationModelsACP
import SwiftUI
import Testing

/// Hosted tests of the editing of a one-line ``ElicitationTextField``: an
/// EditorKit field (`SingleLineField`) in an ``ElicitationView`` under a root
/// command scope, so the window has its undo stack.
///
/// The field carries the control identifier of the field on its text view.
/// Typing writes the answer, Return presses Submit as the footer says,
/// Esc takes back the typing since the field got the focus and leaves the
/// request open, and `edit.undo` of the window takes the typing out.
@Suite(.serialized, .hostedSerially) @MainActor struct ElicitationTextFieldEditingHostedTests {
  /// The answer that the tests type into the `name` field.
  static let name = "Ada"

  /// The control identifier of the `name` field.
  static let control = ElicitationFieldView.controlIdentifier(for: "name")

  /// The form of a request with the one required text field `name`, and
  /// the window of the form.
  struct MountedForm {
    /// The mounted form.
    let form: ElicitationViewHostedTests.Mounted

    /// The window of the form, with its undo stack.
    let window: MountedThread<AnyView>
  }

  /// Shows a form with the one required text field `name` in the root
  /// command scope of a new command system.
  ///
  /// - Returns: The form and its window.
  /// - Throws: The error of the transport, or an issue when the window has
  ///   no undo stack.
  static func mount() async throws -> MountedForm {
    let system = CommandSystem()
    let form = try await ElicitationViewHostedTests.mount(ElicitationFieldErrorsHostedTests.requiredNameParams) {
      SingleLineFieldChecks.scoped($0, in: system)
    }
    return MountedForm(form: form, window: try SingleLineFieldChecks.window(of: form.harness, system: system))
  }

  @Test func theTextViewOfTheFieldAloneCarriesTheControlIdentifier() async throws {
    let mounted = try await Self.mount()
    defer { mounted.form.close() }

    try SingleLineFieldChecks.expectOneTextViewCarries(Self.control, in: mounted.form.harness)
    #expect(mounted.form.harness.element(identifier: Self.control)?.label == "Name")
  }

  @Test func typingInTheFieldWritesTheAnswerAndEnablesSubmit() async throws {
    let mounted = try await Self.mount()
    defer { mounted.form.close() }
    let harness = mounted.form.harness
    try #require(harness.element(identifier: ElicitationView.submitIdentifier)?.isEnabled == false)

    try SingleLineFieldChecks.type(Self.name, intoFieldWith: Self.control, in: harness)

    #expect(harness.element(identifier: Self.control)?.value == Self.name)
    #expect(harness.element(identifier: ElicitationView.submitIdentifier)?.isEnabled == true)
  }

  @Test func returnInTheFieldSubmitsTheForm() async throws {
    let mounted = try await Self.mount()
    defer { mounted.form.close() }
    try SingleLineFieldChecks.type(Self.name, intoFieldWith: Self.control, in: mounted.form.harness)

    try mounted.form.harness.sendKey(.return)

    let accepted = try JSONValue(json: #"{"action": "accept", "content": {"name": "\#(Self.name)"}}"#)
    #expect(try await mounted.form.result() == accepted)
  }

  @Test func escapeInTheFieldTakesBackTheTypingAndKeepsTheRequest() async throws {
    let mounted = try await Self.mount()
    defer { mounted.form.close() }
    let textView = try SingleLineFieldChecks.type(Self.name, intoFieldWith: Self.control, in: mounted.form.harness)
    try #require(textView.string == Self.name)

    try mounted.form.harness.sendKey(.escape)

    #expect(textView.string.isEmpty)
    #expect(mounted.form.harness.element(identifier: ElicitationView.submitIdentifier)?.isEnabled == false)
    #expect(mounted.form.session.model.pendingElicitations.count == 1)
  }

  @Test func theWindowUndoTakesTheTypingOutOfTheField() async throws {
    let mounted = try await Self.mount()
    defer { mounted.form.close() }

    let textView = try await SingleLineFieldChecks.typeAndUndoAll(
      Self.name, intoFieldWith: Self.control, in: mounted.window)

    #expect(textView.string.isEmpty)
    #expect(mounted.form.harness.element(identifier: ElicitationView.submitIdentifier)?.isEnabled == false)
    #expect(!mounted.window.stack.canUndo)
  }
}
