import EditorCommands

/// How a command of the kit shows in the surfaces of EditorKit: its id, its
/// titles, its icon, its places in the menus and its key.
///
/// Each verb of the kit gives one presentation.
/// `CommandDefinition.init(_:target:isVisible:make:)` makes the EditorKit
/// definition of the verb from it, so all the verbs of the kit get their
/// definitions in one way.
nonisolated struct AgentCommandPresentation: Sendable {
  /// The command id of the verb, `agent.<verb>`.
  let id: CommandID

  /// The title that the menus and the palette show.
  let title: String

  /// The title that a command button shows, or `nil` for ``title``.
  var buttonTitle: String?

  /// The SF Symbol of the verb, or `nil` for no icon.
  let icon: String?

  /// The place of the verb in the menu bar, or `nil` for no menu.
  let menu: MenuPlacement?

  /// The place of the verb in the context menu, or `nil` for no context
  /// menu.
  let contextMenu: ContextMenuPlacement?

  /// The CUA key of the verb, or `nil` for no key.
  var key: KeyChord?
}

/// The definition of a kit verb from its presentation.
extension CommandDefinition {
  /// Makes the EditorKit definition of a kit verb from its presentation.
  ///
  /// The definition holds `target` weakly, so a registry that outlives the
  /// scope of the target does not keep the target. The key of the
  /// presentation is the key of the CUA keymap.
  ///
  /// - Parameters:
  ///   - presentation: The presentation of the verb.
  ///   - target: The target of the scope that registers the definition.
  ///   - isVisible: Tells if the command shows in a surface. The default
  ///     shows the command in each surface.
  ///   - make: Makes the command from the target, or `nil` when the target
  ///     is gone, and the payload of the invocation.
  nonisolated init<Target: AnyObject & Sendable>(
    _ presentation: AgentCommandPresentation, target: Target,
    isVisible: @escaping @Sendable (CommandContext) -> Bool = { _ in true },
    make: @escaping @Sendable (_ target: Target?, _ payload: CommandPayload?) -> any Command
  ) {
    var keys: [KeymapMode: KeyChord] = [:]
    keys[.cua] = presentation.key
    self.init(
      id: presentation.id,
      title: .static(presentation.title),
      buttonTitle: presentation.buttonTitle.map(CommandTitle.static),
      icon: presentation.icon,
      menu: presentation.menu,
      contextMenu: presentation.contextMenu,
      keys: keys,
      isVisible: isVisible,
      make: { [weak target] payload in make(target, payload) })
  }
}
