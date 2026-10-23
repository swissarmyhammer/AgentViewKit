import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import FoundationModelsACP
import SwiftUI
import Testing

@testable import AgentViewKit

/// Hosted tests of the search field of a ``SessionListView``: a one-line
/// EditorKit field (`SingleLineField`) in a root command scope, so the window
/// has its undo stack.
///
/// The field carries ``SessionListView/searchIdentifier`` on its text view.
/// Typing filters the rows, Return submits nothing and keeps the query, Esc
/// takes back the typing since the field got the focus, and `edit.undo` of
/// the window takes the typing out.
@Suite(.serialized, .hostedSerially) @MainActor struct SessionListSearchFieldHostedTests {
  /// The query that the tests type. It matches the working directory of
  /// the closed session alone.
  static let query = "docs"

  /// The row identifiers of the first page, in list order.
  static let allRows = [
    SessionPickerConnectionModelHostedTests.row(ScriptedSession.sessionID),
    SessionPickerConnectionModelHostedTests.row(SessionPickerConnectionModelHostedTests.closedSessionID),
  ]

  /// The row identifiers that ``query`` keeps.
  static let matchingRows = [
    SessionPickerConnectionModelHostedTests.row(SessionPickerConnectionModelHostedTests.closedSessionID)
  ]

  /// Shows the picker of `session` in the root command scope of a new
  /// command system, and waits until the picker reports the end of its
  /// first refresh.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - presses: The recorder of the press reports of the picker.
  /// - Returns: The window of the picker.
  /// - Throws: An issue when the window has no undo stack.
  static func mount(
    _ session: ScriptedSession, presses: ReportRecorder<String> = ReportRecorder()
  ) async throws -> MountedThread<some View> {
    let system = CommandSystem()
    let calls = ReportRecorder<String?>()
    let picker = SessionListView(connection: session.connection) { _ in }
      .environment(\.sessionListCallReport, calls.report)
      .environment(\.sessionListPressReport, presses.report)
    let harness = HostedViewHarness(
      SingleLineFieldChecks.scoped(picker, in: system), size: SessionPickerConnectionModelHostedTests.listSize)
    await harness.render { !calls.values.isEmpty }
    return try SingleLineFieldChecks.window(of: harness, system: system)
  }

  /// The row identifiers that the picker shows.
  ///
  /// - Parameter window: The window of the picker.
  /// - Returns: The identifiers, in view order.
  static func rows(in window: MountedThread<some View>) -> [String] {
    SessionPickerConnectionModelHostedTests.rowIdentifiers(in: window.harness)
  }

  @Test func theTextViewOfTheSearchFieldAloneCarriesTheSearchIdentifier() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let window = try await Self.mount(session)
    defer { window.harness.close() }

    try SingleLineFieldChecks.expectOneTextViewCarries(SessionListView.searchIdentifier, in: window.harness)
    #expect(window.harness.element(identifier: SessionListView.searchIdentifier)?.label == "Search")
  }

  /// The search sends no request, so Return has nothing to submit: it
  /// presses no button, inserts no line, and keeps the query and the
  /// filtered rows.
  @Test func returnInTheSearchFieldKeepsTheQueryAndPressesNothing() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let presses = ReportRecorder<String>()
    let window = try await Self.mount(session, presses: presses)
    defer { window.harness.close() }
    let textView = try SingleLineFieldChecks.type(
      Self.query, intoFieldWith: SessionListView.searchIdentifier, in: window.harness)

    try window.harness.sendKey(.return)

    #expect(textView.string == Self.query)
    #expect(Self.rows(in: window) == Self.matchingRows)
    #expect(presses.values.isEmpty)
  }

  @Test func escapeInTheSearchFieldTakesBackTheTypingAndShowsEachRow() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let window = try await Self.mount(session)
    defer { window.harness.close() }
    let textView = try SingleLineFieldChecks.type(
      Self.query, intoFieldWith: SessionListView.searchIdentifier, in: window.harness)
    try #require(Self.rows(in: window) == Self.matchingRows)

    try window.harness.sendKey(.escape)

    #expect(textView.string.isEmpty)
    #expect(Self.rows(in: window) == Self.allRows)
  }

  @Test func theWindowUndoTakesTheTypingOutOfTheSearchField() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let window = try await Self.mount(session)
    defer { window.harness.close() }

    let textView = try await SingleLineFieldChecks.typeAndUndoAll(
      Self.query, intoFieldWith: SessionListView.searchIdentifier, in: window)

    #expect(textView.string.isEmpty)
    #expect(Self.rows(in: window) == Self.allRows)
    #expect(!window.stack.canUndo)
  }
}
