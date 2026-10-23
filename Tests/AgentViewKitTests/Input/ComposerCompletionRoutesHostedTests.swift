@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorComplete
import EditorExtensions
import Foundation
import SwiftUI
import Testing

/// One prefix-completion route of the composer tests, and the rows of its
/// provider: the sigil set of the chat input of TestudoApp (^6nkvrk1).
struct ComposerRouteFixture: Sendable, CustomTestStringConvertible {
  /// The sigil of the route.
  let sigil: String

  /// Where the sigil opens a token.
  let anchor: CompletionTokenOpening.Anchor

  /// The rows of the provider of the route, in the order of the host.
  let rows: [StaticListCompletionProvider.Item]

  /// The labels of the rows, in the order the popup lists them.
  var labels: [String] { rows.map(\.label) }

  /// The text that an accept of the first row gives: the sigil and the text
  /// of the row.
  var firstAccepted: String { sigil + rows[0].text }

  /// The route over a provider of ``rows``.
  var route: PrefixCompletionRoute {
    PrefixCompletionRoute(sigil, anchor: anchor, provider: StaticListCompletionProvider(rows))
  }

  var testDescription: String { sigil }

  /// `@` to project files.
  nonisolated static let files = ComposerRouteFixture(
    sigil: "@", anchor: .tokenStart, rows: [.init("README.md"), .init("Package.swift")])

  /// `^` to tasks.
  nonisolated static let tasks = ComposerRouteFixture(
    sigil: "^", anchor: .tokenStart,
    rows: [
      .init("a1b2c3d", label: "Fix the build", detail: "doing"),
      .init("e4f5a6b", label: "Write the docs", detail: "todo"),
    ])

  /// `#` to tags.
  nonisolated static let tags = ComposerRouteFixture(
    sigil: "#", anchor: .tokenStart, rows: [.init("work"), .init("home")])

  /// `/` to commands, at the start of a line.
  nonisolated static let commands = ComposerRouteFixture(
    sigil: "/", anchor: .lineStart,
    rows: [.init("review", label: "/review"), .init("ship", label: "/ship")])

  /// Every route of the tests.
  nonisolated static let all = [files, tasks, tags, commands]

  /// The routes that a host gives to the composer.
  static var routes: [PrefixCompletionRoute] { all.map(\.route) }
}

/// A key that accepts an open completion.
enum ComposerAcceptKey: String, CaseIterable, Sendable {
  /// The Return key.
  case returnKey

  /// The Tab key.
  case tab

  /// The key equivalent that the harness sends.
  var key: KeyEquivalent {
    switch self {
    case .returnKey: .return
    case .tab: .tab
    }
  }
}

/// A thread view of a scripted session whose default composer gets the
/// prefix-completion routes of the host with one modifier, as TestudoApp
/// gives them.
struct RoutedComposerThreadHost: View {
  /// The scripted session of the thread.
  let session: ScriptedSession

  /// The model and the completion engine of the editor of the composer.
  let editorSession: PromptEditorSession

  /// The routes of the host.
  let routes: [PrefixCompletionRoute]

  var body: some View {
    AgentThreadView(session: session.model, connection: session.connection) {
      DefaultThreadComposer(editorSession: editorSession)
    }
    .composerCompletions(routes)
  }
}

/// Tests for the prefix-completion routes of the composer (^8mv9xpj): the
/// host gives the routes with ``SwiftUI/View/composerCompletions(_:)``, and
/// the composer does the rest. Typing a sigil lists the rows of its route in
/// the popup at the caret, in the floating bottom bar. Return and Tab accept
/// the selected row as one entry of the window undo stack.
@Suite(.serialized, .hostedSerially) @MainActor struct ComposerCompletionRoutesHostedTests {
  /// How far the leading edge of the popup may be from the caret, in points.
  static let caretTolerance: CGFloat = 1

  /// The text before the sigil in the caret test, so that the caret is not
  /// at the leading edge of the editor.
  static let caretLead = "fix the "

  /// Shows a thread with the default composer and `routes`, under a command
  /// system.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - editorSession: The session of the editor of the composer.
  ///   - routes: The routes of the host.
  ///   - fileRoot: The file root of the composer, or `nil`.
  /// - Returns: The mounted thread.
  /// - Throws: An error when the window has no undo stack.
  static func mount(
    _ session: ScriptedSession, editorSession: PromptEditorSession,
    routes: [PrefixCompletionRoute] = ComposerRouteFixture.routes, fileRoot: URL? = nil
  ) throws -> MountedThread<some View> {
    try ComposerHarness.mountThread(of: session.model) {
      RoutedComposerThreadHost(session: session, editorSession: editorSession, routes: routes)
        .promptFileRoot(fileRoot)
        .environment(\.sessionModel, session.model)
    }
  }

