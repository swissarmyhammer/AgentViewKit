import AppKit
import EditorCommands
import EditorCommandsUI
import SwiftUI

/// The calls that the composer gives to the agent commands.
///
/// ``PromptInputView`` registers a hook in the ``AgentCommandTarget`` of its
/// scope, so that ``AgentCommandVerb/send`` submits the composer and
/// ``AgentCommandVerb/focusComposer`` focuses its editor. ``MessageActions``
/// loads the text of a message into the composer through the hook.
struct AgentComposerHook {
  /// The identity of the view that registered the hook.
  let owner: ObjectIdentifier

  /// Tells if a submit sends or queues the text now.
  let canSubmit: @MainActor () -> Bool

  /// Submits the text of the composer.
  let submit: @MainActor () -> Void

  /// Replaces the text of the composer with the argument.
  let load: @MainActor (String) -> Void

  /// Moves the focus to the editor of the composer. Returns `true` when the
  /// focus moved.
  let focus: @MainActor () -> Bool
}

/// The live objects that the agent commands act on (plan.md §4.1).
///
/// An ``AgentCommandScope`` owns one target and keeps its values current.
/// The views in the scope read the target from
/// ``SwiftUI/EnvironmentValues/agentCommandTarget``. They add the parts that
/// only they have: the scroll anchors of the list, the store of the expanded
/// items, and the composer. They dispatch their own verbs through
/// ``perform(_:payload:)``, so that a palette, a key, and a button run the
/// same command.
@MainActor
final class AgentCommandTarget {
  /// The kind of the focus segment of an agent command scope.
  static let segmentKind = "agentThread"

  /// The radix of the thread identity in the focus segment: hexadecimal.
  static let segmentIdentityRadix = 16

  /// The thread that the commands act on.
  var thread: AgentThread?

  /// The actions that the commands call.
  var actions: any AgentThreadActions = LoggingThreadActions()

  /// The pasteboard that ``AgentCommandVerb/copyThread`` writes to.
  var pasteboard: any Pasteboard = NSPasteboard.general

  /// The store of the expanded items, or `nil` when no thread view is shown.
  var expandedBlocks: ExpandedBlocksStore?

  /// The scroll anchors of the thread list, or `nil` when no list is shown.
  var anchors: ScrollAnchorManager?

  /// The hook of the composer, or `nil` when no composer is in the scope.
  var composer: AgentComposerHook?

  /// The command system that the scope registered the commands in.
  var system: CommandSystem?

  /// The path of the scope in ``system``.
  var path: FocusPath?

  /// Makes a target with no thread.
  init() {}

  /// The focus segment of the scope of `thread`.
  ///
  /// The identifier comes from the identity of the thread, so two thread
  /// views in one window have two scopes.
  ///
  /// - Parameter thread: The thread.
  /// - Returns: The segment `agentThread:<identity>`.
  static func segment(for thread: AgentThread) -> FocusSegment {
    let identity = String(
      UInt(bitPattern: ObjectIdentifier(thread)), radix: segmentIdentityRadix)
    return FocusSegment(kind: segmentKind, id: identity)
  }

  // MARK: - Dispatch

  /// Dispatches `verb` through the registry of the scope.
  ///
  /// - Parameters:
  ///   - verb: The verb to run.
  ///   - payload: The payload of the dispatch, or `nil`.
  /// - Returns: `true` when a command ran. `false` when the scope has no
  ///   system, or when the command is not available.
  @discardableResult
  func perform(_ verb: AgentCommandVerb, payload: CommandPayload? = nil) -> Bool {
    guard let system, let path else { return false }
    return system.registry.perform(verb.id, at: path, payload: payload)
  }

  /// Removes the composer hook when `owner` registered it.
  ///
  /// - Parameter owner: The identity of the view that goes away.
  func removeComposer(owner: ObjectIdentifier) {
    guard composer?.owner == owner else { return }
    composer = nil
  }

  // MARK: - Availability

  /// Tells if `verb` can run now, with the reason when it cannot.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - payload: The payload of the dispatch, or `nil`.
  /// - Returns: The availability.
  func availability(of verb: AgentCommandVerb, payload: CommandPayload?) -> Availability {
    guard let thread else {
      return .unavailable(reason: String(localized: "The thread is not shown."))
    }
    let isAvailable: Bool
    switch verb {
    case .send: isAvailable = canSend(payload: payload)
    case .cancel: isAvailable = !Self.isIdle(thread.state)
    case .approvePending: isAvailable = answer(payload: payload, rejects: false) != nil
    case .rejectPending: isAvailable = answer(payload: payload, rejects: true) != nil
    case .jumpToNext: isAvailable = anchors != nil && jumpTarget(forward: true) != nil
    case .jumpToPrevious: isAvailable = anchors != nil && jumpTarget(forward: false) != nil
    case .copyThread: isAvailable = !Self.plainText(of: thread).isEmpty
    case .toggleExpandAll: isAvailable = expandedBlocks != nil && !thread.items.isEmpty
    case .scrollToBottom: isAvailable = anchors != nil && thread.lastItemID != nil
    case .focusComposer: isAvailable = composer != nil
    }
    return isAvailable ? .available : .unavailable(reason: Self.reason(for: verb))
  }

