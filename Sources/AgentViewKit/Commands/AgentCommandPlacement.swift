import EditorCommands
import FoundationModelsACPClient

nonisolated extension MenuPath {
  /// The Session menu of the agent commands.
  ///
  /// The path has no system slot, so EditorKit `EditorMenuCommands` shows it
  /// as a custom menu, with the raw value as its title. A host puts its own
  /// session commands in the same menu with this path.
  public static let session: MenuPath = "Session"
}

/// The kinds of the focus segments of the agent command scopes.
///
/// An ``AgentThreadView`` adds the segment `agentThread:<sessionId>`. In that
/// scope, each message row adds `agentMessage:<rowKey>`, and each permission
/// request card adds `agentRequest:<id>`. The id of a request is the
/// `uuidString` of the local id of the `PendingPermissionRequest`. A host
/// registers its own commands for a message or a request in these scopes,
/// for example with `requires: .enclosing(AgentScopeKind.message)`.
public nonisolated enum AgentScopeKind {
  /// The kind of the scope of a thread.
  public static let thread = "agentThread"

  /// The kind of the scope of a message row.
  public static let message = "agentMessage"

  /// The kind of the scope of a permission request card.
  public static let request = "agentRequest"

  /// The kinds of the item scopes in a thread.
  static let items: Set<String> = [message, request]

  /// The segment of the scope of a message row.
  ///
  /// - Parameter rowKey: The row key of the transcript entry of the message.
  /// - Returns: The segment `agentMessage:<rowKey>`.
  static func message(rowKey: String) -> FocusSegment {
    FocusSegment(kind: message, id: rowKey)
  }

  /// The segment of the scope of a permission request card.
  ///
  /// - Parameter id: The local id of the pending request.
  /// - Returns: The segment `agentRequest:<uuidString>`.
  static func request(_ id: PendingPermissionRequest.ID) -> FocusSegment {
    FocusSegment(kind: request, id: id.uuidString)
  }

  /// The last item segment of `path`, or `nil` when the path has no item
  /// segment.
  ///
  /// - Parameter path: The invocation path of a command.
  /// - Returns: The segment of the message or the request.
  static func item(in path: FocusPath) -> FocusSegment? {
    path.segments.last { items.contains($0.kind) }
  }
}

nonisolated extension AgentCommandVerb {
  /// The place of the verb in the menu bar (AVK-1), or `nil` when the verb
  /// is not in the menu bar.
  ///
  /// | Menu | Verbs |
  /// | --- | --- |
  /// | ``EditorCommands/MenuPath/session`` | Send Message, Stop, Focus Composer, Copy Thread |
  /// | View | Next Prompt, Previous Prompt, Next Request, Previous Request, Expand or Collapse All, Scroll to Bottom |
  public var menu: MenuPlacement? {
    switch self {
    case .send: MenuPlacement(path: .session, group: "agentPrompt", order: 0)
    case .cancel: MenuPlacement(path: .session, group: "agentPrompt", order: 1)
    case .focusComposer: MenuPlacement(path: .session, group: "agentComposer", order: 0)
    case .copyThread: MenuPlacement(path: .session, group: "agentThread", order: 0)
    case .jumpToNext: MenuPlacement(path: .view, group: "agentPrompts", order: 0)
    case .jumpToPrevious: MenuPlacement(path: .view, group: "agentPrompts", order: 1)
    case .nextRequest: MenuPlacement(path: .view, group: "agentRequests", order: 0)
    case .previousRequest: MenuPlacement(path: .view, group: "agentRequests", order: 1)
    case .toggleExpandAll: MenuPlacement(path: .view, group: "agentThread", order: 0)
    case .scrollToBottom: MenuPlacement(path: .view, group: "agentThread", order: 1)
    case .approvePending, .rejectPending, .copyMessage: nil
    }
  }

  /// The place of the verb in the context menu of an item (AVK-1), or `nil`
  /// when the verb is not in a context menu.
  ///
  /// The context menu of a message shows Copy Message, then Next Prompt and
  /// Previous Prompt. The context menu of a permission request card shows
  /// Approve Request and Reject Request. ``itemKind`` tells the item.
  public var contextMenu: ContextMenuPlacement? {
    switch self {
    case .copyMessage: ContextMenuPlacement(group: 0, order: 0)
    case .jumpToNext: ContextMenuPlacement(group: 1, order: 0)
    case .jumpToPrevious: ContextMenuPlacement(group: 1, order: 1)
    case .approvePending: ContextMenuPlacement(group: 0, order: 0)
    case .rejectPending: ContextMenuPlacement(group: 0, order: 1)
    default: nil
    }
  }

  /// The SF Symbol of the verb.
  public var icon: String {
    switch self {
    case .send: SharedSymbol.send
    case .cancel: SharedSymbol.stop
    case .approvePending: SharedSymbol.accept
    case .rejectPending: SharedSymbol.reject
    case .previousRequest: SharedSymbol.previousRequest
    case .nextRequest: SharedSymbol.nextRequest
    case .jumpToNext: SharedSymbol.nextPrompt
    case .jumpToPrevious: SharedSymbol.previousPrompt
    case .copyThread: SharedSymbol.copyThread
    case .copyMessage: SharedSymbol.copy
    case .toggleExpandAll: SharedSymbol.expandAll
    case .scrollToBottom: SharedSymbol.scrollToBottom
    case .focusComposer: SharedSymbol.focusComposer
    }
  }

  /// The kind of the item scope whose context menu shows the verb, or `nil`
  /// when no context menu shows the verb.
  var itemKind: String? {
    switch self {
    case .copyMessage, .jumpToNext, .jumpToPrevious: AgentScopeKind.message
    case .approvePending, .rejectPending: AgentScopeKind.request
    default: nil
    }
  }

  /// The payload key that the item of the invocation path gives, or `nil`
  /// when the verb does not act on the item.
  var itemPayloadKey: String? {
    switch self {
    case .copyMessage: AgentCommandPayload.messageKey
    case .approvePending, .rejectPending: AgentCommandPayload.requestKey
    default: nil
    }
  }

  /// Tells if the menus, the context menus and the palette show the verb at
  /// `path`.
  ///
  /// A verb with no ``itemKind`` shows at each path. At a path with no item
  /// segment, each verb shows, but ``copyMessage`` needs a message. At a
  /// path in an item scope, a verb with an ``itemKind`` shows only for an
  /// item of that kind. Thus the context menu of a message does not show
  /// Approve Request.
  ///
  /// - Parameter path: The invocation path.
  /// - Returns: `true` when the verb shows.
  func isVisible(at path: FocusPath) -> Bool {
    guard let itemKind else { return true }
    guard let item = AgentScopeKind.item(in: path) else { return self != .copyMessage }
    return item.kind == itemKind
  }
}
