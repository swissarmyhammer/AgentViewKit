import EditorCommands
import FoundationModelsACP
import FoundationModelsACPClient

/// The verbs of the kit as EditorKit commands (plan.md §4.1, §11 decision 14).
///
/// Each verb has a stable ``id`` and a ``title``. An ``AgentCommandScope``
/// registers one command for each verb in the ambient `CommandSystem`, so the
/// command palette, the menus, and the keybindings editor show the verbs.
/// ``AgentKeymap`` gives the default keys.
///
/// A host can dispatch a verb by id through the registry of the system:
///
/// ```swift
/// system.registry.perform(AgentCommandVerb.cancel.id, at: path)
/// ```
public nonisolated enum AgentCommandVerb: String, CaseIterable, Sendable {
  /// Sends the text of the composer, or the text of the payload.
  case send

  /// Cancels the work of the session: the open prompts, the background work,
  /// and the requests that wait for the user.
  case cancel

  /// Selects an allow option of a pending permission request.
  case approvePending

  /// Selects a reject option of a pending permission request.
  case rejectPending

  /// Brings the request before the front request of the ``RequestDeck`` to
  /// the front. It is not available at the first request, or with one
  /// request or none.
  case previousRequest

  /// Brings the request after the front request of the ``RequestDeck`` to
  /// the front. It is not available at the last request, or with one
  /// request or none.
  case nextRequest

  /// Scrolls the thread list to the next prompt: the next user message.
  case jumpToNext

  /// Scrolls the thread list to the previous prompt: the previous user
  /// message.
  case jumpToPrevious

  /// Copies the messages of the thread as plain text.
  case copyThread

  /// Copies the Markdown of one message: the message of the payload, or the
  /// message of the context menu.
  case copyMessage

  /// Expands each item of the thread, or collapses each item when all items
  /// are expanded.
  case toggleExpandAll

  /// Scrolls the thread list to the end and follows new items.
  case scrollToBottom

  /// Moves the keyboard focus to the composer.
  case focusComposer

  /// The start of the id of each verb.
  public static let idPrefix = "agent."

  /// The command id of the verb, `agent.<verb>`.
  public var id: CommandID {
    CommandID(Self.idPrefix + rawValue)
  }

  /// The title that the menus and the palette show.
  public var title: String {
    switch self {
    case .send: String(localized: "Send Message", bundle: .module)
    case .cancel: String(localized: "Stop", bundle: .module)
    case .approvePending: String(localized: "Approve Request", bundle: .module)
    case .rejectPending: String(localized: "Reject Request", bundle: .module)
    case .previousRequest: String(localized: "Previous Request", bundle: .module)
    case .nextRequest: String(localized: "Next Request", bundle: .module)
    case .jumpToNext: String(localized: "Next Prompt", bundle: .module)
    case .jumpToPrevious: String(localized: "Previous Prompt", bundle: .module)
    case .copyThread: String(localized: "Copy Thread", bundle: .module)
    case .copyMessage: String(localized: "Copy Message", bundle: .module)
    case .toggleExpandAll: String(localized: "Expand or Collapse All", bundle: .module)
    case .scrollToBottom: String(localized: "Scroll to Bottom", bundle: .module)
    case .focusComposer: String(localized: "Focus Composer", bundle: .module)
    }
  }

  /// The verb with the command id, or `nil` when the id is not a verb of
  /// the kit.
  ///
  /// - Parameter id: The command id.
  public init?(id: CommandID) {
    guard id.rawValue.hasPrefix(Self.idPrefix) else { return nil }
    self.init(rawValue: String(id.rawValue.dropFirst(Self.idPrefix.count)))
  }
}

