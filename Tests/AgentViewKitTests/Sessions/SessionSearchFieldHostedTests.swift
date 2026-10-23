@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Hosted tests of the search field of a ``SessionListView``: a one-line
/// EditorKit field (^8zmkh1a).
///
/// Each test shows the picker of a session with two listed sessions under the
/// root command scope of a window, waits until the picker reports the end of
/// its first refresh, and then edits the search field with key events.
@Suite(.serialized, .hostedSerially) @MainActor struct SessionSearchFieldHostedTests {
  /// The search text that keeps only the session in the docs directory.
  static let query = "docs"

  /// The prompt of the search field: its placeholder and its accessibility
  /// label.
  static let prompt = "Search"

  /// Mounts the picker of `session` under the root command scope of a window,
  /// waits until the picker reports the end of its first refresh, and then
  /// renders it.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The mounted picker.
  /// - Throws: An error when the window has no undo stack.
  static func mountPicker(_ session: ScriptedSession) async throws -> MountedOneLineField<some View> {
    let calls = ReportRecorder<String?>()
    let picker = try OneLineFieldHarness.mount(size: SessionPickerConnectionModelHostedTests.listSize) {
      SessionListView(connection: session.connection) { _ in }
        .environment(\.sessionListCallReport, calls.report)
    }
    await picker.harness.render { !calls.values.isEmpty }
    return picker
  }

  /// The text view of the search field of `picker`.
  ///
  /// - Parameter picker: The mounted picker.
  /// - Returns: The text view.
  /// - Throws: An issue when the picker has no search text view.
  static func searchTextView(of picker: MountedOneLineField<some View>) throws -> NSTextView {
    try OneLineFieldHarness.textView(identifier: SessionListView.searchIdentifier, in: picker.harness)
  }

  /// The row identifiers of both listed sessions, in list order.
  static var allRows: [String] {
    [
      SessionPickerConnectionModelHostedTests.row(ScriptedSession.sessionID),
      SessionPickerConnectionModelHostedTests.row(SessionPickerConnectionModelHostedTests.closedSessionID),
    ]
  }

  /// The row identifier of the one session that ``query`` keeps.
  static var queriedRows: [String] {
    [SessionPickerConnectionModelHostedTests.row(SessionPickerConnectionModelHostedTests.closedSessionID)]
  }

  /// The row identifiers that `picker` shows.
  ///
  /// - Parameter picker: The mounted picker.
  /// - Returns: The identifiers, in list order.
  static func rows(of picker: MountedOneLineField<some View>) -> [String] {
    SessionPickerConnectionModelHostedTests.rowIdentifiers(in: picker.harness)
  }

  @Test func theSearchFieldIsAnEditorKitTextViewWithTheIdentifierAndThePrompt() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let picker = try await Self.mountPicker(session)
    defer { picker.harness.close() }

    let textView = try Self.searchTextView(of: picker)

    #expect(picker.harness.firstEditableTextView(of: NSTextField.self) == nil)
    #expect(picker.harness.firstEditableTextView(of: NSTextView.self) === textView)
    #expect(picker.harness.element(identifier: SessionListView.searchIdentifier)?.label == Self.prompt)
  }

  /// Return and Esc each commit the search: the text stays one line, and
  /// the filter stays. No key discards the draft (EditorKit ^a54d840).
  @Test(arguments: [KeyEquivalent.return, .escape])
  func aCommitKeyInTheSearchFieldKeepsTheQueryAndTheFilter(key: KeyEquivalent) async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let picker = try await Self.mountPicker(session)
    defer { picker.harness.close() }
    let textView = try Self.searchTextView(of: picker)
    try OneLineFieldHarness.type(Self.query, into: textView, in: picker.harness)
    try #require(Self.rows(of: picker) == Self.queriedRows)

    try picker.harness.sendKeyDown(key, to: textView)

    #expect(textView.string == Self.query)
    #expect(Self.rows(of: picker) == Self.queriedRows)
  }

  @Test func revertFieldPutsBackTheEmptyQueryAndEachRow() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let picker = try await Self.mountPicker(session)
    defer { picker.harness.close() }
    let textView = try Self.searchTextView(of: picker)
    try OneLineFieldHarness.type(Self.query, into: textView, in: picker.harness)
    try #require(Self.rows(of: picker) == Self.queriedRows)

    try OneLineFieldHarness.revertField(
      at: OneLineFieldHarness.fieldPath(id: SessionListView.searchIdentifier), in: picker)

    #expect(textView.string.isEmpty)
    #expect(Self.rows(of: picker) == Self.allRows)
  }

  @Test func typingInTheSearchFieldIsUndoneByTheWindowUndo() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let picker = try await Self.mountPicker(session)
    defer { picker.harness.close() }
    let textView = try Self.searchTextView(of: picker)
    try OneLineFieldHarness.type(Self.query, into: textView, in: picker.harness)
    try #require(Self.rows(of: picker) == Self.queriedRows)

    try await OneLineFieldHarness.undoAll(Self.query, in: picker)

    #expect(textView.string.isEmpty)
    #expect(Self.rows(of: picker) == Self.allRows)
    #expect(!picker.stack.canUndo)
  }
}
