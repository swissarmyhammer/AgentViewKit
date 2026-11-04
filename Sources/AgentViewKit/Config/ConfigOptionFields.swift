import EditorCommandsUI
import EditorInspector
import FoundationModelsACP
import FoundationModelsACPClient

/// One value of a select config option, as the picker of an inspector row
/// shows it.
///
/// The picker of an `EditorInspector` row shows the description of each
/// choice, so the description is the name of the value, with the name of its
/// group when the values of the option are in groups.
nonisolated struct ConfigChoice: Hashable, Sendable, CustomStringConvertible {
  /// The id of the value, which `session/set_config_option` sends.
  let value: SessionConfigValueId

  /// The name of the value that the picker shows.
  let description: String

  /// The choice of a row whose option the session no longer reports.
  static let missing = ConfigChoice(
    value: SessionConfigValueId(rawValue: ""), description: String(localized: "None", bundle: .module))

  /// The choices of a select option, in the order of the agent. The choices
  /// of a group follow the choices of the group before it.
  ///
  /// - Parameter choices: The values of the select option.
  /// - Returns: One choice for each value.
  static func choices(of choices: ConfigSelectChoices) -> [ConfigChoice] {
    switch choices {
    case .flat(let values):
      values.map { ConfigChoice(value: $0.value, description: $0.name) }
    case .grouped(let groups):
      groups.flatMap { group in
        group.options.map { value in
          ConfigChoice(
            value: value.value, description: String(localized: "\(value.name) (\(group.name))", bundle: .module))
        }
      }
    }
  }
}

/// The values that the inspector rows of ``ConfigOptionsView`` read from the
/// config options of a session, and the inspection of those rows.
///
/// Each get block reads `SessionModel.configOptions` when the row draws, so a
/// `config_option_update` of the agent redraws the row. Each edit block sends
/// `session/set_config_option` and keeps no copy of the value: the row shows
/// the new value when the agent reports it.
enum ConfigOptionFields {
  /// The option of `id`, or `nil` when the options have none.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - options: The options of the session.
  /// - Returns: The option.
  private static func option(_ id: SessionConfigId, in options: [SessionConfigOption]) -> SessionConfigOption? {
    options.first { $0.configId == id }
  }

  /// The select of the option of `id`, or `nil` when the option is not a
  /// select.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - options: The options of the session.
  /// - Returns: The select.
  private static func select(_ id: SessionConfigId, in options: [SessionConfigOption]) -> SessionConfigSelect? {
    guard case .select(let select)? = option(id, in: options)?.type else { return nil }
    return select
  }

  /// The choices of the select option of `id`.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - options: The options of the session.
  /// - Returns: The choices, or none when the option is not a select whose
  ///   values the kit can read.
  static func choices(of id: SessionConfigId, in options: [SessionConfigOption]) -> [ConfigChoice] {
    select(id, in: options)?.choices.map(ConfigChoice.choices(of:)) ?? []
  }

  /// The current choice of the select option of `id`.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - options: The options of the session.
  /// - Returns: The choice of the current value, or `nil` when the option
  ///   is not a select or its current value is none of its choices.
  static func choice(of id: SessionConfigId, in options: [SessionConfigOption]) -> ConfigChoice? {
    guard let current = select(id, in: options)?.currentValue else { return nil }
    return choices(of: id, in: options).first { $0.value == current }
  }

  /// The current value of the boolean option of `id`.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - options: The options of the session.
  /// - Returns: The value, or `nil` when the option is not a boolean.
  static func isOn(_ id: SessionConfigId, in options: [SessionConfigOption]) -> Bool? {
    guard case .boolean(let boolean)? = option(id, in: options)?.type else { return nil }
    return boolean.currentValue
  }

  // MARK: - Inspection

  /// The inspection of the options of `sections`: one group for each
  /// category section, with one row for each option.
  ///
  /// - Parameters:
  ///   - title: The title of the block.
  ///   - sections: The category sections of the options.
  ///   - report: The report that gets `session/set_config_option` when an
  ///     edit starts a request, or `nil`.
  /// - Returns: The inspection.
  static func inspection(
    title: String, sections: [ConfigOptionsView.CategorySection], reporting report: ObservationReport<String>?
  ) -> Inspection<SessionModel> {
    Inspection(title: title) {
      for section in sections {
        FieldGroup(section.title) {
          for option in section.options {
            if let field = selectField(option, reporting: report) { field }
            if let field = booleanField(option, reporting: report) { field }
          }
        }
        .identifier(section.id)
      }
    }
  }

  /// The picker row of a select option, or `nil` for another type.
  ///
  /// - Parameters:
  ///   - option: The option.
  ///   - report: The report of the request that an edit starts, or `nil`.
  /// - Returns: The row.
  private static func selectField(
    _ option: SessionConfigOption, reporting report: ObservationReport<String>?
  ) -> Field<SessionModel, ConfigChoice>? {
    guard case .select = option.type else { return nil }
    let id = option.configId
    return Field(option.name) { session in choice(of: id, in: session.configOptions ?? []) ?? .missing }
      .choices { session in choices(of: id, in: session.configOptions ?? []) }
      .editing { session, choice in
        session.startSetConfigOption(id, to: .id(choice.value), reporting: report)
      }
      .help(option.description ?? option.name)
      .identifier(id.rawValue)
  }

  /// The toggle row of a boolean option, or `nil` for another type.
  ///
  /// - Parameters:
  ///   - option: The option.
  ///   - report: The report of the request that an edit starts, or `nil`.
  /// - Returns: The row.
  private static func booleanField(
    _ option: SessionConfigOption, reporting report: ObservationReport<String>?
  ) -> Field<SessionModel, Bool>? {
    guard case .boolean = option.type else { return nil }
    let id = option.configId
    return Field(option.name) { session in isOn(id, in: session.configOptions ?? []) ?? false }
      .editing { session, isOn in
        session.startSetConfigOption(id, to: .boolean(isOn), reporting: report)
      }
      .help(option.description ?? option.name)
      .identifier(id.rawValue)
  }
}
