import EditorCommandsUI
import EditorInspector
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient

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

  /// The options of the `ChoiceField` of the select option of `id`.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - options: The options of the session.
  /// - Returns: One option for each value, or none when the option is not a
  ///   select whose values the kit can read.
  static func options(
    of id: SessionConfigId, in options: [SessionConfigOption]
  ) -> [ChoiceOption<SessionConfigValueId>] {
    select(id, in: options)?.choices?.choiceOptions ?? []
  }

  /// The current value of the select option of `id`.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - options: The options of the session.
  /// - Returns: The id of the value, or `nil` when the option is not a
  ///   select.
  static func value(of id: SessionConfigId, in options: [SessionConfigOption]) -> SessionConfigValueId? {
    select(id, in: options)?.currentValue
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
        FieldGroup(.verbatim(section.title)) {
          for option in section.options {
            if let field = selectField(option, reporting: report) { field }
            if let field = booleanField(option, reporting: report) { field }
          }
        }
        .identifier(section.id)
      }
    }
  }

  /// The value of a row whose option the session no longer reports. No
  /// option of the row has it, so the row shows no choice until the
  /// inspection drops the row.
  private static let goneValue = SessionConfigValueId(rawValue: "")

  /// The choice row of a select option, or `nil` for another type.
  ///
  /// - Parameters:
  ///   - option: The option.
  ///   - report: The report of the request that an edit starts, or `nil`.
  /// - Returns: The row.
  private static func selectField(
    _ option: SessionConfigOption, reporting report: ObservationReport<String>?
  ) -> Field<SessionModel, SessionConfigValueId>? {
    guard case .select = option.type else { return nil }
    let id = option.configId
    return Field(.verbatim(option.name)) { session in value(of: id, in: session.configOptions ?? []) ?? goneValue }
      .options { session in options(of: id, in: session.configOptions ?? []) }
      .editing { session, value in
        session.startSetConfigOption(id, to: .id(value), reporting: report)
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
    return Field(.verbatim(option.name)) { session in isOn(id, in: session.configOptions ?? []) ?? false }
      .editing { session, isOn in
        session.startSetConfigOption(id, to: .boolean(isOn), reporting: report)
      }
      .help(option.description ?? option.name)
      .identifier(id.rawValue)
  }
}
