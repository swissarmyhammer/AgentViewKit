import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The controls for the config options of a session, grouped by category
/// (plan.md §3.2 "Last-value state", §9 D, §11 decision 16).
///
/// The view reads `SessionModel.configOptions` (the ACP
/// `SessionConfigOption` values) in its body. It keeps no copy of the
/// options and no selected value of its own. When the agent sends a
/// `config_option_update`, the view shows the new values with no user step.
/// When `configOptions` is `nil` or empty, the view is empty.
///
/// The view puts the options in one section for each category, in this
/// order: mode, model, thought level, model config, then the options with no
/// category. An option with a category that the kit does not know is in the
/// last section. A select option shows as a `Picker`. When the choices of the
/// option are in groups, the picker has one section for each group, with the
/// group name as its header. A boolean option shows as a `Toggle`. The kit
/// cannot show an option of a type that it does not know, so the view does
/// not show it.
///
/// Each change calls `SessionModel.setConfigOption(_:)`, which sends
/// `session/set_config_option`. The call returns nothing: the control keeps
/// the value of the model, and shows the new value when the agent reports it
/// in a later `config_option_update`. A failed call adds an error entry to
/// the transcript.
///
/// ``Style/menu`` shows the sections in a menu for a toolbar.
/// ``Style/form`` shows the sections in a `Form` for a settings sheet.
public struct ConfigOptionsView: View {
  /// The presentation of a ``ConfigOptionsView``.
  public enum Style: Sendable, Hashable {
    /// A menu button for a toolbar. The sections are in the menu.
    case menu

    /// A form for a settings sheet. Each select shows its choices in the
    /// form, so that the user sees each choice without a menu.
    case form
  }

  /// The options of one category, in the order of the agent.
  public struct CategorySection: Sendable, Hashable, Identifiable {
    /// The category of the options, or `nil` for the options with no
    /// category that the kit knows.
    public let category: SessionConfigOptionCategory?

    /// The options of the category, in the order of the agent.
    public let options: [SessionConfigOption]

    /// The identifier of the section: the wire value of the category, or
    /// ``ConfigOptionsView/uncategorizedSectionID``.
    public var id: String {
      category?.wireValue ?? ConfigOptionsView.uncategorizedSectionID
    }

    /// The header of the section.
    public var title: String {
      switch category {
      case .mode: String(localized: "Mode")
      case .model: String(localized: "Model")
      case .thoughtLevel: String(localized: "Thought Level")
      case .modelConfig: String(localized: "Model Settings")
      case .unknown, nil: String(localized: "Other")
      }
    }
  }

  /// The accessibility identifier of the form of ``Style/form``.
  public static let viewIdentifier = "config-options"

  /// The accessibility identifier of the menu button of ``Style/menu``.
  public static let menuIdentifier = "config-options-menu"

  /// The start of the accessibility identifier of each control.
  public static let controlIdentifierPrefix = "config-option-"

  /// The start of the accessibility identifier of each category section.
  public static let sectionIdentifierPrefix = "config-section-"

  /// The text between the control identifier and the group id in the
  /// accessibility identifier of a choice group picker.
  public static let groupIdentifierInfix = "-group-"

  /// The text between the control identifier and the value id in the
  /// accessibility identifier of a value.
  public static let choiceIdentifierInfix = "-value-"

  /// The ``CategorySection/id`` of the section of options with no category
  /// that the kit knows.
  public static let uncategorizedSectionID = "uncategorized"

  /// The categories in the order of their sections.
  public static let categoryOrder: [SessionConfigOptionCategory] = [
    .mode, .model, .thoughtLevel, .modelConfig,
  ]

  /// The SF Symbol of the menu button.
  static let menuSymbolName = "slider.horizontal.3"

  /// The session model whose options the view shows.
  let session: SessionModel

  /// The presentation of the view.
  let style: Style

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - session: The session model whose options the view shows.
  ///   - style: The presentation of the view.
  public init(session: SessionModel, style: Style = .menu) {
    self.session = session
    self.style = style
  }

  // MARK: - Identifiers

  /// The accessibility identifier of the control of an option.
  ///
  /// - Parameter id: The id of the option.
  /// - Returns: The identifier, such as `config-option-model`.
  public static func controlIdentifier(for id: SessionConfigId) -> String {
    AccessibilityIdentifier.make(prefix: controlIdentifierPrefix, value: id.rawValue)
  }

