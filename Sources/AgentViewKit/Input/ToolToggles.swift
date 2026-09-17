import SwiftUI

/// The toggles that turn the tools of the agent on and off (plan.md §9 D).
///
/// ``Style/menu`` shows the toggles in a menu for the composer accessory.
/// ``Style/list`` shows them in a form, for a sheet or a popover.
///
/// The view gets its tools in one of two ways:
///
/// - ``init(tools:style:onToggle:)`` shows a host list. A toggle calls the
///   host closure with the tool identifier and the new value. The host
///   updates the list.
/// - ``init(style:onToggle:)`` shows the tools of each connection of the
///   ambient ``ConnectionStore``, one section for each connection. A toggle
///   calls ``ConnectionStore/setToolEnabled(_:_:_:)``, then the host closure.
///
/// The view is empty when it has no tool.
public struct ToolToggles: View {
  /// The host closure that a toggle calls with the tool identifier and the
  /// new value.
  public typealias OnToggle = @MainActor (ToolToggleID, Bool) -> Void

  /// The presentation of a ``ToolToggles``.
  public enum Style: Sendable, Hashable {
    /// A menu button for the composer accessory. The toggles are in the
    /// menu.
    case menu

    /// A form that shows each toggle in place.
    case list
  }

  /// The tools of one section.
  struct ToolSection: Identifiable {
    /// The connection of the tools, or `nil` for a host list.
    let connection: ConnectionID?

    /// The header of the section, or `nil` for no header.
    let title: String?

    /// The tools, in the order to show.
    let tools: [ToolToggle]

    /// The identifier of the section: the connection identifier, or an empty
    /// string for a host list.
    var id: String { connection?.rawValue ?? "" }
  }

  /// The accessibility identifier of the menu button of ``Style/menu``.
  public static let menuIdentifier = "tool-toggles-menu"

  /// The accessibility identifier of the form of ``Style/list``.
  public static let listIdentifier = "tool-toggles"

  /// The start of the accessibility identifier of each toggle.
  public static let toggleIdentifierPrefix = "tool-toggle-"

  /// The SF Symbol of the menu button.
  static let menuSymbolName = "wrench.and.screwdriver"

  /// The host list, or `nil` to read the tools from the connection store.
  let tools: [ToolToggle]?

  /// The presentation of the view.
  let style: Style

  /// The host closure that a toggle calls.
  let onToggle: OnToggle?

  @Environment(\.connectionStore) private var store

  /// Makes the view for a host list of tools.
  ///
  /// - Parameters:
  ///   - tools: The tools, in the order to show.
  ///   - style: The presentation of the view.
  ///   - onToggle: The host closure that a toggle calls with the tool
  ///     identifier and the new value.
  public init(tools: [ToolToggle], style: Style = .menu, onToggle: @escaping OnToggle) {
    self.tools = tools
    self.style = style
    self.onToggle = onToggle
  }

  /// Makes the view for the tools of the ambient ``ConnectionStore``.
  ///
  /// - Parameters:
  ///   - style: The presentation of the view.
  ///   - onToggle: The host closure that a toggle calls after the store
  ///     changes, or `nil` for no call.
  public init(style: Style = .menu, onToggle: OnToggle? = nil) {
    self.tools = nil
    self.style = style
    self.onToggle = onToggle
  }

  /// The accessibility identifier of the toggle of a tool.
  ///
  /// A tool identifier is unique only in its connection, so the identifier
  /// of a store tool holds the connection identifier too.
  ///
  /// - Parameters:
  ///   - tool: The identifier of the tool.
  ///   - connection: The connection of the tool, or `nil` for a host list.
  /// - Returns: `tool-toggle-<tool>` for a host list, or
  ///   `tool-toggle-<connection>-<tool>` for a store tool.
  public static func toggleIdentifier(for tool: ToolToggleID, in connection: ConnectionID? = nil)
    -> String
  {
    let value = connection.map { "\($0.rawValue)-\(tool.rawValue)" } ?? tool.rawValue
    return AccessibilityIdentifier.make(prefix: toggleIdentifierPrefix, value: value)
  }

  /// The sections to show.
  ///
  /// - Returns: One section for a host list with a tool. Otherwise one
  ///   section for each store connection with a tool, in store order.
  private var sections: [ToolSection] {
    if let tools {
      return tools.isEmpty ? [] : [ToolSection(connection: nil, title: nil, tools: tools)]
    }
    return (store?.connections ?? []).compactMap { connection in
      connection.tools.isEmpty
        ? nil
        : ToolSection(connection: connection.id, title: connection.name, tools: connection.tools)
    }
  }

  public var body: some View {
    let sections = sections
    if !sections.isEmpty {
      switch style {
      case .menu:
        Menu(String(localized: "Tools"), systemImage: Self.menuSymbolName) {
          sectionList(sections)
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help(String(localized: "Turn tools on or off"))
        .accessibilityIdentifier(Self.menuIdentifier)
      case .list:
        Form {
          sectionList(sections)
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(Self.listIdentifier)
      }
    }
  }

  /// One section for each connection, with a toggle for each tool.
  ///
  /// - Parameter sections: The sections to show.
  /// - Returns: The sections.
  private func sectionList(_ sections: [ToolSection]) -> some View {
    ForEach(sections) { section in
      Section {
        ForEach(section.tools) { tool in
          // On macOS 27 a switch style has no accessibility label of its
          // own, and a grouped form makes a switch by default. So the view
          // sets the check box style, as ConfigOptionsView does.
          Toggle(tool.name, isOn: binding(for: tool, in: section.connection))
            .toggleStyle(.checkbox)
            .accessibilityIdentifier(Self.toggleIdentifier(for: tool.id, in: section.connection))
        }
      } header: {
        if let title = section.title {
          Text(title)
        }
      }
    }
  }

  /// A binding that reads `tool` and writes to the store and the host
  /// closure.
  ///
  /// - Parameters:
  ///   - tool: The tool of the toggle.
  ///   - connection: The connection of the tool, or `nil` for a host list.
  /// - Returns: The binding of the toggle.
  private func binding(for tool: ToolToggle, in connection: ConnectionID?) -> Binding<Bool> {
    let store = store
    let onToggle = onToggle
    return Binding(
      get: { tool.isEnabled },
      set: { isEnabled in
        if let connection {
          store?.setToolEnabled(connection, tool.id, isEnabled)
        }
        onToggle?(tool.id, isEnabled)
      }
    )
  }
}