  /// Focuses the editor and types `text` into it.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - thread: The mounted thread.
  ///   - editorSession: The session of the editor of the composer.
  /// - Throws: An error when the editor cannot get the focus.
  static func type(
    _ text: String, in thread: MountedThread<some View>, editorSession: PromptEditorSession
  ) async throws {
    try await ComposerHarness.typePrompt(text, in: thread.harness) { editorSession.model.text }
  }

  /// The labels of the rows that the completion session of the editor lists.
  ///
  /// - Parameter editorSession: The session of the editor of the composer.
  /// - Returns: The labels, in list order.
  static func listedLabels(of editorSession: PromptEditorSession) -> [String] {
    ComposerEditorMenuHostedTests.completion(of: editorSession).listedItems.map(\.label)
  }

  /// Waits until the completion session lists each of `labels`, and renders.
  ///
  /// - Parameters:
  ///   - labels: The labels to wait for.
  ///   - editorSession: The session of the editor of the composer.
  ///   - thread: The mounted thread.
  static func waitForRows(
    _ labels: [String], of editorSession: PromptEditorSession, in thread: MountedThread<some View>
  ) async {
    await thread.harness.render { Set(labels).isSubset(of: listedLabels(of: editorSession)) }
  }

  /// Sends `key` to the text view of the editor.
  ///
  /// - Parameters:
  ///   - key: The key to send.
  ///   - thread: The mounted thread.
  /// - Throws: An error when the harness finds no text view.
  static func press(_ key: KeyEquivalent, in thread: MountedThread<some View>) throws {
    let editor = try #require(thread.harness.firstEditableTextView(of: NSTextView.self))
    try thread.harness.sendKeyDown(key, to: editor)
  }

  // MARK: - Rows

  @Test(arguments: ComposerRouteFixture.all)
  func typingASigilListsTheRowsOfItsRoute(_ fixture: ComposerRouteFixture) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let editorSession = PromptEditorSession()
    let thread = try Self.mount(session, editorSession: editorSession)
    defer { thread.harness.close() }

    try await Self.type(fixture.sigil, in: thread, editorSession: editorSession)
    await Self.waitForRows(fixture.labels, of: editorSession, in: thread)