  /// The accessibility identifier of the picker of a choice group in
  /// ``Style/form``.
  ///
  /// - Parameters:
  ///   - id: The id of the select option.
  ///   - groupID: The `groupId` of the group.
  /// - Returns: The identifier, such as `config-option-model-group-fast`.
  public static func groupIdentifier(for id: SessionConfigId, groupID: String) -> String {
    controlIdentifier(for: id, infix: groupIdentifierInfix, suffix: groupID)
  }

  /// The accessibility identifier of one value of a select option.
  ///
  /// - Parameters:
  ///   - id: The id of the select option.
  ///   - value: The `value` id of the choice.
  /// - Returns: The identifier, such as `config-option-model-value-fast-1`.
  public static func choiceIdentifier(for id: SessionConfigId, value: String) -> String {
    controlIdentifier(for: id, infix: choiceIdentifierInfix, suffix: value)
  }

  /// The accessibility identifier of a part of the control of an option.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - infix: The text between the control identifier and `suffix`.
  ///   - suffix: The id of the part.
  /// - Returns: The control identifier, then `infix`, then `suffix`.
  private static func controlIdentifier(
    for id: SessionConfigId,
    infix: String,
    suffix: String
  ) -> String {
    controlIdentifier(for: id) + infix + suffix
  }

  /// The accessibility identifier of the header of a category section.
  ///
  /// - Parameter section: The section.
  /// - Returns: The identifier, such as `config-section-model`.
  public static func sectionIdentifier(for section: CategorySection) -> String {
    AccessibilityIdentifier.make(prefix: sectionIdentifierPrefix, value: section.id)
  }

  // MARK: - Grouping

  /// Tells if the view can show an option.
  ///
  /// - Parameter option: The option.
  /// - Returns: `true` for a boolean option, and for a select option whose
  ///   choices the kit can read.
  public static func isShown(_ option: SessionConfigOption) -> Bool {
    switch option.type {
    case .select(let select): select.choices != nil
    case .boolean: true
    case .unknown: false
    }
  }

  /// Puts the options that the view can show in category sections.
  ///
  /// - Parameter options: The options, in the order of the agent.
  /// - Returns: One section for each category that has an option, in the
  ///   order of ``categoryOrder``, then one section for the other options.
  ///   The options of a section keep the order of the agent.
  public static func sections(for options: [SessionConfigOption]) -> [CategorySection] {
    let shown = options.filter(isShown)
    var sections = categoryOrder.compactMap { category -> CategorySection? in
      let members = shown.filter { $0.category == category }
      return members.isEmpty ? nil : CategorySection(category: category, options: members)
    }
    let others = shown.filter { option in
      guard let category = option.category else { return true }
      return !categoryOrder.contains(category)
    }
    if !others.isEmpty {
      sections.append(CategorySection(category: nil, options: others))
    }
    return sections
  }

  // MARK: - Body

  public var body: some View {
    let sections = Self.sections(for: session.configOptions ?? [])
    if !sections.isEmpty {
      content(sections)
    }
  }

  /// The sections in the presentation of ``style``.
  ///
  /// - Parameter sections: The sections to show.
  /// - Returns: The menu or the form.
  @ViewBuilder
  private func content(_ sections: [CategorySection]) -> some View {
    switch style {
    case .menu:
      Menu(String(localized: "Session Options"), systemImage: Self.menuSymbolName) {
        sectionList(sections, inlineChoices: false)
      }
      .accessibilityIdentifier(Self.menuIdentifier)
    case .form:
      Form {
        sectionList(sections, inlineChoices: true)
      }
      .formStyle(.grouped)
      .accessibilityIdentifier(Self.viewIdentifier)
    }
  }

  /// One section for each category, with its controls.
  ///
  /// - Parameters:
  ///   - sections: The sections to show.
  ///   - inlineChoices: Whether each select shows its choices in place.
  /// - Returns: The sections.
  private func sectionList(_ sections: [CategorySection], inlineChoices: Bool) -> some View {
    ForEach(sections) { section in
      Section {
        ForEach(section.options, id: \.configId) { option in
          ConfigOptionControl(option: option, session: session, inlineChoices: inlineChoices)
        }
      } header: {
        Text(section.title)
          .accessibilityIdentifier(Self.sectionIdentifier(for: section))
      }
    }
  }
}

/// The control of one ACP `SessionConfigOption`: a `Picker` for a select and
/// a `Toggle` for a boolean.
struct ConfigOptionControl: View {
  /// The option to show, as the session model holds it.
  let option: SessionConfigOption

