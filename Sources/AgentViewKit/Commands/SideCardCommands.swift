import EditorCommands
import EditorCommandsUI
import EditorSwiftUI
import FoundationModelsACPClient

/// The actions of a side card of `/btw` as EditorKit commands (D205, D108).
///
/// The scope of each ``SideQuestionCard`` (`agentSideCard:<sessionId>`, see
/// ``AgentScopeKind/sideCard``) registers one command for each verb at its
/// own path. The buttons of the card are the command buttons of the verbs, so
/// a button, the context menu of the card, the Session menu, the keys and
/// the command palette run the same command on the same card.
///
/// Each verb is in the group ``AgentCommandGroup/sideCard``. Escape on a
/// focused card runs Close: the card scope is nearer than the scope of the
/// thread, whose Escape stops the agent.
///
/// While the fork needs input (a pending permission request or a pending
/// elicitation), Send to Chat is not available: the user answers the fork in
/// its own thread. Open and Close stay available, so the user can always
/// dismiss a side question, and Escape on a focused card runs Close.
public nonisolated enum SideCardVerb: String, CaseIterable, Sendable {
  /// Puts the question and the answer into the composer of the thread, at
  /// the caret, with no send. A host action of the card can take the text
  /// instead.
  case sendSideCardToChat

  /// Runs the Open action of the card: the host shows the fork as a thread.
  case openSideCard

  /// Runs the Close action of the card: the host removes the card.
  case closeSideCard

  /// The group of the Session menu that holds the verbs.
  static let menuGroup = "agentSideCard"

  /// The group of the context menu that holds the verbs.
  static let contextMenuGroup = 0

  /// The command id of the verb, `agent.<verb>`.
  public var id: CommandID {
    CommandID(AgentCommandVerb.idPrefix + rawValue)
  }

  /// The title that the buttons, the menus and the palette show.
  public var title: String {
    switch self {
    case .sendSideCardToChat: String(localized: "Send to Chat", bundle: .module)
    case .openSideCard: String(localized: "Open", bundle: .module)
    case .closeSideCard: String(localized: "Close", bundle: .module)
    }
  }

  /// The SF Symbol of the verb.
  public var icon: String {
    switch self {
    case .sendSideCardToChat: AgentSymbol.sendToChat
    case .openSideCard: AgentSymbol.openSideQuestion
    case .closeSideCard: EditorSymbol.action(.dismiss).systemImage
    }
  }

  /// The accessibility identifier of the button of the verb in a card, such
  /// as `side-card-send`.
  public var identifier: String {
    switch self {
    case .sendSideCardToChat: SideQuestionCard.identifier + "-send"
    case .openSideCard: SideQuestionCard.identifier + "-open"
    case .closeSideCard: SideQuestionCard.identifier + "-close"
    }
  }

  /// The group of the verb: ``AgentCommandGroup/sideCard``.
  public var group: AgentCommandGroup {
    .sideCard
  }

  /// The place of the verb in the Session menu, where it acts on the card
  /// that has the focus (TestudoApp D41).
  public var menu: MenuPlacement {
    MenuPlacement(path: .session, group: Self.menuGroup, order: order)
  }

  /// The place of the verb in the context menu of a card.
  public var contextMenu: ContextMenuPlacement {
    ContextMenuPlacement(group: Self.contextMenuGroup, order: order)
  }

  /// The key of the verb that a menu shows, or `nil`: Escape for Close.
  public var key: KeyChord? {
    self == .closeSideCard ? StandardChords.leave : nil
  }

  /// The presentation of the verb in the surfaces of EditorKit: the id, the
  /// title, the icon, the menu, the context menu and the key of the verb.
  var presentation: AgentCommandPresentation {
    AgentCommandPresentation(
      id: id, title: title, icon: icon, menu: menu, contextMenu: contextMenu, key: key)
  }

  /// The sort order of the verb in its menu group: the place of the verb in
  /// `allCases`. The cases are in the order of the buttons.
  private var order: Double {
    Double(Self.allCases.firstIndex(of: self) ?? Self.allCases.endIndex)
  }
}

// MARK: - Command

/// One command of a side card scope: a verb and the target of its scope.
///
/// The command is a value, as EditorKit requires. It holds its target
/// weakly, so a registry that outlives the card does not keep the card.
nonisolated struct SideCardCommand: EditorCommands.Command {
  /// The verb of the command.
  let verb: SideCardVerb

  /// The target of the scope that registered the command.
  weak let target: SideCardTarget?

  /// The command id of the verb.
  var id: CommandID { verb.id }

  /// The title of the verb.
  var title: String { verb.title }

  /// Tells if the verb can run at the target of the scope.
  ///
  /// - Parameter context: The context of the invocation.
  /// - Returns: The availability of the verb at the target, or
  ///   `.sideCardNotShown` when the card is gone.
  func availability(in context: CommandContext) -> Availability {
    CommandTargetAccess.availability(at: target, unavailable: .sideCardNotShown) {
      $0.availability(of: verb)
    }
  }

  /// Runs the verb at the target of the scope. With no target, the run
  /// declines.
  ///
  /// - Parameter context: The context of the invocation.
  /// - Returns: `true` when the verb ran.
  func run(in context: CommandContext) -> Bool {
    CommandTargetAccess.run(at: target) { $0.run(verb) }
  }

  /// The EditorKit definition of `verb` for `target`, from the
  /// presentation of the verb (``SideCardVerb/presentation``).
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - target: The target of the scope.
  /// - Returns: The definition.
  static func definition(of verb: SideCardVerb, for target: SideCardTarget) -> CommandDefinition {
    CommandDefinition(verb.presentation, target: target) { target, _ in
      SideCardCommand(verb: verb, target: target)
    }
  }
}