/// The payload keys and the payload builders of the agent commands.
///
/// A command with no payload acts on the composer or on the first pending
/// request. A payload selects the text to send, or the request and the
/// option to answer.
public nonisolated enum AgentCommandPayload {
  /// The key of the text that ``AgentCommandVerb/send`` sends.
  public static let textKey = "text"

  /// The key of the raw identifier of the permission request to answer. For
  /// a session model, the value is the `uuidString` of the local id of the
  /// `PendingPermissionRequest`.
  public static let requestKey = "request"

  /// The key of the raw identifier of the permission option to select. For
  /// a session model, the value is the `optionId` of the ACP option.
  public static let optionKey = "option"

  /// The key of the comment of a permission answer.
  public static let commentKey = "comment"

  /// The key of the message that ``AgentCommandVerb/copyMessage`` copies. For
  /// a session model, the value is the row key of the transcript entry.
  public static let messageKey = "message"

  /// The payload that sends `text`.
  ///
  /// - Parameter text: The text to send.
  /// - Returns: The payload.
  public static func text(_ text: String) -> CommandPayload {
    CommandPayload(values: [textKey: text])
  }

  /// The payload that answers a pending permission request of a session
  /// model with an option.
  ///
  /// - Parameters:
  ///   - request: The local id of the pending request. The payload holds its
  ///     `uuidString`.
  ///   - option: The `optionId` of the ACP option.
  ///   - comment: The comment of the user, or `nil`.
  /// - Returns: The payload.
  public static func permission(
    request: PendingPermissionRequest.ID, option: PermissionOptionId, comment: String? = nil
  ) -> CommandPayload {
    var values: [String: any Sendable] = [
      requestKey: request.uuidString, optionKey: option.rawValue,
    ]
    values[commentKey] = comment
    return CommandPayload(values: values)
  }

  /// The string value of `key` in `payload`, or `nil`.
  ///
  /// - Parameters:
  ///   - key: The key of the value.
  ///   - payload: The payload, or `nil`.
  /// - Returns: The string.
  static func string(_ key: String, in payload: CommandPayload?) -> String? {
    payload?.value(for: key) as? String
  }
}

/// One agent command: a verb, the target that it acts on, and its payload.
///
/// The command is a value, as EditorKit requires. It holds its target
/// weakly, so a registry that outlives the thread view does not keep the
/// thread. A command with no target is unavailable.
nonisolated struct AgentCommand: Command {
  /// The verb of the command.
  let verb: AgentCommandVerb

  /// The target that the command acts on.
  weak let target: AgentCommandTarget?

  /// The payload of the dispatch, or `nil`.
  let payload: CommandPayload?

  var id: CommandID { verb.id }

  var title: String { verb.title }

  func availability(in context: CommandContext) -> Availability {
    MainActor.assumeIsolated {
      guard let target else {
        return .unavailable(reason: String(localized: "The thread is not shown.", bundle: .module))
      }
      return target.availability(of: verb, payload: payload(at: context.path))
    }
  }

  func run(in context: CommandContext) -> Bool {
    MainActor.assumeIsolated {
      target?.run(verb, payload: payload(at: context.path)) ?? false
    }
  }

  /// The payload of the dispatch, with the item of the invocation path when
  /// the payload does not name an item.
  ///
  /// A context menu runs the command at the path of its item. Thus Copy
  /// Message in the context menu of a message copies that message, and
  /// Approve Request in the context menu of a card answers that request.
  ///
  /// - Parameter path: The invocation path.
  /// - Returns: The payload.
  func payload(at path: FocusPath) -> CommandPayload? {
    guard let key = verb.itemPayloadKey, AgentCommandPayload.string(key, in: payload) == nil,
      let item = AgentScopeKind.item(in: path), item.kind == verb.itemKind, let id = item.id
    else { return payload }
    var values = payload?.values ?? [:]
    values[key] = id
    return CommandPayload(values: values, objects: payload?.objects ?? [:])
  }

  /// The EditorKit definition of `verb` for `target`.
  ///
  /// The definition carries the first default key of ``AgentKeymap``, so a
  /// menu shows the key, and the menu, context menu and icon of the verb.
  /// The menus and the palette show the verb at a path when
  /// ``AgentCommandVerb/isVisible(at:)`` tells so.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - target: The target that the command acts on.
  /// - Returns: The definition.
  static func definition(
    of verb: AgentCommandVerb, for target: AgentCommandTarget
  ) -> CommandDefinition {
    var keys: [KeymapMode: KeyChord] = [:]
    keys[.cua] = AgentKeymap.defaultChords[verb]?.first
    return CommandDefinition(
      id: verb.id,
      title: .static(verb.title),
      icon: verb.icon,
      menu: verb.menu,
      contextMenu: verb.contextMenu,
      keys: keys,
      isVisible: { verb.isVisible(at: $0.path) },
      make: { [weak target] payload in
        AgentCommand(verb: verb, target: target, payload: payload)
      })
  }

  /// The EditorKit definitions of each verb for `target`.
  ///
  /// - Parameter target: The target that the commands act on.
  /// - Returns: One definition for each verb, in the order of the verbs.
  static func definitions(for target: AgentCommandTarget) -> [CommandDefinition] {
    AgentCommandVerb.allCases.map { definition(of: $0, for: target) }
  }
}
