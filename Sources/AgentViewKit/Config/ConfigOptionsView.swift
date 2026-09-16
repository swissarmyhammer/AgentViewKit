import SwiftUI

/// The controls for the session options of a thread, grouped by category
/// (plan.md §9 D, §11 decision 16).
///
/// Pass ``AgentThread/configOptions`` as `options`. The view reads the list
/// in its body, so a host view that reads the thread updates the view when a
/// source replaces the list.
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
/// Each change calls ``AgentThreadActions/setConfigOption(_:_:)`` of the
/// `threadActions` environment value. The control shows the value that the
/// source gives. It shows the new value when the source replaces the list.
///
/// ``Style/menu`` shows the sections in a menu for a toolbar.
/// ``Style/form`` shows the sections in a `Form` for a settings sheet. When
/// the list has no option that the view can show, the view is empty.
public struct ConfigOptionsView: View {
  /// The presentation of a ``ConfigOptionsView``.
  public enum Style: Sendable, Hashable {
    /// A menu button for a toolbar. The sections are in the menu.
    case menu

    /// A form for a settings sheet. Each select shows its choices in the
    /// form, so that the user sees each choice without a menu.
    case form
  }

  /// The options of one category, in the order of the source.
  public struct CategorySection: Sendable, Hashable, Identifiable {
    /// The category of the options, or `nil` for the options with no
    /// category that the kit knows.
    public let category: ConfigOption.Category?

    /// The options of the category, in the order of the source.
    public let options: [ConfigOption]

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
  public static let categoryOrder: [ConfigOption.Category] = [
    .mode, .model, .thoughtLevel, .modelConfig,
  ]

  /// The SF Symbol of the menu button.
  static let menuSymbolName = "slider.horizontal.3"

  /// The options to show.
  let options: [ConfigOption]

  /// The presentation of the view.
  let style: Style

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - options: The options to show, such as ``AgentThread/configOptions``.
  ///   - style: The presentation of the view.
  public init(options: [ConfigOption], style: Style = .menu) {
    self.options = options
    self.style = style
  }

  // MARK: - Identifiers

  /// The accessibility identifier of the control of an option.
  ///
  /// - Parameter id: The identifier of the option.
  /// - Returns: The identifier, such as `config-option-model`.
  public static func controlIdentifier(for id: ConfigOptionID) -> String {
    controlIdentifierPrefix + id.rawValue
  }

  /// The accessibility identifier of the picker of a choice group in
  /// ``Style/form``.
  ///
  /// - Parameters:
  ///   - id: The identifier of the select option.
  ///   - groupID: The ``SelectGroup/id`` of the group.
  /// - Returns: The identifier, such as `config-option-model-group-fast`.
  public static func groupIdentifier(for id: ConfigOptionID, groupID: String) -> String {
    controlIdentifier(for: id, infix: groupIdentifierInfix, suffix: groupID)
  }

  /// The accessibility identifier of one value of a select option.
  ///
  /// - Parameters:
  ///   - id: The identifier of the select option.
  ///   - value: The ``SelectOption/id`` of the value.
  /// - Returns: The identifier, such as `config-option-model-value-fast-1`.
  public static func choiceIdentifier(for id: ConfigOptionID, value: String) -> String {
    controlIdentifier(for: id, infix: choiceIdentifierInfix, suffix: value)
  }

  /// The accessibility identifier of a part of the control of an option.
  ///
  /// - Parameters:
  ///   - id: The identifier of the option.
  ///   - infix: The text between the control identifier and `suffix`.
  ///   - suffix: The id of the part.
  /// - Returns: The control identifier, then `infix`, then `suffix`.
  private static func controlIdentifier(
    for id: ConfigOptionID,
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
    sectionIdentifierPrefix + section.id
  }

  // MARK: - Grouping

  /// Tells if the view can show an option.
  ///
  /// - Parameter option: The option.
  /// - Returns: `true` for a select option and a boolean option.
  public static func isShown(_ option: ConfigOption) -> Bool {
    switch option.kind {
    case .select, .boolean: true
    case .unknown: false
    }
  }

