import Observation
import OSLog

/// The model that the thread views bind to (plan.md §3.2).
///
/// A source fills the thread with ``apply(_:)``. The shape follows the ACP v2
/// update stream. Each property is observed on its own, so a change to the
/// usage does not make a view of the items invalid. A patch changes a record
/// in place and does not write ``items``, so only the row of that record
/// becomes invalid (plan.md §8).
@MainActor
@Observable
public final class AgentThread {
  /// The items of the thread, in order. Each id occurs one time.
  public private(set) var items: [ThreadItem] = []

  /// The state of the current turn.
  public private(set) var state: ThreadState = .idle(nil)

  /// The plans of the agent, keyed by id.
  public private(set) var plans: [PlanID: Plan] = [:]

  /// The terminals that the agent owns, keyed by id.
  public private(set) var terminals: [TerminalID: TerminalRecord] = [:]

  /// The session options: mode, model, thought level, and switches.
  public private(set) var configOptions: [ConfigOption] = []

  /// The slash commands that the agent accepts.
  public private(set) var availableCommands: [SlashCommand] = []

  /// The context usage, or `nil` when the source gave none.
  public private(set) var usage: ContextUsage?

  /// The title and the time of the last change.
  public private(set) var info = ThreadInfo()

  /// The permission requests that wait for the user, in order.
  public private(set) var pendingPermissions: [PermissionRequest] = []

  /// The elicitation requests that wait for the user, in order.
  public private(set) var pendingElicitations: [ElicitationRequest] = []

  /// The authorization requests that wait for the user, in order.
  public private(set) var pendingAuthorizations: [AuthorizationRequest] = []

  /// The messages that still stream, keyed by record id.
  ///
  /// A source sends each chunk with ``ThreadChange/appendStreaming(id:text:)``
  /// and does not patch the record for each chunk. Only the tail row reads
  /// this table. ``ThreadChange/closeStreaming(id:)`` writes the final text to
  /// the record.
  public private(set) var streaming: [String: StreamingMessage] = [:]

  /// The position of each item in ``items``, keyed by item id.
  @ObservationIgnored private var index: [String: Int] = [:]

  /// The log of the thread.
  @ObservationIgnored private let logger = Logger(
    subsystem: "AgentViewKit", category: "AgentThread")

  /// Makes an empty thread.
  public init() {}

  /// The item with the id, or `nil` when the thread has no such item.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: The item.
  public func item(id: String) -> ThreadItem? {
    index[id].map { items[$0] }
  }

  /// Applies one change to the thread.
  ///
  /// - Parameter change: The change to apply.
  public func apply(_ change: ThreadChange) {
    switch change {
    case .insert(let item, let anchor): insert(item, after: anchor)
    case .patch(let id, let patch): self.patch(id: id, with: patch)
    case .replace(let item): replace(item)
    case .remove(let id): remove(id: id)
    case .clear: clear()
    case .setState(let state): self.state = state
    case .setPlan(let plan): plans[plan.id] = plan
    case .removePlan(let id): plans[id] = nil
    case .upsertTerminal(let patch): upsertTerminal(patch)
    case .setConfigOptions(let options): configOptions = options
    case .setAvailableCommands(let commands): availableCommands = commands
    case .setUsage(let usage): self.usage = usage
    case .patchInfo(let patch): info = patch.applied(to: info)
    case .addPermission(let request): pendingPermissions.upsert(request)
    case .resolvePermission(let id): pendingPermissions.removeAll(id: id)
    case .addElicitation(let request): pendingElicitations.upsert(request)
    case .resolveElicitation(let id): pendingElicitations.removeAll(id: id)
    case .addAuthorization(let request): pendingAuthorizations.upsert(request)
    case .resolveAuthorization(let id): pendingAuthorizations.removeAll(id: id)
    case .appendStreaming(let id, let text): appendStreaming(id: id, text: text)
    case .closeStreaming(let id): closeStreaming(id: id)
    }
  }

  // MARK: - Items

