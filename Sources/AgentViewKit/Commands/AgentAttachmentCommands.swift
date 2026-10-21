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
    case .openAttachment: SharedSymbol.open
    case .revealAttachment: SharedSymbol.folder
    case .shareAttachment: SharedSymbol.share
    case .saveAttachment: SharedSymbol.save
    case .quickLookAttachment: SharedSymbol.quickLook
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

/// One attachment command: a verb and the target of its scope.
///
/// The command is a value, as EditorKit requires. It holds its target
/// weakly, so a registry that outlives the view does not keep the target.
/// The command reads the ``Attachment`` of the nearest attachment scope with
/// `@FromTarget`, and runs the verb on it with the service of the target.
nonisolated struct AgentAttachmentCommand: Command {
  /// The verb of the command.
  let verb: AgentAttachmentVerb

  /// The target of the scope that registered the command.
  weak let target: AgentAttachmentTarget?

  /// The attachment of the nearest attachment scope, or `nil`.
  @FromTarget(kind: AgentScopeKind.attachment) var attachment: Attachment?

  /// Makes the command of `verb` for `target`.
  ///
  /// - Parameters:
  ///   - verb: The verb of the command.
  ///   - target: The target of the scope, or `nil`.
  init(verb: AgentAttachmentVerb, target: AgentAttachmentTarget?) {
    self.verb = verb
    self.target = target
  }

  var id: CommandID { verb.id }

  var title: String { verb.title }

  func availability(in context: CommandContext) -> Availability {
    MainActor.assumeIsolated {
      guard target?.service != nil, let attachment else {
        return .unavailable(reason: String(localized: "The attachment is not shown.", bundle: .module))
      }
      return verb.availability(for: attachment)
    }
  }

  func run(in context: CommandContext) -> Bool {
    MainActor.assumeIsolated {
      guard let service = target?.service, let attachment, verb.availability(for: attachment).isAvailable
      else { return false }
      return service.run(verb, on: attachment)
    }
  }

  /// The EditorKit definition of `verb` for `target`, with the title, the
  /// icon, the menu and the context menu of the verb.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - target: The target of the scope.
  /// - Returns: The definition.
  static func definition(of verb: AgentAttachmentVerb, for target: AgentAttachmentTarget) -> CommandDefinition {
    CommandDefinition(
      id: verb.id,
      title: .static(verb.title),
      icon: verb.icon,
      menu: verb.menu,
      contextMenu: verb.contextMenu,
      make: { [weak target] _ in
        AgentAttachmentCommand(verb: verb, target: target)
      })
  }
}

// MARK: - Target

/// The live objects of one attachment scope.
///
/// The mount of an ``AgentAttachmentScope`` keeps the values current. The
/// buttons of ``AttachmentActions`` read the target from the environment and
/// dispatch their verb through ``perform(_:)``, so that a button, the context
/// menu and the palette run the same command.
@MainActor
final class AgentAttachmentTarget {
  /// The service that runs the verbs, or `nil` before the mount gives one.
  var service: (any AttachmentFileService)?

  /// The command system that the scope registered the commands in.
  var system: CommandSystem?

  /// The path of the scope in ``system``.
  var path: FocusPath?

  /// Makes a target with no service.
  init() {}

  /// Dispatches `verb` through the registry of the scope.
  ///
  /// - Parameter verb: The verb to run.
  /// - Returns: `true` when a command ran. `false` when the scope has no
  ///   system, or when the command is not available.
  @discardableResult
  func perform(_ verb: AgentAttachmentVerb) -> Bool {
    AgentCommandDispatch.perform(verb.id, in: system, at: path)
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
  static func register(
    _ target: AgentAttachmentTarget, at path: FocusPath, into registry: inout CommandRegistry,
    groupsOff: Set<AgentCommandGroup> = []
  ) {
    let definitions = AgentAttachmentVerb.allCases.map { verb in
      AgentCommandRegistration.GroupedDefinition(
        group: verb.group, definition: AgentAttachmentCommand.definition(of: verb, for: target))
    }
    AgentCommandRegistration.register(definitions, at: path, into: &registry, groupsOff: groupsOff)
  }

  /// Removes each attachment command at `path`, and the `.host` part of the
  /// node that ``register(_:at:into:groupsOff:)`` wrote.
  ///
  /// The `.scope` part of the node stays: the beacon of the scope removes it
  /// when its view goes away.
  ///
  /// - Parameters:
  ///   - path: The path of the scope.
  ///   - registry: The registry to remove the commands from.
  static func deregister(at path: FocusPath, from registry: inout CommandRegistry) {
    for verb in AgentAttachmentVerb.allCases {
      registry.unregister(verb.id, at: path)
    }
    registry.tree = registry.tree.removing(.host, at: path)
  }
}
