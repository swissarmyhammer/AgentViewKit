import EditorCommands
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient

/// The kinds of the focus segments of the agent command scopes of the kit.
///
/// The kind of the scope of a tool call, ``toolCall``, and its segment are in
/// the style library, so that another kit names a tool call scope with no ACP
/// product. This extension adds the kinds whose segments take a subject of
/// the kit.
///
/// An ``AgentThreadView`` adds the segment `agentThread:<sessionId>`. In that
/// scope, each message row adds `agentMessage:<rowKey>`, each permission
/// request card adds `agentRequest:<id>`, and each tool call card adds
/// `agentToolCall:<toolCallId>`. The id of a request is the `uuidString` of
/// the local id of the `PendingPermissionRequest`. The id of a tool call is
/// its ACP `toolCallId`. A host registers its own commands for a message, a
/// request or a tool call in these scopes, for example with
/// `requires: .enclosing(AgentScopeKind.message)`.
///
/// No agent verb shows in the context menu of a tool call. That menu shows
/// only the commands that a host or another kit registers for
/// ``toolCall``. The kind text is the contract, so the other kit does not
/// link this kit.
///
/// Each attachment chip, image, artifact file and attachment inspector adds
/// `agentAttachment:<id>` (AVK-11). The id is the ``AttachmentID`` of the
/// file. The scope registers the ``AgentAttachmentVerb`` commands at its own
/// path, so the attachment verbs work also in an inspector of the host,
/// outside each thread scope.
///
/// Each ``SideQuestionCard`` adds `agentSideCard:<sessionId>` (D205). The id
/// is the `sessionId` of the fork that the card shows. The card registers
/// the ``SideCardVerb`` commands at its own path, and the subject of its
/// segment is the `SessionModel` of the fork.
///
/// Each control in a bar of a thread, such as Send, the permission-mode
/// picker or the composer editor, adds `agentControl:<identifier>`. The id is
/// the accessibility identifier of the control, such as `prompt-submit`. The
/// scope makes the control a target of the EditorKit jump and navigation. It
/// gives no subject, and it is no item: a command at its path acts on the
/// thread.
///
/// Each item scope gives its live object as the subject of its segment, and a
/// command reads it with `@FromTarget`:
///
/// | Kind | Subject |
/// | --- | --- |
/// | ``thread`` | the `SessionModel` |
/// | ``message`` | the `TranscriptEntry` of the message |
/// | ``request`` | the `PendingPermissionRequest` |
/// | ``toolCall`` | the `ToolCallEntry` |
/// | ``attachment`` | the ``Attachment`` |
/// | ``sideCard`` | the `SessionModel` of the fork |
///
/// ```swift
/// @FromTarget(kind: AgentScopeKind.message) var entry: TranscriptEntry?
/// ```
nonisolated extension AgentScopeKind {
  /// The kind of the scope of a thread.
  public static let thread = "agentThread"

  /// The kind of the scope of a message row.
  public static let message = "agentMessage"

  /// The kind of the scope of a permission request card.
  public static let request = "agentRequest"

  /// The kind of the scope of an attachment: a chip, an image, an artifact
  /// file or the attachment inspector.
  public static let attachment = "agentAttachment"

  /// The kind of the scope of a control in a bar of a thread, such as Send
  /// or the composer editor (`agentControlScope(_:corners:)`).
  public static let control = "agentControl"

  /// The kind of the scope of a side card of `/btw` (``SideQuestionCard``).
  public static let sideCard = "agentSideCard"

  /// The kinds of the item scopes in a thread.
  ///
  /// An attachment is an item, so the context menu of an attachment in a
  /// message shows the attachment verbs and not the verbs of the message. A
  /// side card is an item, so its context menu shows the side card verbs and
  /// not the verbs of the thread.
  static let items: Set<String> = [message, request, toolCall, attachment, sideCard]

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

  /// The segment of the scope of an attachment.
  ///
  /// - Parameter id: The identifier of the attachment.
  /// - Returns: The segment `agentAttachment:<id>`.
  static func attachment(_ id: AttachmentID) -> FocusSegment {
    FocusSegment(kind: attachment, id: id.rawValue)
  }

  /// The segment of the scope of a side card.
  ///
  /// - Parameter id: The `sessionId` of the fork that the card shows.
  /// - Returns: The segment `agentSideCard:<sessionId>`.
  static func sideCard(_ id: SessionId) -> FocusSegment {
    FocusSegment(kind: sideCard, id: id.rawValue)
  }

  /// The segment of the scope of a control in a bar of a thread.
  ///
  /// - Parameter identifier: The accessibility identifier of the control,
  ///   such as `prompt-submit`.
  /// - Returns: The segment `agentControl:<identifier>`.
  static func control(_ identifier: String) -> FocusSegment {
    FocusSegment(kind: control, id: identifier)
  }

  /// The last item segment of `path`, or `nil` when the path has no item
  /// segment.
  ///
  /// - Parameter path: The invocation path of a command.
  /// - Returns: The segment of the message, the request, the tool call, the
  ///   attachment or the side card.
  static func item(in path: FocusPath) -> FocusSegment? {
    path.segments.last { items.contains($0.kind) }
  }
}

