import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The `mode` config option of a session as a segmented control, for the
/// accessory of the composer (plan.md §3.2 "Last-value state",
/// §9 E, §11 decision 16).
///
/// The view reads `SessionModel.configOptions` in its body, and shows the
/// first select option of the `mode` category, with one segment for each
/// value. The segments ignore the groups of grouped choices. When the model
/// has no such option, or `configOptions` is `nil` or empty, the view is
/// empty.
///
/// A change calls `SessionModel.setConfigOption(_:)` with an `id` value. The
/// control shows the value of the model only, and keeps no copy of the
/// selected value: the new value shows when the agent reports it in a later
/// `config_option_update`. A failed call adds an error entry to the
/// transcript.
public struct PermissionModePicker: View {
  /// The accessibility identifier of the segmented control.
  public static let pickerIdentifier = "permission-mode-picker"

  /// The start of the accessibility identifier of each segment.
  public static let segmentIdentifierPrefix = "permission-mode-value-"

  /// The session model whose mode option the view shows.
  let session: SessionModel

  /// Makes the view.
  ///
  /// - Parameter session: The session model whose mode option the view
  ///   shows.
  public init(session: SessionModel) {
    self.session = session
  }

  /// The accessibility identifier of the segment of a value.
  ///
  /// - Parameter value: The `value` id of the choice.
  /// - Returns: The identifier, such as `permission-mode-value-auto`.
  public static func segmentIdentifier(for value: String) -> String {
    AccessibilityIdentifier.make(prefix: segmentIdentifierPrefix, value: value)
  }

  /// The option that the view shows.
  ///
  /// - Parameter options: The config options of the session.
  /// - Returns: The first select option of the `mode` category, or `nil`.
  public static func modeOption(in options: [SessionConfigOption]) -> SessionConfigOption? {
    options.first { option in
      guard option.category == .mode, case .select = option.type else { return false }
      return true
    }
  }

  public var body: some View {
    if let option = Self.modeOption(in: session.configOptions ?? []),
      case .select(let select) = option.type,
      let choices = select.choices
    {
      let selection = session.makeConfigBinding(
        for: option.configId, current: select.currentValue, send: SetSessionConfigOptionRequest.Value.id)
      Picker(option.name, selection: selection) {
        ForEach(choices.options, id: \.value) { value in
          Text(value.name)
            .tag(value.value)
            .accessibilityIdentifier(Self.segmentIdentifier(for: value.value.rawValue))
        }
      }
      .pickerStyle(.segmented)
      .help(option.description ?? option.name)
      .accessibilityIdentifier(Self.pickerIdentifier)
    }
  }
}
