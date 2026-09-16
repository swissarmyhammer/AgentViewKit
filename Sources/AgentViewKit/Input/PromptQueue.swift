import Foundation
import Observation
import SwiftUI

/// The identifier of a ``QueuedPrompt``.
public typealias QueuedPromptID = Identifier<QueuedPrompt>

/// A place in a ``PromptQueue`` that a drag moves items to.
public typealias QueuedPromptPosition = ReorderDifference<
  QueuedPromptID, ReorderableSingleCollectionIdentifier
>.Destination.Position

/// One message that waits in a ``PromptQueue`` (plan.md §9 D).
public nonisolated struct QueuedPrompt: Sendable, Hashable, Identifiable {
  /// The identifier of the item. It does not change when the text changes.
  public let id: QueuedPromptID

  /// The input that the queue sends.
  public var input: UserInput

  /// Makes a queued item.
  ///
  /// - Parameters:
  ///   - id: The identifier of the item.
  ///   - input: The input that the queue sends.
  public init(id: QueuedPromptID, input: UserInput) {
    self.id = id
    self.input = input
  }
}

extension EnvironmentValues {
  /// The queue of the messages that wait while the thread runs a turn.
  ///
  /// When the value is not `nil`, a submit in ``PromptInputView`` while the
  /// thread runs a turn adds the text to this queue. When the turn ends,
  /// ``PromptInputView`` sends the first queued item.
  @Entry public var promptQueue: PromptQueue? = nil
}

extension View {
  /// Gives a message queue to each ``PromptInputView`` in this view.
  ///
  /// - Parameter queue: The queue.
  /// - Returns: The view with the queue in its environment.
  public func promptQueue(_ queue: PromptQueue?) -> some View {
    environment(\.promptQueue, queue)
  }
}

/// The ordered messages that wait while the thread runs a turn
/// (plan.md §9 D).
///
/// ``PromptInputView`` adds a message with ``enqueue(_:)`` while a turn runs.
/// When the turn ends, the composer gets the first item from
/// ``dequeueNext(after:)`` and sends it through
/// ``AgentThreadActions/send(_:)``. ``PromptQueueView`` shows the items and
/// lets the user reorder, edit, drop, and send them.
@MainActor
@Observable
public final class PromptQueue {
  /// The queued items, in send order.
  public private(set) var items: [QueuedPrompt] = []

  /// Makes an empty queue.
  public init() {}

  /// The number of queued items.
  public var count: Int {
    items.count
  }

  /// Whether the queue has no items.
  public var isEmpty: Bool {
    items.isEmpty
  }

  // MARK: - Change

  /// Adds an input after the last item.
  ///
  /// - Parameter input: The input to add.
  /// - Returns: The identifier of the new item.
  @discardableResult
  public func enqueue(_ input: UserInput) -> QueuedPromptID {
    let id = QueuedPromptID(UUID().uuidString)
    items.append(QueuedPrompt(id: id, input: input))
    return id
  }

  /// Removes the item with an identifier. An unknown identifier changes
  /// nothing.
  ///
  /// - Parameter id: The identifier of the item.
  public func remove(_ id: QueuedPromptID) {
    items.removeAll { $0.id == id }
  }

  /// Changes the text of the item with an identifier. The item keeps its
  /// position and its attachments.
  ///
  /// - Parameters:
  ///   - id: The identifier of the item.
  ///   - text: The new text.
  public func update(_ id: QueuedPromptID, text: String) {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return }
    items[index].input.text = text
  }

  /// Moves the items at `source` to `destination`, with the rule of
  /// `Array.move(fromOffsets:toOffset:)`.
  ///
  /// - Parameters:
  ///   - source: The offsets of the items to move.
  ///   - destination: The offset, in the list before the move, that the
  ///     items go before.
  public func move(from source: IndexSet, to destination: Int) {
    items.move(fromOffsets: source, toOffset: destination)
  }

  /// Moves the items with identifiers to a position, in queue order.
  ///
  /// A drag in ``PromptQueueView`` calls this function. Unknown identifiers
  /// change nothing.
  ///
  /// - Parameters:
  ///   - ids: The identifiers of the items to move.
  ///   - position: The item that the moved items go before, or the end.
  public func move(_ ids: [QueuedPromptID], to position: QueuedPromptPosition) {
    let moved = Set(ids)
    let source = IndexSet(items.indices.filter { moved.contains(items[$0].id) })
    guard !source.isEmpty else { return }
    let destination =
      switch position {
      case .before(let target): items.firstIndex { $0.id == target } ?? items.endIndex
      case .end: items.endIndex
      }
    move(from: source, to: destination)
  }

  // MARK: - Dequeue

  /// Removes and returns the item with an identifier, for "send now".
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: The input of the item, or `nil` when no item has `id` or when
  ///   an edit made the text blank. A blank item is removed.
  public func take(_ id: QueuedPromptID) -> UserInput? {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
    let input = items.remove(at: index).input
    return Self.isBlank(input) ? nil : input
  }

  /// Removes and returns the first item that has text.
  ///
  /// An edit can make the text of an item blank. The function removes each
  /// blank item before the returned item, so that the queue sends no blank
  /// message.
  ///
  /// - Returns: The input of the first item with text, or `nil` when there is
  ///   no such item.
  public func dequeueNext() -> UserInput? {
    while !items.isEmpty {
      let input = items.removeFirst().input
      if !Self.isBlank(input) { return input }
    }
    return nil
  }

  /// Removes and returns the first item when `state` shows a finished turn.
  ///
  /// A cancelled turn holds the queue, so that Esc stops the turn and keeps
  /// the queued items (plan.md §9 D).
  ///
  /// - Parameter state: The new state of the thread.
  /// - Returns: The input to send, or `nil` when the state is not idle, when
  ///   the turn was cancelled, or when the queue is empty.
  public func dequeueNext(after state: ThreadState) -> UserInput? {
    guard case .idle(let reason) = state, reason != .cancelled else { return nil }
    return dequeueNext()
  }

  /// Whether an input has only white space in its text.
  ///
  /// - Parameter input: The input to check.
  /// - Returns: `true` when the text is blank.
  private static func isBlank(_ input: UserInput) -> Bool {
    input.text.allSatisfy(\.isWhitespace)
  }
}
