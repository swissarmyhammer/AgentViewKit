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

  /// The commands of the thread.
  static let commands = [
    SlashCommand(name: "compact", description: "Compact the thread", inputHint: "instructions"),
    SlashCommand(name: "plan", description: "Make a plan"),
  ]

  /// Mounts a composer with the EditorKit editor and focuses the editor.
  ///
  /// - Parameters:
  ///   - model: The text model.
  ///   - actions: The actions of the thread.
  ///   - thread: The thread.
  ///   - fileRoot: The file root, or `nil`.
  /// - Returns: The harness.
  static func mount(
    _ model: PromptInputHostedTestModel, actions: NoopThreadActions, thread: AgentThread,
    fileRoot: URL? = nil
  ) throws -> HostedViewHarness<some View> {
    let harness = threadViewHarness(size: composerSize, actions: actions, thread: thread) {
      EditorKitPromptInputHost(model: model, fileRoot: fileRoot)
    }
    harness.pump()
    try #require(harness.focusFirstEditableTextView())
    return harness
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

  @Test func theEditorMountsInTheComposerSlot() throws {
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, actions: NoopThreadActions(), thread: AgentThread())
    defer { harness.close() }

    #expect(harness.element(identifier: StockPromptEditor.identifier) == nil)
    #expect(harness.firstEditableTextView() != nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil)
  }

  // MARK: - Keys

  @Test func returnSendsTheTextAndClearsTheEditor() async throws {
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, actions: actions, thread: AgentThread())
    defer { harness.close() }

    harness.type(Self.message)
    await harness.pump(until: Self.waitTimeout) { model.plainText == Self.message }
    try Self.pressReturn(in: harness)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.message))])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
    let editor = try #require(harness.firstEditableTextView(of: NSTextView.self))
    await harness.pump(until: Self.waitTimeout) { editor.string.isEmpty }
    #expect(editor.string.isEmpty)
  }

  @Test func shiftReturnInsertsANewlineAndDoesNotSend() async throws {
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, actions: actions, thread: AgentThread())
    defer { harness.close() }

    harness.type(Self.message)
    await harness.pump(until: Self.waitTimeout) { model.plainText == Self.message }
    try Self.pressReturn(modifiers: .shift, in: harness)
    await harness.pump(until: Self.waitTimeout) { model.plainText == Self.message + "\n" }

    #expect(actions.calls.isEmpty)
    #expect(model.plainText == Self.message + "\n")
  }

  @Test func commandReturnSendsTheTextWhileTheTurnRuns() async throws {
    let thread = AgentThread()
    thread.apply(.setState(.running))
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, actions: actions, thread: thread)
    defer { harness.close() }

    harness.type(Self.message)
    await harness.pump(until: Self.waitTimeout) { model.plainText == Self.message }
    try Self.pressReturn(modifiers: .command, in: harness)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.message))])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
  }

  @Test func escapeStopsTheRunningTurn() async throws {
    let thread = AgentThread()
    thread.apply(.setState(.running))
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, actions: actions, thread: thread)
    defer { harness.close() }

    try harness.sendKey(.escape)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.cancel])
  }

  // MARK: - Slash commands

  @Test func aSlashListsTheCommandsAndReturnAcceptsOne() async throws {
    let thread = AgentThread()
    thread.apply(.setAvailableCommands(Self.commands))
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, actions: actions, thread: thread)
    defer { harness.close() }

    harness.type("/")
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness).count == 2 }
    #expect(Set(Self.completionLabels(in: harness)) == ["/compact", "/plan"])

    harness.type("co")
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness) == ["/compact"] }
    #expect(Self.completionLabels(in: harness) == ["/compact"])

    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { model.plainText == "/compact " }

    #expect(model.plainText == "/compact ")
    #expect(actions.calls.isEmpty)
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness).isEmpty }
    #expect(Self.completionLabels(in: harness).isEmpty)
  }

  // MARK: - File references

  @Test func anAtSignListsTheFilesAndTheAcceptedFileIsSentAsAnAttachment() async throws {
    let root = try TemporaryFileRoot(files: ["notes.txt", "src/main.swift"])
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, actions: actions, thread: AgentThread(), fileRoot: root.url)
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
    #expect(actions.calls.isEmpty)

    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: "@notes.txt ", attachments: [file]))])
    #expect(model.plainText.isEmpty)
  }

  @Test func anAcceptedDirectoryListsItsEntries() async throws {
    let root = try TemporaryFileRoot(files: ["src/main.swift"])
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(
      model, actions: NoopThreadActions(), thread: AgentThread(), fileRoot: root.url)
    defer { harness.close() }

    harness.type("@s")
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness) == ["src/"] }
    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness) == ["main.swift"] }

    #expect(model.plainText == "@src/")
    #expect(Self.completionLabels(in: harness) == ["main.swift"])
  }

  @Test func withoutAFileRootAnAtSignListsNothing() async throws {
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, actions: NoopThreadActions(), thread: AgentThread())
    defer { harness.close() }

    harness.type("@")
    await harness.pump(until: Self.waitTimeout) { model.plainText == "@" }
    harness.pump(for: 0.3)

    #expect(Self.completionLabels(in: harness).isEmpty)
  }
}
