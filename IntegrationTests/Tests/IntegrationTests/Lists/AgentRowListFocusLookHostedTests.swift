import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The focus look of a row of an ``AgentRowList`` that holds the keyboard
/// focus itself (EditorKit style.md, "Selection and focus").
///
/// A row of a list that opens on a double click is focusable with each
/// interaction, so a `nav.*` move and a jump give the first responder to the
/// focusable view of the row, and not to the beacon of its scope. The row
/// shows that focus as the focused fill of its surface, never as an outline.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListFocusLookHostedTests {
  /// The scope of the list of the bed.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "focusLookList"), rowKind: "focusLookRow")

  /// The ids of the rows, in list order.
  static let ids = ["first", "second", "third"]

  /// The id of the row that takes the focus.
  static let focusedID = ids[0]

  /// The id of the current row, which shows the soft selection fill and not
  /// the focused fill.
  static let currentID = ids[1]

  /// Mounts the list above the reference fill of the bed, gives the focus to
  /// the row ``focusedID`` through the command system, as a `nav.*` move
  /// does, and renders.
  ///
  /// - Returns: The window of the bed.
  /// - Throws: An issue when a beacon never goes live, the focus does not
  ///   land, or the beacon of the row, and not the row, holds the focus.
  static func focusedRowWindow() async throws -> CommandWindow {
    let path = scope.path(ofRow: focusedID)
    let window = try await CommandWindow(beacons: ids.map(scope.path(ofRow:))) {
      AgentRowList(ids, id: \.self, scope: scope, current: currentID, onOpen: { _ in }) { Text($0) }
        .focusLookBed()
        .transaction { $0.disablesAnimations = true }
    }
    try #require(window.system.geometry.requestFocus(at: path))
    await RunLoopBlockFence.afterPendingBlocks()
    window.harness.render()
    try FocusLookBed.requireItemHoldsFocus(in: window.harness)
    return window
  }

  /// A production change that fails this test: the surface of the row reads
  /// only the focus of its scope, so a row that holds the focus itself
  /// shows no focused fill.
  @Test func aRowThatHoldsTheFocusItselfShowsTheFocusedFill() async throws {
    let window = try await Self.focusedRowWindow()
    defer { window.harness.close() }

    let fillCount = try FocusLookBed.referenceFillCount(in: window.harness)

    #expect(fillCount == FocusLookBed.focusedFillCount)
  }

  /// A production change that fails this test: `.focusEffectDisabled()`
  /// stands inside the `.focusable()` of the row, so SwiftUI draws the
  /// system focus ring around the focused row.
  @Test func aRowThatHoldsTheFocusItselfShowsNoSystemFocusRing() async throws {
    let window = try await Self.focusedRowWindow()
    defer { window.harness.close() }

    let holdsRing = FocusLookBed.holdsSystemFocusRing(in: window.harness)

    #expect(!holdsRing)
  }
}