  /// Puts the options that the view can show in category sections.
  ///
  /// - Parameter options: The options, in the order of the source.
  /// - Returns: One section for each category that has an option, in the
  ///   order of ``categoryOrder``, then one section for the other options.
  ///   The options of a section keep the order of the source.
  public static func sections(for options: [ConfigOption]) -> [CategorySection] {
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
    let sections = Self.sections(for: options)
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
        ForEach(section.options) { option in
          ConfigOptionControl(option: option, inlineChoices: inlineChoices)
        }
      } header: {
        Text(section.title)
          .accessibilityIdentifier(Self.sectionIdentifier(for: section))
      }
    }
  }
}

/// The control of one ``ConfigOption``: a `Picker` for a select and a
/// `Toggle` for a boolean.
struct ConfigOptionControl: View {
  /// The option to show.
  let option: ConfigOption

  /// Whether a select shows its choices in place, and not in a menu.
  let inlineChoices: Bool

  @Environment(\.threadActions) private var actions

  var body: some View {
    switch option.kind {
    case .select(let current, let choices):
      picker(current: current, choices: choices)
    case .boolean(let current):
      Toggle(option.name, isOn: binding(current, send: ConfigValue.boolean))
        .toggleStyle(.checkbox)
        .help(option.description ?? option.name)
        .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.id))
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
  private func picker(current: String, choices: SelectChoices) -> some View {
    let selection = binding(current, send: ConfigValue.id)
    switch (choices, inlineChoices) {
    case (.flat(let values), true):
      Picker(option.name, selection: selection) {
        choiceRows(values, tag: { $0 })
      }
      .pickerStyle(.inline)
      .help(option.description ?? option.name)
      .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.id))
    case (.grouped(let groups), true):
      inlineGroups(groups, current: current, selection: selection)
    case (.flat(let values), false):
      Picker(option.name, selection: selection) {
        choiceRows(values, tag: { $0 })
      }
      .pickerStyle(.menu)
      .help(option.description ?? option.name)
      .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.id))
    case (.grouped(let groups), false):
      Picker(option.name, selection: selection) {
        ForEach(groups) { group in
          Section(group.name) {
            choiceRows(group.options, tag: { $0 })
          }
        }
      }
      .pickerStyle(.menu)
      .help(option.description ?? option.name)
      .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.id))
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
    _ groups: [SelectGroup],
    current: String,
    selection: Binding<String>
  ) -> some View {
    VStack(alignment: .leading) {
      Text(option.name)
      ForEach(groups) { group in
        let groupSelection = Binding<String?>(
          get: { group.options.contains { $0.id == current } ? current : nil },
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
          ConfigOptionsView.groupIdentifier(for: option.id, groupID: group.id))
      }
    }
    .help(option.description ?? option.name)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.id))
  }

  /// One tagged row for each value.
  ///
  /// - Parameters:
  ///   - values: The values that the user can select.
  ///   - tag: The function that makes the tag of a value id.
  /// - Returns: The rows.
  private func choiceRows<Tag: Hashable>(
    _ values: [SelectOption],
    tag: @escaping (String) -> Tag
  ) -> some View {
    ForEach(values) { value in
      Text(value.name)
        .tag(tag(value.id))
        .accessibilityIdentifier(
          ConfigOptionsView.choiceIdentifier(for: option.id, value: value.id))
    }
  }

  /// A binding for the control of ``option``.
  ///
  /// - Parameters:
  ///   - current: The value that the source gives.
  ///   - send: The function that makes the config value of a new value.
  /// - Returns: The binding from ``configOptionBinding(id:current:actions:send:)``.
  private func binding<Value: Equatable>(
    _ current: Value,
    send: @escaping (Value) -> ConfigValue
  ) -> Binding<Value> {
    configOptionBinding(id: option.id, current: current, actions: actions, send: send)
  }
}

/// A binding that shows the value of a config option and sends each new
/// value to the thread actions.
///
/// The binding does not keep the new value. The control shows the new value
/// when the source replaces the option list.
///
/// - Parameters:
///   - id: The identifier of the option.
///   - current: The value that the source gives.
///   - actions: The actions that get the new value.
///   - send: The function that makes the config value of a new value.
/// - Returns: The binding.
func configOptionBinding<Value: Equatable>(
  id: ConfigOptionID,
  current: Value,
  actions: any AgentThreadActions,
  send: @escaping (Value) -> ConfigValue
) -> Binding<Value> {
  Binding(
    get: { current },
    set: { newValue in
      guard newValue != current else { return }
      Task {
        await actions.setConfigOption(id, send(newValue))
      }
    })
}
