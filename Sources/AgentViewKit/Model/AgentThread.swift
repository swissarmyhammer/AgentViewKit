import OSLog
import Observation

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

  /// The subagent runs that the agent started, in the order that the source
  /// first sent them. ``SubagentTreeView`` shows them as a tree.
  ///
  /// A patch to a known run changes the run in place and does not write this
  /// array, so only the row of that run becomes invalid.
  public private(set) var subagents: [SubagentRun] = []

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

  /// The restore points of the thread, in turn order. ``CheckpointView``
  /// shows them as a slider.
  public private(set) var checkpoints: [Checkpoint] = []

  /// The branch sets of the thread, keyed by the id of the user message that
  /// the alternatives follow. ``BranchNavigator`` pages through them.
  public internal(set) var branches: [String: BranchSet] = [:]

  /// The messages that still stream, keyed by record id.
  ///
  /// A source sends each chunk with ``ThreadChange/appendStreaming(id:text:)``
  /// and does not patch the record for each chunk. Only the tail row reads
  /// this table. ``ThreadChange/closeStreaming(id:)`` writes the final text to
  /// the record.
  public private(set) var streaming: [String: StreamingMessage] = [:]

  /// The id of the last item, or `nil` when the thread has no items.
  ///
  /// The thread writes this value only when the last item changes. Thus a
  /// view that reads it does not become invalid for each change to
  /// ``items``.
  public private(set) var lastItemID: String?

  /// The position of each item in ``items``, keyed by item id.
  @ObservationIgnored private var index: [String: Int] = [:]

  /// The subagent runs, keyed by run id.
  @ObservationIgnored private var subagentIndex: [SubagentRunID: SubagentRun] = [:]

  /// The log of the thread.
  @ObservationIgnored internal let logger = Logger(
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

  /// The position of the item with the id in ``items``, or `nil` when the
  /// thread has no such item.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: The position.
  public func position(of id: String) -> Int? {
    index[id]
  }

  /// The subagent run with the id, or `nil` when the thread has no such run.
  ///
  /// - Parameter id: The identifier of the run.
  /// - Returns: The run.
  public func subagent(id: SubagentRunID) -> SubagentRun? {
    subagentIndex[id]
  }

  /// Tells if the item is the last item while the thread runs a turn
  /// (plan.md §3.5).
  ///
  /// A reasoning item for which this is `true` is still in progress. The
  /// function reads only ``state`` and ``lastItemID``.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: `true` when the item is last and ``state`` is
  ///   ``ThreadState/running``.
  public func isLastWhileRunning(_ id: String) -> Bool {
    state == .running && lastItemID == id
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
    case .compact(let marker, let ids): compact(marker: marker, removing: ids)
    case .clear: clear()
    case .setState(let state): self.state = state
    case .setPlan(let plan): plans[plan.id] = plan
    case .removePlan(let id): plans[id] = nil
    case .upsertTerminal(let patch): upsertTerminal(patch)
    case .upsertSubagent(let patch): upsertSubagent(patch)
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
    case .setCheckpoints(let checkpoints): self.checkpoints = checkpoints
    case .addBranch(let id, let items): addBranch(afterUserMessage: id, items: items)
    case .selectBranch(let id, let index): selectBranch(afterUserMessage: id, index: index)
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
    noteLastItem()
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
    noteLastItem()
  }

  /// Removes the items with the ids and puts the marker at the position of
  /// the first removed item, with one write to ``items``.
  ///
  /// An item with the id of the marker is removed too, but it is not a
  /// removed item of the marker. When no id is known, the marker takes the
  /// position of that item, or goes at the end.
  private func compact(marker: CompactionMarker, removing ids: [String]) {
    let removing = Set(ids)
    var kept: [ThreadItem] = []
    var removedIDs: [String] = []
    var removedKinds: [String: Int] = [:]
    var firstRemovedPosition: Int?
    var replacedPosition: Int?
    var replacedRevision: Int?
    for item in items {
      if item.id == marker.id {
        replacedPosition = kept.endIndex
        replacedRevision = item.record.revision
      } else if removing.contains(item.id) {
        firstRemovedPosition = firstRemovedPosition ?? kept.endIndex
        removedIDs.append(item.id)
        removedKinds[item.kindName, default: 0] += 1
      } else {
        kept.append(item)
      }
    }
    marker.removedItemIDs = removedIDs
    marker.removedKinds = removedKinds
    if let replacedRevision {
      marker.revision = replacedRevision + 1
    }
    let position = firstRemovedPosition ?? replacedPosition ?? kept.endIndex
    kept.insert(.compaction(marker), at: position)
    items = kept
    index = [:]
    reindex(from: 0)
    noteLastItem()
  }

  private func clear() {
    items = []
    index = [:]
    plans = [:]
    terminals = [:]
    subagents = []
    subagentIndex = [:]
    pendingPermissions = []
    pendingElicitations = []
    pendingAuthorizations = []
    checkpoints = []
    branches = [:]
    streaming = [:]
    noteLastItem()
  }

  /// Replaces the items after the item with the id by `tail`, in one write to
  /// ``items``. An unknown id changes nothing.
  ///
  /// - Parameters:
  ///   - id: The identifier of the item that stays last before `tail`.
  ///   - tail: The new items after that item.
  internal func replaceItems(after id: String, with tail: [ThreadItem]) {
    guard let position = index[id] else { return }
    for item in items[(position + 1)...] {
      index[item.id] = nil
    }
    items = Array(items[...position]) + tail
    reindex(from: position + 1)
    noteLastItem()
  }

  /// Writes ``lastItemID`` when the last item changed.
  private func noteLastItem() {
    let last = items.last?.id
    guard lastItemID != last else { return }
    lastItemID = last
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

  private func upsertSubagent(_ patch: SubagentPatch) {
    guard let run = subagentIndex[patch.id] else {
      let run = patch.makeRun()
      subagentIndex[patch.id] = run
      subagents.append(run)
      return
    }
    patch.applyFields(to: run)
    run.bump()
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
  ///
  /// When the record is in a branch that the thread does not show, the text
  /// goes to that record, and ``items`` does not change.
  private func closeStreaming(id: String) {
    guard let message = streaming.removeValue(forKey: id) else { return }
    message.close()
    if item(id: id) == nil, let hidden = hiddenBranchItem(id: id) {
      if let patch = finalTextPatch(message.text, for: hidden), patch.applyFields(to: hidden) {
        hidden.record.bump()
      }
      return
    }
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
