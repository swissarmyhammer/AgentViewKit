import EditorCommandsUI
import EditorInspector
import EditorStyle
import EditorSwiftUI
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
/// last section. A select option shows as an EditorKit `ChoiceField`. When
/// the choices of the option are in groups, the field has one section for
/// each group, with the group name as its header. A boolean option shows as
/// an EditorKit `ToggleField`. Each value is a named accessibility action of
/// its field, the name of the value. The kit
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
/// ``Style/form`` shows the sections as the content of an inspector: an
/// EditorKit `InspectorView` of the session, with one group for each
/// category and one row for each option, a choice row for a select and a
/// toggle row for a boolean. The view is not `SessionModel.inspection`: the agent names
/// the options of each session, and the inspection of a type is the same for
/// each session, so the form builds its own inspection from the options that
/// the model holds. The rows take EditorKit's accessibility identifiers:
/// ``viewIdentifier``, the id of the category section and the id of the
/// option, such as `config-options.model.model`.
public struct ConfigOptionsView: View {
  /// The presentation of a ``ConfigOptionsView``.
  public enum Style: Sendable, Hashable {
    /// A menu button for a toolbar. The sections are in the menu.
    case menu

    /// The content of an inspector, a panel or a settings sheet: an
    /// EditorKit `InspectorView` with one row for each option.
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
    public var title: String { label.text }

    /// The header of the section as the name of its inspector group, keyed
    /// by its source text in each language.
    var label: FieldLabel {
      switch category {
      case .mode: FieldLabel(localized: "Mode", bundle: .module)
      case .model: FieldLabel(localized: "Model", bundle: .module)
      case .thoughtLevel: FieldLabel(localized: "Thought Level", bundle: .module)
      case .modelConfig: FieldLabel(localized: "Model Settings", bundle: .module)
      case .unknown, nil: FieldLabel(localized: "Other", bundle: .module)
      }
    }
  }

  /// The identifier of the `InspectorView` of ``Style/form``: the first
  /// part of the accessibility identifier of each of its rows.
  public static let viewIdentifier = "config-options"

  /// The accessibility identifier of the menu button of ``Style/menu``.
  public static let menuIdentifier = "config-options-menu"

  /// The start of the accessibility identifier of each control.
  public static let controlIdentifierPrefix = "config-option-"

  /// The start of the accessibility identifier of each category section.
  public static let sectionIdentifierPrefix = "config-section-"

  /// The ``CategorySection/id`` of the section of options with no category
  /// that the kit knows.
  public static let uncategorizedSectionID = "uncategorized"

  /// The categories in the order of their sections.
  public static let categoryOrder: [SessionConfigOptionCategory] = [
    .mode, .model, .thoughtLevel, .modelConfig,
  ]

  /// The SF Symbol of the menu button.
  static let menuSymbolName = SharedSymbol.options

  /// The session model whose options the view shows.
  let session: SessionModel

  /// The presentation of the view.
  let style: Style

  /// The report that gets the method of each request that a row of the
  /// form starts, or `nil`.
  @Environment(\.requestStartReport) private var reportRequestStart

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

  /// The accessibility identifier of the control of an option in the menu of
  /// ``Style/menu``.
  ///
  /// - Parameter id: The id of the option.
  /// - Returns: The identifier, such as `config-option-model`.
  public static func controlIdentifier(for id: SessionConfigId) -> String {
    AccessibilityIdentifier.make(prefix: controlIdentifierPrefix, value: id.rawValue)
  }

  /// The accessibility identifier of the header of a category section in the
  /// menu of ``Style/menu``.
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
      Menu(String(localized: "Session Options", bundle: .module), systemImage: Self.menuSymbolName)
      {
        sectionList(sections)
      }
      .accessibilityIdentifier(Self.menuIdentifier)
    case .form:
      InspectorView(
        session,
        ConfigOptionFields.inspection(title: Self.formTitle, sections: sections, reporting: reportRequestStart),
        id: Self.viewIdentifier)
    }
  }

  /// The title of the block of the form.
  private static var formTitle: String {
    String(localized: "Session Options", bundle: .module)
  }

  /// One section of the menu for each category, with its controls.
  ///
  /// - Parameter sections: The sections to show.
  /// - Returns: The sections.
  private func sectionList(_ sections: [CategorySection]) -> some View {
    ForEach(sections) { section in
      Section {
        ForEach(section.options, id: \.configId) { option in
          ConfigOptionControl(option: option, session: session)
        }
      } header: {
        Text(section.title)
          .accessibilityIdentifier(Self.sectionIdentifier(for: section))
      }
    }
  }
}

/// The control of one ACP `SessionConfigOption` in the menu of
/// ``ConfigOptionsView/Style/menu``: an EditorKit `ChoiceField` in the menu
/// style for a select and a `ToggleField` for a boolean.
struct ConfigOptionControl: View {
  /// The option to show, as the session model holds it.
  let option: SessionConfigOption

  /// The session model that gets each change.
  let session: SessionModel

  /// The report that gets the method of each request that a change starts,
  /// or `nil`.
  @Environment(\.requestStartReport) private var reportRequestStart

  var body: some View {
    control
      .help(option.description ?? option.name)
      .accessibilityIdentifier(ConfigOptionsView.controlIdentifier(for: option.configId))
  }

  /// The field of the type of ``option``.
  @ViewBuilder private var control: some View {
    switch option.type {
    case .select(let select):
      if let choices = select.choices {
        ChoiceField(
          option.name, selection: binding(select.currentValue, send: SetSessionConfigOptionRequest.Value.id),
          options: choices.choiceOptions
        )
        .pickerStyle(.menu)
      }
    case .boolean(let boolean):
      ToggleField(option.name, isOn: binding(boolean.currentValue, send: SetSessionConfigOptionRequest.Value.boolean))
    case .unknown:
      EmptyView()
    }
  }

  /// A binding for the control of ``option``.
  ///
  /// - Parameters:
  ///   - current: The value that the session model holds.
  ///   - send: The function that makes the request value of a new value.
  /// - Returns: The binding from
  ///   `SessionModel.makeConfigBinding(for:current:reporting:send:)`, with
  ///   the ``SwiftUI/EnvironmentValues/requestStartReport`` of the view.
  private func binding<Value: Equatable>(
    _ current: Value,
    send: @escaping (Value) -> SetSessionConfigOptionRequest.Value
  ) -> Binding<Value> {
    session.makeConfigBinding(for: option.configId, current: current, reporting: reportRequestStart, send: send)
  }
}

#Preview("Configuration form") {
  ConfigOptionsView(session: PreviewFixtures.configuredSession, style: .form)
}

#Preview("Configuration menu") {
  ConfigOptionsView(session: PreviewFixtures.configuredSession)
}
