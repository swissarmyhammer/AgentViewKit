import SwiftUI

/// The identifier of a ``ToolToggle`` in the host list of a ``ToolToggles``.
///
/// For an MCP tool, this is the tool name.
public typealias ToolToggleID = Identifier<ToolToggle>

/// A tool that the user can turn on or off.
public nonisolated struct ToolToggle: Sendable, Hashable, Identifiable {
  /// The identifier of the tool in the host list.
  public let id: ToolToggleID
  /// The name of the tool that the user sees.
  public var name: String
  /// Whether the agent can use the tool.
  public var isEnabled: Bool

  /// Makes a tool toggle.
  ///
  /// - Parameters:
  ///   - id: The identifier of the tool in the host list.
  ///   - name: The name of the tool that the user sees.
  ///   - isEnabled: Whether the agent can use the tool.
  public init(id: ToolToggleID, name: String, isEnabled: Bool) {
    self.id = id
    self.name = name
    self.isEnabled = isEnabled
  }
}

/// The toggles that turn the tools of the agent on and off (plan.md §9 D).
///
/// ``Style/menu`` shows the toggles in a menu for the composer accessory.
/// ``Style/list`` shows them in a form, for a sheet or a popover.
///
/// The view shows a host list of tools. A toggle calls the host closure with
/// the tool identifier and the new value. The host updates the list. The
/// view is empty when the list has no tool.
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

  /// The accessibility identifier of the menu button of ``Style/menu``.
  public static let menuIdentifier = "tool-toggles-menu"

  /// The accessibility identifier of the form of ``Style/list``.
  public static let listIdentifier = "tool-toggles"

  /// The start of the accessibility identifier of each toggle.
  public static let toggleIdentifierPrefix = "tool-toggle-"

  /// The SF Symbol of the menu button.
  static let menuSymbolName = "wrench.and.screwdriver"

  /// The host list, in the order to show.
  let tools: [ToolToggle]

  /// The presentation of the view.
  let style: Style

  /// The host closure that a toggle calls.
  let onToggle: OnToggle

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

  /// The accessibility identifier of the toggle of a tool.
  ///
  /// - Parameter tool: The identifier of the tool.
  /// - Returns: `tool-toggle-<tool>`.
  public static func toggleIdentifier(for tool: ToolToggleID) -> String {
    AccessibilityIdentifier.make(prefix: toggleIdentifierPrefix, value: tool.rawValue)
  }

  public var body: some View {
    if !tools.isEmpty {
      switch style {
      case .menu:
        Menu(String(localized: "Tools"), systemImage: Self.menuSymbolName) {
          toolSection
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help(String(localized: "Turn tools on or off"))
        .accessibilityIdentifier(Self.menuIdentifier)
      case .list:
        Form {
          toolSection
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(Self.listIdentifier)
      }
    }
  }

  /// One section with a toggle for each tool.
  private var toolSection: some View {
    Section {
      ForEach(tools) { tool in
        // On macOS 27 a switch style has no accessibility label of its own,
        // and a grouped form makes a switch by default. So the view sets the
        // check box style, as ConfigOptionsView does.
        Toggle(tool.name, isOn: binding(for: tool))
          .toggleStyle(.checkbox)
          .accessibilityIdentifier(Self.toggleIdentifier(for: tool.id))
      }
    }
  }

  /// A binding that reads `tool` and writes to the host closure.
  ///
  /// - Parameter tool: The tool of the toggle.
  /// - Returns: The binding of the toggle.
  private func binding(for tool: ToolToggle) -> Binding<Bool> {
    let onToggle = onToggle
    return Binding(
      get: { tool.isEnabled },
      set: { isEnabled in onToggle(tool.id, isEnabled) }
    )
  }
}
