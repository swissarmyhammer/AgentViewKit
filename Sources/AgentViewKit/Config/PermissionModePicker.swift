import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The `mode` config option of a session as a segmented EditorKit
/// `ChoiceField`, for the accessory of the composer (plan.md §3.2
/// "Last-value state", §9 E, §11 decision 16).
///
/// The view reads `SessionModel.configOptions` in its body, and shows the
/// first select option of the `mode` category, with one segment for each
/// value. The segments ignore the groups of grouped choices. Each value is
/// also a named accessibility action of the control, the name of the value.
/// When the model has no such option, or `configOptions` is `nil` or empty,
/// the view is empty.
///
/// A change calls `SessionModel.setConfigOption(_:)` with an `id` value. The
/// control shows the value of the model only, and keeps no copy of the
/// selected value: the new value shows when the agent reports it in a later
/// `config_option_update`. A failed call adds an error entry to the
/// transcript.
public struct PermissionModePicker: View {
  /// The accessibility identifier of the segmented control.
  public static let pickerIdentifier = "permission-mode-picker"

  /// The session model whose mode option the view shows.
  let session: SessionModel

  /// Makes the view.
  ///
  /// - Parameter session: The session model whose mode option the view
  ///   shows.
  public init(session: SessionModel) {
    self.session = session
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

  /// The segmented choice of the mode option, or nothing when the session
  /// reports no select option of the `mode` category.
  public var body: some View {
    if let option = Self.modeOption(in: session.configOptions ?? []),
      case .select(let select) = option.type,
      let choices = select.choices
    {
      let selection = session.makeConfigBinding(
        for: option.configId, current: select.currentValue, send: SetSessionConfigOptionRequest.Value.id)
      ChoiceField(option.name, selection: selection, options: choices.options.map { $0.choiceOption() })
        .pickerStyle(.segmented)
        .help(ConfigOptionFields.tooltip(of: option))
        .accessibilityIdentifier(Self.pickerIdentifier)
        .agentControlScope(Self.pickerIdentifier)
    }
  }
}

#Preview("Permission mode") {
  PermissionModePicker(session: PreviewFixtures.configuredSession)
}
