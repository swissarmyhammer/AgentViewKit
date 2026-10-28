import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The selection and the keys of the session picker, which come from the
/// command scopes of its rows, the `nav.*` commands of EditorKit and its
/// jump mode, and not from a native list.
///
/// Each test shows the picker of a ``ScriptedSession`` in a window with a
/// command system that the test holds, so that it can read the geometry of
/// the rows and start a jump session. The selected row is the row whose scope
/// holds the focus. A key goes to the window, as a typed key does, and the
/// list routes it to the registry at the focused scope.
@Suite(.serialized, .hostedSerially) @MainActor struct SessionListNavigationHostedTests {
  /// The ids of the two listed sessions of the first page, in list order.
  static let listedIDs = [ScriptedSession.sessionID, SessionPickerConnectionModelHostedTests.closedSessionID]

  /// Mounts the picker of a session in a window with `system`, waits until
  /// the picker reports the end of its first refresh, and then renders it.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - system: The command system of the window.
  ///   - calls: The recorder of the call reports of the picker.
  ///   - presses: The recorder of the press reports of the picker.
  ///   - onOpen: The action for a resumed session.
  /// - Returns: The harness that shows the picker.
  static func mountPicker(
    _ session: ScriptedSession, system: CommandSystem, calls: ReportRecorder<String?> = ReportRecorder(),
    presses: ReportRecorder<String> = ReportRecorder(), onOpen: @escaping (SessionModel) -> Void = { _ in }
  ) async -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(
      SessionListView(connection: session.connection, onOpen: onOpen)
        .environment(\.sessionListCallReport, calls.report)
        .environment(\.sessionListPressReport, presses.report)
        .commandSystem(system),
      size: SessionPickerConnectionModelHostedTests.listSize)
    await harness.render { !calls.values.isEmpty }
    return harness
  }

  /// The path of the scope of the list of `connection`.
  ///
  /// - Parameter connection: The connection model of the picker.
  /// - Returns: The path of the list scope, at the root of the window.
  static func listPath(of connection: ConnectionModel) -> FocusPath {
    .root(SessionListView.listSegment(for: connection))
  }

  /// The paths of the scopes of the rows of the listed sessions, in list
  /// order.
  ///
  /// - Parameter connection: The connection model of the picker.
  /// - Returns: The row paths.
  static func rowPaths(of connection: ConnectionModel) -> [FocusPath] {
    listedIDs.map { listPath(of: connection).appending(SessionListView.rowSegment(for: SessionId(rawValue: $0))) }
  }

  /// The scope among `scopes` whose area is the area of the first responder
  /// of the window: the scope that holds the focus.
  ///
  /// The frames must be equal, not only overlap: the list scope holds its
  /// rows, so the center of the list can lie in a row.
  ///
  /// - Parameters:
  ///   - scopes: The paths of the candidate scopes.
  ///   - system: The command system of the window.
  ///   - harness: The harness that shows the picker.
  /// - Returns: The path of the focused scope, or `nil` when none of
  ///   `scopes` holds the focus.
  static func focusedScope(among scopes: [FocusPath], in system: CommandSystem, harness: HostedViewHarness<some View>)
    -> FocusPath?
  {
    guard let responder = harness.window.firstResponder as? NSView,
      let frame = WindowSpace.rect(of: responder)
    else { return nil }
    return scopes.first { system.geometry.rect(of: $0) == frame }
  }

  /// The row that holds the keyboard focus, which is the selected row.
  ///
  /// - Parameters:
  ///   - rows: The row paths.
  ///   - system: The command system of the window.
  ///   - harness: The harness that shows the picker.
  /// - Returns: The path of the selected row, or `nil` when no row is
  ///   selected.
  static func selectedRow(among rows: [FocusPath], in system: CommandSystem, harness: HostedViewHarness<some View>)
    -> FocusPath?
  {
    focusedScope(among: rows, in: system, harness: harness)
  }

  @Test func theDownArrowSelectsTheNextRowAndTheUpArrowTheRowBefore() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let system = CommandSystem()
    let harness = await Self.mountPicker(session, system: system)
    defer { harness.close() }
    let rows = Self.rowPaths(of: session.connection)
    try #require(system.geometry.requestFocus(at: rows[0]))
    harness.render()
    try #require(Self.selectedRow(among: rows, in: system, harness: harness) == rows[0])

    try harness.sendKey(.downArrow)
    #expect(Self.selectedRow(among: rows, in: system, harness: harness) == rows[1])

    try harness.sendKey(.upArrow)
    #expect(Self.selectedRow(among: rows, in: system, harness: harness) == rows[0])
  }

  /// Return runs the open command of the list at the selected row. The
  /// picker reports the press of the row in the same step as it starts the
  /// resume, and gives the resumed model to its open action before it
  /// reports the end of the call.
  @Test func returnOpensTheSessionOfTheSelectedRow() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let system = CommandSystem()
    var opened: [SessionModel] = []
    let calls = ReportRecorder<String?>()
    let presses = ReportRecorder<String>()
    let harness = await Self.mountPicker(session, system: system, calls: calls, presses: presses) { opened.append($0) }
    defer { harness.close() }
    let rows = Self.rowPaths(of: session.connection)
    try #require(system.geometry.requestFocus(at: rows[1]))
    harness.render()
    let reportsBefore = calls.values.count

    try harness.sendKey(.return)
    try #require(presses.values == [SessionPickerConnectionModelHostedTests.row(Self.listedIDs[1])])
    await harness.render { calls.values.count > reportsBefore }

    #expect(opened.map(\.sessionId.rawValue) == [Self.listedIDs[1]])
  }

  /// Esc runs `nav.drillOut` at the selected row, which gives the focus to
  /// the list itself, so no row is selected.
  @Test func escapeClearsTheSelection() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let system = CommandSystem()
    let harness = await Self.mountPicker(session, system: system)
    defer { harness.close() }
    let rows = Self.rowPaths(of: session.connection)
    try #require(system.geometry.requestFocus(at: rows[1]))
    harness.render()
    try #require(Self.selectedRow(among: rows, in: system, harness: harness) == rows[1])

    try harness.sendKey(.escape)

    let list = Self.listPath(of: session.connection)
    #expect(Self.focusedScope(among: rows + [list], in: system, harness: harness) == list)
  }

  @Test func aJumpSessionLabelsEachRowAndAJumpToARowSelectsIt() async throws {
    let session = try await SessionPickerConnectionModelHostedTests.openSession()
    defer { session.close() }
    let system = CommandSystem()
    let harness = await Self.mountPicker(session, system: system)
    defer { harness.close() }
    let rows = Self.rowPaths(of: session.connection)
    let jump = JumpModeController(system: system)
    try #require(jump.activate(layer: Self.listPath(of: session.connection)))
    let labelled = Set(try #require(jump.overlayState?.chips).map(\.id))
    #expect(labelled.isSuperset(of: rows))

    try #require(jump.commit(rows[1]))
    harness.render()

    #expect(Self.selectedRow(among: rows, in: system, harness: harness) == rows[1])
  }
}
