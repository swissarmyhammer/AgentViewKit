import FoundationModelsACP

/// How `PermissionView` shows the ACP options of a pending permission request,
/// and when it offers to switch the session to auto mode (plan.md §9 E, §14,
/// R8).
///
/// `Docs/decisions/permission-ux.md` records the survey of Claude Code,
/// Cursor, and Codex, and the two decision tables. `PermissionPresentationTests`
/// parses those tables and compares each row with this type.
///
/// This type records a design decision. It holds no state.
public nonisolated enum PermissionPresentation {
  /// The `mode` choice id of auto mode. Claude Code uses this id for the
  /// mode in which a classifier model reviews most actions.
  public static let autoModeID = "auto"

  /// The `mode` choice id of plan mode. In plan mode the user approves a
  /// plan, not a single command, so the card does not offer auto mode.
  public static let planModeID = "plan"

  /// The value that the switch-to-auto action sends for the
  /// `SessionConfigOption` that ``autoModeOption(in:)`` gives.
  public static let autoModeValue = SetSessionConfigOptionRequest.Value.id(
    SessionConfigValueId(rawValue: autoModeID))

  /// The known kinds in the order that the card shows them.
  ///
  /// The one-time answers come first in each pair, as the prompts of Claude
  /// Code and Codex show them.
  private static let displayOrder: [PermissionOptionKind] = [
    .allowOnce, .allowAlways, .rejectOnce, .rejectAlways,
  ]

  /// The position of the first kind in ``displayOrder``. The decision table
  /// counts from one.
  private static let firstPosition = 1

  /// Gives the place of a kind on the card.
  ///
  /// - Parameter kind: The kind of an option.
  /// - Returns: The position that the decision table gives the kind. Each
  ///   unknown kind has the position after the last known kind.
  public static func position(of kind: PermissionOptionKind) -> Int {
    let index = displayOrder.firstIndex(of: kind) ?? displayOrder.endIndex
    return index + firstPosition
  }

  /// Puts the kinds of the options of a request in the order that the card
  /// shows them.
  ///
  /// The sort of the Swift standard library is stable, so kinds with the
  /// same position, such as two unknown kinds, keep the order of the
  /// request. The result keeps each repeated kind.
  ///
  /// - Parameter kinds: The kinds, in the order of the request.
  /// - Returns: The same kinds, sorted by ``position(of:)``.
  public static func order(for kinds: [PermissionOptionKind]) -> [PermissionOptionKind] {
    sorted(items: kinds) { $0 }
  }

  /// Puts the options of a request in the order that the card shows them.
  ///
  /// The sort is the same as the sort of the kinds: it uses the kind of each
  /// option, and it is stable. `PermissionView` shows its buttons in this
  /// order.
  ///
  /// - Parameter options: The ACP options, in the order of the request.
  /// - Returns: The same options, sorted by the ``position(of:)`` of their
  ///   kinds.
  public static func order(
    of options: [FoundationModelsACP.PermissionOption]
  ) -> [FoundationModelsACP.PermissionOption] {
    sorted(items: options, by: \.kind)
  }

  /// Puts the options of a kit request of the old thread path in the order
  /// that the card shows them.
  ///
  /// `AgentCommandTarget` answers the requests of `AgentThread` with this
  /// order. The function goes away with the kit request types.
  ///
  /// - Parameter options: The kit options, in the order of the request.
  /// - Returns: The same options, in the order that the card gives the ACP
  ///   options of the same kinds.
  static func order(of options: [AgentViewKit.PermissionOption]) -> [AgentViewKit.PermissionOption] {
    sorted(items: options) { PermissionOptionKind(wireValue: $0.kind.wireValue) }
  }

  /// Sorts items by the ``position(of:)`` of their kinds. The sort is stable.
  ///
  /// - Parameters:
  ///   - items: The items, in the order of the request.
  ///   - kind: Gives the kind of an item.
  /// - Returns: The same items in the order of the card.
  private static func sorted<Item>(items: [Item], by kind: (Item) -> PermissionOptionKind) -> [Item] {
    items.sorted { position(of: kind($0)) < position(of: kind($1)) }
  }

  /// Tells if the card shows an option with less visual weight.
  ///
  /// The one-time answers are the primary buttons. A kept answer changes
  /// later prompts too, so the user must select it on purpose. A kind that
  /// the kit does not know, such as a directory-scoped grant from a source,
  /// is also secondary.
  ///
  /// - Parameter kind: The kind of an option.
  /// - Returns: `true` when the option is secondary.
  public static func isSecondary(kind: PermissionOptionKind) -> Bool {
    switch kind {
    case .allowOnce, .rejectOnce: false
    case .allowAlways, .rejectAlways, .unknown: true
    }
  }

  /// Tells if the card offers the "switch to auto" action.
  ///
  /// - Parameter configOptions: The config options of the session model.
  /// - Returns: `true` when ``autoModeOption(in:)`` gives an option.
  public static func showsSwitchToAuto(configOptions: [SessionConfigOption]) -> Bool {
    autoModeOption(in: configOptions) != nil
  }

  /// Gives the config option that the "switch to auto" action sets.
  ///
  /// The first option of the `mode` category decides. The action is
  /// available when that option is a select, one of its values has the id
  /// ``autoModeID``, and the current value is not ``autoModeID`` or
  /// ``planModeID``.
  ///
  /// - Parameter configOptions: The config options of the session model.
  /// - Returns: The mode option, or `nil` when the card must not offer the
  ///   action.
  public static func autoModeOption(in configOptions: [SessionConfigOption]) -> SessionConfigOption? {
    guard let option = configOptions.first(where: { $0.category == .mode }),
      case .select(let select) = option.type,
      select.currentValue.rawValue != autoModeID,
      select.currentValue.rawValue != planModeID,
      let choices = select.choices,
      choices.options.contains(where: { $0.value.rawValue == autoModeID })
    else { return nil }
    return option
  }
}