// MARK: - Target

/// The live objects of one side card scope.
///
/// The mount of a ``SideQuestionCard`` keeps the values current. Each
/// availability check and each run reads the session model of the fork
/// again.
@MainActor
final class SideCardTarget {
  /// The question of the card.
  var question = ""

  /// The session model of the fork, or `nil` before the mount gives one.
  var session: SessionModel?

  /// The Open action of the host.
  var open: (@MainActor () -> Void)?

  /// The Close action of the host.
  var close: (@MainActor () -> Void)?

  /// The Send to Chat action of the host, or `nil` when the card inserts the
  /// text in the composer of ``thread``.
  var hostSend: (@MainActor (String) -> Void)?

  /// The target of the thread that shows the card, whose composer gets the
  /// text of Send to Chat when the host gives no action.
  weak var thread: AgentCommandTarget?

  /// Makes a target with no fork and no actions.
  init() {}

  /// The text of Send to Chat: the question and the answer of the fork, or
  /// `nil` when the fork has no answer yet.
  var chatText: String? {
    guard let session else { return nil }
    let answer = SideQuestionCard.answer(of: session)
    guard !answer.isEmpty else { return nil }
    return SideQuestionCard.chatText(question: question, answer: answer)
  }

  /// Tells if `verb` can run now, with the reason when it cannot.
  ///
  /// - Parameter verb: The verb.
  /// - Returns: `.unavailable` with no fork; for Send to Chat while the fork
  ///   needs input, with no answer, or with no host action and no composer.
  ///   Otherwise `.available`.
  func availability(of verb: SideCardVerb) -> Availability {
    guard let session else { return .sideCardNotShown }
    guard verb == .sendSideCardToChat else { return .available }
    guard !SideQuestionCard.needsInput(session) else { return .sideCardNeedsInput }
    guard chatText != nil else { return .sideCardHasNoAnswer }
    guard hostSend != nil || thread?.composer != nil else { return .sideCardHasNoComposer }
    return .available
  }

  /// Runs `verb`.
  ///
  /// Send to Chat gives the text to the host action, or focuses the composer
  /// of the thread and inserts the text at its caret, with no send: the path
  /// of Mention… (``AgentCommandVerb/insertMention``). The run declines where
  /// the verb is not available, so a key goes on to the next binding of its
  /// chord.
  ///
  /// - Parameter verb: The verb.
  /// - Returns: `true` when the verb ran.
  func run(_ verb: SideCardVerb) -> Bool {
    guard availability(of: verb).isAvailable else { return false }
    switch verb {
    case .sendSideCardToChat: return sendToChat()
    case .openSideCard: open?()
    case .closeSideCard: close?()
    }
    return true
  }

  /// Gives the text of Send to Chat to the host action, or inserts it in the
  /// composer of the thread.
  ///
  /// - Returns: `false` when the card has no text or no place for it.
  private func sendToChat() -> Bool {
    guard let text = chatText else { return false }
    if let hostSend {
      hostSend(text)
      return true
    }
    guard let composer = thread?.composer else { return false }
    _ = composer.focus()
    composer.insert(text)
    return true
  }
}

/// The reasons of a side card command that cannot run.
nonisolated extension Availability {
  /// The availability of a side card command whose card is gone.
  static var sideCardNotShown: Availability {
    .unavailable(reason: String(localized: "The side question is not shown.", bundle: .module))
  }

  /// The availability of Send to Chat while the fork needs input.
  static var sideCardNeedsInput: Availability {
    .unavailable(
      reason: String(
        localized: "The side question needs input. Open it to answer.", bundle: .module))
  }

  /// The availability of Send to Chat before the fork answers.
  static var sideCardHasNoAnswer: Availability {
    .unavailable(reason: String(localized: "The side question has no answer yet.", bundle: .module))
  }

  /// The availability of Send to Chat with no host action and no composer.
  static var sideCardHasNoComposer: Availability {
    .unavailable(reason: String(localized: "The composer is not shown.", bundle: .module))
  }
}

// MARK: - Registration

/// Registers and removes the commands of a side card scope in a registry.
///
/// The mount of a card and the headless tests use the same calls.
enum SideCardRegistration {
  /// Registers the scope node and one command for each verb of `target` at
  /// `path`.
  ///
  /// The call does not register a verb of a group in `groupsOff`, and it
  /// unregisters a verb that an earlier call registered, with the same rule
  /// as the thread verbs (``AgentCommandRegistration``).
  ///
  /// - Parameters:
  ///   - target: The target of the scope.
  ///   - path: The path of the scope.
  ///   - registry: The registry to register into.
  ///   - groupsOff: The groups whose verbs the call does not register.
  static func register(
    _ target: SideCardTarget, at path: FocusPath, into registry: inout CommandRegistry,
    groupsOff: Set<AgentCommandGroup> = []
  ) {
    let definitions = SideCardVerb.allCases.map { verb in
      AgentCommandRegistration.GroupedDefinition(
        group: verb.group, definition: SideCardCommand.definition(of: verb, for: target))
    }
    AgentCommandRegistration.register(definitions, at: path, into: &registry, groupsOff: groupsOff)
  }

  /// Removes each side card command at `path`, and the `.host` part of the
  /// node that ``register(_:at:into:groupsOff:)`` wrote.
  ///
  /// The `.scope` part of the node stays: the beacon of the scope removes it
  /// when its view goes away.
  ///
  /// - Parameters:
  ///   - path: The path of the scope.
  ///   - registry: The registry to remove the commands from.
  static func deregister(at path: FocusPath, from registry: inout CommandRegistry) {
    AgentCommandRegistration.deregister(SideCardVerb.allCases.map(\.id), at: path, from: &registry)
  }
}
