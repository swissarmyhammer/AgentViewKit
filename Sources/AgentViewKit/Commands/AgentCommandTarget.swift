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
/// The target holds the `SessionModel` of the scope, and keeps no copy of its
/// values. Each availability check and each run reads the model again:
///
/// - Cancel is available while the `agentState` of the session model is
///   `.running` or `.requiresAction`, and it calls
///   `SessionModel.cancel(meta:)`.
/// - Send with a text payload calls `SessionModel.prompt(_:meta:)`.
/// - Approve and reject read `SessionModel.pendingPermissions`, and call
///   `selectPermission(_:option:)`.
/// - Copy reads the user message entries and the agent message entries of the
///   transcript. Jump goes to the next or the previous user message entry.
///   Expand all gives each entry to the store, so that the store reads the
///   expanded policy for the entry.
@MainActor
final class AgentCommandTarget {
  /// The kind of the focus segment of an agent command scope.
  static let segmentKind = "agentThread"

  /// The line that separates two messages in the copy text: one blank line.
  static let sectionSeparator = "\n\n"

  /// The session model that the commands act on, or `nil` when no scope
  /// gave one.
  var session: SessionModel?

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

  /// The focus segment of the scope of `session`.
  ///
  /// The identifier is the `sessionId` of the session model. Thus two thread
  /// views of two sessions in one window have two scopes.
  ///
  /// - Parameter session: The session model of the scope.
  /// - Returns: The segment `agentThread:<sessionId>`.
  static func segment(for session: SessionModel) -> FocusSegment {
    FocusSegment(kind: segmentKind, id: session.sessionId.rawValue)
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
    guard let session else {
      return .unavailable(reason: String(localized: "The thread is not shown."))
    }
    guard isAvailable(verb, payload: payload, in: session) else {
      return .unavailable(reason: Self.reason(for: verb))
    }
    return .available
  }

  /// Tells if `verb` can run now on `session`.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - payload: The payload of the dispatch, or `nil`.
  ///   - session: The session model of the scope.
  /// - Returns: `true` when the verb can run.
  private func isAvailable(
    _ verb: AgentCommandVerb, payload: CommandPayload?, in session: SessionModel
  ) -> Bool {
    switch verb {
    case .send: canSend(payload: payload)
    case .cancel: Self.isActive(session.agentState)
    case .approvePending: answer(payload: payload, rejects: false) != nil
    case .rejectPending: answer(payload: payload, rejects: true) != nil
    case .jumpToNext: anchors != nil && jumpTarget(forward: true) != nil
    case .jumpToPrevious: anchors != nil && jumpTarget(forward: false) != nil
    case .copyThread: !Self.plainText(of: session).isEmpty
    case .toggleExpandAll: expandedBlocks != nil && !session.transcript.isEmpty
    case .scrollToBottom: anchors != nil && !session.transcript.isEmpty
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
    guard let session, availability(of: verb, payload: payload).isAvailable else { return false }
    switch verb {
    case .send: send(payload: payload, to: session)
    case .cancel: session.startCancel()
    case .approvePending: respond(payload: payload, rejects: false)
    case .rejectPending: respond(payload: payload, rejects: true)
    case .jumpToNext: jump(forward: true)
    case .jumpToPrevious: jump(forward: false)
    case .copyThread: pasteboard.copyText(Self.plainText(of: session))
    case .toggleExpandAll: toggleExpandAll(session)
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
  /// The session model gets the text as `session/prompt` at once.
  ///
  /// - Parameters:
  ///   - payload: The payload of the dispatch, or `nil`.
  ///   - session: The session model of the scope.
  private func send(payload: CommandPayload?, to session: SessionModel) {
    guard let text = AgentCommandPayload.string(AgentCommandPayload.textKey, in: payload) else {
      composer?.submit()
      return
    }
    session.startPrompt(text: text)
  }

  // MARK: - Permission

  /// A pending permission request of the session model, and one of its ACP
  /// options.
  private struct PermissionAnswer {
    /// The local id of the pending request.
    let id: PendingPermissionRequest.ID

    /// The option that the answer selects.
    let option: FoundationModelsACP.PermissionOption
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
    guard let session else { return nil }
    let requestID = AgentCommandPayload.string(AgentCommandPayload.requestKey, in: payload)
    let optionID = AgentCommandPayload.string(AgentCommandPayload.optionKey, in: payload)
    return Self.answer(in: session, requestID: requestID, optionID: optionID, rejects: rejects)
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
    return select(options, id: optionID, key: \.optionId.rawValue).map {
      PermissionAnswer(id: pending.id, option: $0)
    }
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

  /// Sends the answer that the payload selects.
  ///
  /// The session model gets `selectPermission(_:option:)`, and a comment of
  /// the payload goes out as the next prompt
  /// (`SessionModel.answerPermission(_:option:comment:)`).
  ///
  /// - Parameters:
  ///   - payload: The payload of the dispatch, or `nil`.
  ///   - rejects: `true` for a reject option, `false` for an allow option.
  private func respond(payload: CommandPayload?, rejects: Bool) {
    guard let session, let answer = answer(payload: payload, rejects: rejects) else { return }
    let comment = AgentCommandPayload.string(AgentCommandPayload.commentKey, in: payload)
    session.answerPermission(answer.id, option: answer.option.optionId, comment: comment)
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
    guard let session else { return nil }
    let transcript = session.transcript
    let current = anchors?.visibleIDs.first.flatMap { key in
      transcript.firstIndex { $0.rowKey == key }
    }
    let turns = Self.turnRows(of: transcript)
    if forward {
      return turns.first { turn in current.map { turn.position > $0 } ?? true }?.key
    }
    guard let current else { return nil }
    return turns.last { $0.position < current }?.key
  }

  /// The position and the row key of each user message row, in order.
  ///
  /// - Parameter transcript: The entries of `SessionModel.transcript`.
  /// - Returns: One row for each `UserMessageEntry` of the transcript.
  private static func turnRows(of transcript: [TranscriptEntry]) -> [(position: Int, key: String)] {
    transcript.enumerated().compactMap { position, entry in
      if case .userMessage = entry { (position, entry.rowKey) } else { nil }
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
  /// Each entry goes to the store in the entry form. An entry with no
  /// decision reads the ``ExpandedBlocksStore/defaultExpanded`` policy.
  ///
  /// - Parameter session: The session model of the scope.
  private func toggleExpandAll(_ session: SessionModel) {
    guard let store = expandedBlocks else { return }
    let transcript = session.transcript
    let expandsAll = !transcript.allSatisfy { store.isExpanded(entry: $0) }
    for entry in transcript {
      if expandsAll { store.expand(entry: entry) } else { store.collapse(entry: entry) }
    }
  }

  // MARK: - Copy

  /// The role line of a user message.
  private static var userRole: String { String(localized: "User") }

  /// The role line of an agent message.
  private static var assistantRole: String { String(localized: "Assistant") }

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
