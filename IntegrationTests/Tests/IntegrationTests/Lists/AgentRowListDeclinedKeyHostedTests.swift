import AppKit
import EditorCommands
import EditorCommandsTestSupport
import EditorCommandsUI
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The window of one test: an ``AgentRowList`` of two rows that open, and a
/// key handler of the host around the list that records each key that
/// reaches it.
///
/// The window is never made key: the list routes each key at the focused row
/// through ``AgentRowListKeys``, and `HostedViewHarness.sendKey(_:modifiers:)`
/// sends a key to the window itself.
@MainActor private struct DeclineBed {
  /// The ids of the rows, in list order.
  static let ids = ["first", "second"]

  /// The list of the bed.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "declineList"), rowKind: "declineRow")

  /// The id of the command of the host that the test binds at a row and that
  /// declines each run.
  static let declinerID: CommandID = "host.declineOnRow"

  /// The command system of the window.
  let system: CommandSystem

  /// The id of each open, in order.
  let opened: ReportRecorder<String>

  /// The characters of each key that reaches the key handler of the host,
  /// in order.
  let hostKeys: ReportRecorder<String>

  /// The runs of the declining command.
  let declines = CommandRunLog()

  /// The harness that shows the window.
  let harness: HostedViewHarness<AnyView>

  /// Mounts the list, waits for the beacons of its rows, and gives the focus
  /// to the second row.
  init() throws {
    let system = CommandSystem()
    let opened = ReportRecorder<String>()
    let hostKeys = ReportRecorder<String>()
    let open = opened.report
    let reportKey = hostKeys.report
    self.system = system
    self.opened = opened
    self.hostKeys = hostKeys
    harness = HostedViewHarness(
      AnyView(
        AgentRowList(Self.ids, id: \.self, scope: Self.scope) { id in
          open(id)
        } row: { id in
          Text(id)
        }
        .onKeyPress(phases: .down) { press in
          reportKey(press.characters)
          return .ignored
        }
        .commandSystem(system)),
      size: AgentRowListBedSupport.windowSize)
    try #require(waitForLiveBeacons([Self.rowPath(0), Self.rowPath(1)], in: system))
    try #require(system.geometry.requestFocus(at: Self.rowPath(1)))
    harness.render()
  }

  /// The path of the scope of the row at `index`.
  ///
  /// - Parameter index: The index of the row.
  /// - Returns: The path of the row.
  static func rowPath(_ index: Int) -> FocusPath {
    scope.path(ofRow: ids[index])
  }

  /// Binds `chord` at the focused row to a command of the host that declines
  /// each run.
  ///
  /// - Parameter chord: The chord of the command.
  func bindDecliner(to chord: KeyChord) {
    system.registry.register(
      .makeRecording(id: Self.declinerID, keys: [.cua: chord], log: declines, handles: false),
      at: Self.rowPath(1))
  }
}

/// A key that a command declines at a row of an ``AgentRowList`` goes on
/// (EditorKit ^jaxzzkn, AVK ^zb5td6w).
///
/// The decision for the list: a declined key falls through. The Open command
/// of the list declines only where its availability is unavailable (no open
/// action, or a path off a row), and EditorKit checks that availability just
/// before the run, so the Open command takes each key it is offered. A key
/// that a command nearer the row declines goes on to the next binding, which
/// is the Open command for Return, and a key that every command declines
/// leaves the key handler of the list `.ignored`, so the host gets it.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListDeclinedKeyHostedTests {
  @Test func returnThatACommandOfTheRowDeclinesOpensTheRow() throws {
    let bed = try DeclineBed()
    defer { bed.harness.close() }
    bed.bindDecliner(to: KeyChord.return)

    try bed.harness.sendKey(.return)

    #expect(bed.declines.runs.map(\.id) == [DeclineBed.declinerID])
    #expect(bed.opened.values == [DeclineBed.ids[1]])
  }

  @Test func aKeyThatEveryCommandDeclinesGoesOnToTheHost() throws {
    let bed = try DeclineBed()
    defer { bed.harness.close() }
    let key: KeyEquivalent = "x"
    bed.bindDecliner(to: KeyChord(String(key.character)))

    try bed.harness.sendKey(key)

    #expect(bed.declines.runs.map(\.id) == [DeclineBed.declinerID])
    #expect(bed.hostKeys.values == [String(key.character)])
  }
}
