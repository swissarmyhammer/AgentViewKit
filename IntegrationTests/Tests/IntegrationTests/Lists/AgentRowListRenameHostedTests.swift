import AppKit
import EditorCommands
import EditorCommandsUI
import EditorCore
import EditorSwiftUI
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The window of one test: an ``AgentRowList`` of two rows that open, and a
/// borderless EditorKit rename field (`SingleLineField`) in each row, as the
/// rename of a session in the sidebar of a host (TestudoApp D197 b).
///
/// The window is never made key. A test makes the text view of a field the
/// first responder, and `HostedViewHarness.sendKey(_:modifiers:)` sends a key
/// to the window.
@MainActor private struct RenameBed {
  /// The ids of the rows, in list order.
  static let ids = ["first", "second"]

  /// The list of the bed.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "renameList"), rowKind: "renameRow")

  /// The text that a test types into a rename field.
  static let typed = "x"

  /// The command system of the window.
  let system: CommandSystem

  /// The id of each open, in order.
  let opened: ReportRecorder<String>

  /// The reason of each commit of a rename field, in order.
  let commits: ReportRecorder<EditorCommitReason>

  /// The harness that shows the window.
  let harness: HostedViewHarness<AnyView>

  /// Mounts the list with a rename field in each row, and waits for the
  /// beacons of its rows.
  init() async throws {
    let system = CommandSystem()
    let opened = ReportRecorder<String>()
    let commits = ReportRecorder<EditorCommitReason>()
    let open = opened.report
    let commit = commits.report
    let models = Dictionary(uniqueKeysWithValues: Self.ids.map { ($0, EditorModel($0)) })
    self.system = system
    self.opened = opened
    self.commits = commits
    harness = try await CommandWindow(system: system, beacons: [Self.rowPath(0), Self.rowPath(1)]) {
      AgentRowList(Self.ids, id: \.self, scope: Self.scope) { id in
        open(id)
      } row: { id in
        SingleLineField(model: models[id] ?? EditorModel(id), id: "rename-\(id)")
          .onEditorCommit { commit($0.reason) }
          .editorTextAccessibilityIdentifier(Self.fieldIdentifier(id))
      }
    }.harness
  }

  /// The path of the scope of the row at `index`.
  ///
  /// - Parameter index: The index of the row.
  /// - Returns: The path of the row.
  static func rowPath(_ index: Int) -> FocusPath {
    scope.path(ofRow: ids[index])
  }

  /// The accessibility identifier of the text view of the rename field of
  /// the row with `id`.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: The identifier.
  static func fieldIdentifier(_ id: String) -> String {
    "rename-field-\(id)"
  }

  /// Types ``typed`` into the rename field of the second row in place of
  /// the old name, as a rename does, and then presses `key`. The field of
  /// each row starts with the id of the row as its text.
  ///
  /// - Parameter key: The key to press after the typing.
  /// - Throws: An issue when the field cannot take the focus, or when the
  ///   typing does not reach the field.
  func rename(thenPress key: KeyEquivalent) throws {
    try SingleLineFieldChecks.type(
      Self.typed, intoFieldWith: Self.fieldIdentifier(Self.ids[1]), in: harness,
      replacingAllText: true, thenPress: key)
  }
}

/// A rename field in a row of an ``AgentRowList`` gets its own keys (D197 b):
/// while the field is in edit, the list takes no key, so Return commits the
/// field and Esc ends its edit, in place of `agentRowList.open` and
/// `nav.drillOut`. When the edit ends, the list takes its keys again.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListRenameHostedTests {
  @Test func returnInTheRenameFieldCommitsTheFieldAndOpensNoRow() async throws {
    let bed = try await RenameBed()
    defer { bed.harness.close() }

    try bed.rename(thenPress: .return)

    #expect(bed.commits.values == [.submit])
    #expect(bed.opened.values.isEmpty)
  }

  @Test func escapeInTheRenameFieldEndsTheEditAndOpensNoRow() async throws {
    let bed = try await RenameBed()
    defer { bed.harness.close() }

    try bed.rename(thenPress: .escape)

    #expect(bed.commits.values == [.leave])
    #expect(bed.opened.values.isEmpty)
  }

  @Test func returnOnTheRowAfterTheRenameOpensTheRow() async throws {
    let bed = try await RenameBed()
    defer { bed.harness.close() }
    try bed.rename(thenPress: .return)
    try #require(bed.system.geometry.requestFocus(at: RenameBed.rowPath(1)))
    bed.harness.render()

    try bed.harness.sendKey(.return)

    #expect(bed.opened.values == [RenameBed.ids[1]])
  }
}
