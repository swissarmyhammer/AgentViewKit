import AgentViewKitTestSupport
import Foundation
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// A composer state for the tests of the three submit results: the draft of
/// a session in a draft store, one attached file, and each prompt that the
/// composer starts.
@MainActor final class ComposerSubmitFixture {
  /// The text of the prompt in the composer.
  static let prompt = "ask the planner"

  /// The name of the attached file.
  static let fileName = "notes.txt"

  /// The folder of the attached file.
  let root: TemporaryFileRoot

  /// The draft store of the composer.
  let store = PromptDraftStore()

  /// The session model of the composer.
  let session = SessionModel.preview()

  /// The attachment list of the composer.
  var attachments: [AgentViewKit.Attachment]

  /// Each input that the composer starts as a prompt, in order.
  private(set) var started: [UserInput] = []

  /// Makes the state: the draft holds ``prompt``, and the list holds one file.
  ///
  /// - Throws: The error of the write of the file.
  init() throws {
    root = try TemporaryFileRoot(files: [Self.fileName])
    attachments = [AgentViewKit.Attachment(url: root.url.appending(path: Self.fileName))]
    store.draft(for: session).text = AttributedString(Self.prompt)
  }

  /// The text of the draft of the session in the store.
  var text: AttributedString {
    store.draft(for: session).text
  }

  /// Applies `result` to the composer, as the composer does after the submit
  /// hook returns.
  ///
  /// - Parameter result: The result of the submit hook.
  /// - Returns: The outcome of the submit.
  func apply(_ result: ComposerSubmitResult) -> PromptSubmitOutcome {
    let draft = store.draft(for: session)
    return PromptInputView<EditorKitPromptEditor, DefaultPromptAccessory>.apply(
      result,
      text: Binding(get: { draft.text }, set: { draft.text = $0 }),
      attachments: Binding(get: { self.attachments }, set: { self.attachments = $0 })
    ) { self.started.append($0) }
  }
}

/// Tests for the three results of the submit hook: `.send`, `.cancel` and
/// `.consumed` (D199, D205).
@Suite @MainActor struct ComposerSubmitResultTests {
  // MARK: - Consumed

  @Test func aConsumeIsNoCancel() {
    #expect(!ComposerSubmitResult.consumed.isCancelled)
  }

  @Test func aConsumeIsConsumed() {
    #expect(ComposerSubmitResult.consumed.isConsumed)
  }

  @Test func aSendIsNotConsumed() {
    #expect(!ComposerSubmitResult.send.isConsumed)
  }

  @Test func aConsumedPromptStartsNoPrompt() throws {
    let fixture = try ComposerSubmitFixture()

    _ = fixture.apply(.consumed)

    #expect(fixture.started.isEmpty)
  }

  @Test func aConsumedPromptReportsTheConsume() throws {
    let fixture = try ComposerSubmitFixture()

    #expect(fixture.apply(.consumed) == .consumed)
  }

  @Test func aConsumedPromptEmptiesTheDraftStore() throws {
    let fixture = try ComposerSubmitFixture()

    _ = fixture.apply(.consumed)

    #expect(fixture.store.draft(for: fixture.session).text == AttributedString())
  }

  @Test func aConsumedPromptClearsTheFiles() throws {
    let fixture = try ComposerSubmitFixture()

    _ = fixture.apply(.consumed)

    #expect(fixture.attachments.isEmpty)
  }

  @Test func oneUndoRestoresTheTextOfAConsumedPrompt() throws {
    let fixture = try ComposerSubmitFixture()
    let model = PromptEditorSession().model(startingWith: ComposerSubmitFixture.prompt)

    _ = fixture.apply(.consumed)
    // The editor takes the cleared text as it does after a send.
    model.replaceAll(String(fixture.text.characters))
    model.finalizeUndoGroup()
    model.undo()

    #expect(model.text == ComposerSubmitFixture.prompt)
  }

  @Test func aConsumeOfABlankTextSendsNothing() throws {
    let fixture = try ComposerSubmitFixture()
    fixture.store.draft(for: fixture.session).text = AttributedString(" ")

    #expect(fixture.apply(.consumed) == .notSent)
  }

  // MARK: - Cancel

  @Test func aCancelKeepsTheText() throws {
    let fixture = try ComposerSubmitFixture()

    _ = fixture.apply(.cancel)

    #expect(fixture.text == AttributedString(ComposerSubmitFixture.prompt))
  }

  @Test func aCancelKeepsTheFiles() throws {
    let fixture = try ComposerSubmitFixture()

    _ = fixture.apply(.cancel)

    #expect(fixture.attachments.count == 1)
  }

  @Test func aCancelStartsNoPrompt() throws {
    let fixture = try ComposerSubmitFixture()

    #expect(fixture.apply(.cancel) == .notSent)
    #expect(fixture.started.isEmpty)
  }

  // MARK: - Send

  @Test func aSendStartsThePromptWithTheTextAndTheFiles() throws {
    let fixture = try ComposerSubmitFixture()
    let file = fixture.root.url.appending(path: ComposerSubmitFixture.fileName)

    _ = fixture.apply(.send)

    #expect(fixture.started == [UserInput(text: ComposerSubmitFixture.prompt, attachments: [file])])
  }

  @Test func aSendReportsTheSend() throws {
    let fixture = try ComposerSubmitFixture()

    #expect(fixture.apply(.send) == .sent)
  }

  @Test func aSendEmptiesTheDraftStore() throws {
    let fixture = try ComposerSubmitFixture()

    _ = fixture.apply(.send(addingText: ["Sent to planner: delivered"]))

    #expect(fixture.text == AttributedString())
  }

  @Test func aSendClearsTheFiles() throws {
    let fixture = try ComposerSubmitFixture()

    _ = fixture.apply(.send)

    #expect(fixture.attachments.isEmpty)
  }
}