/// The named group and order values of the menu and context menu places of
/// the verbs. A lower value comes first.
nonisolated private enum Slot {
  /// The order of the first row in a group.
  static let first: Double = 0
  /// The order of the second row in a group.
  static let second: Double = 1
  /// The order of the third row in a group.
  static let third: Double = 2
  /// The order of the fourth row in a group.
  static let fourth: Double = 3
  /// The order of the fifth row in a group.
  static let fifth: Double = 4
  /// The context menu group of the actions on the item, such as Copy Message.
  static let itemGroup = 0
  /// The context menu group of the navigation rows, such as Next Prompt.
  static let navigationGroup = 1
}

nonisolated extension AgentCommandVerb {
  /// The place of the verb in the menu bar (AVK-1).
  ///
  /// Each verb has a place, because the main menu, the context menus and the
  /// palette show the same commands for the same focus (TestudoApp D41).
  ///
  /// | Menu | Verbs |
  /// | --- | --- |
  /// | ``EditorCommands/MenuPath/session`` | Send Message, Stop, Focus Composer, Mention…, Approve Request, Reject Request, Copy Thread, Export as Markdown…, Fork from Here |
  /// | View | Next Prompt, Previous Prompt, Next Request, Previous Request, Expand or Collapse All, Scroll to Bottom, Go to Parent Session, Open Child Session, Previous Sibling Session, Next Sibling Session, Jump to Session |
  /// | Edit | Copy Message |
  ///
  /// EditorKit puts the rows of the Edit path right after the Cut, Copy and
  /// Paste rows of the system Edit menu, so Copy Message is next to Copy.
  /// Fork from Here is after Export as Markdown…, in the same order as the
  /// buttons of ``MessageActions``. In the Session menu, it acts on the
  /// selected message.
  public var menu: MenuPlacement? {
    switch self {
    case .send: MenuPlacement(path: .session, group: "agentPrompt", order: Slot.first)
    case .cancel: MenuPlacement(path: .session, group: "agentPrompt", order: Slot.second)
    case .focusComposer: MenuPlacement(path: .session, group: "agentComposer", order: Slot.first)
    case .insertMention: MenuPlacement(path: .session, group: "agentComposer", order: Slot.second)
    case .approvePending: MenuPlacement(path: .session, group: "agentRequest", order: Slot.first)
    case .rejectPending: MenuPlacement(path: .session, group: "agentRequest", order: Slot.second)
    case .copyThread: MenuPlacement(path: .session, group: "agentThread", order: Slot.first)
    case .exportMarkdown: MenuPlacement(path: .session, group: "agentThread", order: Slot.second)
    case .forkFromHere: MenuPlacement(path: .session, group: "agentThread", order: Slot.third)
    case .jumpToNext: MenuPlacement(path: .view, group: "agentPrompts", order: Slot.first)
    case .jumpToPrevious: MenuPlacement(path: .view, group: "agentPrompts", order: Slot.second)
    case .nextRequest: MenuPlacement(path: .view, group: "agentRequests", order: Slot.first)
    case .previousRequest: MenuPlacement(path: .view, group: "agentRequests", order: Slot.second)
    case .toggleExpandAll: MenuPlacement(path: .view, group: "agentThread", order: Slot.first)
    case .scrollToBottom: MenuPlacement(path: .view, group: "agentThread", order: Slot.second)
    case .copyMessage: MenuPlacement(path: .edit, group: "agentClipboard", order: Slot.first)
    case .copyCodeBlock: MenuPlacement(path: .edit, group: "agentClipboard", order: Slot.second)
    case .goToParent: MenuPlacement(path: .view, group: "agentSessions", order: Slot.first)
    case .openChild: MenuPlacement(path: .view, group: "agentSessions", order: Slot.second)
    case .previousSibling: MenuPlacement(path: .view, group: "agentSessions", order: Slot.third)
    case .nextSibling: MenuPlacement(path: .view, group: "agentSessions", order: Slot.fourth)
    case .jumpToSession: MenuPlacement(path: .view, group: "agentSessions", order: Slot.fifth)
    }
  }

  /// The place of the verb in the context menu of an item (AVK-1), or `nil`
  /// when the verb is not in a context menu.
  ///
  /// The context menu of a message shows Copy Message and Fork from Here,
  /// then Next Prompt and Previous Prompt. The context menu of a permission request card shows
  /// Approve Request and Reject Request. ``itemKind`` tells the item. The
  /// context menu of a fenced code block in rendered Markdown shows Copy
  /// Code Block (``isVisible(in:)``).
  public var contextMenu: ContextMenuPlacement? {
    switch self {
    case .copyMessage: ContextMenuPlacement(group: Slot.itemGroup, order: Slot.first)
    case .copyCodeBlock: ContextMenuPlacement(group: Slot.itemGroup, order: Slot.second)
    case .forkFromHere: ContextMenuPlacement(group: Slot.itemGroup, order: Slot.third)
    case .insertMention: ContextMenuPlacement(group: Slot.itemGroup, order: Slot.first)
    case .jumpToNext: ContextMenuPlacement(group: Slot.navigationGroup, order: Slot.first)
    case .jumpToPrevious: ContextMenuPlacement(group: Slot.navigationGroup, order: Slot.second)
    case .approvePending: ContextMenuPlacement(group: Slot.itemGroup, order: Slot.first)
    case .rejectPending: ContextMenuPlacement(group: Slot.itemGroup, order: Slot.second)
    default: nil
    }
  }

  /// The SF Symbol of the verb.
  public var icon: String {
    switch self {
    case .send: AgentSymbol.send
    case .cancel: AgentSymbol.stop
    case .approvePending: AgentSymbol.accept
    case .rejectPending: AgentSymbol.reject
    case .previousRequest, .previousSibling: EditorSymbol.action(.back).systemImage
    case .nextRequest, .nextSibling: EditorSymbol.action(.forward).systemImage
    case .jumpToNext: AgentSymbol.nextPrompt
    case .jumpToPrevious: AgentSymbol.previousPrompt
    case .copyThread: AgentSymbol.copyThread
    case .exportMarkdown: AgentSymbol.save
    case .forkFromHere: AgentSymbol.fork
    case .copyMessage, .copyCodeBlock: AgentSymbol.copy
    case .toggleExpandAll: AgentSymbol.expandAll
    case .scrollToBottom: AgentSymbol.scrollToBottom
    case .focusComposer: AgentSymbol.focusComposer
    case .insertMention: AgentSymbol.mention
    case .goToParent: AgentSymbol.parentSession
    case .openChild: AgentSymbol.childSession
    case .jumpToSession: AgentSymbol.jumpToSession
    }
  }

  /// The kind of the item scope whose context menu shows the verb, or `nil`
  /// when no context menu shows the verb.
  var itemKind: String? {
    switch self {
    case .copyMessage, .forkFromHere, .jumpToNext, .jumpToPrevious: AgentScopeKind.message
    case .approvePending, .rejectPending: AgentScopeKind.request
    default: nil
    }
  }

  /// The payload key that the item of the invocation path gives, or `nil`
  /// when the verb does not act on the item.
  var itemPayloadKey: String? {
    switch self {
    case .copyMessage, .forkFromHere: AgentCommandPayload.messageKey
    case .approvePending, .rejectPending: AgentCommandPayload.requestKey
    default: nil
    }
  }

  /// Tells if the menus, the context menus and the palette show the verb at
  /// `path`.
  ///
  /// A verb with no ``itemKind`` shows at each path. At a path with no item
  /// segment, each verb shows. Its availability tells if it can run there:
  /// ``copyMessage`` needs a message, so the Edit menu shows it disabled
  /// until a message has the focus. ``forkFromHere`` in the Session menu is
  /// the same. At a path in an item scope, a verb with
  /// an ``itemKind`` shows only for an item of that kind. Thus the context
  /// menu of a message does not show Approve Request. No verb has the item
  /// kind ``AgentScopeKind/toolCall``, so the context menu of a tool call
  /// shows no agent verb.
  ///
  /// - Parameter path: The invocation path.
  /// - Returns: `true` when the verb shows.
  func isVisible(at path: FocusPath) -> Bool {
    // Mention… acts on the composer, so the context menu of an item does not
    // show it. The composer and the thread show it.
    if self == .insertMention { return AgentScopeKind.item(in: path) == nil }
    guard let itemKind, let item = AgentScopeKind.item(in: path) else { return true }
    return item.kind == itemKind
  }

  /// Tells if the menus, the context menus and the palette show the verb in
  /// `context`.
  ///
  /// ``copyCodeBlock`` shows only in a fenced code block: the context has
  /// the code block of EditorKit (`EditorCodeBlockScope.isInside(_:)`). The
  /// gate also matches the caret in a block, which a structural gate does
  /// not. Each other verb shows as ``isVisible(at:)`` tells for the path of
  /// the context.
  ///
  /// - Parameter context: The folded context of the invocation path.
  /// - Returns: `true` when the verb shows.
  func isVisible(in context: CommandContext) -> Bool {
    guard self != .copyCodeBlock else { return EditorCodeBlockScope.isInside(context) }
    return isVisible(at: context.path)
  }
}