    let rows = thread.harness.elements(under: EditorKitPromptEditor.completionListIdentifier)
      .filter { $0.identifier == EditorKitPromptEditor.completionRowIdentifier }
    #expect(Self.listedLabels(of: editorSession) == fixture.labels)
    #expect(rows.map(\.label) == fixture.labels)
  }

  /// A `/` route takes the `/` from the slash commands of the agent: the
  /// popup lists the rows of the route alone.
  @Test func aSlashRouteTakesTheSlashFromTheAgentCommands() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let editorSession = PromptEditorSession()
    let thread = try Self.mount(session, editorSession: editorSession)
    defer { thread.harness.close() }
    let model = session.model
    try await session.sendUpdate(EditorKitPromptEditorHostedTests.commandsUpdate)
    await thread.harness.render { model.availableCommands != nil }

    try await Self.type(ComposerRouteFixture.commands.sigil, in: thread, editorSession: editorSession)
    await Self.waitForRows(ComposerRouteFixture.commands.labels, of: editorSession, in: thread)

    #expect(Self.listedLabels(of: editorSession) == ComposerRouteFixture.commands.labels)
  }

  /// An `@` route takes the `@` from the file references of the file root:
  /// the popup lists the rows of the route alone.
  @Test func anAtRouteTakesTheAtFromTheFileRoot() async throws {
    let root = try TemporaryFileRoot(files: ["notes.txt"])
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let editorSession = PromptEditorSession()
    let thread = try Self.mount(session, editorSession: editorSession, fileRoot: root.url)
    defer { thread.harness.close() }

    try await Self.type(ComposerRouteFixture.files.sigil, in: thread, editorSession: editorSession)
    await Self.waitForRows(ComposerRouteFixture.files.labels, of: editorSession, in: thread)

    #expect(Self.listedLabels(of: editorSession) == ComposerRouteFixture.files.labels)
  }

  /// With no routes, a sigil that no kit source owns opens no popup.
  @Test func withNoRoutesASigilOpensNoPopup() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let editorSession = PromptEditorSession()
    let thread = try Self.mount(session, editorSession: editorSession, routes: [])
    defer { thread.harness.close() }

    try await Self.type(ComposerRouteFixture.tasks.sigil, in: thread, editorSession: editorSession)

    #expect(!ComposerEditorMenuHostedTests.completion(of: editorSession).isOpen)
    #expect(thread.harness.frame(identifier: EditorKitPromptEditor.completionListIdentifier) == nil)
  }

  // MARK: - Accept

  @Test(arguments: ComposerAcceptKey.allCases)
  func anAcceptKeyInsertsTheSelectedRow(_ key: ComposerAcceptKey) async throws {
    let fixture = ComposerRouteFixture.tasks
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let editorSession = PromptEditorSession()
    let thread = try Self.mount(session, editorSession: editorSession)
    defer { thread.harness.close() }
    try await Self.type(fixture.sigil, in: thread, editorSession: editorSession)
    await Self.waitForRows(fixture.labels, of: editorSession, in: thread)

    try Self.press(key.key, in: thread)

    #expect(editorSession.model.text == fixture.firstAccepted)
    #expect(!ComposerEditorMenuHostedTests.completion(of: editorSession).isOpen)
    #expect(session.promptTexts.isEmpty)
  }

  /// The accept leaves no popup open, so the next Return sends the prompt
  /// with the accepted row.
  @Test func aReturnAfterAnAcceptSendsThePrompt() async throws {
    let fixture = ComposerRouteFixture.tasks
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let editorSession = PromptEditorSession()
    let thread = try Self.mount(session, editorSession: editorSession)
    defer { thread.harness.close() }
    try await Self.type(fixture.sigil, in: thread, editorSession: editorSession)
    await Self.waitForRows(fixture.labels, of: editorSession, in: thread)
    try Self.press(.tab, in: thread)
    try #require(editorSession.model.text == fixture.firstAccepted)

    try Self.press(.return, in: thread)

    #expect(editorSession.model.text.isEmpty)
    await ObservationWait.until { !session.promptTexts.isEmpty }
    #expect(session.promptTexts == [fixture.firstAccepted])
  }

  /// An accept is ONE entry on the window undo stack: one `edit.undo` takes
  /// the whole accepted row out and gives back the typed sigil.
  @Test(arguments: ComposerAcceptKey.allCases)
  func oneWindowUndoTakesTheWholeAcceptOut(_ key: ComposerAcceptKey) async throws {
    let fixture = ComposerRouteFixture.tasks
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let editorSession = PromptEditorSession()
    let thread = try Self.mount(session, editorSession: editorSession)
    defer { thread.harness.close() }
    try await Self.type(fixture.sigil, in: thread, editorSession: editorSession)
    await Self.waitForRows(fixture.labels, of: editorSession, in: thread)
    let typing = try #require(thread.stack.undoTop)
    try Self.press(key.key, in: thread)
    try #require(editorSession.model.text == fixture.firstAccepted)
    let accept = try #require(thread.stack.undoTop)
    try #require(accept.id != typing.id)

    try await ComposerWindowUndoHostedTests.perform(.undo, in: thread)

    #expect(editorSession.model.text == fixture.sigil)
    #expect(thread.stack.undoTop?.id == typing.id)
  }

  // MARK: - Placement

  /// The popup sits at the caret: its leading edge is at the caret, and it is
  /// above the glass of the field, in the floating bottom bar.
  @Test func thePopupSitsAtTheCaret() async throws {
    let fixture = ComposerRouteFixture.tasks
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let editorSession = PromptEditorSession()
    let thread = try Self.mount(session, editorSession: editorSession)
    defer { thread.harness.close() }
    try await Self.type(Self.caretLead + fixture.sigil, in: thread, editorSession: editorSession)
    await Self.waitForRows(fixture.labels, of: editorSession, in: thread)

    let textView = try #require(thread.harness.firstEditableTextView(of: NSTextView.self))
    let caret = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)
    let list = try #require(thread.harness.frame(identifier: EditorKitPromptEditor.completionListIdentifier))
    let field = try #require(thread.harness.frame(identifier: PromptFieldSurface.identifier))
    #expect(abs(list.minX - caret.minX) <= Self.caretTolerance, "list \(list), caret \(caret)")
    #expect(list.minY > field.maxY, "list \(list), field \(field)")
  }
}
