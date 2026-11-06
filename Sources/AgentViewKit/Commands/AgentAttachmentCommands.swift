import EditorCommands
import EditorCommandsUI
import Foundation

/// The actions on an attached file as EditorKit commands (AVK-11, D108).
///
/// The scope of each attachment chip, image, artifact file and attachment
/// inspector (`agentAttachment:<id>`, see ``AgentScopeKind/attachment``)
/// registers one command for each verb at its own path. A command reads the
/// ``Attachment`` of its scope with `@FromTarget`. Thus the buttons of the
/// inspector, the context menu of the attachment and the command palette run
/// the same command.
///
/// Each verb is in the group ``AgentCommandGroup/attachment``, in the File
/// menu and in the context menu of the attachment. A verb is available only
/// when it can run: a file URL must point to a file that exists, and Reveal in
/// Finder, Save and Quick Look need a local file.
public nonisolated enum AgentAttachmentVerb: String, CaseIterable, Sendable {
  /// Opens the file in its default application.
  case openAttachment

  /// Shows the file in the Finder.
  case revealAttachment

  /// Shares the file with the share picker of the system.
  case shareAttachment

  /// Saves a copy of the file.
  case saveAttachment

  /// Shows the file in a Quick Look panel.
  case quickLookAttachment

  /// The group of the File menu that holds the verbs.
  static let menuGroup = "agentAttachment"

  /// The group of the context menu that holds the verbs.
  static let contextMenuGroup = 0

  /// The command id of the verb, `agent.<verb>`.
  public var id: CommandID {
    CommandID(AgentCommandVerb.idPrefix + rawValue)
  }

  /// The title that the buttons, the menus and the palette show.
  public var title: String {
    switch self {
    case .openAttachment: String(localized: "Open", bundle: .module)
    case .revealAttachment: String(localized: "Reveal in Finder", bundle: .module)
    case .shareAttachment: String(localized: "Share", bundle: .module)
    case .saveAttachment: String(localized: "Save", bundle: .module)
    case .quickLookAttachment: String(localized: "Quick Look", bundle: .module)
    }
  }

  /// The SF Symbol of the verb.
  public var icon: String {
    switch self {
    case .openAttachment: AgentSymbol.open
    case .revealAttachment: AgentSymbol.folder
    case .shareAttachment: AgentSymbol.share
    case .saveAttachment: AgentSymbol.save
    case .quickLookAttachment: AgentSymbol.quickLook
    }
  }

  /// The group of the verb: ``AgentCommandGroup/attachment``.
  public var group: AgentCommandGroup {
    .attachment
  }

  /// The place of the verb in the File menu (AVK-1).
  public var menu: MenuPlacement {
    MenuPlacement(path: .file, group: Self.menuGroup, order: order)
  }

  /// The place of the verb in the context menu of an attachment (AVK-1).
  public var contextMenu: ContextMenuPlacement {
    ContextMenuPlacement(group: Self.contextMenuGroup, order: order)
  }

  /// The sort order of the verb in its menu group: the place of the verb in
  /// `allCases`. The cases are in the order of the buttons.
  private var order: Double {
    Double(Self.allCases.firstIndex(of: self) ?? Self.allCases.endIndex)
  }

  /// Tells if the verb needs a local file. Open and Share also work on a URL
  /// that is not a file.
  private var needsLocalFile: Bool {
    switch self {
    case .openAttachment, .shareAttachment: false
    case .revealAttachment, .saveAttachment, .quickLookAttachment: true
    }
  }

  /// Tells if the verb can run on `attachment`, with the reason when it
  /// cannot.
  ///
  /// The buttons of ``AttachmentActions`` and the command read the same
  /// rule.
  ///
  /// - Parameter attachment: The attachment of the scope.
  /// - Returns: `.unavailable` when a file URL points to no file, or when the
  ///   verb needs a local file and the URL is not a file URL.
  func availability(for attachment: Attachment) -> Availability {
    let url = attachment.url
    guard !url.isFileURL || FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
      return .unavailable(reason: String(localized: "The file does not exist.", bundle: .module))
    }
    guard url.isFileURL || !needsLocalFile else {
      return .unavailable(reason: String(localized: "The attachment is not a local file.", bundle: .module))
    }
    return .available
  }
}

// MARK: - Command

