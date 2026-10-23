@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import FoundationModelsACP
import SwiftUI
import Testing

@Suite(.serialized, .hostedSerially) @MainActor struct EditorKitPromptEditorHostedTests {
  /// The text that the tests type.
  static let message = "Hello"

  /// The size of a window that shows the composer and the completion list
  /// above it.
  static let composerSize = CGSize(width: 480, height: 400)

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
  ///   - requestStartReport: The report that gets the method of each request
  ///     that a view starts, or `nil`.
  /// - Returns: The harness.
  /// - Throws: An error when the editor cannot get the focus.
  static func mount(
    _ model: PromptInputHostedTestModel, session: ScriptedSession, fileRoot: URL? = nil,
    requestStartReport: ObservationReport<String>? = nil
  ) throws -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: composerSize) {
      PromptInputHost(model: model, fileRoot: fileRoot)
        .environment(\.sessionModel, session.model)
        .environment(\.requestStartReport, requestStartReport)
    }
    harness.render()
    try #require(harness.focusFirstEditableTextView())
    return harness
  }

  /// Sends the running state of the agent, waits until the session model
  /// has the running state, and then renders the composer.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The harness that shows the composer.
  /// - Throws: The error of the transport.
  static func startRunning(_ session: ScriptedSession, in harness: HostedViewHarness<some View>) async throws {
    let model = session.model
    try await session.sendUpdate(ScriptedSession.runningState)
    await harness.render {
      if case .running = model.agentState { true } else { false }
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

  // MARK: - Mount

  @Test func theEditorMountsInTheComposerSlot() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session)
    defer { harness.close() }

    #expect(harness.element(identifier: EditorKitPromptEditor.identifier) != nil)
    #expect(harness.firstEditableTextView() != nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil)
  }

  /// The text view that takes typing carries the placeholder of the composer
  /// as its accessibility label, so VoiceOver names the element that has the
  /// focus.
  @Test func theTextViewOfTheEditorCarriesThePlaceholderAsItsLabel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try Self.mount(PromptInputHostedTestModel(), session: session)
    defer { harness.close() }

    let placeholder = PromptInputView<EditorKitPromptEditor, DefaultPromptAccessory>.placeholder
    #expect(harness.element(identifier: EditorKitPromptEditor.identifier)?.label == placeholder)
  }

  // MARK: - Keys

  @Test func returnSendsTheTextAndClearsTheEditor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session)
    defer { harness.close() }

    try await ComposerHarness.typePrompt(Self.message, in: harness) { model.plainText }
    try Self.pressReturn(in: harness)
    // The composer calls the host closure in the same step as it starts the
    // prompt task, so a key that sent nothing stops the test here.
    try #require(model.submitCount == 1)
    await ObservationWait.until { !session.promptTexts.isEmpty }

    #expect(session.promptTexts == [Self.message])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
    let editor = try #require(harness.firstEditableTextView(of: NSTextView.self))
    harness.render()
    #expect(editor.string.isEmpty)
  }

  @Test func shiftReturnInsertsANewlineAndDoesNotSend() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = try Self.mount(model, session: session)
    defer { harness.close() }

    try await ComposerHarness.typePrompt(Self.message, in: harness) { model.plainText }
    try Self.pressReturn(modifiers: .shift, in: harness)
    try harness.requireTextViewShows(Self.message + "\n")
    await ObservationWait.until { model.plainText == Self.message + "\n" }

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

    try await ComposerHarness.typePrompt(Self.message, in: harness) { model.plainText }
    try Self.pressReturn(modifiers: .command, in: harness)
    try #require(model.submitCount == 1)
    await ObservationWait.until { !session.promptTexts.isEmpty }

    #expect(session.promptTexts == [Self.message])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
  }

  @Test func escapeStopsTheRunningTurn() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let starts = ReportRecorder<String>()
    let harness = try Self.mount(model, session: session, requestStartReport: starts.report)
    defer { harness.close() }
    try await Self.startRunning(session, in: harness)

    try harness.sendKey(.escape)
    // Esc starts the cancel in the same step as the key, so a key that
    // started nothing stops the test here.
    try #require(starts.values == [ScriptedSession.cancelMethod])
    await ObservationWait.until { !session.agent.messages(method: ScriptedSession.cancelMethod).isEmpty }

    #expect(session.agent.messages(method: ScriptedSession.cancelMethod).count == 1)
  }

  // MARK: - Slash commands
  //
  // The completion tests below call the completion engine that the editor
  // composes (`PromptEditorSession.engine(commands:root:)`), and await its
  // query directly. In the hosted editor, the query waits for the debounce of
  // EditorKit on a clock, off the main actor, and no model value that these
  // tests observe holds the rows. EditorKit ^c3ya9ed can give an injectable
  // debounce clock. The hosted check that needs no debounce wait is
  // `SlashCommandSessionModelTests.afterAnEmptyCommandsUpdateASlashShowsTheNoCommandsNote`.
  // `ComposerEditorMenuHostedTests` holds the session of the editor, and waits
  // on its model for the rows. Those tests cover the draw of the list, and the
  // path that gives Down and Return to the open list before the submit.

  /// The engine of the editor lists the commands that the agent reported for
  /// a slash, filters them by the text after the slash, and an accept
  /// inserts the command and closes the list. See ^c3ya9ed above.
  @Test func theEditorEngineListsTheReportedCommandsForASlashAndAcceptsOne() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(Self.commandsUpdate)
    let model = session.model
    await ObservationWait.until { model.availableCommands != nil }
    let commands = model.availableCommands

    let all = await CompletionFixture.editor("/", commands: commands, root: nil).query()
    #expect(Set(all) == ["/compact", "/plan"])

    let fixture = CompletionFixture.editor("/co", commands: commands, root: nil)
    #expect(await fixture.query() == ["/compact"])
    #expect(fixture.accept("/compact"))

    #expect(fixture.text == "/compact ")
    #expect(!EditorKitPromptEditor.isTrigger("/compact ", reportsCommands: true, hasRoot: false))
    #expect(session.promptTexts.isEmpty)
  }

  // MARK: - File references

  /// The engine of the editor lists the files for an at sign, directories
  /// first; the accepted file becomes a link in the prompt text, and the
  /// prompt sends it as a resource link. See ^c3ya9ed above.
  @Test func theEditorEngineListsTheFilesForAnAtSignAndTheAcceptedFileGoesOutAsAResourceLink() async throws {
    let root = try TemporaryFileRoot(files: ["notes.txt", "src/main.swift"])

    let all = await CompletionFixture.editor("@", commands: nil, root: root.url).query()
    #expect(all == ["src/", "notes.txt"])

    let fixture = CompletionFixture.editor("@n", commands: nil, root: root.url)
    #expect(await fixture.query() == ["notes.txt"])
    #expect(fixture.accept("notes.txt"))
    #expect(fixture.text == "@notes.txt ")

    let file = root.url.appending(path: "notes.txt")
    let accepted = try #require(EditorKitPromptEditor.acceptedFile(before: Substring(fixture.text), root: root.url))
    let text = EditorKitPromptEditor.attributedText(fixture.text, references: [accepted], root: root.url)
    #expect(String(text.characters) == "@notes.txt ")
    #expect(text.runs.compactMap(\.link) == [file])

    let urls = PromptInputView<EditorKitPromptEditor, DefaultPromptAccessory>.attachmentURLs([], in: text)
    let blocks = PromptContent.makeBlocks(for: UserInput(text: fixture.text, attachments: urls), accepting: nil)
    #expect(blocks.map(PromptCapabilitiesTests.wireType(of:)) == ["text", "resource_link"])
    let link: String? = if case .resourceLink(let link) = blocks.last { link.uri } else { nil }
    #expect(link == file.absoluteString)
  }

  /// An accepted directory stays a trigger, and the engine of the editor then
  /// lists the entries of the directory. See ^c3ya9ed above.
  @Test func theEditorEngineListsTheEntriesOfAnAcceptedDirectory() async throws {
    let root = try TemporaryFileRoot(files: ["src/main.swift"])
    let fixture = CompletionFixture.editor("@s", commands: nil, root: root.url)

    #expect(await fixture.query() == ["src/"])
    #expect(fixture.accept("src/"))
    #expect(fixture.text == "@src/")
    #expect(EditorKitPromptEditor.isTrigger("@src/", reportsCommands: false, hasRoot: true))

    #expect(await fixture.query() == ["main.swift"])
  }

  /// Without a file root, an at sign is no trigger, and the engine of the
  /// editor lists nothing for it. See ^c3ya9ed above.
  @Test func withoutAFileRootTheEditorEngineListsNothingForAnAtSign() async {
    #expect(!EditorKitPromptEditor.isTrigger("@", reportsCommands: false, hasRoot: false))
    #expect(await CompletionFixture.editor("@", commands: nil, root: nil).query().isEmpty)
  }
}