  private func insert(_ item: ThreadItem, after anchor: String?) {
    guard index[item.id] == nil else {
      replace(item)
      return
    }
    let position = anchor.flatMap { index[$0] }.map { $0 + 1 } ?? items.endIndex
    insert(item, at: position)
  }

  private func insert(_ item: ThreadItem, at position: Int) {
    items.insert(item, at: position)
    reindex(from: position)
  }

  private func patch(id: String, with patch: ItemPatch) {
    guard let position = index[id] else {
      insert(patch.makeItem(id: id), at: items.endIndex)
      return
    }
    let item = items[position]
    guard patch.applyFields(to: item) else {
      replace(patch.makeItem(id: id), at: position)
      return
    }
    item.record.bump()
  }

  private func replace(_ item: ThreadItem) {
    guard let position = index[item.id] else {
      insert(item, at: items.endIndex)
      return
    }
    replace(item, at: position)
  }

  /// Puts the item at the position. The new record gets the revision of the
  /// old record plus one, so that a row that compares id and revision sees
  /// the change.
  private func replace(_ item: ThreadItem, at position: Int) {
    item.record.revision = items[position].record.revision + 1
    items[position] = item
  }

  private func remove(id: String) {
    guard let position = index.removeValue(forKey: id) else { return }
    items.remove(at: position)
    reindex(from: position)
  }

  private func clear() {
    items = []
    index = [:]
    plans = [:]
    terminals = [:]
    pendingPermissions = []
    pendingElicitations = []
    pendingAuthorizations = []
    streaming = [:]
  }

  /// Writes the positions of the items from `start` to the end.
  private func reindex(from start: Int) {
    for position in start..<items.endIndex {
      index[items[position].id] = position
    }
  }

  // MARK: - Side tables

  private func upsertTerminal(_ patch: TerminalPatch) {
    guard let terminal = terminals[patch.id] else {
      terminals[patch.id] = patch.makeRecord()
      return
    }
    patch.applyFields(to: terminal)
    terminal.bump()
  }

  /// Gives a chunk to the streaming message of the record. The first chunk
  /// makes the message and renders at once.
  private func appendStreaming(id: String, text: String) {
    guard let message = streaming[id] else {
      streaming[id] = StreamingMessage(id: id, text: text)
      return
    }
    message.append(text)
  }

  /// Closes the streaming message of the record, removes it, and writes its
  /// final text to the record in one patch.
  private func closeStreaming(id: String) {
    guard let message = streaming.removeValue(forKey: id) else { return }
    message.close()
    guard let patch = finalTextPatch(message.text, for: item(id: id)) else {
      logger.error(
        "The record \(id, privacy: .public) has no text field. The streamed text is not kept.")
      return
    }
    self.patch(id: id, with: patch)
  }

  /// The patch that writes the final streamed text to the text field of the
  /// record.
  ///
  /// - Parameters:
  ///   - text: The final text of the streaming message.
  ///   - item: The item of the record, or `nil` when the thread has none.
  /// - Returns: The patch, or `nil` when the record has no text field. When
  ///   the thread has no item, the patch makes an assistant message.
  private func finalTextPatch(_ text: String, for item: ThreadItem?) -> ItemPatch? {
    let content = PatchField.value([ContentBlock(text: text)])
    switch item {
    case .userMessage: return .userMessage(content: content)
    case .assistantMessage, .none: return .assistantMessage(content: content)
    case .reasoning: return .reasoning(segments: .value([text]))
    case .system: return .system(text: .value(text))
    case .toolCall, .structured, .compaction, .error, .unknown: return nil
    }
  }
}

extension Array where Element: Identifiable {
  /// Replaces the element with the same id, or adds the element at the end.
  ///
  /// - Parameter element: The element to put in the array.
  fileprivate mutating func upsert(_ element: Element) {
    guard let position = firstIndex(where: { $0.id == element.id }) else {
      append(element)
      return
    }
    self[position] = element
  }

  /// Removes each element with the id.
  ///
  /// - Parameter id: The identifier of the elements to remove.
  fileprivate mutating func removeAll(id: Element.ID) {
    removeAll { $0.id == id }
  }
}
