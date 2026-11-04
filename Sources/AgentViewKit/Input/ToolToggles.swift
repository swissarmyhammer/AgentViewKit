import EditorInspector
import Observation
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
/// ``Style/list`` shows them as the content of an inspector, a sheet or a
/// popover: an EditorKit `InspectorView` of the list, with one toggle row for
/// each tool. Its rows take EditorKit's scheme ids: the view and the
/// inspection are ``listIdentifier``, and the field is the id of the tool, such
/// as `inspection:tool-toggles/object:tool-toggles-1/field:tools.search`.
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

    /// The content of an inspector: an EditorKit `InspectorView` with one
    /// toggle row for each tool.
    case list
  }

  /// The accessibility identifier of the menu button of ``Style/menu``.
  public static let menuIdentifier = "tool-toggles-menu"

  /// The identifier of the `InspectorView` of ``Style/list``: the first
  /// part of the accessibility identifier of each of its rows.
  public static let listIdentifier = "tool-toggles"

  /// The identifier of the group of the rows of ``Style/list``.
  static let groupIdentifier = "tools"

  /// The start of the accessibility identifier of each toggle of the menu of
  /// ``Style/menu``.
  public static let toggleIdentifierPrefix = "tool-toggle-"

  /// The SF Symbol of the menu button.
  static let menuSymbolName = SharedSymbol.tool

  /// The host list, in the order to show.
  let tools: [ToolToggle]

  /// The presentation of the view.
  let style: Style

  /// The host closure that a toggle calls.
  let onToggle: OnToggle

  /// The list that the rows of ``Style/list`` read, which follows ``tools``.
  @State private var list: ToolToggleList

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
    _list = State(initialValue: ToolToggleList(tools: tools))
  }

  /// The accessibility identifier of the toggle of a tool in the menu of
  /// ``Style/menu``.
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
        Menu(String(localized: "Tools", bundle: .module), systemImage: Self.menuSymbolName) {
          toolSection
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help(String(localized: "Turn tools on or off", bundle: .module))
        .accessibilityIdentifier(Self.menuIdentifier)
      case .list:
        InspectorView(list, Self.inspection(of: tools, onToggle: onToggle), id: Self.listIdentifier)
          .onChange(of: tools) { list.tools = tools }
      }
    }
  }

  /// The inspection of ``Style/list``: one group with a toggle row for each
  /// tool of `tools`, whose edit calls `onToggle`.
  ///
  /// - Parameters:
  ///   - tools: The tools, in the order to show.
  ///   - onToggle: The host closure that a toggle calls.
  /// - Returns: The inspection.
  private static func inspection(of tools: [ToolToggle], onToggle: @escaping OnToggle) -> Inspection<ToolToggleList> {
    Inspection(id: listIdentifier, title: String(localized: "Tools", bundle: .module)) {
      FieldGroup(FieldLabel(localized: "Available", bundle: .module)) {
        for tool in tools {
          Field(.verbatim(tool.name)) { list in list.isEnabled(tool.id) }
            .editing { _, isEnabled in onToggle(tool.id, isEnabled) }
            .identifier(tool.id.rawValue)
        }
      }
      .identifier(groupIdentifier)
    }
  }

  /// One section of the menu with a toggle for each tool.
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

/// The host list of a ``ToolToggles`` in the ``ToolToggles/Style/list``
/// style, as the object of its `InspectorView`.
///
/// The view writes the host list here each time it changes, so the rows read
/// the state of each tool when they draw.
@Observable
final class ToolToggleList {
  /// The host list, in the order to show.
  var tools: [ToolToggle]

  /// Makes the list of `tools`.
  ///
  /// - Parameter tools: The host list.
  init(tools: [ToolToggle]) {
    self.tools = tools
  }

  /// Whether the agent can use a tool.
  ///
  /// - Parameter id: The identifier of the tool.
  /// - Returns: The state of the tool, or `false` when the list has no tool
  ///   with the identifier.
  func isEnabled(_ id: ToolToggleID) -> Bool {
    tools.first { $0.id == id }?.isEnabled ?? false
  }
}

#Preview("Tool toggles") {
  @Previewable @State var tools = [
    ToolToggle(id: ToolToggleID("web-search"), name: "Web search", isEnabled: true),
    ToolToggle(id: ToolToggleID("terminal"), name: "Terminal", isEnabled: false),
  ]
  ToolToggles(tools: tools, style: .list) { id, isEnabled in
    if let index = tools.firstIndex(where: { $0.id == id }) {
      tools[index].isEnabled = isEnabled
    }
  }
}
