import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing

/// A host view that shows a composer with the EditorKit editor.
struct EditorKitPromptInputHost: View {
  /// The model that holds the text.
  @Bindable var model: PromptInputHostedTestModel

  /// The file root of the editor, or `nil`.
  let fileRoot: URL?

  var body: some View {
    PromptInputView(
      text: $model.text, onSubmit: { model.submitCount += 1 }, editor: EditorKitPromptEditor.init
    )
    .promptFileRoot(fileRoot)
  }
}

@Suite(.serialized, .hostedSerially) @MainActor struct EditorKitPromptEditorHostedTests {
  /// The text that the tests type.
  static let message = "Hello"

  /// The size of a window that shows the composer and the completion list
  /// above it.
  static let composerSize = CGSize(width: 480, height: 400)

  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// An `available_commands_update` with two commands.
  static let commandsUpdate = #"""
    {"sessionUpdate": "available_commands_update", "availableCommands": [
      {"name": "compact", "description": "Compact the thread",
       "input": {"type": "text", "hint": "instructions"}},
      {"name": "plan", "description": "Make a plan"}]}
    """#

  /// Mounts a composer with the EditorKit editor over the session model of a
  /// scripted session, and focuses the editor.
  ///
  /// - Parameters:
  ///   - model: The text model.
  ///   - session: The scripted session.
  ///   - fileRoot: The file root, or `nil`.
  /// - Returns: The harness.
  /// - Throws: An error when the editor cannot get the focus.
  static func mount(
    _ model: PromptInputHostedTestModel, session: ScriptedSession, fileRoot: URL? = nil
  ) throws -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: composerSize) {
      EditorKitPromptInputHost(model: model, fileRoot: fileRoot)
        .environment(\.sessionModel, session.model)
    }
    harness.pump()
    try #require(harness.focusFirstEditableTextView())
    return harness
  }

  /// Sends the running state of the agent, and waits until the composer
  /// shows the Stop button.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The harness that shows the composer.
  /// - Throws: The error of the transport.
  static func startRunning(_ session: ScriptedSession, in harness: HostedViewHarness<some View>) async throws {
    try await session.sendUpdate(ScriptedSession.runningState)
    await harness.pump(until: waitTimeout) {
      harness.element(identifier: DefaultPromptAccessory.stopIdentifier) != nil
    }
  }

  /// Sends a Return key-down event straight to the text view of the editor,
  /// as AppKit does after SwiftUI lets the press go.
  ///
  /// - Parameters:
  ///   - modifiers: The modifier keys to hold.
  ///   - harness: The harness that shows the editor.
  static func pressReturn(
    modifiers: EventModifiers = [], in harness: HostedViewHarness<some View>
  ) throws {
    let editor = try #require(harness.firstEditableTextView(of: NSTextView.self))
    try harness.sendKeyDown(.return, modifiers: modifiers, to: editor)
  }

  /// The labels of the rows of the completion list.
  static func completionLabels(in harness: HostedViewHarness<some View>) -> [String] {
    harness.accessibilityElements()
      .filter { $0.identifier == EditorKitPromptEditor.completionRowIdentifier }
      .compactMap(\.label)
  }

  // MARK: - Mount

  @Test func theEditorMountsInTheComposerSlot() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session)
    defer { harness.close() }

    #expect(harness.element(identifier: StockPromptEditor.identifier) == nil)
    #expect(harness.firstEditableTextView() != nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil)
  }

  // MARK: - Keys

  @Test func returnSendsTheTextAndClearsTheEditor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session)
    defer { harness.close() }

    harness.type(Self.message)
    await harness.pump(until: Self.waitTimeout) { model.plainText == Self.message }
    try Self.pressReturn(in: harness)
    await harness.pump(until: Self.waitTimeout) { !session.promptTexts.isEmpty }

    #expect(session.promptTexts == [Self.message])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
    let editor = try #require(harness.firstEditableTextView(of: NSTextView.self))
    await harness.pump(until: Self.waitTimeout) { editor.string.isEmpty }
    #expect(editor.string.isEmpty)
  }

  @Test func shiftReturnInsertsANewlineAndDoesNotSend() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session)
    defer { harness.close() }

    harness.type(Self.message)
    await harness.pump(until: Self.waitTimeout) { model.plainText == Self.message }
    try Self.pressReturn(modifiers: .shift, in: harness)
    await harness.pump(until: Self.waitTimeout) { model.plainText == Self.message + "\n" }

    #expect(session.promptTexts.isEmpty)
    #expect(model.plainText == Self.message + "\n")
  }

  @Test func commandReturnSendsTheTextWhileTheTurnRuns() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session)
    defer { harness.close() }
    try await Self.startRunning(session, in: harness)

    harness.type(Self.message)
    await harness.pump(until: Self.waitTimeout) { model.plainText == Self.message }
    try Self.pressReturn(modifiers: .command, in: harness)
    await harness.pump(until: Self.waitTimeout) { !session.promptTexts.isEmpty }

    #expect(session.promptTexts == [Self.message])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
  }

  @Test func escapeStopsTheRunningTurn() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session)
    defer { harness.close() }
    try await Self.startRunning(session, in: harness)

    try harness.sendKey(.escape)
    await harness.pump(until: Self.waitTimeout) {
      !session.agent.messages(method: ScriptedSession.cancelMethod).isEmpty
    }

    #expect(session.agent.messages(method: ScriptedSession.cancelMethod).count == 1)
  }

  // MARK: - Slash commands

  @Test func aSlashListsTheCommandsAndReturnAcceptsOne() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(Self.commandsUpdate)
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session)
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) { session.model.availableCommands != nil }

    harness.type("/")
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness).count == 2 }
    #expect(Set(Self.completionLabels(in: harness)) == ["/compact", "/plan"])

    harness.type("co")
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness) == ["/compact"] }
    #expect(Self.completionLabels(in: harness) == ["/compact"])

    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { model.plainText == "/compact " }

    #expect(model.plainText == "/compact ")
    #expect(session.promptTexts.isEmpty)
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness).isEmpty }
    #expect(Self.completionLabels(in: harness).isEmpty)
  }

  // MARK: - File references

  @Test func anAtSignListsTheFilesAndTheAcceptedFileIsSentAsAnAttachment() async throws {
    let root = try TemporaryFileRoot(files: ["notes.txt", "src/main.swift"])
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session, fileRoot: root.url)
    defer { harness.close() }

    harness.type("@")
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness).count == 2 }
    #expect(Self.completionLabels(in: harness) == ["src/", "notes.txt"])

    harness.type("n")
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness) == ["notes.txt"] }
    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { model.text.runs.contains { $0.link != nil } }

    let file = root.url.appending(path: "notes.txt")
    #expect(model.plainText == "@notes.txt ")
    #expect(model.text.runs.compactMap(\.link) == [file])
    #expect(session.promptTexts.isEmpty)

    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { !session.promptTexts.isEmpty }

    #expect(session.promptTexts == ["@notes.txt "])
    let blocks = try #require(session.promptBlocks.first)
    #expect(blocks.map { $0["type"]?.stringValue } == ["text", "resource_link"])
    #expect(blocks.last?["uri"]?.stringValue == file.absoluteString)
    #expect(model.plainText.isEmpty)
  }

  @Test func anAcceptedDirectoryListsItsEntries() async throws {
    let root = try TemporaryFileRoot(files: ["src/main.swift"])
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session, fileRoot: root.url)
    defer { harness.close() }

    harness.type("@s")
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness) == ["src/"] }
    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness) == ["main.swift"] }

    #expect(model.plainText == "@src/")
    #expect(Self.completionLabels(in: harness) == ["main.swift"])
  }

  @Test func withoutAFileRootAnAtSignListsNothing() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session)
    defer { harness.close() }

    harness.type("@")
    await harness.pump(until: Self.waitTimeout) { model.plainText == "@" }
    harness.pump(for: 0.3)

    #expect(Self.completionLabels(in: harness).isEmpty)
  }
}
