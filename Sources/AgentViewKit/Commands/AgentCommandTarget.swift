import AppKit
import EditorCommands
import EditorCommandsUI
import FoundationModelsACP
import FoundationModelsACPClient
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

  /// Tells if a submit sends the text now.
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
///
/// The target holds the model of the scope, a `SessionModel` or an
/// ``AgentThread``, and keeps no copy of its values. Each availability check
/// and each run reads the model again:
///
/// - Cancel is available while the `agentState` of the session model is
///   `.running` or `.requiresAction`, and it calls
///   `SessionModel.cancel(meta:)`.
/// - Send with a text payload calls `SessionModel.prompt(_:meta:)`.
/// - Approve and reject read `SessionModel.pendingPermissions`, and call
///   `selectPermission(_:option:)`.
/// - Copy reads the user message entries and the agent message entries of the
///   transcript. Jump goes to the next or the previous user message entry.
///   Expand all reads the row key of each entry.
///
/// The deprecated thread path reads the ``AgentThread`` and calls the
/// ``AgentThreadActions`` in the same way. It goes away with the kit session
/// model.
@MainActor
final class AgentCommandTarget {
  /// The kind of the focus segment of an agent command scope.
  static let segmentKind = "agentThread"

  /// The radix of the thread identity in the focus segment: hexadecimal.
  static let segmentIdentityRadix = 16

  /// The line that separates two messages in the copy text: one blank line.
  static let sectionSeparator = "\n\n"

  /// The model that the commands act on, or `nil` when no scope gave one.
  var source: ConversationSource?

  /// The actions that the commands of a thread call, or `nil` when no scope
  /// gave them. The commands of a session model call the session model.
  var actions: (any AgentThreadActions)?

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

  /// Makes a target with no model.
  init() {}

  /// The focus segment of the scope of `source`.
  ///
  /// The identifier of a session model is its `sessionId`. The identifier of
  /// a thread comes from the identity of the thread object. Thus two thread
  /// views of two models in one window have two scopes.
  ///
  /// - Parameter source: The model of the scope.
  /// - Returns: The segment `agentThread:<identity>`.
  static func segment(for source: ConversationSource) -> FocusSegment {
    switch source {
    case .thread(let thread):
      let identity = String(UInt(bitPattern: ObjectIdentifier(thread)), radix: segmentIdentityRadix)
      return FocusSegment(kind: segmentKind, id: identity)
    case .session(let session):
      return FocusSegment(kind: segmentKind, id: session.sessionId.rawValue)
    }
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
    guard let source else {
      return .unavailable(reason: String(localized: "The thread is not shown."))
    }
    guard isAvailable(verb, payload: payload, in: source) else {
      return .unavailable(reason: Self.reason(for: verb))
    }
    return .available
  }

