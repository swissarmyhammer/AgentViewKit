@testable import AgentViewKit
import Foundation
import FoundationModelsACPClient
import Testing

/// The table tests of the pure focus rule of the request deck (deck design
/// section 4, test plan row 37).
///
/// Each row gives the request ids and the front id before and after one
/// change of the model. The rule gives the focus move of the deck, or no
/// move.
struct RequestDeckFocusTests {
  /// Three request ids, oldest first.
  nonisolated static let ids: [PendingRequest.ID] = (0..<3).map { _ in UUID() }

  /// The request ids at `positions` of ``ids``.
  ///
  /// - Parameter positions: The positions, from zero.
  /// - Returns: The ids, in the order of `positions`.
  nonisolated static func ids(_ positions: Int...) -> [PendingRequest.ID] {
    positions.map { ids[$0] }
  }

  /// One row of the focus table. `@Test(arguments:)` reads the rows outside
  /// the main actor.
  nonisolated struct Row: CustomTestStringConvertible, Sendable {
    /// The name of the row in the test report.
    let name: String
    /// The request ids before the change, oldest first.
    let oldIDs: [PendingRequest.ID]
    /// The request ids after the change, oldest first.
    let newIDs: [PendingRequest.ID]
    /// The front request before the change, or `nil`.
    let oldFront: PendingRequest.ID?
    /// The front request after the change, or `nil`.
    let newFront: PendingRequest.ID?
    /// The move that the row expects, or `nil` for no move.
    let expected: DeckFocusMove?

    var testDescription: String { name }
  }

  /// The rows of the table.
  nonisolated static let rows: [Row] = [
    Row(
      name: "a first request comes into an empty deck", oldIDs: [], newIDs: ids(0),
      oldFront: nil, newFront: ids[0], expected: nil),
    Row(
      name: "a new request goes at the back", oldIDs: ids(0), newIDs: ids(0, 1),
      oldFront: ids[0], newFront: ids[0], expected: nil),
    Row(
      name: "the front resolves and a card stays", oldIDs: ids(0, 1), newIDs: ids(1),
      oldFront: ids[0], newFront: ids[1], expected: .nextFront(ids[1])),
    Row(
      name: "the last card resolves", oldIDs: ids(0), newIDs: [],
      oldFront: ids[0], newFront: nil, expected: .promptEditor),
    Row(
      name: "the user brings the next request to the front", oldIDs: ids(0, 1), newIDs: ids(0, 1),
      oldFront: ids[0], newFront: ids[1], expected: .broughtToFront(ids[1])),
    Row(
      name: "a card behind the front resolves", oldIDs: ids(0, 1, 2), newIDs: ids(0, 2),
      oldFront: ids[0], newFront: ids[0], expected: nil),
    Row(
      name: "the front resolves and a new request comes", oldIDs: ids(0), newIDs: ids(1),
      oldFront: ids[0], newFront: ids[1], expected: .nextFront(ids[1])),
    Row(
      name: "a front that the user chose resolves", oldIDs: ids(0, 1, 2), newIDs: ids(0, 2),
      oldFront: ids[1], newFront: ids[0], expected: .nextFront(ids[0])),
    Row(
      name: "nothing changes", oldIDs: ids(0, 1), newIDs: ids(0, 1),
      oldFront: ids[0], newFront: ids[0], expected: nil),
  ]

  @Test(arguments: rows)
  func theFocusMovesOnlyWhenTheOldFrontLeftOrTheUserChangedTheFront(row: Row) {
    let move = RequestDeck.focusTarget(
      oldIDs: row.oldIDs, newIDs: row.newIDs, oldFront: row.oldFront, newFront: row.newFront)

    #expect(move == row.expected)
  }

  @Test @MainActor func eachMoveNamesTheViewThatGetsTheFocus() {
    let id = Self.ids[0]
    let card = RequestDeck.identifier(for: id.uuidString)

    #expect(DeckFocusMove.nextFront(id).identifier == card)
    #expect(DeckFocusMove.broughtToFront(id).identifier == card)
    #expect(DeckFocusMove.promptEditor.identifier == StockPromptEditor.identifier)
  }

  @Test func onlyAFrontThatTheUserChoseTakesTheKeyboardFocus() {
    let id = Self.ids[0]

    #expect(DeckFocusMove.broughtToFront(id).keyboardFocus == id)
    #expect(DeckFocusMove.nextFront(id).keyboardFocus == nil)
    #expect(DeckFocusMove.promptEditor.keyboardFocus == nil)
  }
}