  /// The text that tells the user why `verb` cannot run.
  ///
  /// - Parameter verb: The verb.
  /// - Returns: The reason.
  static func reason(for verb: AgentCommandVerb) -> String {
    switch verb {
    case .send: String(localized: "Type a message first.")
    case .cancel: String(localized: "The agent does not run a turn.")
    case .approvePending, .rejectPending: String(localized: "No request waits for an answer.")
    case .jumpToNext: String(localized: "No turn is below.")
    case .jumpToPrevious: String(localized: "No turn is above.")
    case .copyThread: String(localized: "The thread has no messages.")
    case .toggleExpandAll: String(localized: "The thread has no items.")
    case .scrollToBottom: String(localized: "The thread list is not shown.")
    case .focusComposer: String(localized: "The composer is not shown.")
    }
  }

  /// Tells if `state` is an idle state.
  ///
  /// - Parameter state: The run state of the thread.
  /// - Returns: `true` for ``ThreadState/idle(_:)``.
  static func isIdle(_ state: ThreadState) -> Bool {
    if case .idle = state { return true }
    return false
  }

  // MARK: - Run

  /// Runs `verb`.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - payload: The payload of the dispatch, or `nil`.
  /// - Returns: `true` when the verb ran.
  func run(_ verb: AgentCommandVerb, payload: CommandPayload?) -> Bool {
    guard let thread, availability(of: verb, payload: payload).isAvailable else { return false }
    switch verb {
    case .send: send(payload: payload)
    case .cancel: actions.startCancel()
    case .approvePending: respond(payload: payload, rejects: false)
    case .rejectPending: respond(payload: payload, rejects: true)
    case .jumpToNext: jump(forward: true)
    case .jumpToPrevious: jump(forward: false)
    case .copyThread: pasteboard.copyText(Self.plainText(of: thread))
    case .toggleExpandAll: toggleExpandAll(thread)
    case .scrollToBottom: anchors?.pinToBottom()
    case .focusComposer: return composer?.focus() ?? false
    }
    return true
  }

  // MARK: - Send

  /// Tells if a send can run.
  ///
  /// - Parameter payload: The payload of the dispatch, or `nil`.
  /// - Returns: `true` when the payload has text that is not blank, or when
  ///   the payload has no text and the composer can submit.
  private func canSend(payload: CommandPayload?) -> Bool {
    if let text = AgentCommandPayload.string(AgentCommandPayload.textKey, in: payload) {
      return !text.allSatisfy(\.isWhitespace)
    }
    return composer?.canSubmit() ?? false
  }

  /// Sends the text of the payload, or submits the composer.
  ///
  /// - Parameter payload: The payload of the dispatch, or `nil`.
  private func send(payload: CommandPayload?) {
    guard let text = AgentCommandPayload.string(AgentCommandPayload.textKey, in: payload) else {
      composer?.submit()
      return
    }
    actions.startSend(UserInput(text: text))
  }

  // MARK: - Permission

  /// The request and the option that a permission answer selects.
  ///
  /// - Parameters:
  ///   - payload: The payload of the dispatch, or `nil`. With no request
  ///     key, the answer is for the first pending request. With no option
  ///     key, the answer selects the first option of the kind in display
  ///     order.
  ///   - rejects: `true` for a reject option, `false` for an allow option.
  ///     An option of an unknown kind is an allow option, as in
  ///     ``PermissionView``.
  /// - Returns: The request and the option, or `nil` when there is none.
  private func answer(
    payload: CommandPayload?, rejects: Bool
  ) -> (request: PermissionRequest, option: PermissionOption)? {
    guard let thread else { return nil }
    let requestID = AgentCommandPayload.string(AgentCommandPayload.requestKey, in: payload)
    let request =
      requestID.map { id in thread.pendingPermissions.first { $0.id.rawValue == id } }
      ?? thread.pendingPermissions.first
    guard let request else { return nil }
    let options = PermissionPresentation.order(of: request.options)
      .filter { Self.isReject($0.kind) == rejects }
    let optionID = AgentCommandPayload.string(AgentCommandPayload.optionKey, in: payload)
    let option = optionID.map { id in options.first { $0.id.rawValue == id } } ?? options.first
    return option.map { (request, $0) }
  }

