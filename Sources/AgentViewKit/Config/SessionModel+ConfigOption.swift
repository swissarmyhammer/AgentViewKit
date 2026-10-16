import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The config option requests of a session model (plan.md §3.2 "Other
/// requests").
extension SessionModel {
  /// The ACP method of the set-config-option request.
  private static let setConfigOptionMethod = "session/set_config_option"

  /// A binding for the control of one config option.
  ///
  /// The getter gives `current`, the value that ``configOptions`` holds. The
  /// setter sends a new value with `setConfigOption(_:)` and keeps no copy of
  /// it. The control shows the new value when the agent reports it in a
  /// later `config_option_update`. A failed call adds an error entry, and the
  /// control keeps the value of the model.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - current: The value of the option in the model.
  ///   - report: The report that gets `session/set_config_option` when the
  ///     setter starts a request, or `nil`.
  ///   - send: The function that makes the request value of a new value.
  /// - Returns: The binding.
  func makeConfigBinding<Value: Equatable>(
    for id: SessionConfigId,
    current: Value,
    reporting report: ObservationReport<String>? = nil,
    send: @escaping (Value) -> SetSessionConfigOptionRequest.Value
  ) -> Binding<Value> {
    Binding(
      get: { current },
      set: { newValue in
        guard newValue != current else { return }
        self.startSetConfigOption(id, to: send(newValue), reporting: report)
      })
  }

  /// Starts a main-actor task that sends `session/set_config_option` with
  /// `setConfigOption(_:)`.
  ///
  /// ``makeConfigBinding(for:current:reporting:send:)`` and the "switch to
  /// auto" button of ``PermissionView`` call this function.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - value: The new value.
  ///   - report: The report that gets `session/set_config_option` in the
  ///     same step, before the task starts, or `nil`.
  func startSetConfigOption(
    _ id: SessionConfigId, to value: SetSessionConfigOptionRequest.Value,
    reporting report: ObservationReport<String>? = nil
  ) {
    let request = SetSessionConfigOptionRequest(configId: id, sessionId: sessionId, value: value)
    startRequest(Self.setConfigOptionMethod, reporting: report) { try await self.setConfigOption(request) }
  }
}
