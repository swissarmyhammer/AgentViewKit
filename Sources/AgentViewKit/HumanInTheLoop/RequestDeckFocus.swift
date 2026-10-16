import FoundationModelsACPClient

/// A focus move of a ``RequestDeck`` (deck design section 4).
///
/// ``RequestDeck/focusTarget(oldIDs:newIDs:oldFront:newFront:)`` makes the
/// move. The move is a value with no view and no model, so a table test can
/// examine it.
nonisolated enum DeckFocusMove: Equatable, Sendable {
  /// The old front request left `pendingRequests`. The VoiceOver focus goes
  /// to the card of the new front request. The keyboard focus does not move.
  case nextFront(PendingRequest.ID)

  /// The last pending request left `pendingRequests`. The VoiceOver focus
  /// goes back to the prompt editor (``StockPromptEditor/identifier``). A
  /// waiting card can stay in the deck: it asks for no input and is not a
  /// pending request.
  case promptEditor

  /// The user brought a request to the front, for example with Previous or
  /// Next. The VoiceOver focus and the keyboard focus go into its card.
  case broughtToFront(PendingRequest.ID)

  /// The accessibility identifier of the view that gets the VoiceOver focus.
  /// The identifiers of the views are main-actor values.
  @MainActor var identifier: String {
    switch self {
    case .nextFront(let id), .broughtToFront(let id): RequestDeck.identifier(for: id.uuidString)
    case .promptEditor: StockPromptEditor.identifier
    }
  }

  /// The id of the request whose card gets the keyboard focus, or `nil` when
  /// the keyboard focus does not move.
  var keyboardFocus: PendingRequest.ID? {
    guard case .broughtToFront(let id) = self else { return nil }
    return id
  }
}

extension RequestDeck {
  /// The focus move of the deck after one change of its requests.
  ///
  /// A new card does not take the focus. The deck moves the focus only in
  /// two cases:
  ///
  /// 1. The old front request left `pendingRequests`: the focus goes to the
  ///    card of the new front request, or to the prompt editor when no
  ///    pending request stays. The accept of a URL mode elicitation also
  ///    removes it from `pendingRequests`, while its card stays as a waiting
  ///    card. The ids are only the ids of the pending requests, so a waiting
  ///    card does not count.
  /// 2. The old front request stays, and the front changed: the user brought
  ///    a request to the front. The focus and the keyboard focus go into its
  ///    card.
  ///
  /// - Parameters:
  ///   - oldIDs: The ids of the pending requests before the change.
  ///   - newIDs: The ids of the pending requests after the change.
  ///   - oldFront: The front request before the change, or `nil`.
  ///   - newFront: The front request after the change, or `nil`.
  /// - Returns: The move, or `nil` when the focus does not move.
  nonisolated static func focusTarget(
    oldIDs: [PendingRequest.ID], newIDs: [PendingRequest.ID], oldFront: PendingRequest.ID?,
    newFront: PendingRequest.ID?
  ) -> DeckFocusMove? {
    guard let oldFront else { return nil }
    guard newIDs.contains(oldFront) else {
      return newFront.map(DeckFocusMove.nextFront) ?? .promptEditor
    }
    guard let newFront, newFront != oldFront else { return nil }
    return .broughtToFront(newFront)
  }
}
