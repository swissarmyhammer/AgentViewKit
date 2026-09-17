/// The alternative continuations of a thread after one user message
/// (plan.md §9 A).
///
/// Each alternative is the list of items that follow the user message, to the
/// end of the thread. Thus the branch of an earlier message holds the later
/// turns too. ``BranchNavigator`` pages through the alternatives.
///
/// The thread shows the alternative at ``selectedIndex``. While it shows, the
/// live items are in ``AgentThread/items``, and the entry at
/// ``selectedIndex`` holds the items of the last swap or add. A change to the
/// live items goes into that entry at the next swap or add.
///
/// The kit keeps the branches local. No source sends them (plan.md §9 A).
/// A source uses ``AgentThread/isInHiddenBranch(_:)`` and
/// ``AgentThread/regeneratedUserMessage(for:)`` to stay in step with the
/// shown branch (`Docs/decisions/branches.md`).
@MainActor
public struct BranchSet {
  /// The alternatives, in the order that they were added. The first entry is
  /// the continuation that the thread had before the first branch.
  public internal(set) var alternatives: [[ThreadItem]]

  /// The position of the alternative that the thread shows.
  public internal(set) var selectedIndex: Int

  /// The number of alternatives.
  public var count: Int { alternatives.count }
}

extension AgentThread {
  /// The id of the user message whose branch set ``BranchNavigator`` shows
  /// on the assistant message with the id.
  ///
  /// This is the last user message before the assistant message, when the
  /// assistant message is the first assistant message after that user
  /// message. Thus only one message of a turn shows the navigator.
  ///
  /// - Parameter id: The identifier of the assistant message.
  /// - Returns: The id of the user message, or `nil` when the item is not an
  ///   assistant message, has no user message before it, or is not the first
  ///   assistant message after it.
  public func branchUserMessageID(forAssistantMessage id: String) -> String? {
    guard let position = position(of: id), case .assistantMessage = items[position] else {
      return nil
    }
    for item in items[..<position].reversed() {
      switch item {
      case .userMessage(let message): return message.id
      case .assistantMessage: return nil
      default: continue
      }
    }
    return nil
  }

  /// Adds `items` as a new alternative after the user message. The thread
  /// does not show the new alternative.
  ///
  /// The first add makes the set: the live items after the user message
  /// become the first alternative, and the thread shows it.
  ///
  /// - Parameters:
  ///   - userMessageID: The identifier of the user message.
  ///   - newItems: The items of the new alternative.
  internal func addBranch(
    afterUserMessage userMessageID: String, items newItems: [ThreadItem]
  ) {
    guard let tail = trailingItems(afterUserMessage: userMessageID) else {
      logger.error(
        "No user message has the id \(userMessageID, privacy: .private). The branch is not added.")
      return
    }
    var set = branches[userMessageID] ?? BranchSet(alternatives: [tail], selectedIndex: 0)
    set.alternatives[set.selectedIndex] = tail
    set.alternatives.append(newItems)
    branches[userMessageID] = set
  }

  /// Shows the alternative at `index` after the user message.
  ///
  /// The live items after the user message go into the entry of the shown
  /// alternative. Then the items of the alternative at `index` replace them,
  /// in one write to ``items``. The checkpoints do not change.
  ///
  /// - Parameters:
  ///   - userMessageID: The identifier of the user message.
  ///   - index: The position of the alternative to show. When the thread
  ///     shows this alternative, nothing changes.
  internal func selectBranch(afterUserMessage userMessageID: String, index: Int) {
    guard var set = branches[userMessageID], set.alternatives.indices.contains(index),
      let tail = trailingItems(afterUserMessage: userMessageID)
    else {
      logger.error("No branch \(index) after \(userMessageID, privacy: .private) is known.")
      return
    }
    guard index != set.selectedIndex else { return }
    set.alternatives[set.selectedIndex] = tail
    set.selectedIndex = index
    branches[userMessageID] = set
    replaceItems(after: userMessageID, with: set.alternatives[index])
  }

  /// Tells if the item with the id is in a branch that the thread does not
  /// show.
  ///
  /// A source does not apply a change to such an item, because the change
  /// puts the item back in ``items`` (`Docs/decisions/branches.md`).
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: `true` when ``items`` has no item with the id, and an
  ///   alternative that the thread does not show has one.
  public func isInHiddenBranch(_ id: String) -> Bool {
    item(id: id) == nil && hiddenBranchItem(id: id) != nil
  }

  /// The item with the id in an alternative that the thread does not show.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: The item, or `nil` when no such alternative has it.
  internal func hiddenBranchItem(id: String) -> ThreadItem? {
    for set in branches.values {
      for (index, alternative) in set.alternatives.enumerated() where index != set.selectedIndex {
        if let item = alternative.first(where: { $0.id == id }) {
          return item
        }
      }
    }
    return nil
  }

  /// The user message that a send of `input` answers again after Regenerate.
  ///
  /// ``BranchNavigator`` shows a new empty branch after the user message, and
  /// then sends the input of the message again. A source that gets this send
  /// does not add a second user message (`Docs/decisions/branches.md`).
  ///
  /// - Parameter input: The input of the send.
  /// - Returns: The last item of the thread, when it is a user message with a
  ///   ``BranchSet`` and the same input. Otherwise `nil`.
  public func regeneratedUserMessage(for input: UserInput) -> Message? {
    guard case .userMessage(let message)? = items.last, branches[message.id] != nil,
      MessageActions.input(of: message) == input
    else { return nil }
    return message
  }

  /// The items after the user message, to the end of the thread.
  ///
  /// - Parameter userMessageID: The identifier of the user message.
  /// - Returns: The items, or `nil` when no user message has the id.
  private func trailingItems(afterUserMessage userMessageID: String) -> [ThreadItem]? {
    guard let position = position(of: userMessageID),
      case .userMessage = items[position]
    else { return nil }
    return Array(items[(position + 1)...])
  }
}