  /// The session model that gets each change.
  let session: SessionModel

  /// Whether a select shows its choices in place, and not in a menu.
  let inlineChoices: Bool

  var body: some View {
    switch option.type {
    case .select(let select):
      if let choices = select.choices {
        picker(current: select.currentValue, choices: choices)
      }
    case .boolean(let boolean):
      Toggle(option.name, isOn: binding(boolean.currentValue, send: SetSessionConfigOptionRequest.Value.boolean))
        .toggleStyle(.checkbox)
        .help(option.description ?? option.name)
        .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.configId))
    case .unknown:
      EmptyView()
    }
  }

  /// The picker of a select option.
  ///
  /// - Parameters:
  ///   - current: The id of the selected value.
  ///   - choices: The values that the user can select.
  /// - Returns: The picker. It has one section for each group of `choices`.
  @ViewBuilder
  private func picker(current: SessionConfigValueId, choices: ConfigSelectChoices) -> some View {
    let selection = binding(current, send: SetSessionConfigOptionRequest.Value.id)
    switch (choices, inlineChoices) {
    case (.flat(let values), true):
      Picker(option.name, selection: selection) {
        choiceRows(values, tag: { $0 })
      }
      .pickerStyle(.inline)
      .help(option.description ?? option.name)
      .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.configId))
    case (.grouped(let groups), true):
      inlineGroups(groups, current: current, selection: selection)
    case (.flat(let values), false):
      Picker(option.name, selection: selection) {
        choiceRows(values, tag: { $0 })
      }
      .pickerStyle(.menu)
      .help(option.description ?? option.name)
      .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.configId))
    case (.grouped(let groups), false):
      Picker(option.name, selection: selection) {
        ForEach(groups, id: \.groupId) { group in
          Section(group.name) {
            choiceRows(group.options, tag: { $0 })
          }
        }
      }
      .pickerStyle(.menu)
      .help(option.description ?? option.name)
      .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.configId))
    }
  }

  /// The groups of a select option, with their values in place.
  ///
  /// An inline picker shows the header of a `Section` as a value that the
  /// user can select. Thus each group is an inline picker of its own, with
  /// the group name as its label. The picker of a group selects nothing when
  /// the current value is in another group.
  ///
  /// - Parameters:
  ///   - groups: The groups of values.
  ///   - current: The id of the selected value.
  ///   - selection: The binding of the option.
  /// - Returns: The label of the option and one picker for each group.
  private func inlineGroups(
    _ groups: [SessionConfigSelectGroup],
    current: SessionConfigValueId,
    selection: Binding<SessionConfigValueId>
  ) -> some View {
    VStack(alignment: .leading) {
      Text(option.name)
      ForEach(groups, id: \.groupId) { group in
        let groupSelection = Binding<SessionConfigValueId?>(
          get: { group.options.contains { $0.value == current } ? current : nil },
          set: { newValue in
            if let newValue {
              selection.wrappedValue = newValue
            }
          })
        Picker(group.name, selection: groupSelection) {
          choiceRows(group.options, tag: Optional.some)
        }
        .pickerStyle(.inline)
        .accessibilityIdentifier(
          ConfigOptionsView.groupIdentifier(for: option.configId, groupID: group.groupId.rawValue))
      }
    }
    .help(option.description ?? option.name)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.configId))
  }

  /// One tagged row for each value.
  ///
  /// - Parameters:
  ///   - values: The values that the user can select.
  ///   - tag: The function that makes the tag of a value id.
  /// - Returns: The rows.
  private func choiceRows<Tag: Hashable>(
    _ values: [SessionConfigSelectOption],
    tag: @escaping (SessionConfigValueId) -> Tag
  ) -> some View {
    ForEach(values, id: \.value) { value in
      Text(value.name)
        .tag(tag(value.value))
        .accessibilityIdentifier(
          ConfigOptionsView.choiceIdentifier(for: option.configId, value: value.value.rawValue))
    }
  }

  /// A binding for the control of ``option``.
  ///
  /// - Parameters:
  ///   - current: The value that the session model holds.
  ///   - send: The function that makes the request value of a new value.
  /// - Returns: The binding from `SessionModel.makeConfigBinding(for:current:send:)`.
  private func binding<Value: Equatable>(
    _ current: Value,
    send: @escaping (Value) -> SetSessionConfigOptionRequest.Value
  ) -> Binding<Value> {
    session.makeConfigBinding(for: option.configId, current: current, send: send)
  }
}
