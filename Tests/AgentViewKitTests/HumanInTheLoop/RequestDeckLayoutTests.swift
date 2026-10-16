@testable import AgentViewKit
import Foundation
import FoundationModelsACPClient
import Testing

/// The table tests of the pure layout of the request deck (deck design
/// sections 2 and 3).
///
/// Each row gives the request ids in FIFO order and the front id of the
/// model. The layout gives the front card, the top edges, the count of the
/// cards that do not show, the position "k of N", and the Previous and Next
/// state.
struct RequestDeckLayoutTests {
  /// Six request ids, oldest first.
  nonisolated static let ids: [PendingRequest.ID] = (0..<6).map { _ in UUID() }

  /// The request ids at `positions` of ``ids``.
  ///
  /// - Parameter positions: The positions, from zero.
  /// - Returns: The ids, in the order of `positions`.
  nonisolated static func ids(_ positions: Int...) -> [PendingRequest.ID] {
    positions.map { ids[$0] }
  }

  /// One row of the layout table. `@Test(arguments:)` reads the rows outside
  /// the main actor.
  nonisolated struct Row: CustomTestStringConvertible, Sendable {
    /// The name of the row in the test report.
    let name: String
    /// The positions in ``ids`` of the requests, oldest first.
    let requests: [Int]
    /// The front id of the model, or `nil`.
    let front: PendingRequest.ID?
    /// The layout that the row expects.
    let expected: DeckLayout

    var testDescription: String { name }
  }

  /// A request id that the requests do not hold: a front that went away.
  nonisolated static let goneID = UUID()

  /// The rows of the table.
  nonisolated static let rows: [Row] = [
    Row(
      name: "no request", requests: [], front: nil,
      expected: DeckLayout(
        front: nil, edges: [], moreCount: 0, position: 0, count: 0, previous: nil, next: nil)),
    Row(
      name: "one request", requests: [0], front: nil,
      expected: DeckLayout(
        front: ids[0], edges: [], moreCount: 0, position: 1, count: 1, previous: nil, next: nil)),
    Row(
      name: "two requests", requests: [0, 1], front: nil,
      expected: DeckLayout(
        front: ids[0], edges: ids(1), moreCount: 0, position: 1, count: 2, previous: nil,
        next: ids[1])),
    Row(
      name: "four requests", requests: [0, 1, 2, 3], front: nil,
      expected: DeckLayout(
        front: ids[0], edges: ids(1, 2, 3), moreCount: 0, position: 1, count: 4, previous: nil,
        next: ids[1])),
    Row(
      name: "six requests", requests: [0, 1, 2, 3, 4, 5], front: nil,
      expected: DeckLayout(
        front: ids[0], edges: ids(1, 2, 3), moreCount: 2, position: 1, count: 6, previous: nil,
        next: ids[1])),
    Row(
      name: "six requests, front in the middle", requests: [0, 1, 2, 3, 4, 5], front: ids[2],
      expected: DeckLayout(
        front: ids[2], edges: ids(0, 1, 3), moreCount: 2, position: 3, count: 6, previous: ids[1],
        next: ids[3])),
    Row(
      name: "six requests, front at the back", requests: [0, 1, 2, 3, 4, 5], front: ids[5],
      expected: DeckLayout(
        front: ids[5], edges: ids(0, 1, 2), moreCount: 2, position: 6, count: 6, previous: ids[4],
        next: nil)),
    Row(
      name: "four requests, the front went away", requests: [0, 1, 2, 3], front: goneID,
      expected: DeckLayout(
        front: ids[0], edges: ids(1, 2, 3), moreCount: 0, position: 1, count: 4, previous: nil,
        next: ids[1])),
  ]

  @Test(arguments: rows)
  func theLayoutGivesTheFrontTheEdgesTheMoreCountThePositionAndThePreviousAndNext(row: Row) {
    let requests = row.requests.map { Self.ids[$0] }
    let layout = RequestDeck.layout(requests: requests, front: row.front)

    #expect(layout == row.expected)
  }

  @Test func eachCardHasTheRoleOfItsPlaceInTheDeck() {
    let layout = RequestDeck.layout(requests: Self.ids, front: Self.ids[2])

    #expect(layout.role(of: Self.ids[2]) == .front)
    #expect(layout.role(of: Self.ids[0]) == .edge(depth: 1))
    #expect(layout.role(of: Self.ids[1]) == .edge(depth: 2))
    #expect(layout.role(of: Self.ids[3]) == .edge(depth: 3))
    #expect(layout.role(of: Self.ids[4]) == .hidden)
    #expect(layout.role(of: Self.ids[5]) == .hidden)
  }

  @Test func onlyADeckWithMoreThanOneRequestShowsItsHeader() {
    #expect(!RequestDeck.layout(requests: [], front: nil).showsHeader)
    #expect(!RequestDeck.layout(requests: Self.ids(0), front: nil).showsHeader)
    #expect(RequestDeck.layout(requests: Self.ids(0, 1), front: nil).showsHeader)
  }
}