  /// Tells if `kind` rejects the operation.
  ///
  /// - Parameter kind: The kind of an option.
  /// - Returns: `true` for `reject_once` and `reject_always`.
  static func isReject(_ kind: PermissionOption.Kind) -> Bool {
    kind == .rejectOnce || kind == .rejectAlways
  }

  /// Sends the answer that the payload selects.
  ///
  /// - Parameters:
  ///   - payload: The payload of the dispatch, or `nil`.
  ///   - rejects: `true` for a reject option, `false` for an allow option.
  private func respond(payload: CommandPayload?, rejects: Bool) {
    guard let answer = answer(payload: payload, rejects: rejects) else { return }
    let comment = AgentCommandPayload.string(AgentCommandPayload.commentKey, in: payload)
    let decision = PermissionDecision(outcome: .selected(answer.option.id), comment: comment)
    let actions = actions
    Task { await actions.respond(to: answer.request, decision) }
  }

  // MARK: - Jump

  /// The identifier of the turn that a jump goes to.
  ///
  /// A turn starts at a user message. The jump starts at the first item in
  /// view. With no item in view, a forward jump goes to the first turn.
  ///
  /// - Parameter forward: `true` for the next turn, `false` for the previous
  ///   turn.
  /// - Returns: The item identifier of the turn, or `nil` when there is none.
  private func jumpTarget(forward: Bool) -> String? {
    guard let thread else { return nil }
    let current = anchors?.visibleIDs.first.flatMap { thread.position(of: $0) }
    let turns = thread.items.enumerated().filter { _, item in
      if case .userMessage = item { return true }
      return false
    }
    if forward {
      return turns.first { position, _ in current.map { position > $0 } ?? true }?.element.id
    }
    guard let current else { return nil }
    return turns.last { position, _ in position < current }?.element.id
  }

  /// Scrolls the list to the next or the previous turn.
  ///
  /// - Parameter forward: `true` for the next turn, `false` for the previous
  ///   turn.
  private func jump(forward: Bool) {
    guard let anchors, let id = jumpTarget(forward: forward) else { return }
    anchors.noteJump(to: id)
    anchors.onScroll(.item(id))
  }

  // MARK: - Expand

  /// Expands each item, or collapses each item when all items are expanded.
  ///
  /// - Parameter thread: The thread.
  private func toggleExpandAll(_ thread: AgentThread) {
    guard let store = expandedBlocks else { return }
    let expandsAll = !thread.items.allSatisfy { store.isExpanded($0) }
    for item in thread.items {
      if expandsAll {
        store.expand(item.id)
      } else {
        store.collapse(item.id)
      }
    }
  }

  // MARK: - Copy

  /// The messages of the thread as plain text.
  ///
  /// Each user and assistant message gives one section: a role line, then
  /// the text blocks that are for the user. A blank line separates two
  /// sections. The text omits the other items.
  ///
  /// - Parameter thread: The thread.
  /// - Returns: The text, or an empty string when the thread has no message
  ///   text.
  static func plainText(of thread: AgentThread) -> String {
    thread.items.compactMap { item -> String? in
      switch item {
      case .userMessage(let message):
        section(role: String(localized: "User"), message: message)
      case .assistantMessage(let message):
        section(role: String(localized: "Assistant"), message: message)
      case .system, .reasoning, .toolCall, .structured, .compaction, .error, .unknown:
        nil
      }
    }
    .joined(separator: "\n\n")
  }

  /// The section of one message.
  ///
  /// - Parameters:
  ///   - role: The role line.
  ///   - message: The message.
  /// - Returns: The section, or `nil` when the message has no text.
  private static func section(role: String, message: Message) -> String? {
    let texts = message.blocks.compactMap { block -> String? in
      guard block.isVisible(to: .user), case .text(let text) = block.content else { return nil }
      return text
    }
    guard !texts.isEmpty else { return nil }
    return ([role + ":"] + texts).joined(separator: "\n")
  }
}

extension EnvironmentValues {
  /// The target of the nearest ``AgentCommandScope``, or `nil`.
  @Entry var agentCommandTarget: AgentCommandTarget? = nil

  /// The identity of the thread of the nearest ``AgentCommandScope``, or
  /// `nil`.
  ///
  /// The scope writes this value in its body, before its mount gives the
  /// thread to the target, so that a scope below can see at once that it is
  /// in a scope for the same thread.
  @Entry var agentCommandScopeThread: ObjectIdentifier? = nil
}