/// One command of an attachment scope: an action and the target of its
/// scope.
///
/// The command is a value, as EditorKit requires. It holds its target
/// weakly, so a registry that outlives the view does not keep the target.
/// The command reads the ``Attachment`` of the nearest attachment scope with
/// `@FromTarget`, and its ``Action`` decides at the target whether it can run
/// and what a run does: an ``AgentAttachmentVerb`` runs on the attachment
/// with the service of the target, and an ``AgentFileSelectionVerb`` runs the
/// select action of the target.
nonisolated struct AgentAttachmentCommand: EditorCommands.Command {
  /// What one command of an attachment scope is and does: its id, its title
  /// and places, its availability and its run at the live target of the
  /// scope, with the attachment of the scope.
  struct Action: Sendable {
    /// The command id.
    let id: CommandID

    /// The title that the menus and the palette show.
    let title: String

    /// The SF Symbol of the command, or `nil`.
    var icon: String?

    /// The place of the command in the File menu, or `nil` for none.
    var menu: MenuPlacement?

    /// The place of the command in the context menu, or `nil` for none.
    var contextMenu: ContextMenuPlacement?

    /// Whether the command can run at the target, with the attachment of
    /// the scope.
    let availability: @MainActor @Sendable (AgentAttachmentTarget, Attachment?) -> Availability

    /// Runs the command at the target, with the attachment of the scope.
    /// Returns `false` when the run declines.
    let run: @MainActor @Sendable (AgentAttachmentTarget, Attachment?) -> Bool
  }

  /// The action of the command.
  let action: Action

  /// The target of the scope that registered the command.
  weak let target: AgentAttachmentTarget?

  /// The attachment of the nearest attachment scope, or `nil`.
  @FromTarget(kind: AgentScopeKind.attachment) var attachment: Attachment?

  /// Makes the command of `action` for `target`.
  ///
  /// - Parameters:
  ///   - action: The action of the command.
  ///   - target: The target of the scope, or `nil`.
  init(action: Action, target: AgentAttachmentTarget?) {
    self.action = action
    self.target = target
  }

  var id: CommandID { action.id }

  var title: String { action.title }

  func availability(in context: CommandContext) -> Availability {
    CommandTargetAccess.availability(at: target, unavailable: .attachmentNotShown) {
      action.availability($0, attachment)
    }
  }

  /// Runs the action at the target of the scope. With no target, the run
  /// declines.
  ///
  /// - Parameter context: The context of the invocation.
  /// - Returns: `true` when the action ran.
  func run(in context: CommandContext) -> Bool {
    CommandTargetAccess.run(at: target) { action.run($0, attachment) }
  }

  /// The EditorKit definition of `action` for `target`, with the title, the
  /// icon, the menu and the context menu of the action.
  ///
  /// - Parameters:
  ///   - action: The action.
  ///   - target: The target of the scope.
  /// - Returns: The definition.
  static func definition(of action: Action, for target: AgentAttachmentTarget) -> CommandDefinition {
    CommandDefinition(
      id: action.id,
      title: .static(action.title),
      icon: action.icon,
      menu: action.menu,
      contextMenu: action.contextMenu,
      make: { [weak target] _ in
        AgentAttachmentCommand(action: action, target: target)
      })
  }
}

extension AgentAttachmentVerb {
  /// The command action of the verb: it runs on the attachment of the scope
  /// with the service of the target.
  ///
  /// The run declines where the command cannot run, the same checks as the
  /// availability: a key then goes on to the next binding of its chord
  /// (EditorKit ^jaxzzkn). A run that reaches the service handles the
  /// invocation, also when the service cannot start the action (it logs the
  /// failure): the user aimed the key at this attachment, so the key does not
  /// go on to another command of the chord (^zb5td6w).
  var action: AgentAttachmentCommand.Action {
    AgentAttachmentCommand.Action(
      id: id, title: title, icon: icon, menu: menu, contextMenu: contextMenu,
      availability: { [self] target, attachment in
        guard target.service != nil, let attachment else { return .attachmentNotShown }
        return availability(for: attachment)
      },
      run: { [self] target, attachment in
        guard let service = target.service, let attachment, availability(for: attachment).isAvailable
        else { return false }
        _ = service.run(self, on: attachment)
        return true
      })
  }
}

// MARK: - Target

/// The live objects of one attachment scope.
///
/// The mount of an ``AgentAttachmentScope`` keeps the service current. The
/// buttons of ``AttachmentActions`` are the command buttons of the verbs at
/// the path of the scope, so that a button, the context menu and the palette
/// run the same command.
@MainActor
final class AgentAttachmentTarget {
  /// The service that runs the verbs, or `nil` before the mount gives one.
  var service: (any AttachmentFileService)?

  /// The action that changes the file selection for a press on the file
  /// view of the scope, which the ``AgentFileSelectionVerb`` commands run,
  /// or `nil` when the view selects no file.
  var select: ((AttachmentSelectionChange) -> Void)?

  /// Makes a target with no service and no select action.
  init() {}
}

nonisolated extension Availability {
  /// The availability of an attachment command whose scope shows no
  /// attachment, or whose target is gone.
  static var attachmentNotShown: Availability {
    .unavailable(reason: String(localized: "The attachment is not shown.", bundle: .module))
  }
}

// MARK: - Registration

/// Registers and removes the attachment commands of a scope in a registry.
///
/// The mount of a scope and the headless tests use the same calls.
enum AgentAttachmentRegistration {
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
  ///   - selects: Whether the file view of the scope selects its file, so
  ///     the call registers the ``AgentFileSelectionVerb`` commands too. A
  ///     call without them unregisters them. No group turns them off: they
  ///     are the bound clicks of the view, which no menu shows.
  static func register(
    _ target: AgentAttachmentTarget, at path: FocusPath, into registry: inout CommandRegistry,
    groupsOff: Set<AgentCommandGroup> = [], selects: Bool = false
  ) {
    let definitions = AgentAttachmentVerb.allCases.map { verb in
      AgentCommandRegistration.GroupedDefinition(
        group: verb.group, definition: AgentAttachmentCommand.definition(of: verb.action, for: target))
    }
    AgentCommandRegistration.register(definitions, at: path, into: &registry, groupsOff: groupsOff)
    for verb in AgentFileSelectionVerb.allCases {
      if selects {
        registry.register(AgentAttachmentCommand.definition(of: verb.action, for: target), at: path)
      } else {
        registry.unregister(verb.id, at: path)
      }
    }
  }

  /// Removes each attachment command and each file selection command at
  /// `path`, and the `.host` part of the node that
  /// ``register(_:at:into:groupsOff:selects:)`` wrote.
  ///
  /// The `.scope` part of the node stays: the beacon of the scope removes it
  /// when its view goes away.
  ///
  /// - Parameters:
  ///   - path: The path of the scope.
  ///   - registry: The registry to remove the commands from.
  static func deregister(at path: FocusPath, from registry: inout CommandRegistry) {
    let ids = AgentAttachmentVerb.allCases.map(\.id) + AgentFileSelectionVerb.allCases.map(\.id)
    for id in ids {
      registry.unregister(id, at: path)
    }
    registry.tree = registry.tree.removing(.host, at: path)
  }
}