  /// Tells if `verb` can run now on `source`.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - payload: The payload of the dispatch, or `nil`.
  ///   - source: The model of the scope.
  /// - Returns: `true` when the verb can run.
  private func isAvailable(
    _ verb: AgentCommandVerb, payload: CommandPayload?, in source: ConversationSource
  ) -> Bool {
    switch verb {
    case .send: canSend(payload: payload)
    case .cancel: Self.canCancel(source)
    case .approvePending: answer(payload: payload, rejects: false) != nil
    case .rejectPending: answer(payload: payload, rejects: true) != nil
    case .jumpToNext: anchors != nil && jumpTarget(forward: true) != nil
    case .jumpToPrevious: anchors != nil && jumpTarget(forward: false) != nil
    case .copyThread: !Self.plainText(of: source).isEmpty
    case .toggleExpandAll: expandedBlocks != nil && source.rowCount > 0
    case .scrollToBottom: anchors != nil && source.lastRowKey != nil
    case .focusComposer: composer != nil
    }
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

  /// Tells if the agent of `source` does work that a cancel stops.
  ///
  /// - Parameter source: The model of the scope.
  /// - Returns: `true` while the `agentState` of a session model is
  ///   `.running` or `.requiresAction`, or while a thread is not idle.
  static func canCancel(_ source: ConversationSource) -> Bool {
    switch source {
    case .thread(let thread): !isIdle(thread.state)
    case .session(let session): isActive(session.agentState)
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

  /// Tells if `state` is a state of foreground work.
  ///
  /// - Parameter state: The `agentState` of a session model, or `nil` when
  ///   the agent reported no state.
  /// - Returns: `true` for `.running` and `.requiresAction`. A state that
  ///   the kit does not know is not foreground work.
  static func isActive(_ state: StateUpdate?) -> Bool {
    switch state {
    case .running, .requiresAction: true
    case .idle, .unknown, nil: false
    }
  }

  // MARK: - Run

  /// Runs `verb`.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - payload: The payload of the dispatch, or `nil`.
  /// - Returns: `true` when the verb ran.
  func run(_ verb: AgentCommandVerb, payload: CommandPayload?) -> Bool {
    guard let source, availability(of: verb, payload: payload).isAvailable else { return false }
    switch verb {
    case .send: send(payload: payload, to: source)
    case .cancel: cancel(source)
    case .approvePending: respond(payload: payload, rejects: false)
    case .rejectPending: respond(payload: payload, rejects: true)
    case .jumpToNext: jump(forward: true)
    case .jumpToPrevious: jump(forward: false)
    case .copyThread: pasteboard.copyText(Self.plainText(of: source))
    case .toggleExpandAll: toggleExpandAll(source)
    case .scrollToBottom: anchors?.pinToBottom()
    case .focusComposer: return composer?.focus() ?? false
    }
    return true
  }

  // MARK: - Send and cancel

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
  /// A session model gets the text as `session/prompt` at once. A thread
  /// gets it through ``AgentThreadActions/send(_:)``.
  ///
  /// - Parameters:
  ///   - payload: The payload of the dispatch, or `nil`.
  ///   - source: The model of the scope.
  private func send(payload: CommandPayload?, to source: ConversationSource) {
    guard let text = AgentCommandPayload.string(AgentCommandPayload.textKey, in: payload) else {
      composer?.submit()
      return
    }
    switch source {
    case .thread: actions?.startSend(UserInput(text: text))
    case .session(let session): session.startPrompt(text: text)
    }
  }

  /// Stops the work of the agent of `source`.
  ///
  /// A session model sends `session/cancel` with `cancel(meta:)`. A thread
  /// calls ``AgentThreadActions/cancel()``.
  ///
  /// - Parameter source: The model of the scope.
  private func cancel(_ source: ConversationSource) {
    switch source {
    case .thread: actions?.startCancel()
    case .session(let session): session.startCancel()
    }
  }

  // MARK: - Permission

  /// The request and the option that a permission answer selects.
  private enum PermissionAnswer {
    /// A request of a thread, and one of its options.
    case thread(PermissionRequest, AgentViewKit.PermissionOption)

    /// A pending request of a session model, and one of its ACP options.
    case session(SessionModel, PendingPermissionRequest.ID, FoundationModelsACP.PermissionOption)
  }

  /// The request and the option that a permission answer selects.
  ///
  /// With no request key in the payload, the answer is for the first pending
  /// request. With no option key, the answer selects the first option of the
  /// kind in display order (``PermissionPresentation/order(of:)``). The
  /// request key of a session model is the `uuidString` of the local id of
  /// the pending request, and the option key is the `optionId`.
  ///
  /// - Parameters:
  ///   - payload: The payload of the dispatch, or `nil`.
  ///   - rejects: `true` for a reject option, `false` for an allow option.
  ///     An option of an unknown kind is an allow option, as in
  ///     ``PermissionView``.
  /// - Returns: The answer, or `nil` when there is none.
  private func answer(payload: CommandPayload?, rejects: Bool) -> PermissionAnswer? {
    let requestID = AgentCommandPayload.string(AgentCommandPayload.requestKey, in: payload)
    let optionID = AgentCommandPayload.string(AgentCommandPayload.optionKey, in: payload)
    switch source {
    case .thread(let thread):
      return Self.answer(in: thread, requestID: requestID, optionID: optionID, rejects: rejects)
    case .session(let session):
      return Self.answer(in: session, requestID: requestID, optionID: optionID, rejects: rejects)
    case nil:
      return nil
    }
  }

  /// The answer to a pending request of a thread.
  ///
  /// - Parameters:
  ///   - thread: The thread.
  ///   - requestID: The raw id of the request, or `nil` for the first one.
  ///   - optionID: The raw id of the option, or `nil` for the first one.
  ///   - rejects: `true` for a reject option, `false` for an allow option.
  /// - Returns: The answer, or `nil` when there is none.
  private static func answer(
    in thread: AgentThread, requestID: String?, optionID: String?, rejects: Bool
  ) -> PermissionAnswer? {
    guard let request = select(thread.pendingPermissions, id: requestID, key: \.id.rawValue) else {
      return nil
    }
    let options = PermissionPresentation.order(of: request.options).filter { isReject($0.kind) == rejects }
    return select(options, id: optionID, key: \.id.rawValue).map { .thread(request, $0) }
  }

  /// The answer to a pending request of a session model.
  ///
  /// - Parameters:
  ///   - session: The session model.
  ///   - requestID: The `uuidString` of the local id of the request, or
  ///     `nil` for the first one.
  ///   - optionID: The `optionId` of the option, or `nil` for the first one.
  ///   - rejects: `true` for a reject option, `false` for an allow option.
  /// - Returns: The answer, or `nil` when there is none.
  private static func answer(
    in session: SessionModel, requestID: String?, optionID: String?, rejects: Bool
  ) -> PermissionAnswer? {
    guard let pending = select(session.pendingPermissions, id: requestID, key: \.id.uuidString) else {
      return nil
    }
    let options = PermissionPresentation.order(of: pending.request.options)
      .filter { PermissionPresentation.isReject(kind: $0.kind) == rejects }
    return select(options, id: optionID, key: \.optionId.rawValue).map { .session(session, pending.id, $0) }
  }

  /// The item whose key is `id`, or the first item when there is no `id`.
  ///
  /// - Parameters:
  ///   - items: The items, in order.
  ///   - id: The key to find, or `nil` for the first item.
  ///   - key: Gives the key of an item.
  /// - Returns: The item, or `nil` when no item has the key.
  private static func select<Item>(_ items: [Item], id: String?, key: (Item) -> String) -> Item? {
    guard let id else { return items.first }
    return items.first { key($0) == id }
  }

  /// Tells if `kind` rejects the operation.
  ///
  /// - Parameter kind: The kind of an option of a thread request.
  /// - Returns: `true` for `reject_once` and `reject_always`.
  static func isReject(_ kind: AgentViewKit.PermissionOption.Kind) -> Bool {
    kind == .rejectOnce || kind == .rejectAlways
  }

  /// Sends the answer that the payload selects.
  ///
  /// A session model gets `selectPermission(_:option:)`, and a comment of the
  /// payload goes out as the next prompt
  /// (`SessionModel.answerPermission(_:option:comment:)`). A thread gets the
  /// decision with the comment through the actions.
  ///
  /// - Parameters:
  ///   - payload: The payload of the dispatch, or `nil`.
  ///   - rejects: `true` for a reject option, `false` for an allow option.
  private func respond(payload: CommandPayload?, rejects: Bool) {
    guard let answer = answer(payload: payload, rejects: rejects) else { return }
    let comment = AgentCommandPayload.string(AgentCommandPayload.commentKey, in: payload)
    switch answer {
    case .thread(let request, let option):
      guard let actions else { return }
      let decision = PermissionDecision(outcome: .selected(option.id), comment: comment)
      Task { await actions.respond(to: request, decision) }
    case .session(let session, let id, let option):
      session.answerPermission(id, option: option.optionId, comment: comment)
    }
  }

  // MARK: - Jump

  /// The row key of the turn that a jump goes to.
  ///
  /// A turn starts at a user message. The jump starts at the first row in
  /// view. With no row in view, a forward jump goes to the first turn.
  ///
  /// - Parameter forward: `true` for the next turn, `false` for the previous
  ///   turn.
  /// - Returns: The row key of the turn, or `nil` when there is none.
  private func jumpTarget(forward: Bool) -> String? {
    guard let source else { return nil }
    let current = anchors?.visibleIDs.first.flatMap { source.position(of: $0) }
    let turns = Self.turnRows(of: source)
    if forward {
      return turns.first { turn in current.map { turn.position > $0 } ?? true }?.key
    }
    guard let current else { return nil }
    return turns.last { $0.position < current }?.key
  }

  /// The position and the row key of each user message row, in order.
  ///
  /// - Parameter source: The model of the scope.
  /// - Returns: One row for each user message item of a thread, or for each
  ///   `UserMessageEntry` of a transcript.
  private static func turnRows(of source: ConversationSource) -> [(position: Int, key: String)] {
    switch source {
    case .thread(let thread):
      thread.items.enumerated().compactMap { position, item in
        if case .userMessage = item { (position, item.id) } else { nil }
      }
    case .session(let session):
      session.transcript.enumerated().compactMap { position, entry in
        if case .userMessage = entry { (position, entry.rowKey) } else { nil }
      }
    }
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

  /// Expands each row, or collapses each row when all rows are expanded.
  ///
  /// - Parameter source: The model of the scope.
  private func toggleExpandAll(_ source: ConversationSource) {
    guard let store = expandedBlocks else { return }
    let expandsAll = !Self.isEachRowExpanded(of: source, in: store)
    for key in source.rowKeys {
      if expandsAll {
        store.expand(key)
      } else {
        store.collapse(key)
      }
    }
  }

  /// Tells if each row of `source` is expanded.
  ///
  /// A thread item with no decision reads the
  /// ``ExpandedBlocksStore/defaultExpanded`` policy. The policy takes a
  /// thread item, so a transcript entry reads only its decision.
  ///
  /// - Parameters:
  ///   - source: The model of the scope.
  ///   - store: The store of the expanded rows.
  /// - Returns: `true` when each row is expanded.
  private static func isEachRowExpanded(of source: ConversationSource, in store: ExpandedBlocksStore) -> Bool {
    switch source {
    case .thread(let thread): thread.items.allSatisfy { store.isExpanded($0) }
    case .session(let session): session.transcript.allSatisfy { store.isExpanded($0.rowKey) }
    }
  }

  // MARK: - Copy

  /// The role line of a user message.
  private static var userRole: String { String(localized: "User") }

  /// The role line of an agent message.
  private static var assistantRole: String { String(localized: "Assistant") }

  /// The messages of the model of a scope as plain text.
  ///
  /// - Parameter source: The model of the scope.
  /// - Returns: The text, or an empty string when the model has no message
  ///   text.
  static func plainText(of source: ConversationSource) -> String {
    switch source {
    case .thread(let thread): plainText(of: thread)
    case .session(let session): plainText(of: session)
    }
  }

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
      case .userMessage(let message): section(role: userRole, texts: texts(of: message))
      case .assistantMessage(let message): section(role: assistantRole, texts: texts(of: message))
      case .reasoning, .toolCall, .error, .unknown: nil
      }
    }
    .joined(separator: sectionSeparator)
  }

  /// The message entries of the transcript of a session model as plain text,
  /// in transcript order.
  ///
  /// Each `UserMessageEntry` and `AgentMessageEntry` gives one section: a
  /// role line, then the text blocks that are for the user. The entries come
  /// from ``ThreadExporter/messageTexts(in:)``, the same function as the
  /// Markdown export, so the adjacent text chunks of an entry join as the
  /// view shows them. A blank line separates two sections. The text omits
  /// the other entries.
  ///
  /// - Parameter session: The session model.
  /// - Returns: The text, or an empty string when the transcript has no
  ///   message text.
  static func plainText(of session: SessionModel) -> String {
    ThreadExporter.messageTexts(in: session.transcript).compactMap { message in
      section(role: roleLine(for: message.role), texts: message.texts)
    }
    .joined(separator: sectionSeparator)
  }

  /// The role line of a message of `role`.
  ///
  /// - Parameter role: The sender of the message.
  /// - Returns: ``userRole`` or ``assistantRole``.
  private static func roleLine(for role: MessageRole) -> String {
    switch role {
    case .user: userRole
    case .assistant: assistantRole
    }
  }

  /// The text blocks of a thread message that are for the user.
  ///
  /// - Parameter message: The message.
  /// - Returns: The texts, in order.
  private static func texts(of message: Message) -> [String] {
    message.blocks.compactMap { block -> String? in
      guard block.isVisible(to: .user), case .text(let text) = block.content else { return nil }
      return text
    }
  }

  /// The section of one message.
  ///
  /// - Parameters:
  ///   - role: The role line.
  ///   - texts: The texts of the message that are for the user.
  /// - Returns: The section, or `nil` when the message has no text.
  private static func section(role: String, texts: [String]) -> String? {
    guard !texts.isEmpty else { return nil }
    return ([role + ":"] + texts).joined(separator: "\n")
  }
}

extension EnvironmentValues {
  /// The target of the nearest ``AgentCommandScope``, or `nil`.
  @Entry var agentCommandTarget: AgentCommandTarget? = nil

  /// The focus segment of the nearest ``AgentCommandScope``, or `nil`.
  ///
  /// The scope writes this value in its body, before its mount gives the
  /// model to the target, so that a scope below can see at once that it is
  /// in a scope for the same model.
  @Entry var agentCommandScopeSegment: FocusSegment? = nil
}
