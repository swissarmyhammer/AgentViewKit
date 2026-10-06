import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The config option requests of a session model (update.md §4.2 "Other
/// requests", §4.3 `setConfigOption(_:)`).
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
  ///   - send: The function that makes the request value of a new value.
  /// - Returns: The binding.
  func makeConfigBinding<Value: Equatable>(
    for id: SessionConfigId,
    current: Value,
    send: @escaping (Value) -> SetSessionConfigOptionRequest.Value
  ) -> Binding<Value> {
    Binding(
      get: { current },
      set: { newValue in
        guard newValue != current else { return }
        self.startSetConfigOption(id, to: send(newValue))
      })
  }

  /// Starts a main-actor task that sends `session/set_config_option` with
  /// `setConfigOption(_:)`.
  ///
  /// - Parameters:
  ///   - id: The id of the option.
  ///   - value: The new value.
  private func startSetConfigOption(_ id: SessionConfigId, to value: SetSessionConfigOptionRequest.Value) {
    let request = SetSessionConfigOptionRequest(configId: id, sessionId: sessionId, value: value)
    startRequest(Self.setConfigOptionMethod) { try await self.setConfigOption(request) }
  }
}
