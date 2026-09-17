/// How `PermissionView` shows the options of a ``PermissionRequest``, and when
/// it offers to switch the session to auto mode (plan.md §9 E, §14, R8).
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

  /// The value that the switch-to-auto action sends to the ``ConfigOption``
  /// that ``autoModeOption(in:)`` gives.
  public static let autoModeValue = ConfigValue.id(autoModeID)

  /// The known kinds in the order that the card shows them.
  ///
  /// The one-time answers come first in each pair, as the prompts of Claude
  /// Code and Codex show them.
  private static let displayOrder: [PermissionOption.Kind] = [
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
  public static func position(of kind: PermissionOption.Kind) -> Int {
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
  public static func order(for kinds: [PermissionOption.Kind]) -> [PermissionOption.Kind] {
    kinds.sorted { position(of: $0) < position(of: $1) }
  }

  /// Puts the options of a request in the order that the card shows them.
  ///
  /// The sort is the same as the sort of the kinds: it uses the kind of each
  /// option, and it is stable. `PermissionView` shows its buttons in this
  /// order.
  ///
  /// - Parameter options: The options, in the order of the request.
  /// - Returns: The same options, sorted by the ``position(of:)`` of their
  ///   kinds.
  public static func order(of options: [PermissionOption]) -> [PermissionOption] {
    options.sorted { position(of: $0.kind) < position(of: $1.kind) }
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
  public static func isSecondary(_ kind: PermissionOption.Kind) -> Bool {
    switch kind {
    case .allowOnce, .rejectOnce: false
    case .allowAlways, .rejectAlways, .unknown: true
    }
  }

  /// Tells if the card offers the "switch to auto" action.
  ///
  /// - Parameter configOptions: The config options of the session.
  /// - Returns: `true` when ``autoModeOption(in:)`` gives an option.
  public static func showsSwitchToAuto(configOptions: [ConfigOption]) -> Bool {
    autoModeOption(in: configOptions) != nil
  }

  /// Gives the config option that the "switch to auto" action sets.
  ///
  /// The first option of the `mode` category decides. The action is
  /// available when that option is a select, one of its choices has the id
  /// ``autoModeID``, and the current value is not ``autoModeID`` or
  /// ``planModeID``.
  ///
  /// - Parameter configOptions: The config options of the session.
  /// - Returns: The mode option, or `nil` when the card must not offer the
  ///   action.
  public static func autoModeOption(in configOptions: [ConfigOption]) -> ConfigOption? {
    guard let option = configOptions.first(where: { $0.category == .mode }),
      case .select(let current, let choices) = option.kind,
      current != autoModeID,
      current != planModeID,
      choices.options.contains(where: { $0.id == autoModeID })
    else { return nil }
    return option
  }
}
