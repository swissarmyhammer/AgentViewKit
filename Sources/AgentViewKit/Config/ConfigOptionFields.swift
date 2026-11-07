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

  /// The tooltip of the menu field of `option`: the name of the option,
  /// then its description on the next line when it has one. It is the same
  /// text as the tooltip of an inspector row of the option
  /// (EditorKit `FieldLabel.tooltip(help:)`).
  ///
  /// - Parameter option: The option.
  /// - Returns: The text of the tooltip.
  static func tooltip(of option: SessionConfigOption) -> String {
    FieldLabel.verbatim(option.name).tooltip(help: option.description)
  }

  // MARK: - Inspection

  /// The inspection of the options of `sections`: one group for each
  /// category section, with one row for each option. Its id is the view id
  /// of ``ConfigOptionsView``, `config-options`.
  ///
  /// - Parameters:
  ///   - title: The title of the block.
  ///   - sections: The category sections of the options.
  ///   - report: The report that gets `session/set_config_option` when an
  ///     edit starts a request, or `nil`.
  /// - Returns: The inspection.
  static func inspection(
    title: String, sections: [ConfigOptionsView.CategorySection], reporting report: ObservationReport<String>?
  ) -> Inspection<InspectedClientModel<SessionModel>> {
    Inspection(id: ConfigOptionsView.viewIdentifier, title: title) {
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

  /// The inspector row of one option of the session.
  private typealias OptionField<Value> = Field<InspectedClientModel<SessionModel>, Value>

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
  ) -> OptionField<SessionConfigValueId>? {
    guard case .select = option.type else { return nil }
    let id = option.configId
    let field = OptionField<SessionConfigValueId>(.verbatim(option.name)) {
      value(of: id, in: $0.model.configOptions ?? []) ?? goneValue
    }
    .options { options(of: id, in: $0.model.configOptions ?? []) }
    .editing { inspected, value in
      inspected.model.startSetConfigOption(id, to: .id(value), reporting: report)
    }
    .identifier(id.rawValue)
    return helped(field, by: option)
  }

  /// The toggle row of a boolean option, or `nil` for another type.
  ///
  /// - Parameters:
  ///   - option: The option.
  ///   - report: The report of the request that an edit starts, or `nil`.
  /// - Returns: The row.
  private static func booleanField(
    _ option: SessionConfigOption, reporting report: ObservationReport<String>?
  ) -> OptionField<Bool>? {
    guard case .boolean = option.type else { return nil }
    let id = option.configId
    let field = OptionField<Bool>(.verbatim(option.name)) {
      isOn(id, in: $0.model.configOptions ?? []) ?? false
    }
    .editing { inspected, isOn in
      inspected.model.startSetConfigOption(id, to: .boolean(isOn), reporting: report)
    }
    .identifier(id.rawValue)
    return helped(field, by: option)
  }

  /// Gives `field` the description of `option` as its help, when the option
  /// has one. The tooltip of the row shows the name of the option, then the
  /// help (EditorKit `FieldLabel.tooltip(help:)`), so an option with no
  /// description gets no help, and its tooltip shows its name one time.
  ///
  /// - Parameters:
  ///   - field: The row of the option.
  ///   - option: The option.
  /// - Returns: The row, with the help of the option.
  private static func helped<Value>(_ field: OptionField<Value>, by option: SessionConfigOption) -> OptionField<Value> {
    option.description.map(field.help) ?? field
  }
}
