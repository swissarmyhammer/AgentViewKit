import FoundationModelsACPClient

/// The place of one card in a ``RequestDeck``.
nonisolated enum DeckCardRole: Equatable, Sendable {
  /// The front card, at full size.
  case front
  /// A card behind the front that shows its top edge. Depth 1 is the edge
  /// that is nearest to the front card.
  case edge(depth: Int)
  /// A card that does not show.
  case hidden
}

/// The layout of a ``RequestDeck``: the front card, the top edges behind it,
/// the cards that do not show, the position "k of N", and the state of the
/// Previous and Next controls (deck design sections 2 and 3).
///
/// ``RequestDeck/layout(requests:front:)`` makes the layout. The layout is a
/// value with no view and no model, so a table test can examine it.
nonisolated struct DeckLayout: Equatable, Sendable {
  /// The maximum number of the cards behind the front that show their top
  /// edges.
  static let maximumEdgeCount = 3

  /// The id of the front request, or `nil` when the deck is empty.
  let front: PendingRequest.ID?
  /// The ids of the cards that show their top edges, in FIFO order, with
  /// the front skipped.
  let edges: [PendingRequest.ID]
  /// The number of the cards that do not show: "+N".
  let moreCount: Int
  /// The position k of the front in "k of N", from 1. It is 0 when the deck
  /// is empty.
  let position: Int
  /// The number N of the requests in "k of N".
  let count: Int
  /// The id of the request that Previous brings to the front, or `nil` when
  /// the front is the first request.
  let previous: PendingRequest.ID?
  /// The id of the request that Next brings to the front, or `nil` when the
  /// front is the last request.
  let next: PendingRequest.ID?

  /// Tells if the deck shows the header: "k of N" and the Previous and Next
  /// controls. Only a deck with more than one request shows it.
  var showsHeader: Bool { count > 1 }

  /// The place of a card in the deck.
  ///
  /// - Parameter id: The id of the request of the card.
  /// - Returns: `.front` for the front request, `.edge(depth:)` for a card
  ///   that shows its top edge, and `.hidden` for each other card.
  func role(of id: PendingRequest.ID) -> DeckCardRole {
    if id == front { return .front }
    guard let index = edges.firstIndex(of: id) else { return .hidden }
    return .edge(depth: index + 1)
  }
}

extension RequestDeck {
  /// The layout of a deck.
  ///
  /// The front is the request with the front id of the model. When no
  /// request has that id, for example after the model removed the front
  /// request, the front is the oldest request, as `frontRequest` of the
  /// model gives it. The order of the requests does not change.
  ///
  /// - Parameters:
  ///   - requests: The ids of the requests, oldest first.
  ///   - front: The front id of the model, or `nil`.
  /// - Returns: The layout.
  nonisolated static func layout(requests: [PendingRequest.ID], front: PendingRequest.ID?) -> DeckLayout {
    let index = requests.firstIndex { $0 == front } ?? requests.startIndex
    let behind = requests.enumerated().filter { $0.offset != index }.map(\.element)
    let edges = Array(behind.prefix(DeckLayout.maximumEdgeCount))
    return DeckLayout(
      front: request(at: index, in: requests),
      edges: edges,
      moreCount: behind.count - edges.count,
      position: requests.isEmpty ? 0 : index + 1,
      count: requests.count,
      previous: request(at: index - 1, in: requests),
      next: request(at: index + 1, in: requests))
  }

  /// The request id at a position, or `nil` when the position is outside the
  /// requests.
  ///
  /// - Parameters:
  ///   - index: The position.
  ///   - requests: The ids of the requests.
  /// - Returns: The id, or `nil`.
  private nonisolated static func request(
    at index: Int, in requests: [PendingRequest.ID]
  ) -> PendingRequest.ID? {
    requests.indices.contains(index) ? requests[index] : nil
  }
}
