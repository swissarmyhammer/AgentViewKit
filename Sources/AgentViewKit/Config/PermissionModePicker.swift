import SwiftUI

/// The `mode` config option of a thread as a segmented control, for the
/// accessory of the composer (plan.md §9 E, §11 decision 16).
///
/// Pass ``AgentThread/configOptions`` as `options`. The view shows the first
/// select option of the ``ConfigOption/Category/mode`` category, with one
/// segment for each value. The segments ignore the groups of grouped
/// choices. When the list has no such option, the view is empty.
///
/// A change calls ``AgentThreadActions/setConfigOption(_:_:)`` of the
/// `threadActions` environment value with ``ConfigValue/id(_:)``. The
/// control shows the value that the source gives.
public struct PermissionModePicker: View {
  /// The accessibility identifier of the segmented control.
  public static let pickerIdentifier = "permission-mode-picker"

  /// The start of the accessibility identifier of each segment.
  public static let segmentIdentifierPrefix = "permission-mode-value-"

  /// The options of the thread.
  let options: [ConfigOption]

  @Environment(\.threadActions) private var actions

  /// Makes the view.
  ///
  /// - Parameter options: The options of the thread, such as
  ///   ``AgentThread/configOptions``.
  public init(options: [ConfigOption]) {
    self.options = options
  }

  /// The accessibility identifier of the segment of a value.
  ///
  /// - Parameter value: The ``SelectOption/id`` of the value.
  /// - Returns: The identifier, such as `permission-mode-value-auto`.
  public static func segmentIdentifier(for value: String) -> String {
    segmentIdentifierPrefix + value
  }

  /// The option that the view shows.
  ///
  /// - Parameter options: The options of the thread.
  /// - Returns: The first select option of the `mode` category, or `nil`.
  public static func modeOption(in options: [ConfigOption]) -> ConfigOption? {
    options.first { option in
      guard option.category == .mode, case .select = option.kind else { return false }
      return true
    }
  }

  public var body: some View {
    if let option = Self.modeOption(in: options),
      case .select(let current, let choices) = option.kind
    {
      let selection = configOptionBinding(
        id: option.id, current: current, actions: actions, send: ConfigValue.id)
      Picker(option.name, selection: selection) {
        ForEach(choices.options) { value in
          Text(value.name)
            .tag(value.id)
            .accessibilityIdentifier(Self.segmentIdentifier(for: value.id))
        }
      }
      .pickerStyle(.segmented)
      .help(option.description ?? option.name)
      .accessibilityIdentifier(Self.pickerIdentifier)
    }
  }
}
