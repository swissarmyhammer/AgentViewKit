@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import FoundationModelsACP
import SwiftUI
import Testing

/// Hosted tests of the editing of the number input of an
/// ``ElicitationNumberField``: an EditorKit field
/// (`SingleLineField(model:id:value:format:)`) beside a stepper, in an
/// ``ElicitationView`` under a root command scope, so the window has its undo
/// stack.
///
/// The text view of the input carries the control identifier of the field and
/// the title of the field as its label. Typing changes only the text: a
/// commit (Return, Esc, a focus loss) writes the number when the whole text
/// is one number of the format of the field, and shows the number again in
/// that format. Other text keeps the last number. Return then presses Submit
/// when the form is complete, after the number is written.
@Suite(.serialized, .hostedSerially) @MainActor struct ElicitationNumberFieldEditingHostedTests {
  /// The control identifier of the `count` field.
  static let control = ElicitationFieldView.controlIdentifier(for: "count")

  /// The JSON text of a property schema of an integer field with a maximum
  /// and no minimum, so that the field shows a stepper and a number input.
  static let countProperty = #"{"type": "integer", "title": "Count", "maximum": 9}"#

  /// The JSON text of ``countProperty`` with the default ``defaultCount``.
  static let countWithDefaultProperty = #"{"type": "integer", "title": "Count", "maximum": 9, "default": 3}"#

  /// The default of ``countWithDefaultProperty``, as the field shows it.
  static let defaultCount = "3"

  /// The text that the input shows when the field has no answer and no
  /// minimum.
  static let noAnswerText = "0"

  /// The number that the tests type into the input.
  static let typedCount = "5"

  /// The params of a request with the one required field `count`.
  static var requiredCountParams: String {
    ElicitationViewHostedTests.makeFormParams(properties: ["count": countProperty], required: ["count"])
  }

  /// The params of a request with the one optional field `count`, whose
  /// default is ``defaultCount``.
  static var countWithDefaultParams: String {
    ElicitationViewHostedTests.makeFormParams(properties: ["count": countWithDefaultProperty])
  }

  /// The response of the agent to an accepted form whose only answer is
  /// `count: count`.
  ///
  /// - Parameter count: The JSON text of the number.
  /// - Returns: The `result` member of the response.
  /// - Throws: The error of the JSON parse.
  static func accepted(count: String) throws -> JSONValue {
    try JSONValue(json: #"{"action": "accept", "content": {"count": \#(count)}}"#)
  }

  @Test func theTextViewOfTheInputAloneCarriesTheControlIdentifierAndTheTitle() async throws {
    let mounted = try await ElicitationTextFieldEditingHostedTests.mount(Self.requiredCountParams)
    defer { mounted.form.close() }

    try SingleLineFieldChecks.expectOneTextViewCarries(Self.control, in: mounted.form.harness)
    #expect(mounted.form.harness.element(identifier: Self.control)?.label == "Count")
  }

  @Test(arguments: SingleLineFieldChecks.submitModifiers)
  func returnWritesTheTypedNumberAndSubmitsTheForm(modifiers: SwiftUI.EventModifiers) async throws {
    let mounted = try await ElicitationTextFieldEditingHostedTests.mount(Self.requiredCountParams)
    defer { mounted.form.close() }

    try SingleLineFieldChecks.type(
      Self.typedCount, intoFieldWith: Self.control, in: mounted.form.harness, replacingAllText: true,
      thenPress: .return, modifiers: modifiers)

    #expect(try await mounted.form.result() == Self.accepted(count: Self.typedCount))
  }

  /// A commit of text that is not one number keeps the last number, and the
  /// input shows that number again.
  @Test(arguments: ["4x", "x"])
  func textThatIsNotANumberKeepsTheLastNumberAndShowsItAgain(text: String) async throws {
    try await Self.expectEscapeCommit(of: text, writesAndShows: Self.defaultCount)
  }

  /// An `integer` field reads its text with an integer format: Foundation's
  /// integer format reads a fraction as its whole part, so the commit writes
  /// and shows that whole number. A number format would read 2.5, and the
  /// whole-number write of the field would round it to 3.
  @Test func aFractionInAnIntegerFieldCommitsItsWholePart() async throws {
    try await Self.expectEscapeCommit(of: "2.5", writesAndShows: "2")
  }

  /// `edit.undo` of the window, the command of ⌘Z, takes the typing out of
  /// the input. The number that the input shows when it appears is no undo
  /// entry.
  @Test func theWindowUndoTakesTheTypingOutOfTheInput() async throws {
    let mounted = try await ElicitationTextFieldEditingHostedTests.mount(Self.requiredCountParams)
    defer { mounted.form.close() }

    let textView = try await SingleLineFieldChecks.typeAndUndoAll(
      Self.typedCount, intoFieldWith: Self.control, in: mounted.window, replacingAllText: true)

    #expect(textView.string == Self.noAnswerText)
    #expect(!mounted.window.stack.canUndo)
  }

  /// A submitted form leaves the window, and the typing of its number input
  /// leaves the window undo stack with it, so ⌘Z never undoes typing in an
  /// input that is gone.
  ///
  /// The form shows in a card of the ``RequestDeck``, so that the answer
  /// takes the card out of the window. The number field keeps the model of
  /// its input in a kit-owned `@State` slot, and the Return action of the
  /// input captures the view: EditorKit holds that commit callback in the
  /// mounted view, not in the model, so the model goes with the card.
  @Test func aSubmittedFormTakesTheTypingOfItsNumberInputOffTheWindowUndoStack() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let window = try await ElicitationTextFieldEditingHostedTests.mountInTheDeck(
      session, params: Self.requiredCountParams)
    defer { window.harness.close() }
    try SingleLineFieldChecks.type(
      Self.typedCount, intoFieldWith: Self.control, in: window.harness, replacingAllText: true)
    try #require(window.stack.canUndo)

    try window.harness.sendKey(.return)
    // The model removes the answered elicitation in the same step as the
    // press, so a Return that did not submit the form stops the test here.
    try #require(session.model.pendingElicitations.isEmpty)
    window.harness.render()
    try #require(window.harness.element(identifier: Self.control) == nil)
    await RunLoopBlockFence.afterPendingBlocks()

    #expect(!window.stack.canUndo)
    #expect(!window.stack.canRedo)
  }

  /// Types `text` in place of the default of a form with the one optional
  /// field `count` (``countWithDefaultParams``), commits it with Esc, and
  /// expects that the input shows `number`, and that Submit then sends
  /// `number` as the answer.
  ///
  /// - Parameters:
  ///   - text: The text to type in place of the default.
  ///   - number: The number that the commit keeps, as the input shows it and
  ///     as the JSON text of the answer.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: The error of the transport, or an issue when the field cannot
  ///   take the typing or the Esc.
  static func expectEscapeCommit(
    of text: String, writesAndShows number: String, sourceLocation: SourceLocation = #_sourceLocation
  ) async throws {
    let mounted = try await ElicitationTextFieldEditingHostedTests.mount(Self.countWithDefaultParams)
    defer { mounted.form.close() }

    let textView = try SingleLineFieldChecks.type(
      text, intoFieldWith: Self.control, in: mounted.form.harness, replacingAllText: true,
      thenPress: .escape, sourceLocation: sourceLocation)

    #expect(textView.string == number, sourceLocation: sourceLocation)
    try mounted.form.harness.press(identifier: ElicitationView.submitIdentifier)
    #expect(try await mounted.form.result() == Self.accepted(count: number), sourceLocation: sourceLocation)
  }
}
